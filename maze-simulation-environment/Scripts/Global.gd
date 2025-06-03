extends Node

var maze_scene
var turtle_scene = preload("res://Scenes/turtle.tscn")

# communication consts/vars
var udp_receiver : PacketPeerUDP
var udp_transmitter : PacketPeerUDP
var receiver_thread : Thread

var json_rpc := JSONRPC.new()
var is_listening := false
var running := true

const LOCAL_PORT := 7401
const DEST_IP := "127.0.0.1"
const DEST_PORT := 7400

# other declarations
var player
var maps_list = []

func _ready():
	start_receiver()
	start_transmitter()
	maps_list = get_maps_list()
	transmit("sim_ready", {"scenarios": maps_list})

func _exit_tree():
	print("EXITING TREE!!")
	transmit("sim_stopping", [])
	running = false
	if receiver_thread and receiver_thread.is_alive():
		print("Shutting down receiver...")
		receiver_thread.wait_to_finish()
		udp_receiver.close()

func get_maps_list() -> PackedStringArray:
	var maps_path = "res://Maps"
	var dir := DirAccess.open(maps_path)
	var files := PackedStringArray()
	var pattern := RegEx.new()
	pattern.compile("^map_\\d+\\.json$")  # escape backslashes properly

	if dir:
		for file in dir.get_files():
			if pattern.search(file):
				files.append(file)
	else:
		push_error("Failed to open directory: %s" % maps_path)

	return files

func start_receiver():
	udp_receiver = PacketPeerUDP.new()
	var result : int = udp_receiver.bind(LOCAL_PORT)
	if result != OK:
		push_error("Failed to bind UDP socket to port %d" % LOCAL_PORT)
		return
	is_listening = true
	receiver_thread = Thread.new()
	receiver_thread.start(self._listen_loop)
	print("Receiver listening on port %d" % [LOCAL_PORT])

func start_transmitter():
	udp_transmitter = PacketPeerUDP.new()
	udp_transmitter.set_dest_address(DEST_IP, DEST_PORT)


func _listen_loop(_userdata : Variant = null):
	while running:
		if udp_receiver.get_available_packet_count() > 0:
			var packet := udp_receiver.get_packet()
			var sender_ip := udp_receiver.get_packet_ip()
			var sender_port := udp_receiver.get_packet_port()

			var message := ""
			if typeof(packet) == TYPE_PACKED_BYTE_ARRAY:
				message = packet.get_string_from_utf8()
			else:
				message = str(packet)

			#print("UDP Receiver - received from %s:%d -> %s" % [sender_ip, sender_port, message])

			# Handle JSON-RPC
			var parsed = JSON.parse_string(message)
			if parsed is Dictionary:
				_handle_json_rpc(parsed, sender_ip, sender_port)
		OS.delay_msec(10)  # avoid spinning

func _handle_json_rpc(msg: Dictionary, _ip: String, _port: int) -> void:
	var method = msg.get("method", "")
	var params = msg.get("params", null)
	var id = msg.get("id", null)

	#print("JSON-RPC Method: %s, Params: %s, ID: %s" % [method, str(params), str(id)])

	if method == "actuator_data" and params is Dictionary:
		print("handling actuator_data:", params)
		var agent_id = int(params.get("agent"))
		var data = params.get("data")
		if agent_id != null and data != null:
			var node = instance_from_id(agent_id)
			if node and node.has_method("actuator_input"):
				node.actuator_input(data)
			#else:
				#print("Warning: Could not find turtle with ID %d or turtle lacks actuator_input method" % agent_id)
	else: if method == "start_scenario":
		var scenario = params.get("scenario")
		var unique_id = params.get("unique_id")
		var player_count = params.get("agents", 1)
		call_deferred("_start_scenario_main_thread", turtle_scene, scenario, unique_id, player_count)
	else: if method == "stop_scenario" || method == "panic":
		call_deferred("_stop_scenario_main_thread")

func transmit(method: String, data: Variant):
	var msg = json_rpc.make_notification(method, data)
	udp_transmitter.put_packet(JSON.stringify(msg).to_utf8_buffer())

func _start_scenario_main_thread(agent_scene, scenario, unique_id, player_count):
	if maze_scene and maze_scene.is_inside_tree():
		maze_scene.start_scenario(agent_scene, scenario, unique_id, player_count)
	else:
		print("Maze is not in the scene tree")

func _stop_scenario_main_thread():
	if maze_scene and maze_scene.is_inside_tree():
		maze_scene.stop_scenario()
	else:
		print("Maze is not in the scene tree")
