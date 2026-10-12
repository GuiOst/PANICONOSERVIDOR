class_name SurfaceZone
extends Area3D
## Região do chão com um tipo de superfície diferente (ex.: poça d'água,
## grade metálica sobre o piso). Fica na camada de física 4 ("surface_zone")
## e é encontrada pelo raio dos passos antes do piso de baixo.
##
## Uso: adicione um SurfaceZone com um CollisionShape3D fino (caixa) logo
## acima do piso e escolha a superfície. Sons em
## res://assets/audio/footsteps/<surface>/walk_XX.ogg e run_XX.ogg.

@export_enum("concrete", "metal", "wet") var surface: String = "wet"


func _init() -> void:
	collision_layer = 1 << 3 # camada 4
	collision_mask = 0
	monitoring = false
	monitorable = true
