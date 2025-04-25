extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

# Player states
var speed = 100

# Movement Physics
func _physics_process(delta):
	velocity = Vector2.ZERO # this will obviously be set to something else once we're actually moving the character!
	velocity = velocity.normalized() * speed

	# move_and_collide expects *distance*, not speed.
	var collision = move_and_collide(velocity * delta)
	
	if collision:
		print("Collision with:", collision.get_collider())
		print("Collision normal:", collision.get_normal())
