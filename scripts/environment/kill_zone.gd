class_name KillZone
extends Area3D
## Rede de segurança: se o jogador cair para fora do mapa (bug de colisão,
## por exemplo), é devolvido ao ponto de nascimento em vez de cair para sempre.

signal player_fell(body: Node3D)


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1 << 1 # jogadores
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	player_fell.emit(body)
