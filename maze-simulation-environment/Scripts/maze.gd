extends Node2D

@onready var tilemap = $TileMap
@onready var perimeter_layer = $TileMap/UNBREAKABLE_TILE
@onready var maze_wall_layer = $TileMap/BREAKABLE_TILE
@onready var spawned_players = $SpawnedPlayers

var maze_def = null
var target_area = null  # Reference to the target Area2D
var current_scenario = ""
var current_scenario_id = ""

# Desired grid dimensions
const GRID_COLUMNS = 30  # desired number of columns
const GRID_ROWS = 20     # desired number of rows

var map_width: int
var map_height: int
var map_offset = 0
var grid_scale = 1.0     # scale factor for the tilemap

const BACKGROUND_TILE_ID = 0
const BREAKABLE_TILE_ID = 1
const UNBREAKABLE_TILE_ID = 2
const BACKGROUND_TILE_LAYER = 0
const BREAKABLE_TILE_LAYER = 1
const UNBREAKABLE_TILE_LAYER = 2

var rng = RandomNumberGenerator.new()

const NULL_MAP = {
	"id": -1,
	"width": 9,
	"height": 5,
	"spawn_points": [],
	"target": [],
	"data": []
}

var event_queue = []
var batch_timer: Timer

func _ready():
	Global.maze_scene = self
	maze_def = _load_maze(null)
	calculate_dimensions()
	create_maze()
	batch_timer = Timer.new()
	batch_timer.name = "VelocityHeartbeatTimer"
	add_child(batch_timer)
	batch_timer.wait_time = 0.1
	batch_timer.connect("timeout", _transmit_event_batch)

	# Connect to handle window resizing
	get_tree().root.size_changed.connect(self._on_viewport_resized)

func _load_maze(maze_id) -> Variant:
	if maze_id != null:
		var file = FileAccess.open("res://Maps/%s" % maze_id, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			return JSON.parse_string(content)
		else:
			return NULL_MAP
	else:
		return NULL_MAP

func _on_viewport_resized():
	calculate_dimensions()
	position_grid()
	
func _exit_tree():
	print("Maze is terminating!!")
	Global.transmit("terminating", "maze")

# Calculate maze dimensions and scaling
func calculate_dimensions():
	map_width = maze_def.width + 2 if maze_def is Dictionary else GRID_COLUMNS
	map_height = maze_def.height +2 if maze_def is Dictionary else GRID_ROWS

	var viewport_size = get_viewport_rect().size
	var base_tile_size = tilemap.tile_set.tile_size

	# Calculate scale factors for both dimensions
	var scale_x = viewport_size.x / (base_tile_size.x * map_width)
	var scale_y = viewport_size.y / (base_tile_size.y * map_height)

	# Use the smaller scale to maintain aspect ratio
	grid_scale = min(scale_x, scale_y)

	# Apply scale to tilemap
	tilemap.scale = Vector2(grid_scale, grid_scale)

	# Center the grid
	position_grid()

func position_grid():
	var viewport_size = get_viewport_rect().size
	var grid_pixel_size = Vector2(
		tilemap.tile_set.tile_size.x * map_width * grid_scale,
		tilemap.tile_set.tile_size.y * map_height * grid_scale
	)

	# Calculate padding to center the grid
	var padding = (viewport_size - grid_pixel_size) / 2
	tilemap.position = padding

# Store spawn points at class level so they're accessible to spawn_players
var spawn_points: Array[Vector2] = []
var spawn_point_markers: Array[Node] = []  # Store references to visual markers

func create_maze():
	generate_perimeter()
	generate_maze_walls()
	create_spawn_points()
	if maze_def is Dictionary and maze_def.target.size() >= 2:
		create_target()

# Create and visualize spawn points
func create_spawn_points():
	# Define spawn points in grid coordinates (first empty cell in each corner)
	var grid_spawn_points = [
		Vector2i(1, 1),                    # Top Left
		Vector2i(map_width - 2, 1),      # Top Right
		Vector2i(1, map_height - 2),         # Bottom Left
		Vector2i(map_width - 2, map_height - 2)  # Bottom Right
	]

	# Convert grid positions to world coordinates and visualize them
	spawn_points.clear()
	for pos in grid_spawn_points:
		var world_pos = grid_to_world(pos)
		spawn_points.append(world_pos)
		_draw_spawn_point(pos)

func generate_perimeter():
	#--------------------------------- Unbreakables ------------------------------
	# Generate unbreakable walls at the borders on Layer 2
	for x in range(map_width):
		for y in range(map_height):
			if x == 0 or x == map_width - 1 or y == 0 or y == map_height - 1:
				perimeter_layer.set_cell(Vector2i(x, y + map_offset), UNBREAKABLE_TILE_ID, Vector2i(0, 0), 0)

func generate_maze_walls():
	if maze_def is Dictionary:
		for y in range(maze_def.height):
			for x in range(maze_def.width):
				var cell_index = y * maze_def.width + x
				if cell_index < maze_def.data.size() and maze_def.data[cell_index] > 0:
					maze_wall_layer.set_cell(Vector2i(x+1, y+1 + map_offset), UNBREAKABLE_TILE_ID, Vector2i(0, 0), 0)

func create_target():
	var area = Area2D.new()
	var shape = RectangleShape2D.new()
	shape.extents = Vector2(16,16)

	var collision = CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)

	var target = Node2D.new()
	target.set_script(preload("res://Scripts/maze_target.gd"))
	target.size = shape.extents * 2
	target.color = Color(0.33, 1, 0.5, 0.75)
	target.position = -shape.extents
	area.add_child(target)

	var target_position = grid_to_world(Vector2(GRID_COLUMNS/2, GRID_ROWS/2))
	target_position = grid_to_world(Vector2(maze_def.target[0]+1,maze_def.target[1]+1))

	area.position = target_position
	area.body_entered.connect(_on_body_entered)
	add_child(area)
	target_area = area  # Store reference to target


