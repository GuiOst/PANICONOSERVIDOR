extends Node
## Autoload "GameSettings": guarda as preferências do jogador (controles,
## áudio e vídeo) e as salva em user://settings.cfg.
##
## Qualquer sistema pode ler os valores (ex.: GameSettings.mouse_sensitivity)
## e reagir a mudanças pelo sinal `settings_changed`. Nenhum outro script
## precisa saber como os dados são gravados.

signal settings_changed

const SAVE_PATH := "user://settings.cfg"

enum Quality { LOW, MEDIUM, HIGH }

# --- Jogador ---
var player_name: String = "Jogador"     ## nome mostrado no multiplayer

# --- Controles ---
var mouse_sensitivity: float = 0.25      ## graus por pixel de movimento do mouse
var invert_y: bool = false
var field_of_view: float = 75.0
var head_bob_enabled: bool = true

# --- Áudio (0.0 a 1.0, linear) ---
var master_volume: float = 0.8
var sfx_volume: float = 1.0
var ambience_volume: float = 0.8
var creature_volume: float = 1.0
var ui_volume: float = 0.7

# --- Vídeo ---
var graphics_quality: int = Quality.MEDIUM
var fullscreen: bool = false
var vsync: bool = true


func _ready() -> void:
	load_settings()
	apply_all()


## Aplica tudo o que é global (áudio e janela). A qualidade gráfica da cena
## é aplicada pelo nó GraphicsQuality, que escuta `settings_changed`.
func apply_all() -> void:
	_apply_audio()
	_apply_window()
	settings_changed.emit()


## Altera uma configuração e aplica na hora. Com `persist = false` não grava
## em disco (útil enquanto o jogador arrasta um slider); chame
## `save_settings()` depois.
func set_value(key: StringName, value: Variant, persist: bool = true) -> void:
	if not key in self:
		push_warning("GameSettings: chave desconhecida '%s'" % key)
		return
	set(key, value)
	apply_all()
	if persist:
		save_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("controls", "field_of_view", field_of_view)
	cfg.set_value("controls", "head_bob_enabled", head_bob_enabled)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "ambience_volume", ambience_volume)
	cfg.set_value("audio", "creature_volume", creature_volume)
	cfg.set_value("audio", "ui_volume", ui_volume)
	cfg.set_value("video", "graphics_quality", graphics_quality)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("GameSettings: não foi possível salvar (%s)" % error_string(err))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return # primeira execução: mantém os padrões
	player_name = String(cfg.get_value("player", "name", player_name)).substr(0, 16)
	mouse_sensitivity = clampf(cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity), 0.02, 1.5)
	invert_y = cfg.get_value("controls", "invert_y", invert_y)
	field_of_view = clampf(cfg.get_value("controls", "field_of_view", field_of_view), 60.0, 100.0)
	head_bob_enabled = cfg.get_value("controls", "head_bob_enabled", head_bob_enabled)
	master_volume = clampf(cfg.get_value("audio", "master_volume", master_volume), 0.0, 1.0)
	sfx_volume = clampf(cfg.get_value("audio", "sfx_volume", sfx_volume), 0.0, 1.0)
	ambience_volume = clampf(cfg.get_value("audio", "ambience_volume", ambience_volume), 0.0, 1.0)
	creature_volume = clampf(cfg.get_value("audio", "creature_volume", creature_volume), 0.0, 1.0)
	ui_volume = clampf(cfg.get_value("audio", "ui_volume", ui_volume), 0.0, 1.0)
	graphics_quality = clampi(cfg.get_value("video", "graphics_quality", graphics_quality), Quality.LOW, Quality.HIGH)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	vsync = cfg.get_value("video", "vsync", vsync)


func _apply_audio() -> void:
	_set_bus_volume(&"Master", master_volume)
	_set_bus_volume(&"SFX", sfx_volume)
	_set_bus_volume(&"Ambience", ambience_volume)
	_set_bus_volume(&"Creature", creature_volume)
	_set_bus_volume(&"UI", ui_volume)


func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return # barramento ausente: não é erro fatal
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func _apply_window() -> void:
	# Em modo headless (testes automáticos) não existe janela de verdade.
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
