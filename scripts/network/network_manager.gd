extends Node
## Autoload "Net": tudo sobre conexão, salas (lobby) e sessão multiplayer.
##
## Dois tipos de conexão, com a MESMA lógica de jogo por cima:
##   - Rede local (LAN): ENet direto, o código da sala é o IP do host.
##   - Internet: relay NodeTunnel (sem abrir portas no roteador). O código da
##     sala é gerado pelo servidor de relay e só existe enquanto a sala existir.
##
## Regras de autoridade:
##   - O HOST (peer 1) é a autoridade: valida pedidos de interação, decide
##     quem entra na sala, inicia a partida e repassa o estado dos jogadores.
##   - Cada jogador controla o próprio movimento e envia a posição ao host,
##     que confere se o movimento é plausível antes de repassar.
##
## Fluxo:
##   menu -> create_*_room / join_* -> lobby (lista de jogadores) ->
##   host chama start_session() -> todos carregam a fase -> cada um avisa
##   "pronto" -> host libera a partida -> ... -> leave() volta ao menu.

signal status_changed(text: String)          ## mensagens de progresso para a interface
signal room_ready(code: String)              ## sala criada/entrada com sucesso
signal connection_failed(reason: String)     ## falha ao criar/entrar
signal lobby_updated                         ## lista de jogadores mudou
signal player_joined(peer_id: int, player_name: String)
signal player_left(peer_id: int, player_name: String)
signal session_loading                       ## o host mandou carregar a fase
signal session_started                       ## todos prontos: a partida começou
signal session_ended(reason: String)         ## voltamos ao menu (host saiu, erro...)

enum Mode { OFFLINE, LAN, RELAY }
enum Phase { IDLE, CONNECTING, LOBBY, LOADING, PLAYING }

const GAME_VERSION := "0.2.0"     ## clientes com versão diferente são recusados
const MAX_PLAYERS := 6
const LAN_PORT := 24565
const CONFIG_PATH := "res://config/network.cfg"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const GAME_SCENE := "res://scenes/main/main.tscn"
const CONNECT_TIMEOUT := 15.0
const HEARTBEAT_INTERVAL := 1.5
const HEARTBEAT_TIMEOUT := 10.0
const READY_TIMEOUT := 30.0

var mode: Mode = Mode.OFFLINE
var phase: Phase = Phase.IDLE
var room_code: String = ""
## peer_id -> { "name": String, "ready": bool }
var players: Dictionary = {}
var local_player_name: String = "Jogador"
var last_end_reason: String = ""

# Configuração do relay (lida de res://config/network.cfg; não é segredo).
var relay_address: String = "us-east.nodetunnel.io:8080"
var relay_app_id: String = ""

var _peer: MultiplayerPeer
var _connect_timer: float = -1.0
var _ready_timer: float = -1.0
var _heartbeat_timer: float = 0.0
var _last_seen: Dictionary = {}           # peer_id -> tempo (s) da última mensagem
var _interact_seq: int = 0
var _last_interact_seq: Dictionary = {}   # peer_id -> último seq aceito
var _last_interact_time: Dictionary = {}  # peer_id -> tempo do último pedido aceito
var _clock: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# =================================================================== estado
func is_online() -> bool:
	return mode != Mode.OFFLINE and _peer != null


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


func is_session_active() -> bool:
	return is_online() and (phase == Phase.LOADING or phase == Phase.PLAYING)


func is_playing() -> bool:
	return is_online() and phase == Phase.PLAYING


func my_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


func relay_available() -> bool:
	return ClassDB.class_exists("NodeTunnelPeer")


func relay_configured() -> bool:
	return relay_available() and not relay_app_id.strip_edges().is_empty()


## Ids em ordem (o host primeiro): define o ponto de nascimento de cada um.
func get_player_ids() -> Array[int]:
	var ids: Array[int] = []
	for k in players.keys():
		ids.append(int(k))
	ids.sort()
	return ids


func get_player_name(peer_id: int) -> String:
	return players.get(peer_id, {}).get("name", "Jogador %d" % peer_id)


