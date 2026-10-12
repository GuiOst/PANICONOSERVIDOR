extends SceneTree
## TESTE DE MULTIPLAYER COM PROCESSOS SEPARADOS (instâncias reais do Godot).
##
## Não rode este arquivo sozinho: use tools/tests/run_net_test.sh, que abre
## o host e os clientes ao mesmo tempo e confere os resultados de cada um.
##
## Argumentos (depois de "--"):
##   --role=host|client   --name=Nome   --transport=lan|relay
##   --scenario=main|kill|full|hostleave   --codefile=/caminho   --players=N
##
## Cada instância imprime "[OK]" / "[FALHA]" e no fim
## "=== RESULTADO REDE <papel> <nome>: X OK, Y FALHA(S) ===".

const PORT := 24599

var net: Node
var gm: Node
var bridge: Node
var args := {}
var role := "host"
var my_name := "?"
var transport := "lan"
var scenario := "main"
var codefile := ""
var expected_players := 2
var _ok := 0
var _fail := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	role = args.get("role", "host")
	my_name = args.get("name", "Anfitriao" if role == "host" else "Convidado")
	transport = args.get("transport", "lan")
	scenario = args.get("scenario", "main")
	codefile = args.get("codefile", "/tmp/pns_code.txt")
	expected_players = int(args.get("players", "2"))
	_run.call_deferred()


# ================================================================ util
func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  [OK] ", msg)
	else:
		_fail += 1
		print("  [FALHA] ", msg)


func _log(msg: String) -> void:
	print("[%s %s %.2f] %s" % [role, my_name, Time.get_ticks_msec() / 1000.0, msg])


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(t: float) -> void:
	await create_timer(t).timeout


