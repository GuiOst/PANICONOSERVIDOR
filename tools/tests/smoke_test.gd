extends SceneTree
## =========================================================================
## TESTE AUTOMÁTICO (fumaça) — Pânico no Servidor, Etapa 1
## =========================================================================
## Simula entradas do jogador e verifica movimento, colisão, lanterna,
## interação, porta, disjuntor, pausa, queda para fora do mapa e reinício.
## Não precisa de placa de vídeo. Uso (terminal, na pasta do projeto):
##   godot --headless --path . --script res://tools/tests/smoke_test.gd
## Código de saída 0 = tudo passou.
## =========================================================================

var _fails: int = 0
var _passes: int = 0
var _gs: Node
var _gm: Node


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
		print("  [OK]   ", what)
	else:
		_fails += 1
		printerr("  [FALHA] ", what)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


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


func _hold(actions: Array, frames: int) -> void:
	for a in actions:
		Input.action_press(a)
	await _frames(frames)
	for a in actions:
		Input.action_release(a)


func _place(p: Node, pos: Vector3, yaw_deg: float) -> void:
	p.teleport_to(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos))


func _run() -> void:
	_gs = root.get_node("GameSettings")
	_gm = root.get_node("GameManager")
	print("\n=== Pânico no Servidor — teste automático ===")
	print("Godot ", Engine.get_version_info().string)

	# ---------------------------------------------------------- InputMap
	print("\n[Controles]")
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"jump", &"interact", &"toggle_flashlight", &"pause"]:
		_check(InputMap.has_action(a) and not InputMap.action_get_events(a).is_empty(), "ação '%s' existe no InputMap" % a)

	# ---------------------------------------------------------- Áudio opcional
	print("\n[Áudio opcional]")
	_check(AudioLibrary.load_stream("res://assets/audio/sfx/arquivo_que_nao_existe.wav") == null, "som ausente retorna null sem erro")
	_check(AudioLibrary.load_stream(AudioLibrary.DOOR_SLAM[0]) != null, "som da porta carregado")
	_check(AudioServer.get_bus_index(&"SFX") >= 0 and AudioServer.get_bus_index(&"Ambience") >= 0, "barramentos SFX e Ambience existem")

	# ---------------------------------------------------------- Cena principal
	print("\n[Cena principal]")
	change_scene_to_file("res://scenes/main/main.tscn")
	await _frames(30)
	var main := current_scene
	_check(main != null and main.name == "Main", "main.tscn carregada")
	var player = main.get_node_or_null("Players/LocalPlayer")
	_check(player != null, "jogador criado")
	if player == null:
		_finish()
		return
	_check(player.global_position.distance_to(Vector3(0, 0.05, 0.6)) < 0.3, "jogador na posição inicial (%s)" % player.global_position)
	_check(player.is_on_floor(), "jogador apoiado no chão")
	var hud = main.get_node("HUD")
	var interactor = player.interactor
	var flashlight = player.flashlight

	# ---------------------------------------------------------- Movimento
	print("\n[Movimento]")
	_place(player, Vector3(0, 0.05, 0.0), 0)
	await _frames(5)
	var z0: float = player.global_position.z
	await _hold([&"move_forward"], 60)
	var walked: float = z0 - player.global_position.z
	_check(walked > 2.0 and walked < 3.3, "andar 1 s para frente: %.2f m (esperado ~2.5-3)" % walked)
	await _frames(30)
	_check(player.get_horizontal_speed() < 0.2, "para ao soltar a tecla")
	_place(player, Vector3(0, 0.05, 0.0), 0)
	await _frames(5)
	await _hold([&"move_forward", &"sprint"], 60)
	var spd: float = player.get_horizontal_speed()
	_check(absf(spd - player.sprint_speed) < 0.3, "corrida com Shift: %.2f m/s" % spd)
	await _frames(40)
	_place(player, Vector3(-1.0, 0.05, -1.0), 0)
	await _frames(5)
	await _hold([&"move_forward", &"move_right"], 45)
	_check(absf(player.get_horizontal_speed() - player.walk_speed) < 0.2, "diagonal normalizada: %.2f m/s" % player.get_horizontal_speed())
	await _frames(40)
	# Pulo
	_place(player, Vector3(0, 0.05, -2.0), 0)
	await _frames(10)
	var y0: float = player.global_position.y
	await _press(&"jump")
	await _frames(15)
	_check(player.global_position.y > y0 + 0.4, "pulo funciona (altura %.2f)" % (player.global_position.y - y0))
	await _frames(60)
	_check(player.is_on_floor(), "volta ao chão após o pulo (gravidade)")
	# Mouse: rotação e limite vertical
	player.look.apply_look(Vector2(30, 0))
	_check(absf(rad_to_deg(player.rotation.y) + 30.0) < 0.5, "olhar horizontal gira o corpo")
	player.look.apply_look(Vector2(0, -500))
	_check(absf(rad_to_deg(player.look.rotation.x) - player.look.pitch_limit_deg) < 0.5, "limite vertical para cima respeitado")
	player.look.apply_look(Vector2(0, 1000))
	_check(absf(rad_to_deg(player.look.rotation.x) + player.look.pitch_limit_deg) < 0.5, "limite vertical para baixo respeitado")
	player.look.reset_pitch()

	# ---------------------------------------------------------- Colisão com paredes
	print("\n[Colisões]")
	_place(player, Vector3(-1.0, 0.05, -6.0), 90) # olhando para -X (parede esquerda)
	await _frames(5)
	await _hold([&"move_forward", &"sprint"], 120)
	_check(player.global_position.x > -2.0 + 0.3, "não atravessa a parede (x = %.2f)" % player.global_position.x)
	_place(player, Vector3(0, 0.05, -29.0), 0) # correndo contra o portão do Setor C
	await _frames(5)
	await _hold([&"move_forward", &"sprint"], 150)
	_check(player.global_position.z > -31.8, "não atravessa o portão do fim (z = %.2f)" % player.global_position.z)

	# ---------------------------------------------------------- Lanterna
	print("\n[Lanterna]")
	_check(not flashlight.is_on, "lanterna começa desligada")
	await _press(&"toggle_flashlight")
	_check(flashlight.is_on and flashlight.visible, "F liga a lanterna")
	_check(hud.get_node("Root/FlashlightIndicator/State").text == "LIGADA", "HUD mostra lanterna ligada")
	await _press(&"toggle_flashlight")
	_check(not flashlight.is_on and not flashlight.visible, "F desliga a lanterna")
	_check(hud.get_node("Root/FlashlightIndicator/State").text == "DESLIGADA", "HUD mostra lanterna desligada")

	# ---------------------------------------------------------- Interação + porta
	print("\n[Interação e porta]")
	var door = main.get_node("Level/MaintenanceRoom/DoorMaintenance")
	_place(player, Vector3(-0.6, 0.05, -10.5), 90) # de frente para a porta
	await _frames(5)
	_check(interactor.current_target != null and interactor.current_target.get_parent().get_parent() == door, "raio detecta a porta")
	var prompt: Label = hud.get_node("Root/Prompt")
	_check(prompt.text == "Pressione [E] para abrir", "mensagem: '%s'" % prompt.text)
	await _frames(20)
	_check(prompt.modulate.a > 0.9, "mensagem visível")
	await _press(&"interact")
	_check(door.state == door.State.OPENING, "E começa a abrir a porta")
	await _frames(90)
	_check(door.state == door.State.OPEN, "porta termina aberta")
	_check(door.get_node("Panel").rotation.y > 1.5, "porta abriu PARA LONGE do jogador (ângulo %.0f°)" % rad_to_deg(door.get_node("Panel").rotation.y))
	_check(prompt.text == "Pressione [E] para fechar", "mensagem muda para fechar")
	# Olhar para longe esconde a mensagem
	player.look.apply_look(Vector2(180, 0))
	await _frames(20)
	_check(interactor.current_target == null and prompt.modulate.a < 0.1, "mensagem some ao olhar para longe")
	# Atravessar a porta aberta
	_place(player, Vector3(-0.6, 0.05, -10.5), 90)
	await _frames(3)
	await _hold([&"move_forward"], 100)
	_check(player.global_position.x < -3.0, "passa pela porta aberta (x = %.2f)" % player.global_position.x)
	# Fechar por dentro da sala, olhando para a folha aberta (abre dos dois lados)
	var shape: Node3D = door.get_node("Panel/PanelShape")
	var n: Vector3 = shape.global_basis.z
	var c: Vector3 = shape.global_position
	var from: Vector3 = c + n * 1.3 if (c + n * 1.3).z > c.z else c - n * 1.3
	_place(player, Vector3(from.x, 0.05, from.z), rad_to_deg(atan2(-(c.x - from.x), -(c.z - from.z))))
	await _frames(5)
	_check(interactor.current_target != null, "porta detectada pelo lado de dentro")
	await _press(&"interact")
	await _frames(90)
	_check(door.state == door.State.CLOSED, "porta fecha por dentro")
	_place(player, Vector3(-4.0, 0.05, -10.5), -90) # olhando para +X
	await _frames(3)
	await _hold([&"move_forward", &"sprint"], 90)
	_check(player.global_position.x < -2.3, "porta fechada bloqueia o jogador (x = %.2f)" % player.global_position.x)
	# Abrir de dentro: deve abrir para o corredor (sentido oposto)
	_place(player, Vector3(-3.8, 0.05, -10.5), -90)
	await _frames(5)
	await _press(&"interact")
	await _frames(90)
	_check(door.get_node("Panel").rotation.y < -1.5, "de dentro abre para o lado oposto (ângulo %.0f°)" % rad_to_deg(door.get_node("Panel").rotation.y))
	# Alternar várias vezes no meio do movimento não deixa estado inválido
	for i in 7:
		door.toggle(player.interactor)
		await _frames(9)
	await _frames(120)
	_check(door.state == door.State.OPEN or door.state == door.State.CLOSED, "alternar a porta várias vezes termina em estado estável (%s)" % door.State.keys()[door.state])
	# Porta não esmaga o jogador: fecha com o jogador no caminho -> reabre
	if door.state == door.State.CLOSED:
		door.open(player.interactor)
		await _frames(90)
	_place(player, Vector3(-1.5, 0.05, -10.2), 0)
	await _frames(5)
	door.close()
	await _frames(120)
	_check(door.state != door.State.CLOSED, "porta não fecha através do jogador (estado %s)" % door.State.keys()[door.state])
	_check(player.global_position.distance_to(Vector3(-1.5, 0.05, -10.2)) < 0.3, "jogador não foi empurrado pela porta")

	# ---------------------------------------------------------- Sem interação através da parede
	print("\n[Paredes bloqueiam interação]")
	_place(player, Vector3(1.3, 0.05, -19.4), -90) # corredor, disjuntor do outro lado da parede
	await _frames(5)
	_check(interactor.current_target == null, "disjuntor atrás da parede NÃO é detectado")

	# ---------------------------------------------------------- Disjuntor
	print("\n[Disjuntor]")
	var storage_door = main.get_node("Level/StorageRoom/DoorStorage")
	storage_door.open(null)
	await _frames(90)
	var lamp = main.get_node("Level/Lights/StorageLamp1")
	_check(not lamp.powered and not lamp.get_node("Light").visible, "luz do depósito começa apagada")
	_place(player, Vector3(3.3, 0.05, -19.6), 90)
	await _frames(5)
	_check(interactor.current_target is BreakerSwitch, "disjuntor detectado")
	await _press(&"interact")
	await _frames(5)
	_check(lamp.powered and lamp.get_node("Light").visible, "disjuntor acende as luzes do depósito")
	var fb: Label = hud.get_node("Root/Feedback")
	_check(fb.text == "Energia restabelecida.", "mensagem de retorno: '%s'" % fb.text)

	# ---------------------------------------------------------- Portão trancado
	print("\n[Portão trancado]")
	_place(player, Vector3(0, 0.05, -30.0), 0)
	await _frames(5)
	_check(interactor.current_target is Inspectable, "portão do Setor C detectado")
	await _press(&"interact")
	_check(fb.text.begins_with("Portão do Setor C"), "mensagem do portão: '%s'" % fb.text)

	# ---------------------------------------------------------- Objeto removido
	print("\n[Objeto removido em uso]")
	_place(player, Vector3(-0.6, 0.05, -10.5), 90)
	await _frames(5)
	_place(player, Vector3(0.5, 0.05, -14.0), 0) # sai do caminho da porta
	await _frames(3)
	door.close()
	await _frames(90)
	_place(player, Vector3(-0.6, 0.05, -10.5), 90)
	await _frames(5)
	_check(interactor.current_target != null, "porta na mira antes de ser removida")
	door.queue_free()
	await _frames(20)
	_check(interactor.current_target == null and prompt.modulate.a < 0.1, "remover a porta na mira limpa o alvo e esconde a mensagem")

	# ---------------------------------------------------------- Pausa
	print("\n[Pausa]")
	_place(player, Vector3(0, 0.05, -3.0), 0)
	await _frames(5)
	await _press(&"pause")
	_check(paused, "Esc pausa o jogo")
	var pm = main.get_node("PauseMenu")
	_check(pm.visible, "menu de pausa visível")
	var zp: float = player.global_position.z
	await _hold([&"move_forward"], 40)
	_check(absf(player.global_position.z - zp) < 0.001, "jogador NÃO se move pausado")
	await _press(&"toggle_flashlight")
	_check(not flashlight.is_on, "lanterna não liga pausada")
	await _press(&"pause")
	_check(not paused and not pm.visible, "Esc despausa")
	await _hold([&"move_forward"], 30)
	_check(player.global_position.z < zp - 0.5, "movimento volta após despausar")

	# ---------------------------------------------------------- Opções
	print("\n[Opções]")
	var old_sens: float = _gs.mouse_sensitivity
	_gs.set_value(&"mouse_sensitivity", 0.5, false)
	_check(is_equal_approx(_gs.mouse_sensitivity, 0.5), "sensibilidade ajustável")
	_gs.set_value(&"mouse_sensitivity", old_sens, false)
	var env: Environment = main.get_node("WorldEnvironment").environment
	_gs.set_value(&"graphics_quality", 0, false)
	_check(not env.ssao_enabled and not env.volumetric_fog_enabled, "qualidade Baixa desliga SSAO e névoa volumétrica")
	_gs.set_value(&"graphics_quality", 2, false)
	_check(env.ssao_enabled and env.ssil_enabled and env.volumetric_fog_enabled, "qualidade Alta liga SSAO, SSIL e névoa")
	_gs.set_value(&"graphics_quality", 1, false)
	_gs.set_value(&"master_volume", 0.0, false)
	_check(AudioServer.is_bus_mute(0), "volume geral 0 silencia")
	_gs.set_value(&"master_volume", 0.8, false)

	# ---------------------------------------------------------- Queda para fora do mapa
	print("\n[Rede de segurança]")
	_place(player, Vector3(20, -5, 10), 0)
	await _frames(120)
	_check(player.global_position.distance_to(Vector3(0, 0.05, 0.6)) < 1.0, "quem cai para fora do mapa volta ao início")

	# ---------------------------------------------------------- Reinício
	print("\n[Reiniciar]")
	_gm.restart_level()
	await _frames(30)
	var new_main := current_scene
	_check(new_main != null and new_main != main and new_main.get_node_or_null("Players/LocalPlayer") != null, "reiniciar recria a cena e o jogador")
	_check(new_main.get_node_or_null("Level/MaintenanceRoom/DoorMaintenance") != null, "porta removida no teste voltou após reiniciar")

	_finish()


func _finish() -> void:
	print("\n=== RESULTADO: %d OK, %d FALHA(S) ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)
