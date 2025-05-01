extends Node2D
var size: Vector2
var color: Color

func _ready():
	queue_redraw()


func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), color)

func _on_body_entered(body):
	print("Body entered detection zone:", body.name)