func _wait_until(cond: Callable, timeout: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > int(timeout * 1000.0):
			return false
		await process_frame
	return true


## Espera todos os `count` participantes chegarem ao mesmo ponto.
func _barrier(bname: String, count: int, timeout: float = 30.0) -> bool:
	var key := "b:%s:%s" % [bname, my_name]
	var t0 := Time.get_ticks_msec()
	var last_put := -10000
	while bridge.count_prefix("b:%s:" % bname) < count:
		if Time.get_ticks_msec() - last_put > 400:
			bridge.put(key, true) # reenviado até todos chegarem
			last_put = Time.get_ticks_msec()
		if Time.get_ticks_msec() - t0 > int(timeout * 1000.0):
			_log("barreira '%s' expirou (%d/%d)" % [bname, bridge.count_prefix("b:%s:" % bname), count])
			return false
		await process_frame
	bridge.put(key, true)
	return true


func _scene() -> Node:
	return current_scene


func _player(id: int) -> Node:
	var s := current_scene
	return s.get_node_or_null("Players/P%d" % id) if s else null


func _me() -> Node:
	return _player(net.my_id())


func _door() -> Node:
	return current_scene.get_node("Level/MaintenanceRoom/DoorMaintenance")


func _hold(actions: Array, frames: int) -> void:
	for a in actions:
		Input.action_press(a)
	await _frames(frames)
	for a in actions:
		Input.action_release(a)


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await process_frame


## Move o jogador local em linha reta numa velocidade plausível (3,5 m/s),
## como se estivesse andando. Atravessa paredes (é só um teste), mas o host
## vê uma velocidade normal e aceita.
func _glide(p: Node, target: Vector3, yaw_deg: float, speed: float = 3.5) -> void:
	var mask: int = p.collision_mask
	p.collision_mask = 0 # sem colisão durante o deslize (só no teste)
	var limit := Time.get_ticks_msec() + int((p.global_position.distance_to(target) / speed + 5.0) * 1000.0)
	while p.global_position.distance_to(target) > 0.05:
		if Time.get_ticks_msec() > limit:
			_log("deslize não chegou ao destino (%s)" % p.global_position)
			break
		var step := speed * (1.0 / Engine.physics_ticks_per_second)
		p.global_position = p.global_position.move_toward(target, step)
		p.velocity = Vector3.ZERO
		await physics_frame
	p.collision_mask = mask
	p.rotation.y = deg_to_rad(yaw_deg)
	p.look.rotation.x = 0.0
	await _frames(4)


func _finish() -> void:
	print("=== RESULTADO REDE %s %s: %d OK, %d FALHA(S) ===" % [role, my_name, _ok, _fail])
	if net:
		net.leave()
	await _secs(0.6)
	quit(1 if _fail > 0 else 0)


# ================================================================ conexão
func _host_create() -> bool:
	net.set_local_player_name(my_name)
	if transport == "lan":
		net.create_lan_room(PORT)
	else:
		net.create_online_room()
	var ok: bool = await _wait_until(func(): return net.phase == net.Phase.LOBBY and net.room_code != "", 20.0)
	_check(ok, "host: sala criada (código '%s')" % net.room_code)
	if not ok:
		_log("motivo: %s" % net.last_end_reason)
		return false
	_check(net.is_host() and net.players.size() == 1, "host aparece na lista como host (id 1)")
	var f := FileAccess.open(codefile, FileAccess.WRITE)
	f.store_string("127.0.0.1:%d" % PORT if transport == "lan" else net.room_code)
	f.close()
	return true


func _client_join(check: bool = true) -> bool:
	net.set_local_player_name(my_name)
	# (lambdas copiam variáveis simples, por isso o arquivo é lido de novo)
	await _wait_until(func(): return FileAccess.file_exists(codefile) and FileAccess.get_file_as_string(codefile).strip_edges() != "", 20.0)
	var code := FileAccess.get_file_as_string(codefile).strip_edges() if FileAccess.file_exists(codefile) else ""
	if code == "":
		_check(false, "cliente: código da sala disponível")
		return false
	_log("entrando com o código %s" % code)
	if transport == "lan":
		net.join_lan(code)
	else:
		net.join_online(code)
	var ok: bool = await _wait_until(func(): return net.phase == net.Phase.LOBBY and net.players.has(net.my_id()), 20.0)
	if check:
		_check(ok, "cliente: entrou na sala e recebeu a lista (id %d)" % net.my_id())
	if not ok:
		_log("motivo: %s" % net.last_end_reason)
	return ok


func _start_and_enter(n: int) -> bool:
	if role == "host":
		var all_in: bool = await _wait_until(func(): return net.players.size() == n, 40.0)
		_check(all_in, "host: %d jogadores na sala (%d)" % [n, net.players.size()])
		if not await _barrier("lobby_%s" % scenario, n):
			return false
		net.start_session()
	else:
		await _barrier("lobby_%s" % scenario, n)
	var playing: bool = await _wait_until(func(): return net.is_playing() and _me() != null, 40.0)
	_check(playing, "partida começou e a fase carregou")
	if not playing:
		return false
	await _frames(10)
	return true


# ================================================================ cenários
func _run() -> void:
	net = root.get_node("Net")
	gm = root.get_node("GameManager")
	bridge = Node.new()
	bridge.set_script(load("res://tools/tests/net_test_bridge.gd"))
	bridge.name = "TestBridge"
	root.add_child(bridge)
	# Guarda o último motivo de desconexão (o menu apaga o de Net ao exibir).
	net.session_ended.connect(func(r: String): bridge.data["reason"] = r)
	net.connection_failed.connect(func(r: String): bridge.data["reason"] = r)
	if transport == "relay":
		net.relay_address = OS.get_environment("PNS_RELAY") if OS.has_environment("PNS_RELAY") else "127.0.0.1:8080"
		net.relay_app_id = OS.get_environment("PNS_APP_ID") if OS.has_environment("PNS_APP_ID") else "pns-teste-local"
	print("\n=== Teste de rede: %s '%s' via %s, cenário %s ===" % [role, my_name, transport, scenario])
	match scenario:
		"main":
			await _scenario_main()
		"kill":
			await _scenario_kill()
		"full":
			await _scenario_full()
		"hostleave":
			await _scenario_hostleave()
		"errors":
			await _scenario_errors()
		"ui":
			await _scenario_ui()
		"killclient":
			await _scenario_killclient()
	_finish()


## Dois jogadores: lobby, movimento, portas, itens, validações, saída.
func _scenario_main() -> void:
	if role == "host":
		if not await _host_create():
			return
	else:
		if not await _client_join():
			return
	await _wait_until(func(): return net.players.size() == 2, 20.0)
	var names := []
	for id in net.get_player_ids():
		names.append(net.get_player_name(id))
	_check(names.has("Anfitriao") and names.has("Convidado"), "lista mostra os dois nomes %s" % [names])
	_check(net.get_player_name(1) == "Anfitriao", "o id 1 (host) é o Anfitriao")
	if not await _start_and_enter(2):
		return
	var ids: Array = net.get_player_ids()
	var other_id: int = ids[1] if ids[0] == net.my_id() else ids[0]
	var me = _me()
	var other = _player(other_id)
	_check(me != null and me.is_local, "meu jogador é local (P%d)" % net.my_id())
	_check(other != null and not other.is_local, "o outro jogador existe e é remoto (P%d)" % other_id)
	_check(current_scene.get_node("Players").get_child_count() == 2, "exatamente 2 jogadores na cena")
	if other:
		_check(other.get_node("Model").visible and not me.get_node("Model").visible, "vejo o corpo do outro, não o meu")
		_check(other.get_node("Model/NameLabel").text == net.get_player_name(other_id), "nome acima da cabeça: '%s'" % other.get_node("Model/NameLabel").text)
	await _barrier("ingame", 2)

	# ---------------------------------------------------- movimento
	print("\n[Movimento sincronizado]")
	if role == "host":
		await _hold([&"move_forward"], 60)
		await _frames(30)
		bridge.put("host_pos", me.global_position)
		await _barrier("host_moved", 2)
		await _barrier("client_moving", 2)
		var max_jump := 0.0
		var prev: Vector3 = other.global_position
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 3000:
			await process_frame
			max_jump = maxf(max_jump, other.global_position.distance_to(prev))
			prev = other.global_position
		await _barrier("client_moved", 2)
		await _secs(0.5)
		var cpos: Vector3 = bridge.data.get("client_pos", Vector3.INF)
		var d: float = other.global_position.distance_to(cpos)
		_check(d < 0.2, "host vê o cliente onde ele realmente está (diferença %.3f m)" % d)
		_check(max_jump < 0.35, "movimento remoto suave (maior salto entre quadros %.3f m)" % max_jump)
		_check(other.get_horizontal_speed() < 0.3, "cliente parado aparece parado")
	else:
		await _barrier("host_moved", 2)
		await _secs(0.5)
		var hpos: Vector3 = bridge.data.get("host_pos", Vector3.INF)
		var d: float = other.global_position.distance_to(hpos)
		_check(hpos != Vector3.INF and d < 0.2, "cliente vê o host onde ele realmente está (diferença %.3f m)" % d)
		_check(hpos.z < -1.5, "host andou para frente (z = %.2f)" % hpos.z)
		await _barrier("client_moving", 2)
		await _hold([&"move_forward", &"sprint"], 70)
		await _hold([&"move_left"], 30)
		await _frames(30)
		bridge.put("client_pos", me.global_position)
		await _barrier("client_moved", 2)

	# ---------------------------------------------------- lanterna
	print("\n[Lanterna sincronizada]")
	if role == "client":
		await _press(&"toggle_flashlight")
	await _barrier("flash_on", 2)
	await _secs(0.6)
	if role == "host":
		_check(other.flashlight.is_on, "host vê a lanterna do cliente ligada")
	else:
		_check(me.flashlight.is_on, "cliente ligou a própria lanterna")
	await _barrier("flash_checked", 2)

	# ---------------------------------------------------- porta (cliente abre)
	print("\n[Porta aberta pelo cliente]")
	var door = _door()
	if role == "client":
		await _glide(me, Vector3(-0.6, 0.05, -10.5), 90)
		_check(me.interactor.current_target != null, "cliente mira a porta")
		me.interactor.try_interact()
	await _barrier("door_req", 2)
	await _secs(1.8)
	_check(door.state == door.State.OPEN, "porta ABERTA neste computador")
	_check(door.get_node("Panel").rotation.y > 1.5, "abriu para longe de quem abriu (%.0f°)" % rad_to_deg(door.get_node("Panel").rotation.y))
	bridge.put("door_rot_" + role, door.get_node("Panel").rotation.y)
	await _barrier("door_open", 2)
	var rot_other: float = bridge.data.get("door_rot_" + ("client" if role == "host" else "host"), 99.0)
	_check(absf(rot_other - door.get_node("Panel").rotation.y) < 0.01, "mesmo ângulo nos dois computadores")

	# ---------------------------------------------------- pedido duplicado
	print("\n[Pedido duplicado não executa duas vezes]")
	if role == "client":
		var ia_dup = door.get_node("Panel/InteractArea")
		net.request_interact(ia_dup, me.interactor)
		net.request_interact(ia_dup, me.interactor) # mesmo quadro: deve ser ignorado
	await _barrier("door_dup", 2)
	await _secs(1.8)
	_check(door.state == door.State.CLOSED, "porta FECHADA uma vez só (estado %s)" % door.State.keys()[door.state])
	await _barrier("door_dup_checked", 2)

	# ---------------------------------------------------- bloqueio decidido pelo host
	print("\n[Porta não fecha em cima do jogador (decisão do host)]")
	if role == "client":
		me.interactor.try_interact() # abre de novo
	await _barrier("door_reopen", 2)
	await _secs(1.8)
	if role == "client":
		# Dentro da sala, no arco que a folha percorre ao fechar.
		await _glide(me, Vector3(-2.9, 0.05, -10.4), 0)
	else:
		await _glide(me, Vector3(-0.3, 0.05, -11.6), 90)
	await _barrier("in_position", 2)
	await _secs(0.5)
	if role == "host":
		var ia = door.get_node("Panel/InteractArea")
		_check(net.request_interact(ia, me.interactor), "host pede para fechar a porta")
	var closing: bool = await _wait_until(func(): return door.state == door.State.CLOSING, 1.5)
	_check(closing, "a porta começou a fechar aqui")
	await _secs(2.5)
	_check(door.state == door.State.OPEN, "porta reabriu ao encostar no cliente (estado %s)" % door.State.keys()[door.state])
	bridge.put("door_p_" + role, door._progress)
	await _barrier("block_checked", 2)
	var p_other: float = bridge.data.get("door_p_" + ("client" if role == "host" else "host"), -1.0)
	_check(absf(p_other - door._progress) < 0.01, "estado da porta igual nos dois (%.2f x %.2f)" % [door._progress, p_other])

	# ---------------------------------------------------- mensagem só para quem interagiu
	print("\n[Portão trancado: mensagem só para quem tentou]")
	if role == "client":
		await _glide(me, Vector3(0.0, 0.05, -30.0), 0)
		me.interactor.try_interact()
	await _barrier("gate", 2)
	await _secs(0.8)
	var fb: Label = current_scene.get_node("HUD/Root/Feedback")
	if role == "client":
		_check(fb.text.begins_with("Portão do Setor C"), "cliente recebe a mensagem: '%s'" % fb.text)
	else:
		_check(not fb.text.begins_with("Portão do Setor C"), "host NÃO recebe a mensagem do cliente")
	await _barrier("gate_checked", 2)

	# ---------------------------------------------------- disjuntor (estado do mundo)
	print("\n[Disjuntor acionado pelo cliente]")
	var storage = current_scene.get_node("Level/StorageRoom/DoorStorage")
	var lamp = current_scene.get_node("Level/Lights/StorageLamp1")
	_check(not lamp.powered, "luz do depósito começa apagada")
	if role == "client":
		await _glide(me, Vector3(0.6, 0.05, -19.6), -90)
		var ia2 = storage.get_node("Panel/InteractArea")
		net.request_interact(ia2, me.interactor)
		await _secs(1.6)
		await _glide(me, Vector3(3.3, 0.05, -19.6), 90)
		_check(me.interactor.current_target != null and me.interactor.current_target.has_method("get_prompt") and me.interactor.current_target.get_prompt().contains("disjuntor"), "cliente mira o disjuntor")
		me.interactor.try_interact()
	await _barrier("breaker", 2)
	await _secs(1.0)
	_check(storage.state == storage.State.OPEN, "porta do depósito aberta aqui também")
	_check(lamp.powered, "luzes do depósito acesas neste computador")
	await _barrier("breaker_checked", 2)

	# ---------------------------------------------------- validações do host
	print("\n[Host recusa trapaças]")
	var before: Vector3 = me.global_position
	bridge.put("before_tp_" + role, before)
	await _barrier("tp_ready", 2)
	if role == "client":
		me.global_position = Vector3(0, 0.05, -25.0) # "teleporte"
		await _secs(1.5)
		_check(me.global_position.distance_to(before) < 1.0, "host devolveu o cliente à última posição válida (%.2f m)" % me.global_position.distance_to(before))
	else:
		await _secs(1.5)
		var cb: Vector3 = bridge.data.get("before_tp_client", Vector3.INF)
		_check(other.global_position.distance_to(Vector3(0, 0.05, -25.0)) > 3.0, "host não aceitou o teleporte")
		_check(other.global_position.distance_to(cb) < 1.0, "host mantém o cliente onde ele estava")
	await _barrier("tp_checked", 2)
	var door_state_before: int = door.state
	if role == "client":
		# Pedido de interação com a porta da manutenção estando longe (~10 m).
		var ia3 = door.get_node("Panel/InteractArea")
		net.request_interact(ia3, me.interactor)
	await _secs(1.5)
	_check(door.state == door_state_before, "interação de longe recusada pelo host")
	await _barrier("far_checked", 2)

	# ---------------------------------------------------- menu online não congela
	print("\n[Menu (Esc) numa partida online]")
	if role == "host":
		await _press(&"pause")
		var pm = current_scene.get_node("PauseMenu")
		_check(not paused and gm.is_paused and pm.visible, "Esc abre o menu SEM congelar o jogo")
		_check(not pm.get_node("%RestartButton").visible and pm.get_node("%MenuButton").text == "SAIR DA PARTIDA", "online: sem 'Reiniciar', com 'Sair da partida'")
		var p0: Vector3 = me.global_position
		await _hold([&"move_back"], 30)
		_check(me.global_position.distance_to(p0) < 0.01, "com o menu aberto o jogador não anda")
	await _barrier("menu_open", 2)
	if role == "client":
		await _hold([&"move_back"], 30)
		await _frames(20)
		bridge.put("client_moved_while_menu", me.global_position)
	await _barrier("menu_move", 2)
	if role == "host":
		await _secs(0.5)
		var cp: Vector3 = bridge.data.get("client_moved_while_menu", Vector3.INF)
		_check(other.global_position.distance_to(cp) < 0.2, "o outro jogador continua se movendo enquanto meu menu está aberto")
		await _press(&"pause")
		_check(not gm.is_paused and not current_scene.get_node("PauseMenu").visible, "Esc fecha o menu")
		var p1: Vector3 = me.global_position
		await _hold([&"move_back"], 30)
		_check(me.global_position.distance_to(p1) > 0.3, "controle volta ao fechar o menu (%.2f m)" % me.global_position.distance_to(p1))
	await _barrier("menu_done", 2)

	# ---------------------------------------------------- saída do cliente
	print("\n[Cliente sai da partida]")
	if role == "client":
		net.leave()
		var back: bool = await _wait_until(func(): return current_scene != null and current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn", 5.0)
		_check(back, "cliente voltou ao menu principal")
		await _secs(1.0)
		# Tentar voltar no meio da partida deve ser recusado.
		await _client_join(false)
		var refused: bool = await _wait_until(func(): return net.phase == net.Phase.IDLE, 15.0)
		await _secs(0.5)
		_check(refused and not net.is_online(), "entrar com a partida em andamento é recusado")
		var why: String = bridge.data.get("reason", "")
		_check(why.contains("começou") or why.contains("recusou"), "motivo claro: '%s'" % why)
	else:
		var gone: bool = await _wait_until(func(): return _player(other_id) == null, 5.0)
		_check(gone, "host removeu o jogador que saiu")
		_check(net.players.size() == 1 and net.is_playing(), "host continua jogando sozinho")
		var fb2: Label = current_scene.get_node("HUD/Root/Feedback")
		_check(fb2.text == "Convidado saiu da partida.", "aviso de saída: '%s'" % fb2.text)
		await _secs(6.0) # tempo para o cliente tentar voltar


## O host "cai" (processo encerrado à força). O cliente deve voltar ao menu.
func _scenario_kill() -> void:
	if role == "host":
		if not await _host_create():
			return
	elif not await _client_join():
		return
	if not await _start_and_enter(2):
		return
	await _barrier("ready_to_kill", 2)
	if role == "host":
		print("KILL_ME")
		var f := FileAccess.open(codefile + ".kill", FileAccess.WRITE)
		f.store_string("1")
		f.close()
		await _secs(60.0)
	else:
		var t0 := Time.get_ticks_msec()
		var back: bool = await _wait_until(func(): return not net.is_online() and current_scene != null and current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn", 25.0)
		var dt := (Time.get_ticks_msec() - t0) / 1000.0
		_check(back, "cliente voltou ao menu após a queda do host (%.1f s)" % dt)
		var why: String = bridge.data.get("reason", "")
		_check(why != "", "motivo mostrado: '%s'" % why)


## Host sai de propósito no meio da partida: todos voltam ao menu.
func _scenario_hostleave() -> void:
	if role == "host":
		if not await _host_create():
			return
	elif not await _client_join():
		return
	if not await _start_and_enter(expected_players):
		return
	await _barrier("before_leave", expected_players)
	if role == "host":
		await _secs(0.5)
		gm.go_to_main_menu()
		await _secs(1.0)
		_check(not net.is_online() and current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn", "host voltou ao menu")
	else:
		var t0 := Time.get_ticks_msec()
		var back: bool = await _wait_until(func(): return not net.is_online() and current_scene != null and current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn", 8.0)
		_check(back, "cliente voltou ao menu quando o host saiu (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
		var menu = current_scene
		await _frames(5)
		var msg: String = menu.get("_main_msg").text if menu and menu.get("_main_msg") else ""
		_check(msg.contains("host"), "menu mostra o motivo: '%s'" % msg)


## Sala cheia: 6 jogadores entram, o 7º é recusado; todos jogam juntos.
func _scenario_full() -> void:
	if role == "host":
		if not await _host_create():
			return
	elif my_name == "Extra":
		# Só tenta entrar quando a sala já tem 6.
		await _barrier("six_in", expected_players + 1, 60.0)
		await _client_join(false)
		var refused: bool = await _wait_until(func(): return net.phase == net.Phase.IDLE, 15.0)
		_check(refused and not net.is_online(), "7º jogador recusado")
		var why: String = bridge.data.get("reason", "")
		_check(why.contains("cheia") or why.contains("recusou"), "motivo: '%s'" % why)
		return
	elif not await _client_join():
		return
	await _wait_until(func(): return net.players.size() == expected_players, 60.0)
	_check(net.players.size() == expected_players, "%d jogadores na sala" % net.players.size())
	await _barrier("six_in", expected_players + 1, 60.0)
	await _secs(4.0) # o 7º tenta entrar
	_check(net.players.size() == expected_players, "sala continua com %d após a tentativa do 7º" % net.players.size())
	if not await _start_and_enter(expected_players):
		return
	_check(current_scene.get_node("Players").get_child_count() == expected_players, "%d jogadores na fase" % expected_players)
	# Medição de tráfego (só na LAN, pelas estatísticas do ENet), 5 s parados+andando.
	if transport == "lan":
		var h: ENetConnection = root.multiplayer.multiplayer_peer.host
		h.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
		h.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
		await _hold([&"move_forward"], 300)
		var sent := h.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA) / 5.0 / 1024.0
		var recv := h.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA) / 5.0 / 1024.0
		_log("TRÁFEGO com %d jogadores: envia %.1f KB/s, recebe %.1f KB/s" % [expected_players, sent, recv])
		await _barrier("traffic", expected_players)
	# Todos andam um pouco; cada um confere os outros.
	await _hold([&"move_forward"], 40)
	await _frames(20)
	bridge.put("pos_%d" % net.my_id(), _me().global_position)
	await _barrier("moved6", expected_players)
	await _secs(0.6)
	var worst := 0.0
	for id in net.get_player_ids():
		if id == net.my_id():
			continue
		var real: Vector3 = bridge.data.get("pos_%d" % id, Vector3.INF)
		var p = _player(id)
		if p:
			worst = maxf(worst, p.global_position.distance_to(real))
		else:
			worst = INF
	_check(worst < 0.25, "vejo todos os outros nas posições certas (pior diferença %.3f m)" % worst)
	await _barrier("end6", expected_players)
	await _secs(1.0)


## Erros de conexão (uma instância só): mensagens claras, sem travar.
func _scenario_errors() -> void:
	print("\n[Erros de conexão]")
	var fail_msg := func() -> String: return bridge.data.get("reason", "")
	# IP inválido
	bridge.data["reason"] = ""
	net.join_lan("abc")
	_check(not net.is_online() and fail_msg.call().contains("inválido"), "IP inválido: '%s'" % fail_msg.call())
	# Ninguém na porta (LAN): deve desistir sozinho
	bridge.data["reason"] = ""
	net.join_lan("127.0.0.1:24777")
	var t0 := Time.get_ticks_msec()
	await _wait_until(func(): return fail_msg.call() != "", 25.0)
	_check(fail_msg.call() != "" and not net.is_online(), "sem host na porta: desiste em %.1f s ('%s')" % [(Time.get_ticks_msec() - t0) / 1000.0, fail_msg.call()])
	if transport != "relay":
		return
	var good_app: String = net.relay_app_id
	# App ID que o relay não aceita
	bridge.data["reason"] = ""
	net.relay_app_id = "app-id-que-nao-existe"
	net.create_online_room()
	await _wait_until(func(): return fail_msg.call() != "", 20.0)
	_check(fail_msg.call().contains("App ID"), "App ID recusado: '%s'" % fail_msg.call())
	net.relay_app_id = good_app
	# Código de sala que não existe
	bridge.data["reason"] = ""
	net.join_online("ZZZZZ")
	await _wait_until(func(): return fail_msg.call() != "", 20.0)
	_check(fail_msg.call().contains("não encontrada"), "sala inexistente: '%s'" % fail_msg.call())
	# Relay fora do ar
	bridge.data["reason"] = ""
	var good_addr: String = net.relay_address
	net.relay_address = "127.0.0.1:8099"
	net.create_online_room()
	t0 = Time.get_ticks_msec()
	await _wait_until(func(): return fail_msg.call() != "", 25.0)
	_check(fail_msg.call() != "" and not net.is_online(), "relay fora do ar: desiste em %.1f s ('%s')" % [(Time.get_ticks_msec() - t0) / 1000.0, fail_msg.call()])
	net.relay_address = good_addr
	# Sem App ID configurado
	bridge.data["reason"] = ""
	net.relay_app_id = ""
	net.create_online_room()
	_check(fail_msg.call().contains("App ID"), "sem App ID: '%s'" % fail_msg.call())
	net.relay_app_id = good_app


func _find_button(n: Node, text: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null


func _click(n: Node, text: String) -> bool:
	var b := _find_button(n, text)
	if b == null or b.disabled or not b.is_visible_in_tree():
		_log("botão '%s' indisponível" % text)
		return false
	b.pressed.emit()
	await _frames(3)
	return true


## Fluxo completo PELOS BOTÕES do menu (LAN): criar, entrar, iniciar, sair.
func _scenario_ui() -> void:
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await _frames(10)
	var menu = current_scene
	_check(menu != null and menu.scene_file_path == "res://scenes/ui/main_menu.tscn", "menu principal abriu")
	_check(await _click(menu, "MULTIPLAYER"), "botão MULTIPLAYER")
	menu._name_edit.text = my_name
	menu._name_edit.text_changed.emit(my_name)
	if role == "host":
		_check(await _click(menu, "CRIAR SALA NA REDE LOCAL"), "botão CRIAR SALA NA REDE LOCAL")
		var ok: bool = await _wait_until(func(): return menu._current_page() == &"lobby", 10.0)
		_check(ok, "tela da sala apareceu (%s)" % menu._lobby_code.text)
		var f := FileAccess.open(codefile, FileAccess.WRITE)
		f.store_string(net.room_code)
		f.close()
		var two: bool = await _wait_until(func(): return net.players.size() == 2, 30.0)
		await _frames(5)
		var listed := ""
		for c in menu._lobby_list.get_children():
			listed += (c as Label).text + " | "
		_check(two and listed.contains("Anfitriao (host, você)") and listed.contains("Convidado"), "lista: %s" % listed)
		_check(menu._lobby_log.text.contains("Convidado entrou na sala."), "aviso de entrada: '%s'" % menu._lobby_log.text)
		_check(menu._lobby_start.visible and not menu._lobby_start.disabled, "host vê INICIAR PARTIDA")
		await _barrier("ui_lobby", 2)
		_check(await _click(menu, "INICIAR PARTIDA"), "botão INICIAR PARTIDA")
	else:
		await _wait_until(func(): return FileAccess.file_exists(codefile) and FileAccess.get_file_as_string(codefile).strip_edges() != "", 20.0)
		menu._ip_edit.text = FileAccess.get_file_as_string(codefile).strip_edges()
		var btns: Array = []
		for b in menu.find_children("*", "Button", true, false):
			if b.text == "ENTRAR":
				btns.append(b)
		btns[1].pressed.emit() # o segundo ENTRAR é o da rede local
		var ok: bool = await _wait_until(func(): return menu._current_page() == &"lobby" and net.players.size() == 2, 20.0)
		_check(ok, "cliente chegou à tela da sala")
		_check(not menu._lobby_start.visible and menu._lobby_wait.visible, "cliente NÃO vê INICIAR; vê 'aguardando o host'")
		await _barrier("ui_lobby", 2)
	var playing: bool = await _wait_until(func(): return net.is_playing() and _me() != null, 30.0)
	_check(playing, "partida começou para todos")
	await _barrier("ui_game", 2)
	if role == "host":
		await _secs(0.5)
		await _press(&"pause")
		var pm = current_scene.get_node("PauseMenu")
		_check(await _click(pm, "SAIR DA PARTIDA"), "botão SAIR DA PARTIDA")
		var back: bool = await _wait_until(func(): return current_scene != null and current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn", 5.0)
		_check(back and not net.is_online(), "host voltou ao menu")
	else:
		var back: bool = await _wait_until(func(): return current_scene != null and current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn" and current_scene.get("_main_msg") != null, 8.0)
		await _frames(5)
		_check(back, "cliente voltou ao menu")
		if back:
			_check(String(current_scene._main_msg.text).contains("host"), "mensagem no menu: '%s'" % current_scene._main_msg.text)


## Um cliente "cai" (processo encerrado à força): o host remove o jogador.
func _scenario_killclient() -> void:
	if role == "host":
		if not await _host_create():
			return
	elif not await _client_join():
		return
	if not await _start_and_enter(2):
		return
	await _barrier("ready_to_kill", 2)
	if role == "client":
		var f := FileAccess.open(codefile + ".kill", FileAccess.WRITE)
		f.store_string("1")
		f.close()
		await _secs(60.0)
	else:
		var ids: Array = net.get_player_ids()
		var cid: int = ids[1]
		var t0 := Time.get_ticks_msec()
		var gone: bool = await _wait_until(func(): return _player(cid) == null and net.players.size() == 1, 25.0)
		_check(gone, "host removeu o cliente que caiu (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
		_check(net.is_playing() and _me() != null, "host continua na partida")
