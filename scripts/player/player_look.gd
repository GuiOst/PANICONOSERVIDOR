class_name PlayerLook
extends Node3D
## "Cabeça" do jogador: controle de câmera pelo mouse, limite vertical,
## campo de visão (FOV) e balanço de câmera ao andar (head bob).
##
## Rotação horizontal (yaw) gira o CORPO inteiro; rotação vertical (pitch)
## gira apenas esta cabeça. Assim o movimento sempre segue o olhar.

## Limite para olhar para cima/baixo (graus). 89 evita "virar de ponta-cabeça".
@export_range(45.0, 89.0, 1.0) var pitch_limit_deg: float = 85.0
## Aumento de FOV ao correr (graus). 0 desativa.
@export_range(0.0, 15.0, 0.5) var sprint_fov_boost: float = 4.0

@export_group("Balanço da câmera")
@export_range(0.0, 0.1, 0.001) var bob_amplitude: float = 0.035
@export_range(0.5, 4.0, 0.05) var bob_frequency_walk: float = 1.8
@export_range(0.5, 5.0, 0.05) var bob_frequency_sprint: float = 2.6

var input_enabled: bool = true

var _pitch_deg: float = 0.0
var _bob_phase: float = 0.0
var _bob_weight: float = 0.0

@onready var _body: Player = get_parent() as Player
@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	_camera.fov = GameSettings.field_of_view


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# screen_relative ignora o redimensionamento da janela: a
		# sensibilidade fica igual em qualquer resolução.
		var motion := (event as InputEventMouseMotion).screen_relative
		apply_look(motion * GameSettings.mouse_sensitivity)


## Aplica rotação em graus (x = horizontal, y = vertical). Público para
## permitir controle por gamepad ou rede no futuro.
func apply_look(delta_deg: Vector2) -> void:
	if _body:
		_body.rotate_y(deg_to_rad(-delta_deg.x))
		_body.orthonormalize() # evita acúmulo de erro numérico
	var dy := -delta_deg.y if not GameSettings.invert_y else delta_deg.y
	_pitch_deg = clampf(_pitch_deg + dy, -pitch_limit_deg, pitch_limit_deg)
	rotation.x = deg_to_rad(_pitch_deg)


func reset_pitch() -> void:
	_pitch_deg = 0.0
	rotation.x = 0.0


func _process(delta: float) -> void:
	if _body == null:
		return
	var speed := _body.get_horizontal_speed()
	var moving := speed > 0.5 and _body.is_grounded()

	# --- FOV (com leve aumento ao correr) ---
	var target_fov := GameSettings.field_of_view + (sprint_fov_boost if _body.is_sprinting else 0.0)
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-8.0 * delta))

	# --- Balanço da câmera ---
	if not GameSettings.head_bob_enabled:
		_camera.position = Vector3.ZERO
		return
	_bob_weight = lerpf(_bob_weight, 1.0 if moving else 0.0, 1.0 - exp(-6.0 * delta))
	if moving:
		var freq := bob_frequency_sprint if _body.is_sprinting else bob_frequency_walk
		_bob_phase = fmod(_bob_phase + delta * freq * TAU, TAU * 2.0)
	var amp := bob_amplitude * (1.4 if _body.is_sprinting else 1.0) * _bob_weight
	_camera.position = Vector3(cos(_bob_phase * 0.5) * amp * 0.6, -absf(sin(_bob_phase)) * amp, 0.0)
