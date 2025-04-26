extends Node

var maze_scene = preload("res://Scenes/maze.tscn")
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

func _ready():
	print("Global.gd has loaded")
	start_receiver()
	start_transmitter()
	transmit("sim_ready", [0,1,2,3])
	
func _exit_tree():
	transmit("sim_stopping", [])
	running = false
	if receiver_thread and receiver_thread.is_alive():
		print("Shutting down receiver...")
		receiver_thread.wait_to_finish()
		udp_receiver.close()

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

			print("UDP Receiver - received from %s:%d -> %s" % [sender_ip, sender_port, message])

			# Handle JSON-RPC
			var parsed = JSON.parse_string(message)
			if parsed is Dictionary:
				_handle_json_rpc(parsed, sender_ip, sender_port)
		OS.delay_msec(10)  # avoid spinning

func _handle_json_rpc(msg: Dictionary, _ip: String, _port: int) -> void:
	var method = msg.get("method", "")
	var params = msg.get("params", null)
	var id = msg.get("id", null)

	print("JSON-RPC Method: %s, Params: %s, ID: %s" % [method, str(params), str(id)])
	# You can now dispatch by method, e.g.
	# if method == "ping": ...

func transmit(method: String, data: Array):
	var msg = json_rpc.make_notification(method, data)
	udp_transmitter.put_packet(JSON.stringify(msg).to_utf8_buffer())
