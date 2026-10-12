class_name AudioLibrary
extends RefCounted
## Catálogo CENTRAL de sons e carregamento SEGURO.
##
## Todos os sons são opcionais: se um arquivo não existir, as funções
## retornam null (ou uma lista vazia) e quem chamou simplesmente não toca
## nada. O jogo nunca quebra por falta de um áudio.
##
## Origem e licença de cada gravação: assets/audio/CREDITOS_AUDIO.md
## Para trocar um som: substitua o arquivo no mesmo caminho ou altere aqui.

# ------------------------------------------------------------------ passos
## Superfícies conhecidas. A superfície é lida do chão real sob o jogador
## (metadado "surface" no CollisionShape3D/corpo, ou uma SurfaceZone).
const SURFACE_DEFAULT := &"concrete"
const FOOTSTEP_DIR := "res://assets/audio/footsteps/"
## Quantidade de variações por superfície e tipo de passada.
const FOOTSTEP_COUNTS := {
	&"concrete": {&"walk": 7, &"run": 10},
	&"metal": {&"walk": 5, &"run": 7},
	&"wet": {&"walk": 6, &"run": 6},
}

# ------------------------------------------------------------------- porta
const DOOR_UNLATCH: Array[String] = [
	"res://assets/audio/doors/unlatch_01.ogg",
	"res://assets/audio/doors/unlatch_02.ogg",
	"res://assets/audio/doors/unlatch_03.ogg",
]
const DOOR_CREAK_OPEN: Array[String] = [
	"res://assets/audio/doors/creak_open_01.ogg",
	"res://assets/audio/doors/creak_open_02.ogg",
	"res://assets/audio/doors/creak_open_03.ogg",
]
const DOOR_CREAK_CLOSE: Array[String] = [
	"res://assets/audio/doors/creak_close_01.ogg",
	"res://assets/audio/doors/creak_close_02.ogg",
	"res://assets/audio/doors/creak_close_03.ogg",
]
const DOOR_STOP_OPEN: Array[String] = [
	"res://assets/audio/doors/stop_open_01.ogg",
	"res://assets/audio/doors/stop_open_02.ogg",
	"res://assets/audio/doors/stop_open_03.ogg",
]
const DOOR_SLAM: Array[String] = [
	"res://assets/audio/doors/slam_01.ogg",
	"res://assets/audio/doors/slam_02.ogg",
	"res://assets/audio/doors/slam_03.ogg",
]
const DOOR_LOCKED: Array[String] = [
	"res://assets/audio/doors/locked_01.ogg",
	"res://assets/audio/doors/locked_02.ogg",
]

# -------------------------------------------------------------- interações
const FLASHLIGHT_ON := "res://assets/audio/interactions/flashlight_on.wav"
const FLASHLIGHT_OFF := "res://assets/audio/interactions/flashlight_off.wav"
const SWITCH := "res://assets/audio/interactions/breaker_switch.wav"

# ---------------------------------------------------------------- ambiente
const AMBIENCE_UNDERGROUND := "res://assets/audio/ambience/underground_ambience.wav"
const ELECTRICAL_HUM := "res://assets/audio/ambience/electrical_hum.wav"
const LAMP_BUZZ := "res://assets/audio/ambience/lamp_buzz.wav"

# --------------------------------------------------------------- interface
const UI_CLICK := "res://assets/audio/ui/click.ogg"
const UI_HOVER := "res://assets/audio/ui/hover.ogg"

# Barramentos de áudio (default_bus_layout.tres).
const BUS_SFX := &"SFX"
const BUS_AMBIENCE := &"Ambience"
const BUS_CREATURE := &"Creature"
const BUS_UI := &"UI"

# Evita repetir o mesmo aviso no console várias vezes.
static var _missing_reported := {}


## Carrega um AudioStream se ele existir; caso contrário retorna null.
static func load_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		if not _missing_reported.has(path):
			_missing_reported[path] = true
			print_verbose("AudioLibrary: som opcional ausente: %s" % path)
		return null
	return load(path) as AudioStream


## Carrega uma lista de sons, ignorando os ausentes.
static func load_streams(paths: Array[String]) -> Array[AudioStream]:
	var result: Array[AudioStream] = []
	for p in paths:
		var s := load_stream(p)
		if s:
			result.append(s)
	return result


## Caminhos dos passos de uma superfície ("walk" ou "run").
static func footstep_paths(surface: StringName, gait: StringName) -> Array[String]:
	var paths: Array[String] = []
	var counts: Dictionary = FOOTSTEP_COUNTS.get(surface, {})
	var n: int = counts.get(gait, 0)
	for i in n:
		paths.append("%s%s/%s_%02d.ogg" % [FOOTSTEP_DIR, surface, gait, i + 1])
	return paths


## Escolhe um índice aleatório evitando os `avoid` últimos usados
## (reduz a repetição perceptível). `history` é atualizado.
static func pick_index(count: int, history: Array[int], avoid: int = 2) -> int:
	if count <= 0:
		return -1
	if count == 1:
		return 0
	var keep := mini(avoid, count - 1)
	var choice := randi() % count
	var tries := 0
	while history.has(choice) and tries < 8:
		choice = randi() % count
		tries += 1
	history.append(choice)
	while history.size() > keep:
		history.pop_front()
	return choice


## Toca um som em um player já existente, se houver stream. Retorna true se tocou.
static func play_on(player: Node, stream: AudioStream, pitch_variation: float = 0.0) -> bool:
	if stream == null or player == null or not is_instance_valid(player):
		return false
	if not player.is_inside_tree():
		return false
	player.set(&"stream", stream)
	if pitch_variation > 0.0:
		player.set(&"pitch_scale", randf_range(1.0 - pitch_variation, 1.0 + pitch_variation))
	else:
		player.set(&"pitch_scale", 1.0)
	player.call(&"play")
	return true
