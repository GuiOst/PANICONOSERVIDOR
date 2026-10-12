class_name Flashlight
extends SpotLight3D
## Lanterna de mão presa à câmera (liga/desliga com F).
##
## - A luz fica levemente abaixo e à direita da câmera (como na mão), o que
##   gera sombras mais naturais dos objetos.
## - Tem um pequeno "atraso" ao girar a câmera (balanço), configurável.
## - PREPARADA PARA BATERIA (etapa futura): toda ativação passa por
##   `has_power()`. Um sistema de bateria só precisará sobrescrever/alterar
##   essa função e chamar `set_on(false)` quando acabar a carga.

signal toggled(is_on: bool)

@export var toggle_action: StringName = &"toggle_flashlight"
@export var start_on: bool = false

@export_group("Feixe")
## Alcance da luz em metros.
@export_range(2.0, 60.0, 0.5) var beam_range: float = 26.0:
	set(v):
		beam_range = v
		spot_range = v
## Abertura do cone (graus, metade do ângulo total).
@export_range(5.0, 80.0, 0.5) var beam_angle: float = 27.0:
	set(v):
		beam_angle = v
		spot_angle = v
## Intensidade.
@export_range(0.1, 16.0, 0.1) var beam_energy: float = 7.0:
	set(v):
		beam_energy = v
		light_energy = v

@export_group("Balanço")
## 0 = feixe rígido na câmera; valores maiores = mais atraso ao virar.
@export_range(0.0, 1.0, 0.01) var sway_amount: float = 0.35

var is_on: bool = false
var input_enabled: bool = true

var _smoothed_rotation: Quaternion
var _click_on: AudioStream
var _click_off: AudioStream

@onready var _audio: AudioStreamPlayer3D = get_node_or_null(^"ClickAudio") as AudioStreamPlayer3D


func _ready() -> void:
	spot_range = beam_range
	spot_angle = beam_angle
	light_energy = beam_energy
	_click_on = AudioLibrary.load_stream(AudioLibrary.FLASHLIGHT_ON)
	_click_off = AudioLibrary.load_stream(AudioLibrary.FLASHLIGHT_OFF)
	_smoothed_rotation = global_basis.get_rotation_quaternion()
	set_on(start_on, false)


func _unhandled_input(event: InputEvent) -> void:
	if input_enabled and event.is_action_pressed(toggle_action) and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	set_on(not is_on)


func set_on(value: bool, play_sound: bool = true) -> void:
	if value and not has_power():
		value = false
	var changed := value != is_on
	is_on = value
	visible = value # luz invisível = custo zero de renderização
	set_process(value and sway_amount > 0.0)
	if value:
		_smoothed_rotation = _parent_rotation()
	if play_sound and changed:
		AudioLibrary.play_on(_audio, _click_on if value else _click_off, 0.05)
	if changed:
		toggled.emit(is_on)


## Ponto de extensão para o futuro sistema de bateria.
func has_power() -> bool:
	return true


func _process(delta: float) -> void:
	# O feixe "persegue" a direção da câmera com um leve atraso.
	var target := _parent_rotation()
	var follow := lerpf(40.0, 8.0, sway_amount)
	_smoothed_rotation = _smoothed_rotation.slerp(target, 1.0 - exp(-follow * delta))
	global_basis = Basis(_smoothed_rotation)


func _parent_rotation() -> Quaternion:
	var p := get_parent() as Node3D
	return p.global_basis.get_rotation_quaternion() if p else Quaternion.IDENTITY
