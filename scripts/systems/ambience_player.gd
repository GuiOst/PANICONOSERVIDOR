class_name AmbiencePlayer
extends AudioStreamPlayer
## Som ambiente não posicional (ex.: ronco subterrâneo de fundo).
## Carregado com segurança e com fade-in para não começar de forma abrupta.

@export_file("*.wav", "*.ogg", "*.mp3") var stream_path: String = ""
@export var target_volume_db: float = -8.0
@export var fade_in_time: float = 3.0


func _ready() -> void:
	stream = AudioLibrary.load_stream(stream_path)
	if stream == null:
		return
	volume_db = -60.0
	play()
	var tween := create_tween()
	tween.tween_property(self, "volume_db", target_volume_db, fade_in_time)
