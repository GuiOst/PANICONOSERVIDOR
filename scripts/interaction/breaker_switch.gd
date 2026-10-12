class_name BreakerSwitch
extends Interactable
## Disjuntor de parede: liga/desliga um circuito de luzes.
##
## EXEMPLO de interativo criado por HERANÇA (extends Interactable).
## Todos os nós no grupo `circuit_group` que tiverem o método
## `set_powered(bool)` (ex.: CeilingLamp) são ligados/desligados.
## Na etapa dos geradores, este mesmo contrato poderá ser usado por
## geradores e fusíveis.

signal power_toggled(is_on: bool)

@export var circuit_group: StringName = &"circuit_storage"
@export var is_on: bool = false
## Alavanca visual que gira ao acionar (opcional).
@export var lever_path: NodePath
@export var lever_on_angle_deg: float = -50.0
@export var lever_off_angle_deg: float = 50.0

var _snd: AudioStream

@onready var _lever: Node3D = get_node_or_null(lever_path) as Node3D
@onready var _audio: AudioStreamPlayer3D = get_node_or_null(^"SwitchAudio") as AudioStreamPlayer3D


func _ready() -> void:
	_snd = AudioLibrary.load_stream(AudioLibrary.SWITCH)
	_update_visual(false)
	# Aplica o estado inicial depois que a fase inteira estiver pronta.
	_apply_power.call_deferred()


func get_prompt() -> String:
	return "desligar o disjuntor" if is_on else "ligar o disjuntor"


func _on_interact(interactor: Node) -> void:
	is_on = not is_on
	AudioLibrary.play_on(_audio, _snd, 0.04)
	_update_visual(true)
	_apply_power()
	prompt_changed.emit()
	power_toggled.emit(is_on)
	if interactor and interactor.has_method(&"show_feedback"):
		interactor.call(&"show_feedback", "Energia restabelecida." if is_on else "Circuito desligado.")


func _apply_power() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(circuit_group):
		if node.has_method(&"set_powered"):
			node.call(&"set_powered", is_on)


func _update_visual(animated: bool) -> void:
	if _lever == null:
		return
	var target := deg_to_rad(lever_on_angle_deg if is_on else lever_off_angle_deg)
	if animated:
		var tw := create_tween()
		tw.tween_property(_lever, "rotation:x", target, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_lever.rotation.x = target