## Endereços IPv4 de rede local deste PC, do mais provável ao menos provável
## (192.168.x primeiro; 172.x costuma ser adaptador virtual do Windows/WSL).
func get_lan_addresses() -> PackedStringArray:
	var groups := [PackedStringArray(), PackedStringArray(), PackedStringArray()]
	for a in IP.get_local_addresses():
		if a.contains(":") or not a.is_valid_ip_address():
			continue
		if a.begins_with("192.168."):
			groups[0].append(a)
		elif a.begins_with("10."):
			groups[1].append(a)
		elif a.begins_with("172."):
			var second := int(a.split(".")[1])
			if second >= 16 and second <= 31:
				groups[2].append(a)
	var out := PackedStringArray()
	for g in groups:
		out.append_array(g)
	return out


func set_local_player_name(n: String) -> void:
	local_player_name = sanitize_name(n)


static func sanitize_name(n: String) -> String:
	var clean := ""
	for ch in n.strip_edges():
		# Sem caracteres de controle; nomes curtos e legíveis.
		if ch.unicode_at(0) >= 32 and ch != "[" and ch != "]":
			clean += ch
	clean = clean.substr(0, 16).strip_edges()
	return clean if not clean.is_empty() else "Jogador"


# ======================================================== criar / entrar (LAN)
func create_lan_room(port: int = LAN_PORT) -> void:
	_reset()
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_server(port, MAX_PLAYERS)
	if err != OK:
		_fail("Não foi possível criar a sala na porta %d (%s). A porta pode estar em uso." % [port, error_string(err)])
		return
	_install_peer(enet, Mode.LAN)
	var addrs := get_lan_addresses()
	room_code = ("%s:%d" % [addrs[0], port]) if not addrs.is_empty() else ("127.0.0.1:%d" % port)
	_become_lobby_host()


## `code` = "IP" ou "IP:porta".
func join_lan(code: String) -> void:
	_reset()
	var parts := code.strip_edges().split(":")
	var host := parts[0].strip_edges()
	var port := LAN_PORT
	if parts.size() > 1 and parts[1].is_valid_int():
		port = int(parts[1])
	if host.is_empty() or not (host.is_valid_ip_address() or host == "localhost"):
		_fail("Endereço inválido. Use o IP mostrado pelo host, por exemplo 192.168.0.10")
		return
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_client(host, port)
	if err != OK:
		_fail("Não foi possível iniciar a conexão (%s)." % error_string(err))
		return
	room_code = "%s:%d" % [host, port]
	_install_peer(enet, Mode.LAN)
	phase = Phase.CONNECTING
	_connect_timer = CONNECT_TIMEOUT
	status_changed.emit("Conectando a %s..." % room_code)


# ==================================================== criar / entrar (relay)
func create_online_room() -> void:
	_reset()
	var nt := _make_relay_peer()
	if nt == null:
		return
	# A validação roda no host quando alguém tenta entrar (antes de conectar).
	nt.set(&"join_validation", func(meta: String) -> bool:
		return meta == GAME_VERSION and players.size() < MAX_PLAYERS and phase == Phase.LOBBY)
	nt.connect(&"authenticated", func():
		status_changed.emit("Criando sala...")
		var e: int = nt.call(&"host_room", false, "Panico no Servidor")
		if e != OK:
			_net_fail("O relay recusou a criação da sala."), CONNECT_ONE_SHOT)
	nt.connect(&"room_connected", func():
		room_code = String(nt.get(&"room_id"))
		_become_lobby_host(), CONNECT_ONE_SHOT)
	_start_relay(nt)


func join_online(code: String) -> void:
	_reset()
	code = code.strip_edges()
	if code.is_empty() or code.length() > 64 or code.contains(" "):
		_fail("Código de sala inválido.")
		return
	var nt := _make_relay_peer()
	if nt == null:
		return
	room_code = code
	nt.connect(&"authenticated", func():
		status_changed.emit("Entrando na sala %s..." % code)
		var e: int = nt.call(&"join_room", code, GAME_VERSION)
		if e != OK:
			_net_fail("Não foi possível pedir entrada na sala."), CONNECT_ONE_SHOT)
	# Ao entrar, a NodeTunnel avisa "peer 1 conectado" e o Godot emite
	# connected_to_server -> _on_connected_to_server() registra o jogador.
	_start_relay(nt)


