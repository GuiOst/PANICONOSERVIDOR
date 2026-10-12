extends Control
## Menu principal: Jogar sozinho, Multiplayer (criar/entrar em sala), Opções,
## Créditos e Sair. Também mostra o LOBBY (lista de jogadores da sala).
##
## A interface é montada por código (funções `_build_*`) para ficar fácil de
## ler e alterar sem abrir várias cenas. Toda a parte de rede fica no
## autoload `Net`; este script só chama as funções dele e reage aos sinais.

const GAME_SCENE := "res://scenes/main/main.tscn"
const MAX_LOG := 6

var _pages: Dictionary = {}          # nome -> Control
var _status: Label                   # mensagens na página Multiplayer
var _main_msg: Label                 # avisos na página principal
var _name_edit: LineEdit
var _code_edit: LineEdit
var _ip_edit: LineEdit
var _online_hint: Label
var _btn_online_create: Button
var _btn_online_join: Button
var _connecting_label: Label
# Lobby
var _lobby_title: Label
var _lobby_code: Label
var _lobby_hint: Label
var _lobby_list: VBoxContainer
var _lobby_log: Label
var _lobby_start: Button
var _lobby_wait: Label
var _log_lines: PackedStringArray = []

var _ui_player: AudioStreamPlayer
var _snd_click: AudioStream
var _snd_hover: AudioStream

@onready var _options: PauseMenu = $Options


func _ready() -> void:
	GameManager.reset_pause_state()
	GameManager.release_mouse()
	_build_ui()
	_options.closed.connect(func(): _show(&"main"))
	Net.status_changed.connect(_on_net_status)
	Net.room_ready.connect(_on_room_ready)
	Net.connection_failed.connect(_on_connection_failed)
	Net.lobby_updated.connect(_refresh_lobby)
	Net.player_joined.connect(_on_player_joined)
	Net.player_left.connect(_on_player_left)
	Net.session_ended.connect(_on_session_ended)
	_setup_ui_sounds()
	# Voltando de uma partida/sala encerrada: mostra o motivo.
	if not Net.last_end_reason.is_empty():
		_main_msg.text = Net.last_end_reason
		Net.last_end_reason = ""
	if Net.is_online() and Net.phase == Net.Phase.LOBBY:
		_show(&"lobby")
		_refresh_lobby()
	else:
		_show(&"main")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause") or event.is_echo():
		return
	var current := _current_page()
	if current == &"multiplayer" or current == &"credits":
		_show(&"main")
	elif current == &"connecting":
		_cancel_connect()
	get_viewport().set_input_as_handled()


# ============================================================ construção
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.016, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)
	var vignette := TextureRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.texture = _vignette_texture()
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(vignette)
	move_child(vignette, 1)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.name = "Pages"
	add_child(center)
	move_child(center, 2)

	_pages[&"main"] = _build_main()
	_pages[&"multiplayer"] = _build_multiplayer()
	_pages[&"connecting"] = _build_connecting()
	_pages[&"lobby"] = _build_lobby()
	_pages[&"credits"] = _build_credits()
	for p in _pages.values():
		center.add_child(p)

	var ver := Label.new()
	ver.text = "versão %s" % ProjectSettings.get_setting("application/config/version", "?")
	ver.add_theme_color_override(&"font_color", Color(0.4, 0.39, 0.35))
	ver.add_theme_font_size_override(&"font_size", 18)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(ver)


func _panel(min_width: float = 760.0) -> Array:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_width, 0)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	margin.add_child(box)
	return [panel, box]


func _title(text: String, size: int = 64) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override(&"font_color", Color(0.82, 0.16, 0.1))
	l.add_theme_font_size_override(&"font_size", size)
	return l


