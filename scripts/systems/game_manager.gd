extends Node
## Autoload "GameManager": estado global da partida.
##
## Responsável por:
##  - pausar/despausar (a tecla Esc chega aqui pela ação "pause");
##  - capturar/liberar o mouse de forma consistente;
##  - reiniciar a cena e sair do jogo.
##
## Ele NÃO conhece o jogador nem a interface diretamente: quem precisa reagir
## à pausa escuta o sinal `pause_changed`. Isso evita dependências circulares.
## MULTIPLAYER: numa partida online a "pausa" é só um menu sobreposto: o
## mundo NÃO congela (os outros continuam jogando); apenas o jogador local
## perde o controle enquanto o menu está aberto.

signal pause_changed(is_paused: bool)

var is_paused: bool:
	get:
		return _menu_open if _online() else get_tree().paused

var _menu_open: bool = false


func _ready() -> void:
	# Continua recebendo entrada mesmo com a árvore pausada.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif not is_paused and event is InputEventMouseButton and event.pressed:
		# Clicar na janela (ex.: depois de um Alt+Tab) recaptura o mouse.
		capture_mouse()


func _notification(what: int) -> void:
	# Ao perder o foco da janela, pausa automaticamente para não deixar o
	# personagem andando sozinho.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not is_paused and _has_gameplay():
		set_paused(true)


func toggle_pause() -> void:
	set_paused(not is_paused)


func set_paused(value: bool) -> void:
	if not _has_gameplay():
		return
	if _online():
		_menu_open = value
		get_tree().paused = false
	else:
		_menu_open = false
		get_tree().paused = value
	if value:
		release_mouse()
	else:
		capture_mouse()
	pause_changed.emit(value)


## Chamado quando uma fase começa: nenhum menu aberto.
func reset_pause_state() -> void:
	_menu_open = false
	get_tree().paused = false


func capture_mouse() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Volta ao menu principal (online: sai da sala; se for o host, encerra para todos).
func go_to_main_menu() -> void:
	_menu_open = false
	get_tree().paused = false
	pause_changed.emit(false)
	release_mouse()
	if Net.is_online():
		Net.leave()
	get_tree().change_scene_to_file(Net.MAIN_MENU_SCENE)


func restart_level() -> void:
	if _online():
		return # online não há "reiniciar": só o host poderia, e não é desta etapa
	get_tree().paused = false
	pause_changed.emit(false)
	get_tree().reload_current_scene()


func quit_game() -> void:
	if Net.is_online():
		Net.leave()
		# Dá tempo da mensagem de saída chegar aos outros.
		await get_tree().create_timer(0.3, true).timeout
	get_tree().quit()


func _online() -> bool:
	return Net.is_session_active()


## Só existe "partida" quando a cena atual é uma fase jogável (grupo
## "gameplay_root"). Evita pausar telas futuras como menu principal/lobby.
func _has_gameplay() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.is_in_group(&"gameplay_root")
