class_name HUD
extends CanvasLayer
## Interface durante o jogo: mira, mensagem de interação, mensagens curtas
## e indicador da lanterna. Não conhece o jogador: a cena principal conecta
## os sinais do jogador às funções públicas abaixo.

@export var prompt_fade_time: float = 0.15
@export var feedback_hold_time: float = 2.4
@export var intro_fade_time: float = 2.5

var _prompt_tween: Tween
var _feedback_tween: Tween

@onready var _root: Control = $Root
@onready var _crosshair: Crosshair = $Root/Crosshair
@onready var _prompt: Label = $Root/Prompt
@onready var _feedback: Label = $Root/Feedback
@onready var _flash_icon: TextureRect = $Root/FlashlightIndicator/Icon
@onready var _flash_beam: TextureRect = $Root/FlashlightIndicator/Beam
@onready var _flash_label: Label = $Root/FlashlightIndicator/State
@onready var _fade: ColorRect = $Root/Fade


func _ready() -> void:
	_prompt.text = ""
	_prompt.modulate.a = 0.0
	_feedback.modulate.a = 0.0
	set_flashlight(false)
	GameManager.pause_changed.connect(_on_pause_changed)
	# Entrada em fade a partir do preto.
	_fade.visible = true
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, intro_fade_time).set_delay(0.3)


## Texto completo ("Pressione [E] para abrir") ou "" para esconder.
func set_prompt(text: String) -> void:
	_crosshair.active = text != ""
	if _prompt_tween:
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	if text == "":
		_prompt_tween.tween_property(_prompt, "modulate:a", 0.0, prompt_fade_time)
	else:
		_prompt.text = text
		_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, prompt_fade_time)


## Mensagem curta temporária ("Trancada.").
func show_feedback(text: String) -> void:
	_feedback.text = text
	if _feedback_tween:
		_feedback_tween.kill()
	_feedback.modulate.a = 0.0
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(_feedback, "modulate:a", 1.0, 0.15)
	_feedback_tween.tween_interval(feedback_hold_time)
	_feedback_tween.tween_property(_feedback, "modulate:a", 0.0, 0.6)


func set_flashlight(is_on: bool) -> void:
	_flash_icon.modulate = Color(0.95, 0.88, 0.7, 0.9) if is_on else Color(0.6, 0.6, 0.6, 0.35)
	_flash_beam.visible = is_on
	_flash_label.text = "LIGADA" if is_on else "DESLIGADA"
	_flash_label.modulate.a = 0.85 if is_on else 0.4


func _on_pause_changed(paused: bool) -> void:
	# Durante a pausa só o menu aparece.
	_crosshair.visible = not paused
	_prompt.visible = not paused
	_feedback.visible = not paused