func _make_relay_peer() -> MultiplayerPeer:
	if not relay_available():
		_fail("O plugin NodeTunnel não foi encontrado (pasta addons/nodetunnel).")
		return null
	if relay_app_id.strip_edges().is_empty():
		_fail("Falta o App ID do NodeTunnel em config/network.cfg (veja o tutorial de multiplayer).")
		return null
	var nt := ClassDB.instantiate("NodeTunnelPeer") as MultiplayerPeer
	nt.connect(&"error", func(msg: String):
		var pt := _translate_relay_error(msg)
		if phase == Phase.CONNECTING:
			_net_fail(pt)
		else:
			status_changed.emit("Aviso do relay: %s" % pt))
	nt.connect(&"forced_disconnect", func():
		_net_end("O servidor de relay encerrou a conexão (a sala fechou ou o host saiu)."))
	return nt


func _start_relay(nt: MultiplayerPeer) -> void:
	phase = Phase.CONNECTING
	_connect_timer = CONNECT_TIMEOUT
	status_changed.emit("Conectando ao servidor de relay (%s)..." % relay_address)
	var err: int = nt.call(&"connect_to_relay", relay_address, relay_app_id)
	if err != OK:
		_fail("Não foi possível contatar o relay %s (%s). Verifique a internet." % [relay_address, error_string(err)])
		return
	# Instala JÁ como peer do jogo: o Godot passa a "pollar" a conexão e
	# enxerga todos os eventos (inclusive a chegada do host).
	_install_peer(nt, Mode.RELAY)
	phase = Phase.CONNECTING


static func _translate_relay_error(msg: String) -> String:
	if msg.contains("Room not found"):
		return "Sala não encontrada. Confira o código (a sala some quando o host sai)."
	if msg.contains("denied"):
		return "O host recusou a entrada (sala cheia, partida já começou ou versão diferente do jogo)."
	if msg.contains("App token"):
		return "O relay não aceitou o App ID. Confira o App ID em config/network.cfg."
	if msg.contains("Version"):
		return "A versão do plugin NodeTunnel não é aceita por este relay."
	if msg.contains("full"):
		return "O servidor de relay está lotado. Tente mais tarde."
	return msg


# ================================================================== lobby
func _install_peer(p: MultiplayerPeer, m: Mode) -> void:
	_peer = p
	mode = m
	multiplayer.multiplayer_peer = p


func _become_lobby_host() -> void:
	_connect_timer = -1.0
	phase = Phase.LOBBY
	players.clear()
	players[1] = {"name": local_player_name, "ready": false}
	_last_seen.clear()
	room_ready.emit(room_code)
	lobby_updated.emit()
	status_changed.emit("Sala criada. Código: %s" % room_code)


func _on_connected_to_server() -> void:
	_connect_timer = -1.0
	phase = Phase.LOBBY
	_last_seen[1] = _clock
	status_changed.emit("Conectado. Registrando...")
	_rpc_register.rpc_id(1, local_player_name, GAME_VERSION)


func _on_connection_failed() -> void:
	_net_fail("Não foi possível conectar ao host. Confira o IP e se o host criou a sala.")


func _on_peer_connected(id: int) -> void:
	_last_seen[id] = _clock
	# Clientes esperam o registro (nome/versão) para entrar na lista.


func _on_peer_disconnected(id: int) -> void:
	_last_seen.erase(id)
	if not is_online():
		return
	if id == 1 and not multiplayer.is_server():
		_net_end("O host encerrou a partida ou perdeu a conexão.")
		return
	if players.has(id):
		var n := get_player_name(id)
		players.erase(id)
		player_left.emit(id, n)
		if is_host():
			_rpc_lobby_state.rpc(players, phase)
			_check_all_ready()
		lobby_updated.emit()


func _on_server_disconnected() -> void:
	_net_end("A conexão com o host foi perdida.")


