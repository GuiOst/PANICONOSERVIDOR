class_name DoorAudio
extends Node3D
## Sons da porta industrial, sincronizados com o MOVIMENTO REAL da folha.
##
## Sequência:
##   abrir a partir de fechada: trinco/mecanismo (na hora) -> rangido da
##       dobradiça (quando a folha começa a se mover) -> batida surda no
##       batente quando chega totalmente aberta;
##   fechar: rangido durante o movimento -> BATIDA pesada só quando a folha
##       realmente encosta no batente (estado CLOSED);
##   inverter no meio do caminho: o rangido atual some suavemente e começa
##       o do novo sentido;
##   porta trancada: maçaneta forçada.
##
## Fica como filho da folha (Panel) e usa dois players 3D:
##   Mechanism (perto da maçaneta) e Hinge (na dobradiça).
## Todos os sons são opcionais (sem arquivo = silêncio, sem erro).

@export_group("Volumes (dB)")
@export var unlatch_db: float = -4.0
@export var creak_db: float = -6.0
@export var stop_open_db: float = -8.0
@export var slam_db: float = -1.0
@export var locked_db: float = -4.0

@export_group("Tempo")
## Atraso do rangido após o trinco (a folha pesada demora a "soltar").
@export_range(0.0, 0.5, 0.01) var creak_delay_after_unlatch: float = 0.12
## Duração do fade-out do rangido quando a folha para.
@export_range(0.02, 0.6, 0.01) var creak_fade_time: float = 0.18

@export_group("Espacialização")
@export_range(0.5, 10.0, 0.1) var unit_size: float = 3.5
@export_range(5.0, 80.0, 1.0) var max_distance: float = 30.0

var _mech: AudioStreamPlayer3D
var _hinge: AudioStreamPlayer3D
var _unlatch: Array[AudioStream] = []
var _creak_open: Array[AudioStream] = []
var _creak_close: Array[AudioStream] = []
var _stop_open: Array[AudioStream] = []
var _slam: Array[AudioStream] = []
var _locked: Array[AudioStream] = []
var _hist := {}
var _creak_tween: Tween
var _pending_creak: SceneTreeTimer
var _creak_cb: Callable


func _ready() -> void:
	_unlatch = AudioLibrary.load_streams(AudioLibrary.DOOR_UNLATCH)
	_creak_open = AudioLibrary.load_streams(AudioLibrary.DOOR_CREAK_OPEN)
	_creak_close = AudioLibrary.load_streams(AudioLibrary.DOOR_CREAK_CLOSE)
	_stop_open = AudioLibrary.load_streams(AudioLibrary.DOOR_STOP_OPEN)
	_slam = AudioLibrary.load_streams(AudioLibrary.DOOR_SLAM)
	_locked = AudioLibrary.load_streams(AudioLibrary.DOOR_LOCKED)
	_mech = _make_player("Mechanism", Vector3(1.2, 1.05, 0.0))
	_hinge = _make_player("Hinge", Vector3(0.05, 1.3, 0.0))


func _make_player(node_name: String, pos: Vector3) -> AudioStreamPlayer3D:
	var p := get_node_or_null(NodePath(node_name)) as AudioStreamPlayer3D
	if p == null:
		p = AudioStreamPlayer3D.new()
		p.name = node_name
		add_child(p)
	p.position = pos
	p.bus = AudioLibrary.BUS_SFX
	p.unit_size = unit_size
	p.max_distance = max_distance
	p.attenuation_filter_cutoff_hz = 5000.0 # longe = mais abafado
	return p


## Chamado pela porta quando a folha começa a se mover.
## `opening`: sentido; `from_rest`: estava totalmente parada (aberta/fechada).
func on_motion_started(opening: bool, from_rest: bool) -> void:
	_cancel_pending_creak()
	_fade_out_creak()
	if opening and from_rest:
		_play(_mech, _unlatch, &"unlatch", unlatch_db, 0.04)
		# O rangido começa quando a folha realmente "solta" do batente.
		_pending_creak = get_tree().create_timer(creak_delay_after_unlatch, false)
		_creak_cb = _start_creak.bind(true)
		_pending_creak.timeout.connect(_creak_cb, CONNECT_ONE_SHOT)
	else:
		_start_creak(opening)


## Chamado quando a folha chega ao fim do curso.
func on_motion_finished(is_open: bool) -> void:
	_cancel_pending_creak()
	_fade_out_creak()
	if is_open:
		_play(_mech, _stop_open, &"stop_open", stop_open_db, 0.05)
	else:
		_play(_mech, _slam, &"slam", slam_db, 0.03)


## Movimento interrompido (alguém no caminho): o rangido some.
func on_motion_blocked() -> void:
	_cancel_pending_creak()
	_fade_out_creak()


func on_locked_attempt() -> void:
	_play(_mech, _locked, &"locked", locked_db, 0.04)


func _start_creak(opening: bool) -> void:
	_pending_creak = null
	_play(_hinge, _creak_open if opening else _creak_close, &"creak_open" if opening else &"creak_close", creak_db, 0.06)


func _fade_out_creak() -> void:
	if _hinge == null or not _hinge.playing:
		return
	if _creak_tween and _creak_tween.is_valid():
		_creak_tween.kill()
	_creak_tween = create_tween()
	_creak_tween.tween_property(_hinge, "volume_db", -60.0, creak_fade_time)
	_creak_tween.tween_callback(_hinge.stop)


func _cancel_pending_creak() -> void:
	if _pending_creak and _creak_cb.is_valid() and _pending_creak.timeout.is_connected(_creak_cb):
		_pending_creak.timeout.disconnect(_creak_cb)
	_pending_creak = null


func _play(player: AudioStreamPlayer3D, streams: Array[AudioStream], key: StringName, db: float, pitch_var: float) -> void:
	if streams.is_empty() or player == null:
		return
	if player == _hinge and _creak_tween and _creak_tween.is_valid():
		_creak_tween.kill()
	if not _hist.has(key):
		_hist[key] = [] as Array[int]
	var hist: Array[int] = _hist[key]
	var idx := AudioLibrary.pick_index(streams.size(), hist, 1)
	player.volume_db = db + randf_range(-1.0, 0.5)
	AudioLibrary.play_on(player, streams[idx], pitch_var)
