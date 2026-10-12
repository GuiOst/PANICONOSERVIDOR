class_name Door
extends Node3D
## Porta industrial articulada (abre/fecha com E).
##
## Estrutura esperada da cena (scenes/interactables/industrial_door.tscn):
##   Door (este script)
##   ├─ Frame (StaticBody3D)            batente fixo
##   └─ Panel (AnimatableBody3D)        folha da porta, com origem NA DOBRADIÇA
##       ├─ ...meshes e CollisionShape3D
##       ├─ InteractArea (Interactable)
##       └─ DoorAudio (AudioStreamPlayer3D)
##
## Por que não usar física "de verdade" (RigidBody + HingeJoint)?
##   Portas físicas podem tremer, travar ou ser empurradas pelo jogador.
##   Aqui a abertura é um valor 0..1 (`_progress`) convertido em ângulo:
##   determinístico, reversível a qualquer momento e sem estados presos.
##   O AnimatableBody3D mantém a colisão correta durante o movimento.
##
## Antes de cada passo de movimento, a porta verifica se vai bater no
## jogador; se for, ela espera (abrindo) ou volta a abrir (fechando).

signal state_changed(is_open: bool)
## A folha começou a se mover. `from_rest`: estava parada num extremo.
signal motion_started(opening: bool, from_rest: bool)
## A folha parou porque havia alguém no caminho.
signal motion_blocked
## Alguém tentou abrir com a porta trancada.
signal locked_attempt

enum State { CLOSED, OPENING, OPEN, CLOSING }

@export_group("Movimento")
## Ângulo máximo de abertura (graus).
@export_range(10.0, 170.0, 1.0) var open_angle_deg: float = 100.0
## Tempo (segundos) para abrir ou fechar completamente.
@export_range(0.2, 5.0, 0.05) var open_duration: float = 1.1
## Abre para longe do jogador (permite abrir pelos dois lados).
@export var open_away_from_player: bool = true
## Sentido usado quando `open_away_from_player` é falso (1 ou -1).
@export_enum("Para trás:1", "Para frente:-1") var fixed_direction: int = 1
## Começa aberta.
@export var start_open: bool = false

@export_group("Tranca")
@export var locked: bool = false:
	set(v):
		locked = v
		_update_prompt()
@export var locked_message: String = "Trancada."

@export_group("Textos")
@export var prompt_open: String = "abrir"
@export var prompt_close: String = "fechar"
@export var prompt_locked: String = "tentar abrir"

var state: State = State.CLOSED
var _progress: float = 0.0       # 0 = fechada, 1 = totalmente aberta
var _direction: float = 1.0      # sentido da abertura atual
var _blocked_time: float = 0.0
var _query: PhysicsShapeQueryParameters3D
var _was_blocked: bool = false
var _sounds: DoorAudio

@onready var _panel: AnimatableBody3D = $Panel
@onready var _panel_shape: CollisionShape3D = $Panel/PanelShape
@onready var _interactable: Interactable = $Panel/InteractArea


func _ready() -> void:
	_direction = float(fixed_direction)
	if start_open:
		_progress = 1.0
		state = State.OPEN
	_apply_angle()
	_interactable.interacted.connect(_on_interacted)
	# Multiplayer: o host escolhe o sentido e todos usam o mesmo.
	_interactable.net_params_provider = _net_params
	_interactable.set_meta(&"net_state_target", self)
	_setup_sounds()
	# Consulta reutilizada (sem alocar a cada quadro) para detectar o jogador
	# no caminho da porta. Camada 2 = jogadores.
	# Forma de teste: a folha "engordada" alguns centímetros. Ela encosta no
	# jogador ANTES da folha real, então a porta para sem empurrá-lo.
	_query = PhysicsShapeQueryParameters3D.new()
	var probe := BoxShape3D.new()
	var box := _panel_shape.shape as BoxShape3D
	var base_size := box.size if box else Vector3(1.38, 2.37, 0.08)
	probe.size = base_size + Vector3(0.08, -0.04, 0.12)
	_query.shape = probe
	_query.collision_mask = 1 << 1
	_query.margin = 0.0
	_update_prompt()
	set_physics_process(false) # só processa enquanto se move


## Alterna entre abrir/fechar. `by` é o nó que pediu (para saber o lado).
func toggle(by: Node3D = null) -> void:
	if state == State.OPEN or state == State.OPENING:
		close()
	else:
		open(by)


func open(by: Node3D = null) -> void:
	if locked:
		return
	if state == State.OPEN or state == State.OPENING:
		return
	# Só escolhe um novo sentido se estiver totalmente fechada; se estiver
	# fechando, apenas inverte o movimento (evita a porta "pular" de lado).
	if _progress <= 0.001:
		var net_dir: Variant = _interactable.last_net_params.get("dir") if _interactable else null
		if net_dir != null:
			_direction = 1.0 if float(net_dir) >= 0.0 else -1.0
		else:
			_direction = _choose_direction(by)
	_set_state(State.OPENING)


func close() -> void:
	if state == State.CLOSED or state == State.CLOSING:
		return
	_set_state(State.CLOSING)


func is_open() -> bool:
	return state == State.OPEN or state == State.OPENING


func _on_interacted(interactor: Node) -> void:
	if locked:
		locked_attempt.emit()
		if interactor and interactor.has_method(&"show_feedback"):
			interactor.call(&"show_feedback", locked_message)
		return
	toggle(interactor as Node3D)


