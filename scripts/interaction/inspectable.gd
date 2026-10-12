class_name Inspectable
extends Interactable
## Objeto que apenas mostra uma mensagem curta ao interagir
## (ex.: porta trancada do Setor C, painel sem energia, placas).
## Também é um exemplo mínimo de como criar um interativo novo.

@export_multiline var message: String = "Nada de interessante."
@export_file("*.wav", "*.ogg") var sound_path: String = ""

var _snd: AudioStream

@onready var _audio: AudioStreamPlayer3D = get_node_or_null(^"InspectAudio") as AudioStreamPlayer3D


func _ready() -> void:
	_snd = AudioLibrary.load_stream(sound_path)


func _on_interact(interactor: Node) -> void:
	AudioLibrary.play_on(_audio, _snd, 0.05)
	if interactor and interactor.has_method(&"show_feedback"):
		interactor.call(&"show_feedback", message)
