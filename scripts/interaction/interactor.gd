class_name Interactor
extends RayCast3D
## Raio de interação do jogador (fica preso à câmera).
##
## A cada quadro de física descobre qual Interactable está na mira e avisa a
## interface APENAS quando algo muda (sem criar strings a cada quadro).
## Quando a ação "interact" (E) é pressionada, chama `interact()` no alvo.
##
## O jogador não conhece portas, interruptores etc.: ele só conhece este nó,
## e este nó só conhece o contrato `Interactable`.

## Texto completo para a interface ("" = esconder).
signal prompt_changed(text: String)
## Mensagens curtas de retorno ("Trancada.", "Disjuntor acionado.").
signal feedback_message(text: String)
## Alvo atual mudou (null quando nenhum).
signal target_changed(target: Interactable)

@export_range(0.5, 6.0, 0.1) var interaction_distance: float = 2.2:
	set(value):
		interaction_distance = value
		target_position = Vector3(0.0, 0.0, -interaction_distance)
## Ação do InputMap usada para interagir (o texto da tecla é lido dela).
@export var interact_action: StringName = &"interact"
## Se falso, ignora a entrada (útil para jogadores remotos na Etapa 2).
@export var input_enabled: bool = true

var current_target: Interactable = null
var _current_prompt: String = ""
var _key_label: String = "E"


func _ready() -> void:
	target_position = Vector3(0.0, 0.0, -interaction_distance)
	collide_with_areas = true
	collide_with_bodies = true
	# Camada 1 = mundo (paredes bloqueiam), camada 3 = interativos.
	collision_mask = (1 << 0) | (1 << (Interactable.INTERACTABLE_LAYER - 1))
	hit_from_inside = false
	# Nunca acertar o próprio corpo do jogador.
	var body := _find_owner_body()
	if body:
		add_exception(body)
	_key_label = _read_key_label()


func _physics_process(_delta: float) -> void:
	_update_target()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event.is_action_pressed(interact_action) and not event.is_echo():
		try_interact()


## Tenta interagir com o alvo atual. Retorna true se houve interação.
func try_interact() -> bool:
	force_raycast_update()
	_update_target() # garante que o alvo é o que está na mira AGORA
	if current_target == null:
		return false
	# Offline: interage direto. Online: o pedido vai ao host, que valida e
	# manda todos executarem (veja scripts/network/network_manager.gd).
	var ok: bool = Net.request_interact(current_target, self)
	if ok:
		_refresh_prompt() # o verbo pode ter mudado (abrir -> fechar)
	return ok


## Usado pelos interativos para mostrar uma mensagem curta na tela.
func show_feedback(text: String) -> void:
	feedback_message.emit(text)


func _update_target() -> void:
	var new_target: Interactable = null
	if is_colliding():
		var hit := get_collider()
		if hit is Interactable and is_instance_valid(hit):
			var candidate := hit as Interactable
			if candidate.can_interact(self):
				new_target = candidate
	_set_target(new_target)


func _set_target(target: Interactable) -> void:
	if target == current_target and (target == null or is_instance_valid(target)):
		return
	# Desconecta do alvo anterior (se ainda existir).
	if current_target != null and is_instance_valid(current_target):
		if current_target.prompt_changed.is_connected(_refresh_prompt):
			current_target.prompt_changed.disconnect(_refresh_prompt)
		if current_target.tree_exiting.is_connected(_on_target_exiting):
			current_target.tree_exiting.disconnect(_on_target_exiting)
	current_target = target
	if current_target != null:
		current_target.prompt_changed.connect(_refresh_prompt)
		current_target.tree_exiting.connect(_on_target_exiting)
	target_changed.emit(current_target)
	_refresh_prompt()


func _on_target_exiting() -> void:
	# O objeto foi removido da cena enquanto estava na mira.
	current_target = null
	target_changed.emit(null)
	_refresh_prompt()


func _refresh_prompt() -> void:
	var text := ""
	if current_target != null and is_instance_valid(current_target):
		if current_target.can_interact(self):
			text = "Pressione [%s] para %s" % [_key_label, current_target.get_prompt()]
		else:
			# Ficou desabilitado enquanto estava na mira.
			call_deferred(&"_update_target")
	if text != _current_prompt:
		_current_prompt = text
		prompt_changed.emit(text)


func _find_owner_body() -> CollisionObject3D:
	var n := get_parent()
	while n != null:
		if n is CharacterBody3D:
			return n
		n = n.get_parent()
	return null


## Lê do InputMap qual tecla está associada à ação (se o jogador remapear,
## a mensagem acompanha).
func _read_key_label() -> String:
	for ev in InputMap.action_get_events(interact_action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			if code != KEY_NONE:
				return OS.get_keycode_string(code)
	return "E"
