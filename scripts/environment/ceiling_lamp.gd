class_name CeilingLamp
extends Node3D
## Luminária de teto industrial com estados: ligada, desligada e piscando.
##
## - `powered` pode ser alterado por um disjuntor (método `set_powered`).
## - `flicker` faz a lâmpada falhar em intervalos aleatórios CONTROLADOS
##   (rajadas curtas separadas por períodos estáveis), sem custo quando
##   desligada ou estável.
## Estrutura esperada: Light (Light3D), Tube (MeshInstance3D emissivo),
## Buzz (LoopingSound3D, opcional).

@export var powered: bool = true:
	set(v):
		powered = v
		if is_node_ready():
			_apply(1.0 if v else 0.0)
			_update_processing()
@export var flicker: bool = false:
	set(v):
		flicker = v
		if is_node_ready():
			_update_processing()

@export_group("Falhas")
## Segundos estáveis entre rajadas de falha (mínimo, máximo).
@export var stable_time_range: Vector2 = Vector2(1.5, 6.0)
## Quantidade de piscadas por rajada (mínimo, máximo).
@export var burst_count_range: Vector2i = Vector2i(2, 7)
## Chance de a rajada terminar em um apagão mais longo.
@export_range(0.0, 1.0, 0.05) var blackout_chance: float = 0.25

var _light: Light3D
var _tube: MeshInstance3D
var _buzz: Node
var _base_energy: float = 1.0
var _tube_material: StandardMaterial3D
var _base_emission: float = 1.0
var _timer: float = 0.0
var _burst_left: int = 0
var _lit: bool = true


func _ready() -> void:
	_light = get_node_or_null(^"Light") as Light3D
	_tube = get_node_or_null(^"Tube") as MeshInstance3D
	_buzz = get_node_or_null(^"Buzz")
	if _light:
		_base_energy = _light.light_energy
	if _tube:
		# Material próprio para poder variar o brilho sem afetar as outras
		# lâmpadas (as que nunca mudam continuam compartilhando o material).
		var src := _tube.get_active_material(0) as StandardMaterial3D
		if src:
			_tube_material = src.duplicate() as StandardMaterial3D
			_tube.material_override = _tube_material
			_base_emission = _tube_material.emission_energy_multiplier
	_apply(1.0 if powered else 0.0)
	_timer = randf_range(stable_time_range.x, stable_time_range.y)
	_update_processing()


func set_powered(value: bool) -> void:
	powered = value


func _update_processing() -> void:
	set_process(powered and flicker)
	if powered and not flicker:
		_apply(1.0)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	if _burst_left > 0:
		_burst_left -= 1
		_lit = not _lit
		_apply(1.0 if _lit else randf_range(0.0, 0.15))
		_timer = randf_range(0.03, 0.14)
		if _burst_left == 0:
			if randf() < blackout_chance:
				_apply(0.0)
				_lit = false
				_timer = randf_range(0.6, 2.2)
			else:
				_lit = true
				_apply(1.0)
				_timer = randf_range(stable_time_range.x, stable_time_range.y)
	else:
		if not _lit:
			_lit = true
			_apply(1.0)
			_timer = randf_range(stable_time_range.x, stable_time_range.y)
			return
		_burst_left = randi_range(burst_count_range.x, burst_count_range.y) * 2
		_timer = 0.0


## level: 0 = apagada, 1 = brilho normal.
func _apply(level: float) -> void:
	if _light:
		_light.visible = level > 0.01
		_light.light_energy = _base_energy * level
	if _tube_material:
		_tube_material.emission_energy_multiplier = _base_emission * level
	if _buzz and _buzz.has_method(&"set_active"):
		_buzz.call(&"set_active", level > 0.5)