func _text(text: String, size: int = 22, color := Color(0.62, 0.6, 0.54)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_font_size_override(&"font_size", size)
	return l


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(on_press)
	return b


func _build_main() -> Control:
	var pb := _panel(640.0)
	var box: VBoxContainer = pb[1]
	box.add_child(_title("PÂNICO NO SERVIDOR", 58))
	box.add_child(_text("Terror cooperativo · 1 a 6 jogadores", 20, Color(0.55, 0.53, 0.47)))
	box.get_child(1).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(HSeparator.new())
	var play := _button("JOGAR SOZINHO", _play_solo)
	play.name = "SoloButton"
	box.add_child(play)
	var mp := _button("MULTIPLAYER", func(): _show(&"multiplayer"))
	mp.name = "MultiplayerButton"
	box.add_child(mp)
	box.add_child(_button("OPÇÕES", _open_options))
	box.add_child(_button("CRÉDITOS", func(): _show(&"credits")))
	box.add_child(_button("SAIR", func(): get_tree().quit()))
	_main_msg = _text("", 20, Color(0.85, 0.55, 0.3))
	_main_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_main_msg)
	return pb[0]


func _build_multiplayer() -> Control:
	var pb := _panel(900.0)
	var box: VBoxContainer = pb[1]
	box.add_child(_title("MULTIPLAYER", 52))

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override(&"separation", 16)
	var name_label := _text("Seu nome:", 22, Color(0.8, 0.78, 0.7))
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(360, 0)
	_name_edit.text = GameSettings.player_name
	_name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(_name_edit)
	box.add_child(name_row)
	box.add_child(HSeparator.new())

	box.add_child(_text("PELA INTERNET  (sem abrir portas no roteador)", 22, Color(0.85, 0.82, 0.72)))
	_btn_online_create = _button("CRIAR SALA ONLINE", _create_online)
	box.add_child(_btn_online_create)
	var join_row := HBoxContainer.new()
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "código da sala"
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.text_submitted.connect(func(_t): _join_online())
	join_row.add_child(_code_edit)
	_btn_online_join = _button("ENTRAR", _join_online)
	join_row.add_child(_btn_online_join)
	box.add_child(join_row)
	_online_hint = _text("", 18, Color(0.85, 0.55, 0.3))
	box.add_child(_online_hint)
	box.add_child(HSeparator.new())

	box.add_child(_text("REDE LOCAL  (mesmo Wi-Fi / cabo)", 22, Color(0.85, 0.82, 0.72)))
	box.add_child(_button("CRIAR SALA NA REDE LOCAL", _create_lan))
	var ip_row := HBoxContainer.new()
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "IP do host, ex.: 192.168.0.10"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_edit.text_submitted.connect(func(_t): _join_lan())
	ip_row.add_child(_ip_edit)
	ip_row.add_child(_button("ENTRAR", _join_lan))
	box.add_child(ip_row)
	box.add_child(HSeparator.new())

	_status = _text("", 20, Color(0.85, 0.55, 0.3))
	box.add_child(_status)
	box.add_child(_button("VOLTAR", func(): _show(&"main")))
	_update_online_hint()
	return pb[0]


func _build_connecting() -> Control:
	var pb := _panel(760.0)
	var box: VBoxContainer = pb[1]
	box.add_child(_title("CONECTANDO", 48))
	_connecting_label = _text("...", 22, Color(0.8, 0.78, 0.7))
	_connecting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_connecting_label)
	box.add_child(_button("CANCELAR", _cancel_connect))
	return pb[0]


func _build_lobby() -> Control:
	var pb := _panel(900.0)
	var box: VBoxContainer = pb[1]
	_lobby_title = _title("SALA", 52)
	box.add_child(_lobby_title)
	var code_row := HBoxContainer.new()
	_lobby_code = _text("", 28, Color(0.95, 0.9, 0.75))
	_lobby_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_row.add_child(_lobby_code)
	code_row.add_child(_button("COPIAR", _copy_code))
	box.add_child(code_row)
	_lobby_hint = _text("", 18)
	box.add_child(_lobby_hint)
	box.add_child(HSeparator.new())
	_lobby_list = VBoxContainer.new()
	_lobby_list.add_theme_constant_override(&"separation", 6)
	box.add_child(_lobby_list)
	box.add_child(HSeparator.new())
	_lobby_log = _text("", 18, Color(0.55, 0.53, 0.47))
	box.add_child(_lobby_log)
	_lobby_start = _button("INICIAR PARTIDA", func(): Net.start_session())
	box.add_child(_lobby_start)
	_lobby_wait = _text("Aguardando o host iniciar a partida...", 20, Color(0.8, 0.78, 0.7))
	box.add_child(_lobby_wait)
	box.add_child(_button("SAIR DA SALA", _leave_room))
	return pb[0]