@rpc("any_peer", "call_remote", "reliable")
func _rpc_register(player_name: String, version: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var reason := ""
	if version != GAME_VERSION:
		reason = "Versão diferente (host %s, sua %s). Atualizem o jogo." % [GAME_VERSION, version]
	elif players.size() >= MAX_PLAYERS:
		reason = "A sala está cheia (máximo %d jogadores)." % MAX_PLAYERS
	elif phase != Phase.LOBBY:
		reason = "A partida já começou."
	if not reason.is_empty():
		_rpc_rejected.rpc_id(id, reason)
		_kick_later(id)
		return
	players[id] = {"name": _unique_name(sanitize_name(player_name)), "ready": false}
	_last_seen[id] = _clock
	player_joined.emit(id, players[id].name)
	_rpc_lobby_state.rpc(players, phase)
	lobby_updated.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_rejected(reason: String) -> void:
	_net_end(reason)


@rpc("authority", "call_remote", "reliable")
func _rpc_lobby_state(state: Dictionary, host_phase: int) -> void:
	var before := players.keys()
	players = {}
	for k in state.keys():
		players[int(k)] = state[k]
	# Na primeira lista recebida todos "já estavam lá": sem avisos de entrada.
	if not before.is_empty():
		for k in players.keys():
			if not before.has(k) and k != my_id():
				player_joined.emit(k, get_player_name(k))
	if room_code.is_empty():
		room_code = "?"
	if phase == Phase.LOBBY and before.is_empty():
		room_ready.emit(room_code)
	lobby_updated.emit()


func _unique_name(n: String) -> String:
	var names := []
	for p in players.values():
		names.append(p.name)
	if not names.has(n):
		return n
	var i := 2
	while names.has("%s %d" % [n, i]):
		i += 1
	return "%s %d" % [n, i]


func _kick_later(id: int) -> void:
	# Dá tempo da mensagem de recusa chegar antes de desconectar.
	await get_tree().create_timer(0.5).timeout
	if _peer and _peer is ENetMultiplayerPeer and multiplayer.get_peers().has(id):
		(_peer as ENetMultiplayerPeer).disconnect_peer(id)
	# (NodeTunnel não permite expulsar; o cliente recusado sai sozinho.)


# ================================================================ sessão
## Só o host. Leva todos para a fase.
func start_session() -> void:
	if not is_host() or phase != Phase.LOBBY:
		return
	for k in players.keys():
		players[k].ready = false
	_rpc_load_game.rpc()
	_rpc_load_game()


@rpc("authority", "call_remote", "reliable")
func _rpc_load_game() -> void:
	phase = Phase.LOADING
	_last_valid.clear()
	_state_seq = 0
	_ready_timer = READY_TIMEOUT if multiplayer.is_server() else -1.0
	session_loading.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)


## A cena da fase chama isto quando terminou de montar os jogadores.
func notify_scene_ready() -> void:
	if not is_online():
		return
	if multiplayer.is_server():
		_mark_ready(1)
	else:
		_rpc_client_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_ready() -> void:
	if multiplayer.is_server():
		_mark_ready(multiplayer.get_remote_sender_id())


func _mark_ready(id: int) -> void:
	if players.has(id):
		players[id].ready = true
	_check_all_ready()


func _check_all_ready() -> void:
	if not is_host() or phase != Phase.LOADING:
		return
	for p in players.values():
		if not p.ready:
			return
	_ready_timer = -1.0
	_rpc_begin.rpc()
	_rpc_begin()


@rpc("authority", "call_remote", "reliable")
func _rpc_begin() -> void:
	phase = Phase.PLAYING
	session_started.emit()


## Sair da sala/partida (qualquer jogador). O host sair encerra para todos.
func leave(reason: String = "") -> void:
	if is_online() and phase != Phase.CONNECTING:
		# Avisa antes de fechar: os outros não precisam esperar o timeout.
		if multiplayer.is_server():
			_rpc_goodbye.rpc()
		else:
			_rpc_goodbye.rpc_id(1)
	_end_session(reason, true)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_goodbye() -> void:
	var id := multiplayer.get_remote_sender_id()
	if id == 1 and not multiplayer.is_server():
		_net_end("O host encerrou a partida.")
	elif multiplayer.is_server():
		_on_peer_disconnected(id)


func _end_session(reason: String, _voluntary: bool = false) -> void:
	var was_online := mode != Mode.OFFLINE or phase != Phase.IDLE
	last_end_reason = reason
	_reset()
	if not was_online:
		return
	session_ended.emit(reason)
	# Volta ao menu se estivermos em outra cena (ex.: no meio da partida).
	var tree := get_tree()
	if tree and tree.current_scene and tree.current_scene.scene_file_path != MAIN_MENU_SCENE:
		tree.paused = false
		tree.change_scene_to_file(MAIN_MENU_SCENE)


## Versões "seguras" para usar DENTRO de eventos de rede (sinais da conexão,
## RPCs). Trocar o multiplayer_peer enquanto o Godot ainda está processando
## pacotes dessa conexão derruba o jogo, então o encerramento é adiado para o
## fim do quadro. Chamadas repetidas viram uma só.
var _ending: bool = false


func _net_end(reason: String) -> void:
	if _ending:
		return
	_ending = true
	_finish_net_end.call_deferred(reason, false)


