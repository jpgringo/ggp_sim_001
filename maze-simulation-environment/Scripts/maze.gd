extends Node2D

@onready var tilemap = $TileMap
@onready var unbreakable_layer = $TileMap/UNBREAKABLE_TILE
@onready var spawned_players = $SpawnedPlayers

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

class DrawerRect:
	extends Node2D
	var size: Vector2

	func _ready():
		queue_redraw()

	func _draw():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0, 0, 0.5))

func _ready():
	Global.maze_scene = self
	calculate_dimensions()
	create_maze()
	# Connect to handle window resizing
	get_tree().root.size_changed.connect(self._on_viewport_resized)

func _on_viewport_resized():
	calculate_dimensions()
	position_grid()

# Calculate maze dimensions and scaling
func calculate_dimensions():
	map_width = GRID_COLUMNS
	map_height = GRID_ROWS
	
	var viewport_size = get_viewport_rect().size
	var base_tile_size = tilemap.tile_set.tile_size
	
	# Calculate scale factors for both dimensions
	var scale_x = viewport_size.x / (base_tile_size.x * GRID_COLUMNS)
	var scale_y = viewport_size.y / (base_tile_size.y * GRID_ROWS)
	
	# Use the smaller scale to maintain aspect ratio
	grid_scale = min(scale_x, scale_y)
	
	# Apply scale to tilemap
	tilemap.scale = Vector2(grid_scale, grid_scale)
	
	# Center the grid
	position_grid()

func position_grid():
	var viewport_size = get_viewport_rect().size
	var grid_pixel_size = Vector2(
		tilemap.tile_set.tile_size.x * GRID_COLUMNS * grid_scale,
		tilemap.tile_set.tile_size.y * GRID_ROWS * grid_scale
	)
	
	# Calculate padding to center the grid
	var padding = (viewport_size - grid_pixel_size) / 2
	tilemap.position = padding
	
# Store spawn points at class level so they're accessible to spawn_players
var spawn_points: Array[Vector2] = []

func create_maze():
	generate_perimeter()
	create_spawn_points()
	create_target()

# Create and visualize spawn points
func create_spawn_points():
	# Define spawn points in grid coordinates (first empty cell in each corner)
	var grid_spawn_points = [
		Vector2i(1, 1),                    # Top Left
		Vector2i(GRID_COLUMNS - 2, 1),      # Top Right
		Vector2i(1, GRID_ROWS - 2),         # Bottom Left
		Vector2i(GRID_COLUMNS - 2, GRID_ROWS - 2)  # Bottom Right
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
				unbreakable_layer.set_cell(Vector2i(x, y + map_offset), UNBREAKABLE_TILE_ID, Vector2i(0, 0), 0)	
				
func create_target():
	var area = Area2D.new()
	var shape = RectangleShape2D.new()
	shape.extents = Vector2(32,32)

	var collision = CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)

	var target = Node2D.new()
	target.set_script(preload("res://Scripts/maze_target.gd"))
	target.size = shape.extents * 2
	target.color = Color(0.33, 1, 0.5, 0.75)
	target.position = -shape.extents
	area.add_child(target)

	area.position = Vector2(150, 100)
	area.body_entered.connect(_on_body_entered)
	add_child(area)


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
			player.global_position = spawn_coords
			spawned_players.add_child(player)
			player.call_deferred("_post_add_debug")
			players_in_level.append(player)
			spawned = true

func stop_simulation():
	# Remove and destroy all spawned players
	for player in spawned_players.get_children():
		player.queue_free()

func _on_body_entered(body):
	body.queue_free()
	Global.transmit("reached_target", {"agent": body.get_instance_id()})
