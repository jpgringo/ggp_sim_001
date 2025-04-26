extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

# Player states
var speed = 100
var previous_velocity = Vector2.ZERO

# Movement and Animation
func _physics_process(delta):
	# Get input direction and calculate velocity
	var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_direction.normalized() * speed
	
	# Check if velocity changed and transmit if it did
	if velocity != previous_velocity:
		Global.transmit("agent_data", [0, {"velocity": velocity}])
		previous_velocity = velocity
	
	# Update animations based on movement
	update_animation(input_direction)
	
	# Move the character
	var collision = move_and_collide(velocity * delta)
	
	if collision:
		print("Collision with:", collision.get_collider())
		print("Collision normal:", collision.get_normal())

func update_animation(input_direction: Vector2):
	# If there's no input, play idle animation
	if input_direction == Vector2.ZERO:
		animated_sprite.play("idle")
		animated_sprite.flip_h = false
		return
	
	# Handle horizontal movement animations
	if abs(input_direction.x) > abs(input_direction.y):
		animated_sprite.play("side")
		animated_sprite.flip_h = input_direction.x > 0
	# Handle vertical movement animations
	elif input_direction.y < 0:
		animated_sprite.play("up")
	elif input_direction.y > 0:
		animated_sprite.play("down")
