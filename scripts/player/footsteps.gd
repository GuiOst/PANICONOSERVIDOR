class_name Footsteps
extends AudioStreamPlayer3D
## Passos do jogador com gravações reais, por superfície.
##
## Como funciona:
##  - O ritmo vem da DISTÂNCIA percorrida (não de um temporizador), então
##    acompanha exatamente a velocidade real; parado = sem passos.
##  - No ar não há passos; ao aterrissar toca um passo mais forte.
##  - A superfície é descoberta por um raio para baixo, a partir dos pés:
##      1) uma SurfaceZone (Area3D na camada 4, ex.: poça d'água), ou
##      2) metadado "surface" no CollisionShape3D atingido, ou no corpo;
##      3) se nada for encontrado, usa "concrete".
##  - Caminhada e corrida usam CONJUNTOS DE GRAVAÇÕES DIFERENTES.
##  - Evita repetir as duas últimas variações e varia levemente afinação
##    e volume.
##  - É um AudioStreamPlayer3D (áudio espacial): outros jogadores (Etapa 2)
##    ouvirão os passos vindo da posição certa.

@export_group("Ritmo")
## Metros por passo andando / correndo.
@export_range(0.3, 2.0, 0.05) var walk_stride: float = 0.78
@export_range(0.3, 3.0, 0.05) var sprint_stride: float = 1.2
## Abaixo desta velocidade (m/s) não há passos.
@export_range(0.05, 2.0, 0.05) var min_speed: float = 0.4

@export_group("Volume")
@export_range(-30.0, 6.0, 0.5) var walk_volume_db: float = -6.0
@export_range(-30.0, 6.0, 0.5) var sprint_volume_db: float = -2.0
## Quanto o volume acompanha a velocidade (0 = fixo).
@export_range(0.0, 1.0, 0.05) var speed_volume_influence: float = 0.6
## Variação aleatória de afinação (±).
@export_range(0.0, 0.2, 0.01) var pitch_variation: float = 0.05
## Velocidade de queda mínima para tocar som ao aterrissar.
@export_range(0.0, 10.0, 0.1) var landing_min_speed: float = 2.5

@export_group("Superfície")
## Distância máxima do raio de detecção de piso (a partir dos pés).
@export_range(0.1, 2.0, 0.05) var surface_probe_length: float = 0.6

const SURFACE_ZONE_LAYER := 4

## Emitido a cada passo tocado. Na etapa do monstro, ele poderá "ouvir"
## passos por este sinal (correr faz mais barulho que andar).
signal step_played(surface: StringName, running: bool, loudness_db: float)

var current_surface: StringName = AudioLibrary.SURFACE_DEFAULT

var _sets := {}            # superfície -> { "walk": [streams], "run": [streams] }
var _history := {}         # chave "superfície/passada" -> últimos índices usados
var _distance: float = 0.0
var _query: PhysicsRayQueryParameters3D

@onready var _body: Player = owner as Player


func _ready() -> void:
	bus = AudioLibrary.BUS_SFX
	for surface in AudioLibrary.FOOTSTEP_COUNTS.keys():
		var entry := {}
		for gait in [&"walk", &"run"]:
			entry[gait] = AudioLibrary.load_streams(AudioLibrary.footstep_paths(surface, gait))
		_sets[surface] = entry
	if _body == null or _count_streams() == 0:
		set_physics_process(false) # sem sons: o componente se desliga sem erro
		return
	_query = PhysicsRayQueryParameters3D.new()
	_query.collision_mask = (1 << 0) | (1 << (SURFACE_ZONE_LAYER - 1))
	_query.collide_with_areas = true
	_query.collide_with_bodies = true
	_query.exclude = [_body.get_rid()]
	_body.landed.connect(_on_landed)


func _physics_process(delta: float) -> void:
	if not _body.is_grounded():
		return
	var speed := _body.get_horizontal_speed()
	if speed < min_speed:
		# Parado: o próximo passo sai logo que voltar a andar.
		_distance = maxf(_distance, walk_stride * 0.6)
		return
	_distance += speed * delta
	var stride := sprint_stride if _body.is_sprinting else walk_stride
	if _distance >= stride:
		_distance = 0.0
		play_step(_body.is_sprinting, speed)


## Toca um passo agora (público para animações/rede no futuro).
func play_step(running: bool, speed: float, extra_db: float = 0.0) -> void:
	current_surface = detect_surface()
	var gait: StringName = &"run" if running else &"walk"
	var streams := _streams_for(current_surface, gait)
	if streams.is_empty():
		return
	var key := "%s/%s" % [current_surface, gait]
	if not _history.has(key):
		_history[key] = [] as Array[int]
	var hist: Array[int] = _history[key]
	var idx := AudioLibrary.pick_index(streams.size(), hist, 2)
	# Volume proporcional à intensidade do movimento.
	var base_db := sprint_volume_db if running else walk_volume_db
	var ref_speed := _body.sprint_speed if running else _body.walk_speed
	var ratio := clampf(speed / maxf(ref_speed, 0.1), 0.3, 1.2)
	var speed_db := linear_to_db(lerpf(1.0, ratio, speed_volume_influence))
	volume_db = base_db + speed_db + extra_db + randf_range(-1.0, 1.0)
	AudioLibrary.play_on(self, streams[idx], pitch_variation)
	step_played.emit(current_surface, running, volume_db)


## Descobre a superfície sob os pés (consulta física única, sem alocação
## de novos objetos a cada passo).
func detect_surface() -> StringName:
	if _query == null or not is_inside_tree():
		return AudioLibrary.SURFACE_DEFAULT
	var from := _body.global_position + Vector3.UP * 0.2
	_query.from = from
	_query.to = from + Vector3.DOWN * surface_probe_length
	var hit := _body.get_world_3d().direct_space_state.intersect_ray(_query)
	if hit.is_empty():
		return AudioLibrary.SURFACE_DEFAULT
	var collider: Object = hit.get("collider")
	if collider is SurfaceZone:
		return StringName((collider as SurfaceZone).surface)
	# Metadado na forma de colisão atingida (vários pisos podem dividir o
	# mesmo corpo físico) e depois no próprio corpo.
	if collider is CollisionObject3D:
		var co := collider as CollisionObject3D
		var shape_idx: int = hit.get("shape", -1)
		if shape_idx >= 0:
			var owner_id := co.shape_find_owner(shape_idx)
			var shape_node := co.shape_owner_get_owner(owner_id) as Node
			if shape_node and shape_node.has_meta(&"surface"):
				return StringName(shape_node.get_meta(&"surface"))
		if co.has_meta(&"surface"):
			return StringName(co.get_meta(&"surface"))
	return AudioLibrary.SURFACE_DEFAULT


func _streams_for(surface: StringName, gait: StringName) -> Array:
	var entry: Dictionary = _sets.get(surface, _sets.get(AudioLibrary.SURFACE_DEFAULT, {}))
	var list: Array = entry.get(gait, [])
	if list.is_empty():
		# Se faltar a corrida (ou a caminhada) dessa superfície, usa a outra.
		list = entry.get(&"walk" if gait == &"run" else &"run", [])
	if list.is_empty() and surface != AudioLibrary.SURFACE_DEFAULT:
		return _streams_for(AudioLibrary.SURFACE_DEFAULT, gait)
	return list


func _count_streams() -> int:
	var n := 0
	for s in _sets.values():
		for list in s.values():
			n += (list as Array).size()
	return n


func _on_landed(fall_speed: float) -> void:
	if fall_speed >= landing_min_speed:
		play_step(true, _body.sprint_speed, 2.0)
		_distance = 0.0