# Convert grid coordinates to world coordinates
func grid_to_world(grid_pos: Vector2i, center_in_cell: bool = true) -> Vector2:
	var tile_size = tilemap.tile_set.tile_size
	# First convert to tilemap local coordinates
	var local_pos = Vector2(
		grid_pos.x * tile_size.x,
		grid_pos.y * tile_size.y
	)

	# Apply centering if needed
	if center_in_cell:
		local_pos += Vector2(tile_size.x / 2.0, tile_size.y / 2.0)

	# Convert to world coordinates
	return tilemap.to_global(local_pos)

# Debug function to visualize spawn points
func _draw_spawn_point(grid_pos: Vector2i):
	var marker = ColorRect.new()
	marker.size = Vector2(4, 4)  # Small marker
	marker.position = grid_to_world(grid_pos, true) - marker.size/2
	marker.color = Color(1, 0, 0, 0.5)  # Semi-transparent red
	marker.z_index = 100  # Ensure it's visible above everything
	add_child(marker)
	spawn_point_markers.append(marker)  # Store reference to the marker

func spawn_players(player_scene, instance_count = 1):
	rng.randomize()
	# Ensure tilemap is at z-index 0 and players will be above
	tilemap.z_index = 0

	# Create a local copy of spawn points that we can modify
	var available_spawn_points = spawn_points.duplicate()
	var players_in_level = []
	for i in range(instance_count):
		var attempts = 0
		var spawned = false
		while attempts < spawn_points.size() and not spawned:
			var random_index = rng.randi() % available_spawn_points.size()
			var spawn_coords = available_spawn_points[random_index]
			available_spawn_points.remove_at(random_index) # Remove the used spawn point
			#if is_valid_spawnpoint(spawn_coords) and not
			#is_spawnpoint_taken(spawn_coords):
			var player = player_scene.instantiate()
			player.scenario_id = current_scenario_id
			player.event_handler = Callable(self, "_handle_event")
			player.global_position = spawn_coords
			spawned_players.add_child(player)
			players_in_level.append(player)
			spawned = true
	return players_in_level

func start_scenario(agent_scene, scenario, unique_id, player_count):
	print("will start scenario %s with unique id %s" % [scenario, unique_id])
	stop_scenario(true, false)
	current_scenario = scenario
	current_scenario_id = unique_id
	maze_def = _load_maze(scenario)
	calculate_dimensions()
	create_maze()
	var new_players = spawn_players(agent_scene, player_count)
	var player_data = new_players.map(func(player): return {"id": str(player.get_instance_id()), "actuators": player.ACTUATORS})
	Global.transmit("scenario_started", {"scenario": scenario, "unique_id": unique_id, "agents": player_data})
	batch_timer.start()

func stop_scenario(remove_perimeter = false, broadcast = true):
	print("maze will stop scenario %s (%s)" % [current_scenario_id, current_scenario])
	# Remove and destroy all spawned players
	for player in spawned_players.get_children():
		player.queue_free()
	clear_scenario(remove_perimeter)
	batch_timer.stop()
	if broadcast:
		Global.transmit("scenario_stopped", {"id": current_scenario_id, "scenario": current_scenario})
	current_scenario = ""
	current_scenario_id = ""


func clear_scenario(remove_perimeter = false):
	# Clear all tiles from the maze wall layer
	maze_wall_layer.clear()

	# Remove the target if it exists
	if target_area:
		target_area.queue_free()
		target_area = null

	# Remove spawn point visual markers and clear arrays
	for marker in spawn_point_markers:
		marker.queue_free()
	spawn_point_markers.clear()
	spawn_points.clear()

	if remove_perimeter:
		perimeter_layer.clear()


func _on_body_entered(body):
	body.queue_free()
	Global.transmit("reached_target", {"agent": body.get_instance_id()})

func _handle_event(event):
	event_queue.push_back(event)

func _transmit_event_batch():
	print("will transmit batch with %d messages" % event_queue.size(), event_queue)
	Global.transmit("batch", {"sensor_data": event_queue})
	event_queue.clear()
