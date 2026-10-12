class_name Player
extends CharacterBody3D
## Corpo do jogador: movimento, gravidade, pulo e corrida.
##
## Responsabilidades SEPARADAS em nós filhos:
##   Head (PlayerLook)       -> mouse, inclinação da câmera, FOV, balanço
##   Flashlight              -> lanterna
##   Interactor              -> raio de interação (tecla E)
##   Footsteps               -> sons de passos
##
## MULTIPLAYER:
##   - Jogador LOCAL (`is_local = true`): lê o teclado em `_gather_input()`,
##     simula a física e envia o próprio estado ao host 20x por segundo.
##   - Jogador REMOTO: não lê entrada nem simula física; recebe "fotos"
##     (snapshots) de posição/rotação e as INTERPOLA com ~100 ms de atraso,
##     o que deixa o movimento suave mesmo com pacotes chegando irregulares.

## Emitido quando o jogador encosta no chão depois de estar no ar.
signal landed(fall_speed: float)

@export_group("Movimento")
## Velocidade andando (m/s).
@export_range(0.5, 10.0, 0.1) var walk_speed: float = 3.0
## Velocidade correndo com Shift (m/s).
@export_range(0.5, 15.0, 0.1) var sprint_speed: float = 5.4
## Quão rápido atinge a velocidade desejada (maior = mais "seco").
@export_range(1.0, 40.0, 0.5) var acceleration: float = 10.0
## Quão rápido para ao soltar as teclas.
@export_range(1.0, 40.0, 0.5) var deceleration: float = 12.0
## Fração de controle no ar (0 = nenhum, 1 = total).
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.3
## Só corre se estiver indo para frente (mais natural em jogos de terror).
@export var sprint_forward_only: bool = true

@export_group("Pulo")
@export var jump_enabled: bool = true
@export_range(1.0, 10.0, 0.1) var jump_velocity: float = 4.2

@export_group("Física")
@export_range(0.1, 4.0, 0.05) var gravity_multiplier: float = 1.0
@export_range(5.0, 80.0, 1.0) var max_fall_speed: float = 40.0

## Falso para jogadores controlados pela rede.
@export var is_local: bool = true

## Id de rede (1 = host). Offline é sempre 1.
var net_id: int = 1
## Nome mostrado acima da cabeça (multiplayer).
var display_name: String = ""
## Cor do macacão (diferencia jogadores).
var suit_color: Color = Color(0.36, 0.38, 0.42)

const INTERP_DELAY := 0.1        ## atraso de interpolação (s)
const MAX_EXTRAPOLATION := 0.2   ## quanto "adivinhar" sem pacotes novos (s)

# Estado de entrada (preenchido localmente ou, no futuro, pela rede).
var move_input: Vector2 = Vector2.ZERO
var wants_sprint: bool = false
var wants_jump: bool = false

var is_sprinting: bool = false
var input_enabled: bool = true:
	set(value):
		input_enabled = value
		if not value:
			move_input = Vector2.ZERO
			wants_sprint = false
			wants_jump = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _was_on_floor: bool = true

# --- rede ---
var _snapshots: Array[Dictionary] = []
var _last_snapshot_seq: int = -1
var _net_grounded: bool = true
var _send_accum: float = 0.0

@onready var look: PlayerLook = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: Flashlight = $Head/Camera3D/Flashlight
@onready var interactor: Interactor = $Head/Camera3D/Interactor


func _ready() -> void:
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(46.0)
	floor_stop_on_slope = true
	# Componentes de entrada só ficam ativos no jogador local.
	look.input_enabled = is_local
	flashlight.input_enabled = is_local
	interactor.input_enabled = is_local
	camera.current = is_local
	_setup_model()
	if not is_local:
		# Lanterna de outro jogador: sem sombra (custa caro e não é necessária).
		flashlight.shadow_enabled = false


## Corpo visível: só aparece para os OUTROS jogadores (você não vê o seu).
func _setup_model() -> void:
	var model := get_node_or_null(^"Model") as Node3D
	var visor := get_node_or_null(^"Head/Visor") as Node3D
	if model:
		model.visible = not is_local
		var mesh := model.get_node_or_null(^"BodyMesh") as MeshInstance3D
		if mesh and mesh.get_surface_override_material(0):
			var mat := mesh.get_surface_override_material(0).duplicate() as StandardMaterial3D
			mat.albedo_color = suit_color
			mesh.set_surface_override_material(0, mat)
		var label := model.get_node_or_null(^"NameLabel") as Label3D
		if label:
			label.text = display_name
	if visor:
		visor.visible = not is_local


## Liga/desliga todos os controles do jogador local (menus, carregamento).
func set_controls_enabled(value: bool) -> void:
	input_enabled = value
	if is_local:
		look.input_enabled = value
		flashlight.input_enabled = value
		interactor.input_enabled = value


## No chão? (remotos usam o que veio pela rede)
func is_grounded() -> bool:
	return is_on_floor() if is_local else _net_grounded


