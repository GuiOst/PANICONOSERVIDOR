class_name PauseMenu
extends CanvasLayer
## Menu de pausa (Esc). Funciona com a árvore pausada porque o nó está em
## process_mode = ALWAYS. Quem pausa de fato é o GameManager; este menu
## apenas reage ao sinal `pause_changed` e oferece os botões.

const QUALITY_NAMES := ["Baixa", "Média", "Alta"]

## Emitido ao fechar as Opções no modo "standalone" (menu principal).
signal closed

## Verdadeiro quando usado pelo menu principal só para mostrar as Opções.
@export var standalone: bool = false

@onready var _main_page: Control = %MainPage
@onready var _options_page: Control = %OptionsPage
@onready var _resume: Button = %ResumeButton
@onready var _options: Button = %OptionsButton
@onready var _restart: Button = %RestartButton
@onready var _quit: Button = %QuitButton
@onready var _menu: Button = %MenuButton
@onready var _subtitle: Label = $Root/Center/Panel/Margin/MainPage/Subtitle
@onready var _back: Button = %BackButton
@onready var _grid: GridContainer = %Grid

var _syncing: bool = false
var _ui_player: AudioStreamPlayer
var _snd_click: AudioStream
var _snd_hover: AudioStream


func _ready() -> void:
	visible = false
	GameManager.pause_changed.connect(_on_pause_changed)
	_resume.pressed.connect(func(): GameManager.set_paused(false))
	_options.pressed.connect(_show_options)
	_restart.pressed.connect(GameManager.restart_level)
	_menu.pressed.connect(GameManager.go_to_main_menu)
	_quit.pressed.connect(GameManager.quit_game)
	_back.pressed.connect(_on_back)
	_setup_options()
	_setup_ui_sounds()


func _unhandled_input(event: InputEvent) -> void:
	# Esc dentro das Opções volta para a página principal em vez de fechar.
	if visible and _options_page.visible and event.is_action_pressed(&"pause"):
		_on_back()
		get_viewport().set_input_as_handled()


func _on_back() -> void:
	if standalone:
		GameSettings.save_settings()
		visible = false
		closed.emit()
	else:
		_show_main()


## Abre direto nas Opções (usado pelo menu principal).
func open_options() -> void:
	visible = true
	_show_options()


func _on_pause_changed(paused: bool) -> void:
	if standalone:
		return
	visible = paused
	if paused:
		var online := Net.is_session_active()
		# Online o jogo não para e não existe "reiniciar".
		_restart.visible = not online
		_menu.text = "SAIR DA PARTIDA" if online else "MENU PRINCIPAL"
		($Root/Center/Panel/Margin/MainPage/Title as Label).text = "MENU" if online else "PAUSADO"
		_subtitle.text = "PARTIDA ONLINE  ·  O JOGO CONTINUA RODANDO" if online else "PÂNICO NO SERVIDOR  ·  SETOR B-2"
		_show_main()
	else:
		GameSettings.save_settings()


func _show_main() -> void:
	_options_page.visible = false
	_main_page.visible = true
	_resume.grab_focus.call_deferred()


func _show_options() -> void:
	_sync_from_settings()
	_main_page.visible = false
	_options_page.visible = true
	_back.grab_focus.call_deferred()


# --------------------------------------------------------------- Opções
func _setup_options() -> void:
	var q := _grid.get_node(^"QualityOption") as OptionButton
	q.clear()
	for i in QUALITY_NAMES.size():
		q.add_item(QUALITY_NAMES[i], i)
	_bind_slider("Sensitivity", &"mouse_sensitivity", "%.2f")
	_bind_slider("Fov", &"field_of_view", "%d°")
	_bind_slider("Master", &"master_volume", "pct")
	_bind_slider("Sfx", &"sfx_volume", "pct")
	_bind_slider("Ambience", &"ambience_volume", "pct")
	_bind_slider("Creature", &"creature_volume", "pct")
	_bind_slider("Ui", &"ui_volume", "pct")
	q.item_selected.connect(func(idx: int): _apply(&"graphics_quality", idx))
	_bind_check("Fullscreen", &"fullscreen")
	_bind_check("Vsync", &"vsync")
	_bind_check("HeadBob", &"head_bob_enabled")
	_bind_check("InvertY", &"invert_y")
	_sync_from_settings()


func _bind_slider(key: String, setting: StringName, fmt: String) -> void:
	var slider := _grid.get_node(NodePath(key + "Slider")) as HSlider
	var value_label := _grid.get_node(NodePath(key + "Value")) as Label
	slider.value_changed.connect(func(v: float):
		value_label.text = _format(v, fmt)
		_apply(setting, v, false))
	# Grava em disco só ao soltar o slider.
	slider.drag_ended.connect(func(_changed: bool): GameSettings.save_settings())


func _bind_check(key: String, setting: StringName) -> void:
	var check := _grid.get_node(NodePath(key + "Check")) as CheckButton
	check.toggled.connect(func(on: bool): _apply(setting, on))


func _apply(setting: StringName, value: Variant, persist: bool = true) -> void:
	if _syncing:
		return
	GameSettings.set_value(setting, value, persist)


func _sync_from_settings() -> void:
	_syncing = true
	_set_slider("Sensitivity", GameSettings.mouse_sensitivity, "%.2f")
	_set_slider("Fov", GameSettings.field_of_view, "%d°")
	_set_slider("Master", GameSettings.master_volume, "pct")
	_set_slider("Sfx", GameSettings.sfx_volume, "pct")
	_set_slider("Ambience", GameSettings.ambience_volume, "pct")
	_set_slider("Creature", GameSettings.creature_volume, "pct")
	_set_slider("Ui", GameSettings.ui_volume, "pct")
	(_grid.get_node(^"QualityOption") as OptionButton).select(GameSettings.graphics_quality)
	(_grid.get_node(^"FullscreenCheck") as CheckButton).button_pressed = GameSettings.fullscreen
	(_grid.get_node(^"VsyncCheck") as CheckButton).button_pressed = GameSettings.vsync
	(_grid.get_node(^"HeadBobCheck") as CheckButton).button_pressed = GameSettings.head_bob_enabled
	(_grid.get_node(^"InvertYCheck") as CheckButton).button_pressed = GameSettings.invert_y
	_syncing = false


func _set_slider(key: String, value: float, fmt: String) -> void:
	(_grid.get_node(NodePath(key + "Slider")) as HSlider).value = value
	(_grid.get_node(NodePath(key + "Value")) as Label).text = _format(value, fmt)


func _format(v: float, fmt: String) -> String:
	if fmt == "pct":
		return "%d%%" % roundi(v * 100.0)
	if fmt == "%d°":
		return "%d°" % roundi(v)
	return fmt % v


# ------------------------------------------------------- sons da interface
## Clique e "hover" em todos os botões do menu (barramento UI).
func _setup_ui_sounds() -> void:
	_snd_click = AudioLibrary.load_stream(AudioLibrary.UI_CLICK)
	_snd_hover = AudioLibrary.load_stream(AudioLibrary.UI_HOVER)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = AudioLibrary.BUS_UI
	_ui_player.max_polyphony = 3
	add_child(_ui_player)
	for node in find_children("*", "BaseButton", true, false):
		var b := node as BaseButton
		b.pressed.connect(_play_ui.bind(true))
		b.mouse_entered.connect(_play_ui.bind(false))


func _play_ui(click: bool) -> void:
	if not click and not visible:
		return
	AudioLibrary.play_on(_ui_player, _snd_click if click else _snd_hover)