func _net_fail(reason: String) -> void:
	if _ending:
		return
	_ending = true
	_finish_net_end.call_deferred(reason, true)


func _finish_net_end(reason: String, as_failure: bool) -> void:
	_ending = false
	if as_failure:
		if phase == Phase.CONNECTING:
			_fail(reason)
		elif mode != Mode.OFFLINE:
			_end_session(reason)
	else:
		_end_session(reason)


func _fail(reason: String) -> void:
	last_end_reason = reason
	_reset()
	connection_failed.emit(reason)
	status_changed.emit(reason)


func _reset() -> void:
	_connect_timer = -1.0
	_ready_timer = -1.0
	if _peer is ENetMultiplayerPeer:
		# ENet: envia o que estiver na fila (despedida) e fecha na hora, para
		# a porta ficar livre e uma nova sala poder ser criada em seguida.
		var enet := _peer as ENetMultiplayerPeer
		if enet.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
			if enet.host:
				enet.host.flush()
			enet.close()
	elif _peer:
		# Relay: mantém a conexão viva por um instante para a última mensagem
		# (despedida) sair de verdade; depois fecha.
		_closing.append({"peer": _peer, "t": 0.5})
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.OFFLINE
	phase = Phase.IDLE
	room_code = ""
	players.clear()
	_last_seen.clear()
	_last_interact_seq.clear()
	_last_interact_time.clear()
	_last_valid.clear()
	_last_correction.clear()


var _closing: Array[Dictionary] = []


func _poll_closing(delta: float) -> void:
	for c in _closing.duplicate():
		c.t -= delta
		var p: MultiplayerPeer = c.peer
		if p.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
			p.poll()
		if c.t <= 0.0:
			if p.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
				p.close()
			_closing.erase(c)


# ========================================================== interações
## Chamado pelo Interactor do jogador local. Em partida online o pedido vai
## para o host, que valida e manda TODOS executarem na mesma ordem.
func request_interact(target: Interactable, interactor: Node) -> bool:
	if not is_session_active():
		return target.interact(interactor)
	var path := _scene_path(target)
	if path.is_empty():
		return false
	_interact_seq += 1
	if multiplayer.is_server():
		_host_handle_interact(1, path, _interact_seq)
	else:
		_rpc_request_interact.rpc_id(1, path, _interact_seq)
	return true


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_interact(path: String, seq: int) -> void:
	if multiplayer.is_server():
		_host_handle_interact(multiplayer.get_remote_sender_id(), path, seq)


func _host_handle_interact(peer_id: int, path: String, seq: int) -> void:
	# Pedidos repetidos (mesmo seq) ou rápidos demais são ignorados.
	if seq <= int(_last_interact_seq.get(peer_id, 0)):
		return
	if _clock - float(_last_interact_time.get(peer_id, -10.0)) < 0.15:
		return
	var scene := get_tree().current_scene
	if scene == null or path.is_empty() or path.contains(".."):
		return
	var target := scene.get_node_or_null(NodePath(path)) as Interactable
	var player := _player_node(peer_id)
	if target == null or player == null:
		return
	var interactor: Node = player.get(&"interactor")
	if interactor == null or not target.can_interact(interactor) or target.is_on_cooldown():
		return
	# O jogador precisa estar perto do objeto (posição conhecida pelo host).
	var reach: float = float(interactor.get(&"interaction_distance")) + 1.6
	var eye: Vector3 = (player as Node3D).global_position + Vector3.UP * 1.6
	if eye.distance_to(_closest_point(target, eye)) > reach:
		return
	_last_interact_seq[peer_id] = seq
	_last_interact_time[peer_id] = _clock
	var params := target.get_net_params(interactor)
	_rpc_do_interact.rpc(path, peer_id, params)
	_rpc_do_interact(path, peer_id, params)


@rpc("authority", "call_remote", "reliable")
func _rpc_do_interact(path: String, peer_id: int, params: Dictionary) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var target := scene.get_node_or_null(NodePath(path)) as Interactable
	var player := _player_node(peer_id)
	if target == null or player == null:
		return
	target.interact_networked(player.get(&"interactor"), params)


func _closest_point(target: Interactable, from: Vector3) -> Vector3:
	# Aproximação: centro da forma de colisão mais próxima.
	var best := target.global_position
	var best_d := INF
	for c in target.get_children():
		if c is CollisionShape3D:
			var p := (c as CollisionShape3D).global_position
			var d := p.distance_to(from)
			if d < best_d:
				best_d = d
				best = p
	return best