func _physics_process(delta: float) -> void:
	var target := 1.0 if state == State.OPENING else 0.0
	var step := delta / maxf(open_duration, 0.01)
	var next := move_toward(_progress, target, step)

	if _is_blocked(next):
		if not _was_blocked:
			_was_blocked = true
			motion_blocked.emit()
		_blocked_time += delta
		# Fechando e alguém no caminho por um tempo: reabre (como portas reais
		# com sensor). Abrindo: apenas espera o caminho liberar.
		# Online, SÓ o host toma essa decisão e avisa todos.
		if state == State.CLOSING and _blocked_time > 0.35 and _decides_locally():
			_blocked_time = 0.0
			_set_state(State.OPENING)
			_broadcast_state()
		return
	_blocked_time = 0.0
	if _was_blocked:
		_was_blocked = false
		motion_started.emit(state == State.OPENING, false) # retomou o movimento
	_progress = next
	_apply_angle()

	if is_equal_approx(_progress, target):
		_set_state(State.OPEN if target >= 1.0 else State.CLOSED)
		# Ao terminar, o host confirma o estado final (corrige atrasos).
		if _decides_locally() and Net.is_session_active():
			_broadcast_state()


# ------------------------------------------------------------ multiplayer
## Offline ou host: decide bloqueios. Clientes só seguem o host.
func _decides_locally() -> bool:
	return not Net.is_session_active() or Net.is_host()


func _net_params(interactor: Node) -> Dictionary:
	if not locked and _progress <= 0.001 and not is_open():
		return {"dir": _choose_direction(interactor as Node3D)}
	return {}


func _broadcast_state() -> void:
	if Net.is_host() and Net.is_session_active():
		Net.broadcast_object_state(_interactable, get_net_state())


func get_net_state() -> Dictionary:
	return {"s": int(state), "p": _progress, "d": _direction, "l": locked}


## Recebido do host: corrige estado/posição sem tocar sons repetidos.
func apply_net_state(st: Dictionary) -> void:
	var new_state := int(st.get("s", state)) as State
	_direction = 1.0 if float(st.get("d", _direction)) >= 0.0 else -1.0
	locked = bool(st.get("l", locked))
	_progress = clampf(float(st.get("p", _progress)), 0.0, 1.0)
	_apply_angle()
	if new_state != state:
		_set_state(new_state)
	else:
		_update_prompt()


func _set_state(new_state: State) -> void:
	var from_rest := _progress <= 0.001 or _progress >= 0.999
	state = new_state
	var moving := new_state == State.OPENING or new_state == State.CLOSING
	set_physics_process(moving)
	_was_blocked = false
	if moving:
		motion_started.emit(new_state == State.OPENING, from_rest)
	_update_prompt()
	if new_state == State.OPEN:
		state_changed.emit(true)
	elif new_state == State.CLOSED:
		state_changed.emit(false)


## Cria (se necessário) o componente de som e liga os eventos de movimento.
## Os sons ficam presos à folha, então se movem junto com ela.
func _setup_sounds() -> void:
	_sounds = get_node_or_null(^"Panel/DoorSounds") as DoorAudio
	if _sounds == null:
		_sounds = DoorAudio.new()
		_sounds.name = "DoorSounds"
		_panel.add_child(_sounds)
	motion_started.connect(_sounds.on_motion_started)
	motion_blocked.connect(_sounds.on_motion_blocked)
	state_changed.connect(_sounds.on_motion_finished)
	locked_attempt.connect(_sounds.on_locked_attempt)


func _apply_angle() -> void:
	if _panel == null:
		_panel = get_node_or_null(^"Panel") as AnimatableBody3D
		if _panel == null:
			return
	# smoothstep: começa e termina devagar (aparência de porta pesada)
	var eased := _progress * _progress * (3.0 - 2.0 * _progress)
	_panel.rotation.y = deg_to_rad(open_angle_deg) * eased * _direction


func _angle_for(progress: float) -> float:
	var eased := progress * progress * (3.0 - 2.0 * progress)
	return deg_to_rad(open_angle_deg) * eased * _direction


## Verdadeiro se mover a folha para `next_progress` invadiria um jogador.
## Ao ABRIR, um jogador que já estava encostado na porta não bloqueia
## (a folha se afasta dele); só um contato novo bloqueia.
func _is_blocked(next_progress: float) -> bool:
	if not _overlaps_player_at(next_progress):
		return false
	if state == State.OPENING and _overlaps_player_at(_progress):
		return false
	return true


func _overlaps_player_at(progress: float) -> bool:
	if _query == null or not is_inside_tree():
		return false
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var panel_parent := _panel.get_parent() as Node3D
	var local := Transform3D(Basis(Vector3.UP, _angle_for(progress)), _panel.position)
	_query.transform = panel_parent.global_transform * local * _panel_shape.transform
	return not space.intersect_shape(_query, 1).is_empty()


func _choose_direction(by: Node3D) -> float:
	if not open_away_from_player or by == null:
		return float(fixed_direction)
	# Lado do jogador em relação à porta (eixo Z local). Ângulo positivo
	# empurra a ponta livre da folha para -Z, ou seja, para longe de quem
	# está em +Z.
	var local_pos := global_transform.affine_inverse() * by.global_position
	return 1.0 if local_pos.z >= 0.0 else -1.0


func _update_prompt() -> void:
	if _interactable == null:
		return
	if locked:
		_interactable.prompt_text = prompt_locked
	elif state == State.OPEN or state == State.OPENING:
		_interactable.prompt_text = prompt_close
	else:
		_interactable.prompt_text = prompt_open
