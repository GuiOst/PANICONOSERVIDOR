class_name LoopingSound3D
extends AudioStreamPlayer3D
## Som 3D em loop (zumbido de lâmpada, ruído elétrico...) carregado de forma
## segura a partir de um caminho. Se o arquivo não existir, fica em silêncio.
##
## Usar caminho (String) em vez de arrastar o AudioStream no Inspector evita
## que a cena fique com referência quebrada caso o arquivo seja removido.

@export_file("*.wav", "*.ogg", "*.mp3") var stream_path: String = ""
## Começa em um ponto aleatório do loop para que várias fontes iguais
## não toquem sincronizadas (soaria artificial).
@export var randomize_start: bool = true


func _ready() -> void:
	if stream == null:
		stream = AudioLibrary.load_stream(stream_path)
	if stream == null:
		return
	if autoplay or playing:
		return
	var start := 0.0
	if randomize_start:
		start = randf() * maxf(stream.get_length() - 0.1, 0.0)
	play(start)


## Liga/desliga o som (usado, por exemplo, quando a luz apaga).
func set_active(active: bool) -> void:
	if stream == null:
		return
	if active and not playing:
		play(randf() * maxf(stream.get_length() - 0.1, 0.0))
	elif not active and playing:
		stop()