func _scene_path(n: Node) -> String:
	var scene := get_tree().current_scene
	if scene == null or not scene.is_ancestor_of(n):
		return ""
	return String(scene.get_path_to(n))


func _player_node(peer_id: int) -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null(NodePath("Players/P%d" % peer_id)) if scene else null


## Só o host: envia o estado completo de um objeto a todos (correção).
func broadcast_object_state(target: Node, state: Dictionary) -> void:
	if not is_host() or not is_session_active():
		return
	var path := _scene_path(target)
	if not path.is_empty():
		_rpc_object_state.rpc(path, state)


@rpc("authority", "call_remote", "reliable")
func _rpc_object_state(path: String, state: Dictionary) -> void:
	var scene := get_tree().current_scene
	if scene == null or path.contains(".."):
		return
	var target := scene.get_node_or_null(NodePath(path))
	if target and target.has_method(&"apply_net_state"):
		target.call(&"apply_net_state", state)


# ===================================================== estado dos jogadores
const STATE_RATE := 20.0               ## envios por segundo (cada jogador)
const MAX_PLAUSIBLE_SPEED := 5.4 * 1.6 ## corrida + folga
const FLAG_SPRINT := 1
const FLAG_GROUNDED := 2
const FLAG_FLASHLIGHT := 4

var _state_seq: int = 0
var _last_valid: Dictionary = {}      # peer_id -> {pos, t}  (host)
var _last_correction: Dictionary = {} # peer_id -> tempo     (host)


func clock() -> float:
	return _clock


## Chamado pelo jogador LOCAL a cada envio (20 Hz).
func send_local_state(pos: Vector3, yaw: float, pitch: float, vel: Vector3, flags: int) -> void:
	if not is_playing():
		return
	_state_seq += 1
	if multiplayer.is_server():
		_relay_state(1, _state_seq, pos, yaw, pitch, vel, flags)
	else:
		_rpc_state.rpc_id(1, _state_seq, pos, yaw, pitch, vel, flags)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_state(seq: int, pos: Vector3, yaw: float, pitch: float, vel: Vector3, flags: int) -> void:
	if not multiplayer.is_server() or phase != Phase.PLAYING:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	_last_seen[id] = _clock
	if not _plausible(id, pos, vel, yaw, pitch):
		return
	var p := _player_node(id)
	if p and p.has_method(&"push_snapshot"):
		p.call(&"push_snapshot", seq, pos, yaw, pitch, vel, flags)
	_relay_state(id, seq, pos, yaw, pitch, vel, flags)


## Host: repassa o estado de `id` a todos os outros clientes (um envio por
## destinatário; ninguém recebe de volta o próprio estado).
func _relay_state(id: int, seq: int, pos: Vector3, yaw: float, pitch: float, vel: Vector3, flags: int) -> void:
	for other in players.keys():
		if other != 1 and other != id:
			_rpc_peer_state.rpc_id(other, id, seq, pos, yaw, pitch, vel, flags)


@rpc("authority", "call_remote", "unreliable")
func _rpc_peer_state(id: int, seq: int, pos: Vector3, yaw: float, pitch: float, vel: Vector3, flags: int) -> void:
	if phase != Phase.PLAYING or id == my_id():
		return
	_last_seen[1] = _clock
	var p := _player_node(id)
	if p and p.has_method(&"push_snapshot"):
		p.call(&"push_snapshot", seq, pos, yaw, pitch, vel, flags)


## Host: recusa posições impossíveis (teleporte, velocidade absurda, NaN).
func _plausible(id: int, pos: Vector3, vel: Vector3, yaw: float, pitch: float) -> bool:
	if not (pos.is_finite() and vel.is_finite() and is_finite(yaw) and is_finite(pitch)):
		return false
	if absf(pos.x) > 500.0 or absf(pos.z) > 500.0 or pos.y < -60.0 or pos.y > 60.0:
		return false
	var last: Variant = _last_valid.get(id)
	var ok := true
	if last == null:
		ok = _near_spawn(pos, 4.0)
	else:
		var dt := _clock - float(last.t)
		var flat := Vector2(pos.x - last.pos.x, pos.z - last.pos.z).length()
		var allowed := MAX_PLAUSIBLE_SPEED * (dt + 0.25) + 0.5
		# Voltar ao ponto inicial (queda para fora do mapa) é permitido.
		ok = flat <= allowed or _near_spawn(pos, 1.5)
	if ok:
		_last_valid[id] = {"pos": pos, "t": _clock}
	elif _clock - float(_last_correction.get(id, -10.0)) > 0.5 and last != null:
		_last_correction[id] = _clock
		_rpc_correct.rpc_id(id, last.pos)
	return ok