func _build_credits() -> Control:
	var pb := _panel(980.0)
	var box: VBoxContainer = pb[1]
	box.add_child(_title("CRÉDITOS", 52))
	box.add_child(_text(
		"Feito com Godot Engine (licença MIT).\n" +
		"Multiplayer pela internet: NodeTunnel, de curtjs (licença MIT).\n" +
		"Sons gravados: autores e licenças em assets/audio/CREDITOS_AUDIO.md.\n" +
		"Fonte: DejaVu Sans Mono (licença livre Bitstream Vera/DejaVu).", 22, Color(0.8, 0.78, 0.7)))
	box.add_child(_button("VOLTAR", func(): _show(&"main")))
	return pb[0]


func _vignette_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.09, 0.03, 0.025, 0.0))
	g.set_color(1, Color(0, 0, 0, 0.9))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.45)
	t.fill_to = Vector2(1.1, 1.1)
	t.width = 256
	t.height = 256
	return t


# ============================================================ navegação
func _show(page: StringName) -> void:
	for k in _pages.keys():
		_pages[k].visible = k == page
	_options.visible = false
	if page == &"multiplayer":
		_status.text = ""
		_update_online_hint()
	if page == &"lobby":
		_refresh_lobby()
	var first := _first_button(_pages[page])
	if first:
		first.grab_focus.call_deferred()


func _current_page() -> StringName:
	for k in _pages.keys():
		if _pages[k].visible:
			return k
	return &""


func _first_button(n: Node) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if not (b as Button).disabled:
			return b
	return null


func _open_options() -> void:
	for p in _pages.values():
		p.visible = false
	_options.open_options()


func _play_solo() -> void:
	if Net.is_online():
		Net.leave()
	get_tree().change_scene_to_file(GAME_SCENE)


# ============================================================ multiplayer
func _on_name_changed(t: String) -> void:
	var clean := Net.sanitize_name(t)
	Net.set_local_player_name(clean)
	GameSettings.player_name = clean
	GameSettings.save_settings()


func _apply_name() -> void:
	_on_name_changed(_name_edit.text)


func _update_online_hint() -> void:
	if not Net.relay_available():
		_online_hint.text = "Plugin NodeTunnel não encontrado (addons/nodetunnel). Use a rede local."
	elif not Net.relay_configured():
		_online_hint.text = "Falta o App ID gratuito do NodeTunnel em config/network.cfg (veja docs/TUTORIAL_MULTIPLAYER.md)."
	else:
		_online_hint.text = "Servidor de relay: %s" % Net.relay_address
	var ok := Net.relay_configured()
	_btn_online_create.disabled = not ok
	_btn_online_join.disabled = not ok


func _create_online() -> void:
	_apply_name()
	_begin_connecting("Conectando ao servidor de relay...")
	Net.create_online_room()


func _join_online() -> void:
	_apply_name()
	if _code_edit.text.strip_edges().is_empty():
		_status.text = "Digite o código que o host mostrou."
		return
	_begin_connecting("Conectando...")
	Net.join_online(_code_edit.text)


func _create_lan() -> void:
	_apply_name()
	_begin_connecting("Criando sala...")
	Net.create_lan_room()


func _join_lan() -> void:
	_apply_name()
	if _ip_edit.text.strip_edges().is_empty():
		_status.text = "Digite o IP que aparece na tela do host."
		return
	_begin_connecting("Conectando...")
	Net.join_lan(_ip_edit.text)


func _begin_connecting(text: String) -> void:
	_connecting_label.text = text
	_show(&"connecting")


func _cancel_connect() -> void:
	Net.leave()
	_show(&"multiplayer")
	_status.text = "Conexão cancelada."


