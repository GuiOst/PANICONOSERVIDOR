extends SceneTree
## =========================================================================
## TESTE AUTOMÁTICO DE ÁUDIO — Etapa A (passos e porta)
## =========================================================================
## Verifica, simulando o jogador:
##  - todos os arquivos de passos/porta existem e carregam;
##  - parado = sem passos; no ar = sem passos;
##  - caminhada e corrida usam conjuntos diferentes;
##  - a superfície vem do chão REAL (concreto, chapa metálica, poça);
##  - o ritmo acompanha a distância percorrida;
##  - a porta toca trinco -> rangido -> batente ao abrir e
##    rangido -> batida ao fechar, a batida SÓ quando fecha de verdade.
## Uso: godot --headless --path . --script res://tools/tests/audio_test.gd
## =========================================================================

var _fails := 0
var _passes := 0
var _steps: Array = []


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
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await process_frame


func _place(p: Node, pos: Vector3, yaw: float) -> void:
	p.teleport_to(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), pos))


func _path(player: AudioStreamPlayer3D) -> String:
	return player.stream.resource_path if player.stream else ""


func _run() -> void:
	print("\n=== Teste de áudio (Etapa A) ===")
	# ------------------------------------------------------------ arquivos
	var total := 0
	var missing := 0
	for surface in AudioLibrary.FOOTSTEP_COUNTS.keys():
		for gait in [&"walk", &"run"]:
			for p in AudioLibrary.footstep_paths(surface, gait):
				total += 1
				if AudioLibrary.load_stream(p) == null:
					missing += 1
	_check(missing == 0 and total >= 40, "passos: %d gravações carregadas (%d ausentes)" % [total, missing])
	var door_lists := [AudioLibrary.DOOR_UNLATCH, AudioLibrary.DOOR_CREAK_OPEN, AudioLibrary.DOOR_CREAK_CLOSE,
		AudioLibrary.DOOR_STOP_OPEN, AudioLibrary.DOOR_SLAM, AudioLibrary.DOOR_LOCKED]
	var dn := 0
	for l in door_lists:
		dn += AudioLibrary.load_streams(l).size()
	_check(dn == 17, "porta: %d gravações carregadas" % dn)
	for bus_name in [&"SFX", &"Ambience", &"Creature", &"UI"]:
		_check(AudioServer.get_bus_index(bus_name) >= 0, "barramento '%s' existe" % bus_name)

	change_scene_to_file("res://scenes/main/main.tscn")
	await _frames(30)
	var main := current_scene
	var player = main.get_node("Players/LocalPlayer")
	var fs = player.get_node("Footsteps")
	fs.step_played.connect(func(surface, running, _db):
		_steps.append({"surface": surface, "running": running, "floor": player.is_on_floor(), "path": fs.stream.resource_path}))

	# ------------------------------------------------------------ passos
	print("\n[Passos]")
	_place(player, Vector3(0, 0.05, -1.0), 0)
	await _frames(10)
	_steps.clear()
	await _frames(60)
	_check(_steps.is_empty(), "parado: nenhum passo")

	_steps.clear()
	var z0: float = player.global_position.z
	await _hold([&"move_forward"], 120)
	var dist: float = z0 - player.global_position.z
	_check(_steps.size() >= 4, "andando: %d passos em %.1f m" % [_steps.size(), dist])
	var expected: float = dist / fs.walk_stride
	_check(absf(_steps.size() - expected) <= 1.5, "ritmo segue a distância (esperado ~%.1f)" % expected)
	_check(_steps.all(func(s): return s.surface == &"concrete" and not s.running and "/concrete/walk_" in s.path), "andando no corredor: concreto + gravações de caminhada")
	var distinct := {}
	for s in _steps:
		distinct[s.path] = true
	_check(distinct.size() >= mini(_steps.size(), 3), "variações diferentes (%d arquivos distintos)" % distinct.size())
	var no_repeat := true
	for i in range(1, _steps.size()):
		if _steps[i].path == _steps[i - 1].path:
			no_repeat = false
	_check(no_repeat, "nunca repete a mesma gravação em seguida")
	await _frames(40)

	_place(player, Vector3(0, 0.05, -1.0), 0)
	await _frames(10)
	_steps.clear()
	await _hold([&"move_forward", &"sprint"], 100)
	var runs := _steps.filter(func(s): return s.running)
	_check(runs.size() >= 3 and runs.all(func(s): return "/concrete/run_" in s.path), "correndo: gravações de corrida (%d passos)" % runs.size())
	await _frames(40)

	# Pulo: nenhum passo enquanto no ar
	_place(player, Vector3(0, 0.05, -2.0), 0)
	await _frames(10)
	_steps.clear()
	Input.action_press(&"move_forward")
	await _press(&"jump")
	await _frames(50)
	Input.action_release(&"move_forward")
	_check(_steps.all(func(s): return s.floor), "nenhum passo tocado no ar (%d passos, todos no chão)" % _steps.size())
	await _frames(40)

	# Poça d'água (superfície molhada)
	_place(player, Vector3(-1.15, 0.05, -16.4), 0)
	await _frames(10)
	_steps.clear()
	await _hold([&"move_forward"], 70)
	var wet := _steps.filter(func(s): return s.surface == &"wet")
	_check(wet.size() >= 1 and wet.all(func(s): return "/wet/" in s.path), "poça: superfície molhada detectada (%d de %d passos)" % [wet.size(), _steps.size()])
	await _frames(30)

	# Chapa metálica da sala técnica
	main.get_node("Level/StorageRoom/DoorStorage").open(null)
	await _frames(90)
	_place(player, Vector3(7.8, 0.05, -22.4), 0)
	await _frames(10)
	_steps.clear()
	await _hold([&"move_forward"], 70)
	var metal := _steps.filter(func(s): return s.surface == &"metal")
	_check(metal.size() >= 2 and metal.all(func(s): return "/metal/" in s.path), "chapa metálica: superfície metal detectada (%d de %d passos)" % [metal.size(), _steps.size()])

	# ------------------------------------------------------------ porta
	print("\n[Porta]")
	var door = main.get_node("Level/MaintenanceRoom/DoorMaintenance")
	var mech: AudioStreamPlayer3D = door.get_node("Panel/DoorSounds/Mechanism")
	var hinge: AudioStreamPlayer3D = door.get_node("Panel/DoorSounds/Hinge")
	_place(player, Vector3(-0.6, 0.05, -10.5), 90)
	await _frames(5)
	await _press(&"interact")
	_check(mech.playing and "/doors/unlatch_" in _path(mech), "abrir: trinco toca imediatamente")
	_check(not hinge.playing, "rangido ainda não começou (folha ainda presa)")
	await _frames(12)
	_check(hinge.playing and "/doors/creak_open_" in _path(hinge), "rangido de abertura durante o movimento")
	await _frames(70)
	_check(door.state == door.State.OPEN, "porta aberta")
	_check("/doors/stop_open_" in _path(mech), "batente ao chegar totalmente aberta")
	await _frames(30)
	_check(not hinge.playing or hinge.volume_db < -40.0, "rangido some quando a folha para")
	_place(player, Vector3(0.5, 0.05, -13.0), 0)
	await _frames(3)
	door.close()
	await _frames(3)
	_check(hinge.playing and "/doors/creak_close_" in _path(hinge), "fechar: rangido de fechamento")
	await _frames(30)
	_check(door.state == door.State.CLOSING and not ("/doors/slam_" in _path(mech)), "batida NÃO toca antes de fechar de verdade")
	await _frames(60)
	_check(door.state == door.State.CLOSED and mech.playing and "/doors/slam_" in _path(mech), "batida pesada exatamente ao fechar")
	door.locked = true
	_place(player, Vector3(-0.6, 0.05, -10.5), 90)
	await _frames(5)
	await _press(&"interact")
	_check("/doors/locked_" in _path(mech) and mech.playing, "porta trancada: maçaneta forçada")
	_check(mech.bus == &"SFX" and mech.max_distance > 10.0, "porta usa áudio 3D no barramento SFX")

	print("\n=== RESULTADO ÁUDIO: %d OK, %d FALHA(S) ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)
