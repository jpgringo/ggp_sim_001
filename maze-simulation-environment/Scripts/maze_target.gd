extends Node2D
var size: Vector2
var color: Color

func _ready():
	queue_redraw()

func _draw():
	print("DRAWING TARGET")
	draw_rect(Rect2(Vector2.ZERO, size), color)
