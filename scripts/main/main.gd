extends Node3D
## Cena principal da partida.
##
## Responsável por "montar" a partida:
##  - cria os jogadores a partir de player.tscn nos pontos de nascimento;
##  - liga os sinais do jogador LOCAL à interface (HUD);
##  - trata quedas para fora do mapa (KillZone).
##
## Offline: um jogador ("Players/LocalPlayer").
## Online: um nó por jogador conectado, chamado "Players/P<id>" (o mesmo nome
## em todos os computadores, para a rede achar o jogador certo). O host usa o
## primeiro ponto do grupo "player_spawn"; os outros seguem a ordem dos ids.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
## Cores dos macacões, na ordem de entrada (até 6 jogadores).
const SUIT_COLORS := [
	Color(0.36, 0.38, 0.42), Color(0.62, 0.42, 0.12), Color(0.18, 0.4, 0.52),
	Color(0.5, 0.2, 0.18), Color(0.28, 0.45, 0.22), Color(0.45, 0.3, 0.5),
]

var local_player: Player

@onready var _players: Node3D = $Players
@onready var _hud: HUD = $HUD


func _ready() -> void:
	if Net.is_session_active():
		_spawn_online_players()
	else:
		local_player = spawn_player(true, 0)
	_connect_hud(local_player)
	for kz in get_tree().get_nodes_in_group(&"kill_zone"):
		if kz.has_signal(&"player_fell"):
			kz.connect(&"player_fell", _on_player_fell)
	GameManager.reset_pause_state()
	GameManager.pause_changed.connect(_on_pause_changed)
	GameManager.capture_mouse()
	if Net.is_session_active():
		# Ninguém se move até todos terem carregado a fase.
		local_player.set_controls_enabled(false)
		_hud.show_feedback("Aguardando os outros jogadores...")
		Net.session_started.connect(_on_session_started)
		Net.player_left.connect(_on_net_player_left)
		Net.status_changed.connect(_on_net_status)
		Net.notify_scene_ready()


func spawn_player(is_local: bool, spawn_index: int, peer_id: int = 1, player_name: String = "") -> Player:
	var p := PLAYER_SCENE.instantiate() as Player
	p.is_local = is_local
	p.net_id = peer_id
	p.display_name = player_name
	p.suit_color = SUIT_COLORS[spawn_index % SUIT_COLORS.size()]
	if Net.is_session_active():
		p.name = "P%d" % peer_id
	else:
		p.name = "LocalPlayer" if is_local else "Player%d" % spawn_index
	_players.add_child(p)
	p.teleport_to(_get_spawn_transform(spawn_index))
	return p


func _spawn_online_players() -> void:
	var ids := Net.get_player_ids()
	var me := Net.my_id()
	for i in ids.size():
		var id: int = ids[i]
		var p := spawn_player(id == me, i, id, Net.get_player_name(id))
		if id == me:
			local_player = p
	if local_player == null:
		# Segurança: nunca ficar sem jogador local.
		local_player = spawn_player(true, ids.size(), me, Net.local_player_name)


func _get_spawn_transform(index: int) -> Transform3D:
	var spawns := get_tree().get_nodes_in_group(&"player_spawn")
	if spawns.is_empty():
		push_warning("Nenhum nó no grupo 'player_spawn'; usando a origem.")
		return Transform3D(Basis.IDENTITY, Vector3(0, 1, 0))
	return (spawns[index % spawns.size()] as Node3D).global_transform


func _connect_hud(p: Player) -> void:
	p.interactor.prompt_changed.connect(_hud.set_prompt)
	p.interactor.feedback_message.connect(_hud.show_feedback)
	p.flashlight.toggled.connect(_hud.set_flashlight)
	_hud.set_flashlight(p.flashlight.is_on)


func _on_player_fell(body: Node3D) -> void:
	# Só o jogador local é reposicionado aqui; os remotos seguem a rede.
	if body is Player and (body as Player).is_local:
		(body as Player).teleport_to(_get_spawn_transform(0))
		_hud.show_feedback("Você voltou ao ponto inicial.")


func _on_pause_changed(paused: bool) -> void:
	# Online o mundo não congela: só tiramos o controle do jogador.
	if Net.is_session_active() and local_player:
		local_player.set_controls_enabled(not paused and Net.is_playing())


func _on_session_started() -> void:
	if local_player and not GameManager.is_paused:
		local_player.set_controls_enabled(true)
	_hud.show_feedback("Todos conectados. Boa sorte.")


func _on_net_player_left(peer_id: int, player_name: String) -> void:
	var node := _players.get_node_or_null(NodePath("P%d" % peer_id))
	if node:
		node.queue_free()
	_hud.show_feedback("%s saiu da partida." % player_name)


func _on_net_status(text: String) -> void:
	if text.begins_with("Aviso"):
		_hud.show_feedback(text)