func _near_spawn(pos: Vector3, radius: float) -> bool:
	for sp in get_tree().get_nodes_in_group(&"player_spawn"):
		if (sp as Node3D).global_position.distance_to(pos) <= radius:
			return true
	return false


## Cliente: o host recusou o movimento; volta para a última posição válida.
@rpc("authority", "call_remote", "reliable")
func _rpc_correct(pos: Vector3) -> void:
	var p := _player_node(my_id())
	if p and p.has_method(&"net_correct"):
		p.call(&"net_correct", pos)


# =========================================================== heartbeat
@rpc("any_peer", "call_remote", "unreliable")
func _rpc_ping() -> void:
	_last_seen[multiplayer.get_remote_sender_id()] = _clock


## Qualquer mensagem de um peer conta como "vivo" (chamado pelos jogadores).
func mark_seen(peer_id: int) -> void:
	_last_seen[peer_id] = _clock


func _process(delta: float) -> void:
	_clock += delta
	_poll_closing(delta)
	if _connect_timer > 0.0:
		_connect_timer -= delta
		if _connect_timer <= 0.0:
			_fail("Tempo esgotado ao conectar. Verifique o código/IP e a internet.")
			return
	if _ready_timer > 0.0:
		_ready_timer -= delta
		if _ready_timer <= 0.0 and is_host() and phase == Phase.LOADING:
			# Quem não carregou a tempo fica de fora; a partida começa.
			for k in players.keys():
				if not players[k].ready and k != 1:
					var n := get_player_name(k)
					players.erase(k)
					_rpc_rejected.rpc_id(k, "Seu computador demorou demais para carregar a fase.")
					_kick_later(k)
					player_left.emit(k, n)
			_rpc_lobby_state.rpc(players, phase)
			_check_all_ready()
	if not is_online() or phase == Phase.CONNECTING:
		return
	_heartbeat_timer -= delta
	if _heartbeat_timer <= 0.0:
		_heartbeat_timer = HEARTBEAT_INTERVAL
		if multiplayer.is_server():
			_rpc_ping.rpc()
		else:
			_rpc_ping.rpc_id(1)
		_check_timeouts()


func _check_timeouts() -> void:
	# Proteção extra: alguns relays não avisam quando alguém cai.
	if multiplayer.is_server():
		for id in players.keys():
			if id != 1 and _clock - float(_last_seen.get(id, _clock)) > HEARTBEAT_TIMEOUT:
				_on_peer_disconnected(id)
	elif _clock - float(_last_seen.get(1, _clock)) > HEARTBEAT_TIMEOUT:
		_end_session("Sem resposta do host há %d segundos." % int(HEARTBEAT_TIMEOUT))


# ============================================================== config
func _load_config() -> void:
	# Ordem: arquivo do projeto -> "network.cfg" ao lado do .exe exportado
	# (permite trocar o App ID sem reexportar). O último encontrado vence.
	var paths := [CONFIG_PATH]
	if OS.has_feature("template"):
		paths.append(OS.get_executable_path().get_base_dir().path_join("network.cfg"))
	for path in paths:
		var cfg := ConfigFile.new()
		if cfg.load(path) == OK:
			relay_address = String(cfg.get_value("relay", "address", relay_address)).strip_edges()
			var app := String(cfg.get_value("relay", "app_id", "")).strip_edges()
			if not app.is_empty():
				relay_app_id = app
	# Variáveis de ambiente (úteis para testes): PNS_RELAY / PNS_APP_ID
	if OS.has_environment("PNS_RELAY"):
		relay_address = OS.get_environment("PNS_RELAY")
	if OS.has_environment("PNS_APP_ID"):
		relay_app_id = OS.get_environment("PNS_APP_ID")
	var settings := get_node_or_null(^"/root/GameSettings")
	if settings and "player_name" in settings:
		local_player_name = sanitize_name(settings.get(&"player_name"))
