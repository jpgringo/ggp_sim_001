extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

# Constants
const VELOCITY_SENSOR_ID = 0
const TOUCH_SENSOR_ID = 1
const HEARTBEAT_SEC = 3.0  # Send selected sensor updates at this interval
const ACTUATORS = 1

# Node references
@onready var heartbeat_timer = $VelocityHeartbeatTimer

# 'owning' scenario
@export var scenario_id: String

# Player states
var speed = 100
var previous_velocity = Vector2.ZERO
var is_remote_controlled = false  # Track remote control state

# event management
var _event_handler = null

func set_event_handler(handler):
	print("setting event handler")
	_event_handler = handler

func get_event_handler():
	return _event_handler

@export var event_handler: Callable:
	get:
		return get_event_handler()
	set(value):
		print("SETTING event handler on player")
		set_event_handler(value)

func _ready():
	print("Turtle created!!")
	# Transmit agent creation message
	Global.transmit("agent_created", {"id": self.get_instance_id(), "actuators": 1})

	queue_velocity_event(velocity)
	#transmit_velocity_reading()

	# Setup velocity heartbeat timer
	heartbeat_timer = Timer.new()
	heartbeat_timer.name = "VelocityHeartbeatTimer"
	add_child(heartbeat_timer)
	heartbeat_timer.wait_time = 0.1
	heartbeat_timer.connect("timeout", _on_heartbeat)
	heartbeat_timer.start()

# Movement and Animation
func _physics_process(_delta):
	# Get input direction and calculate velocity
	var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Only process keyboard input if we're not being controlled remotely
	if not is_remote_controlled:
		velocity = input_direction.normalized() * speed

	# Transmit velocity data if changed
	if velocity != previous_velocity:
		#transmit_velocity_reading()
		queue_velocity_event(velocity)
		previous_velocity = velocity

	# Update animations based on movement
	update_animation(input_direction)

	# Move the character
	var collision = move_and_collide(velocity * _delta)

	if collision:
		#print("Collision with:", collision.get_collider())
		#print("Collision normal:", collision.get_normal())
		queue_collision_event(collision)
		#transmit_collision_event(collision)

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


func _notification(what):
	# Called when the node is about to be destroyed
	if what == NOTIFICATION_PREDELETE:
		Global.transmit("agent_destroyed", {"id": self.get_instance_id()})

func _on_heartbeat():
	# Send current velocity data regardless of whether it has changed
	#transmit_velocity_reading()
	#print("queuing velocity event:", velocity)
	queue_velocity_event(velocity)

func transmit_velocity_reading():
	Global.transmit("sensor_data", {
		"scenario": scenario_id,
		"agent": self.get_instance_id(),
		"data": [VELOCITY_SENSOR_ID, PackedFloat32Array([velocity.x, velocity.y])]
	})

func actuator_input(data: Array):
	#print("Turtle %d received actuator data: %s" % [self.get_instance_id(), str(data)])
	if data.size() >= 2:
		var actuator_id = data[0]
		var values = data[1]
		#print("Actuator ID: %d, Values: %s" % [actuator_id, str(values)])

		# Handle movement actuator
		if actuator_id == 0 and values is Array and values.size() >= 2:
			# Mark this turtle as being controlled remotely
			self.is_remote_controlled = true

			var motion = Vector2(values[0], values[1])

			# Set velocity based on the two values (x, y)
			velocity = motion.normalized() * speed

			# Update animation based on the new velocity
			update_animation(velocity)

func queue_velocity_event(velocity_reading):
	if _event_handler is Callable:
		_event_handler.call({
		"scenario": scenario_id,
		"agent": self.get_instance_id(),
		"data": [VELOCITY_SENSOR_ID, PackedFloat32Array([velocity_reading.x, velocity_reading.y])]
	})

func queue_collision_event(collision):
	if _event_handler is Callable:
		_event_handler.call({
		"scenario": scenario_id,
		# the main node's instance ID is probably good for identifying the agent, but for geometry
		# calculations we probably want collision.get_local_shape()
		"agent": self.get_instance_id(),
		"data": [TOUCH_SENSOR_ID, PackedFloat32Array([to_local(collision.get_position()).x, to_local(collision.get_position()).y, collision.get_normal().x, collision.get_normal().y])]
	})


func transmit_collision_event(collision):
	# only pass data that would be 'knowable' from a collision sensor, not 'omniscient' Godot game logic
	# eventually, it might be good to use some combination of `get_collider_velocity`, `get_depth`,
	# `get_remainder`, and `get_travel` to determine the 'force' of the collision, but for now our
	# very, very simple agent should only understand that it has contacted something, and where on
	# its 'body' the contact occurred
	var data = {
		"scenario": scenario_id,
		# the main node's instance ID is probably good for identifying the agent, but for geometry
		# calculations we probably want collision.get_local_shape()
		"agent": self.get_instance_id(),
		"data": [TOUCH_SENSOR_ID, PackedFloat32Array([to_local(collision.get_position()).x, to_local(collision.get_position()).y, collision.get_normal().x, collision.get_normal().y])]
	}
	#print("collision data:", data)
	Global.transmit("sensor_data", data)

	# Immediately send a reset message to clear the collision state
	Global.transmit("sensor_data", {
		"agent": self.get_instance_id(),
		"data": [TOUCH_SENSOR_ID, PackedFloat32Array([0.0, 0.0, 0.0, 0.0])]
	})
