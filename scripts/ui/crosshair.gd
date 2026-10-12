class_name Crosshair
extends Control
## Mira discreta: um ponto pequeno que cresce levemente quando há algo
## interativo na mira. Desenhada por código (sem textura).

@export var idle_radius: float = 2.0
@export var active_radius: float = 4.0
@export var idle_color: Color = Color(0.85, 0.85, 0.8, 0.45)
@export var active_color: Color = Color(0.95, 0.9, 0.75, 0.95)

var active: bool = false:
	set(v):
		if active != v:
			active = v
			queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	if active:
		draw_circle(c, active_radius + 1.5, Color(0, 0, 0, 0.5))
		draw_circle(c, active_radius, active_color)
	else:
		draw_circle(c, idle_radius + 1.0, Color(0, 0, 0, 0.35))
		draw_circle(c, idle_radius, idle_color)