func _physics_process(delta: float) -> void:
	if not is_local:
		_remote_update()
		return
	_gather_input()

	var on_floor := is_on_floor()

	# --- Gravidade ---
	if not on_floor:
		velocity.y = maxf(velocity.y - _gravity * gravity_multiplier * delta, -max_fall_speed)

	# --- Pulo ---
	if wants_jump and jump_enabled and on_floor:
		velocity.y = jump_velocity
	wants_jump = false

	# --- Direção desejada (relativa para onde o corpo está virado) ---
	# Input.get_vector já limita o tamanho a 1: a diagonal não fica mais rápida.
	var wish_dir := global_transform.basis * Vector3(move_input.x, 0.0, move_input.y)
	wish_dir.y = 0.0
	var input_strength := minf(move_input.length(), 1.0)
	if wish_dir.length_squared() > 0.0001:
		wish_dir = wish_dir.normalized() * input_strength

	var moving_forward := move_input.y < -0.2
	is_sprinting = wants_sprint and input_strength > 0.1 and on_floor \
		and (moving_forward or not sprint_forward_only)
	var target_speed := sprint_speed if is_sprinting else walk_speed

	# --- Aceleração suave e independente do FPS ---
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var target := wish_dir * target_speed
	var rate := acceleration if wish_dir.length_squared() > 0.0001 else deceleration
	if not on_floor:
		rate *= air_control
	horizontal = horizontal.lerp(target, 1.0 - exp(-rate * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	var fall_speed := -velocity.y
	move_and_slide()

	var now_on_floor := is_on_floor()
	if now_on_floor and not _was_on_floor:
		landed.emit(fall_speed)
	_was_on_floor = now_on_floor

	_send_state(delta)


# ================================================================ rede
func _send_state(delta: float) -> void:
	if not Net.is_playing():
		return
	_send_accum += delta
	if _send_accum < 1.0 / Net.STATE_RATE:
		return
	_send_accum = fmod(_send_accum, 1.0 / Net.STATE_RATE)
	var flags := 0
	if is_sprinting:
		flags |= Net.FLAG_SPRINT
	if is_on_floor():
		flags |= Net.FLAG_GROUNDED
	if flashlight.is_on:
		flags |= Net.FLAG_FLASHLIGHT
	Net.send_local_state(global_position, rotation.y, look.rotation.x, velocity, flags)


## Recebe um estado da rede (jogadores remotos). Pacotes velhos são ignorados.
func push_snapshot(seq: int, pos: Vector3, yaw: float, pitch: float, vel: Vector3, flags: int) -> void:
	if is_local or seq <= _last_snapshot_seq:
		return
	_last_snapshot_seq = seq
	_snapshots.append({"t": Net.clock(), "pos": pos, "yaw": yaw,
		"pitch": clampf(pitch, -1.55, 1.55), "vel": vel.limit_length(50.0), "flags": flags})
	if _snapshots.size() > 30:
		_snapshots.pop_front()


## Interpola entre as duas fotos que cercam (agora - INTERP_DELAY).
func _remote_update() -> void:
	if _snapshots.is_empty():
		return
	var render_t := Net.clock() - INTERP_DELAY
	# Descarta fotos antigas, mantendo uma antes do instante desenhado.
	while _snapshots.size() >= 2 and float(_snapshots[1].t) <= render_t:
		_snapshots.pop_front()
	var a: Dictionary = _snapshots[0]
	var pos: Vector3
	var yaw: float
	var pitch: float
	var vel: Vector3 = a.vel
	if _snapshots.size() >= 2 and render_t >= float(a.t):
		var b: Dictionary = _snapshots[1]
		var span := maxf(float(b.t) - float(a.t), 0.001)
		var w := clampf((render_t - float(a.t)) / span, 0.0, 1.0)
		pos = (a.pos as Vector3).lerp(b.pos, w)
		yaw = lerp_angle(a.yaw, b.yaw, w)
		pitch = lerpf(a.pitch, b.pitch, w)
		vel = (a.vel as Vector3).lerp(b.vel, w)
	else:
		# Sem foto mais nova: prevê um pouquinho pela velocidade e depois para.
		var extra := clampf(render_t - float(a.t), 0.0, MAX_EXTRAPOLATION)
		pos = a.pos + (a.vel as Vector3) * extra
		yaw = a.yaw
		pitch = a.pitch
		if render_t - float(a.t) > MAX_EXTRAPOLATION:
			vel = Vector3.ZERO
	global_position = pos
	rotation.y = yaw
	look.rotation.x = pitch
	velocity = vel
	var flags: int = a.flags
	is_sprinting = (flags & Net.FLAG_SPRINT) != 0
	var grounded := (flags & Net.FLAG_GROUNDED) != 0
	if grounded and not _net_grounded:
		landed.emit(-vel.y if vel.y < 0.0 else 3.0)
	_net_grounded = grounded
	var light_on := (flags & Net.FLAG_FLASHLIGHT) != 0
	if light_on != flashlight.is_on:
		flashlight.set_on(light_on)


## O host recusou nosso movimento: volta para a última posição aceita.
func net_correct(pos: Vector3) -> void:
	if is_local:
		global_position = pos
		velocity = Vector3.ZERO


## ÚNICO ponto que lê o teclado para movimento.
func _gather_input() -> void:
	if not input_enabled:
		move_input = Vector2.ZERO
		wants_sprint = false
		return
	move_input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	wants_sprint = Input.is_action_pressed(&"sprint")
	if Input.is_action_just_pressed(&"jump"):
		wants_jump = true


## Velocidade horizontal atual (usada por passos e balanço de câmera).
func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Teleporta o jogador com segurança (respawn, início de fase).
func teleport_to(target_transform: Transform3D) -> void:
	global_transform = Transform3D(Basis(Vector3.UP, target_transform.basis.get_euler().y), target_transform.origin)
	velocity = Vector3.ZERO
	look.reset_pitch()
