extends Node2D

@onready var tilemap = $TileMap
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
	create_maze()
	spawn_players(Global.turtle_scene,1)

func create_maze():
	generate_unbreakables()

func generate_unbreakables():
	#--------------------------------- Ubreakables ------------------------------
	# Generate unbreakable walls at the borders on Layer 2
	for x in range(map_width):
		for y in range(map_height):
			if x == 0 or x == map_width - 1 or y == 0 or y == map_height - 1:
				tilemap.set_cell(UNBREAKABLE_TILE_LAYER, Vector2i(x, y + map_offset), UNBREAKABLE_TILE_ID, Vector2i(0, 0), 0)	


func spawn_players(player_scene, instance_count = 1):
	rng.randomize()
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
			spawned_players.add_child(player)
			players_in_level.append(player)
			spawned = true
