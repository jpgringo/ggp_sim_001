extends Node2D

@onready var tilemap = $TileMap
@onready var unbreakable_layer = $TileMap/UNBREAKABLE_TILE
@onready var spawned_players = $SpawnedPlayers

const INITIAL_WIDTH = 30
const INITIAL_HEIGHT = 17
var map_width = INITIAL_WIDTH
var map_height = INITIAL_HEIGHT
var map_offset = 0

const BACKGROUND_TILE_ID = 0
const BREAKABLE_TILE_ID = 1
const UNBREAKABLE_TILE_ID = 2
const BACKGROUND_TILE_LAYER = 0
const BREAKABLE_TILE_LAYER = 1
const UNBREAKABLE_TILE_LAYER = 2

var rng = RandomNumberGenerator.new()

func _ready():
	Global.maze_scene = self
	create_maze()

func create_maze():
	generate_unbreakables()

func generate_unbreakables():
	#--------------------------------- Unbreakables ------------------------------
	# Generate unbreakable walls at the borders on Layer 2
	for x in range(map_width):
		for y in range(map_height):
			if x == 0 or x == map_width - 1 or y == 0 or y == map_height - 1:
				unbreakable_layer.set_cell(Vector2i(x, y + map_offset), UNBREAKABLE_TILE_ID, Vector2i(0, 0), 0)	


func spawn_players(player_scene, instance_count = 1):
	print("Maze is spawning:", player_scene)
	rng.randomize()
	print("spawned_players tree root:", spawned_players.get_tree().root)
	print("Does root have Window class?", spawned_players.get_tree().root is Window)
	var spawn_points = [
		Vector2i(1, 1 + map_offset),
		Vector2i(map_width - 2, 1 + map_offset),
		Vector2i(1, map_height - 2 + map_offset),
		Vector2i(map_width - 2, map_height - 2 + map_offset)
	]
	var players_in_level = []
	for i in range(instance_count):
		var attempts = 0
		var spawned = false
		while attempts < spawn_points.size() and not spawned:
			var random_index = rng.randi() % spawn_points.size()
			var spawn_coords = spawn_points[random_index]
			spawn_points.remove_at(random_index) # Remove the used spawn point
			#if is_valid_spawnpoint(spawn_coords) and not
			#is_spawnpoint_taken(spawn_coords):
			var player = player_scene.instantiate()
			player.global_position = tilemap.map_to_local(spawn_coords)
			print("Player already has a parent:", player.get_parent())
			spawned_players.add_child(player)
			player.call_deferred("_post_add_debug")
			players_in_level.append(player)
			print("Instantiated player:", player)
			print("spawned player Is inside tree:", spawned_players.is_inside_tree())
			print("player Is inside tree:", player.is_inside_tree())
			print("Spawning at:", player.global_position)
			print("Visible:", player.visible)
			spawned = true