func _leave_room() -> void:
	Net.leave()
	_log_lines.clear()
	_show(&"multiplayer")
	_status.text = "Você saiu da sala."


func _copy_code() -> void:
	DisplayServer.clipboard_set(Net.room_code)
	_add_log("Código copiado.")


func _on_net_status(text: String) -> void:
	if _current_page() == &"connecting":
		_connecting_label.text = text
	elif _current_page() == &"lobby" and text.begins_with("Aviso"):
		_add_log(text)


func _on_room_ready(_code: String) -> void:
	_log_lines.clear()
	_show(&"lobby")


func _on_connection_failed(reason: String) -> void:
	_show(&"multiplayer")
	_status.text = reason


func _on_session_ended(reason: String) -> void:
	_log_lines.clear()
	if _current_page() == &"lobby" or _current_page() == &"connecting":
		_show(&"multiplayer")
		_status.text = reason if not reason.is_empty() else "Desconectado."
	Net.last_end_reason = ""


func _on_player_joined(_id: int, player_name: String) -> void:
	_add_log("%s entrou na sala." % player_name)


func _on_player_left(_id: int, player_name: String) -> void:
	_add_log("%s saiu da sala." % player_name)


func _add_log(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > MAX_LOG:
		_log_lines.remove_at(0)
	if _lobby_log:
		_lobby_log.text = "\n".join(_log_lines)


func _refresh_lobby() -> void:
	if _lobby_list == null:
		return
	var host := Net.is_host()
	var lan := Net.mode == Net.Mode.LAN
	_lobby_title.text = "SALA (%s)" % ("REDE LOCAL" if lan else "INTERNET")
	_lobby_code.text = ("Endereço: %s" if lan else "Código: %s") % Net.room_code
	if host:
		if lan:
			var addrs := Net.get_lan_addresses()
			var others := ""
			if addrs.size() > 1:
				others = " Se não funcionar, tente: %s." % ", ".join(addrs.slice(1, 4))
			_lobby_hint.text = "Passe este endereço aos amigos na mesma rede.%s Se ninguém conseguir entrar, libere o jogo no Firewall do Windows (veja o tutorial)." % others
		else:
			_lobby_hint.text = "Passe este código aos amigos. Ele só vale enquanto você estiver na sala."
	else:
		_lobby_hint.text = "Você está conectado. Se o host sair, a sala fecha."
	for c in _lobby_list.get_children():
		c.queue_free()
	var ids := Net.get_player_ids()
	for id in ids:
		var tags: PackedStringArray = []
		if id == 1:
			tags.append("host")
		if id == Net.my_id():
			tags.append("você")
		var line := _text("%s %s%s" % ["★" if id == 1 else "•", Net.get_player_name(id),
			(" (%s)" % ", ".join(tags)) if not tags.is_empty() else ""], 24,
			Color(0.95, 0.88, 0.7) if id == Net.my_id() else Color(0.8, 0.78, 0.7))
		_lobby_list.add_child(line)
	_lobby_list.add_child(_text("%d de %d jogadores" % [ids.size(), Net.MAX_PLAYERS], 18, Color(0.55, 0.53, 0.47)))
	_lobby_start.visible = host
	_lobby_start.disabled = not host or Net.phase != Net.Phase.LOBBY
	_lobby_start.text = "INICIAR PARTIDA" if ids.size() > 1 else "INICIAR PARTIDA (sozinho na sala)"
	_lobby_wait.visible = not host


# ============================================================ sons de UI
func _setup_ui_sounds() -> void:
	_snd_click = AudioLibrary.load_stream(AudioLibrary.UI_CLICK)
	_snd_hover = AudioLibrary.load_stream(AudioLibrary.UI_HOVER)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = AudioLibrary.BUS_UI
	_ui_player.max_polyphony = 3
	add_child(_ui_player)
	for node in $Pages.find_children("*", "BaseButton", true, false):
		var b := node as BaseButton
		b.pressed.connect(func(): AudioLibrary.play_on(_ui_player, _snd_click))
		b.mouse_entered.connect(func(): AudioLibrary.play_on(_ui_player, _snd_hover))
