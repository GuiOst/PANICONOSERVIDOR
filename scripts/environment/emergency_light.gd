class_name EmergencyLight
extends Node3D
## Luz de emergência vermelha que pulsa lentamente.
## Estrutura: Light (Light3D) e Lens (MeshInstance3D emissivo, opcional).

@export_range(0.2, 10.0, 0.1) var pulse_period: float = 2.6
@export_range(0.0, 1.0, 0.05) var min_level: float = 0.25

var _light: Light3D
var _material: StandardMaterial3D
var _base_energy: float = 1.0
var _base_emission: float = 1.0
var _t: float = 0.0


func _ready() -> void:
	_light = get_node_or_null(^"Light") as Light3D
	if _light:
		_base_energy = _light.light_energy
	var lens := get_node_or_null(^"Lens") as MeshInstance3D
	if lens:
		var src := lens.get_active_material(0) as StandardMaterial3D
		if src:
			_material = src.duplicate() as StandardMaterial3D
			lens.material_override = _material
			_base_emission = _material.emission_energy_multiplier
	_t = randf() * pulse_period


func _process(delta: float) -> void:
	_t = fmod(_t + delta, pulse_period)
	var s := sin(_t / pulse_period * PI)
	var level := lerpf(min_level, 1.0, s * s)
	if _light:
		_light.light_energy = _base_energy * level
	if _material:
		_material.emission_energy_multiplier = _base_emission * level
