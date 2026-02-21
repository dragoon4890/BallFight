extends Node

@export var player_scene: PackedScene
@export var spawn_points: Node3D # A Node3D containing Marker3D children

var peer = ENetMultiplayerPeer.new()
var port = 9999
var address = "127.0.0.1"

func _ready():
	# --- Auto-Setup Input Map ---
	# This ensures your controls work without manual project settings
	var inputs = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP],
		"move_backward": [KEY_S, KEY_DOWN],
		"ui_accept": [KEY_SPACE], # Jump
		"ui_cancel": [KEY_ESCAPE], # Unlock Mouse
		"attack": [MOUSE_BUTTON_LEFT],
		"dodge": [KEY_SHIFT]
	}

	for action in inputs:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			
		for key in inputs[action]:
			var event
			if typeof(key) == TYPE_INT and key < 10: # Mouse Button
				event = InputEventMouseButton.new()
				event.button_index = key
			else: # Keyboard Key
				event = InputEventKey.new()
				event.keycode = key
			
			InputMap.action_add_event(action, event)

	# --- Connect Multiplayer Signals ---
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	
func host_game():
	var error = peer.create_server(port, 4) # Max 4 players
	if error != OK:
		print("Cannot host: " + str(error))
		return
	multiplayer.multiplayer_peer = peer
	print("Waiting for players...")
	
	hide_menu()
	
	# Host is also a player, so spawn immediately
	spawn_player(1)

func join_game(ip_address="127.0.0.1"):
	address = ip_address
	var error = peer.create_client(address, port)
	if error != OK:
		print("Cannot join: " + str(error))
		return
	multiplayer.multiplayer_peer = peer
	
	hide_menu()

func hide_menu():
	var canvas = get_node_or_null("CanvasLayer")
	if canvas:
		canvas.visible = false

func _on_connected_to_server():
	print("Connected to server!")
	# We (the client) have successfully connected.
	# Spawn ourselves (the local player)
	spawn_player(multiplayer.get_unique_id())

func _on_peer_connected(id):
	print("Player connected: " + str(id))
	# Spawn the other player that just connected
	spawn_player(id)

func _on_peer_disconnected(id):
	print("Player disconnected: " + str(id))
	# Find and remove their character node
	if has_node(str(id)):
		get_node(str(id)).queue_free()

func spawn_player(id):
	var player = player_scene.instantiate()
	player.name = str(id) # Important for network authority
	
	# Deterministic spawn position based on ID
	var spawn_pos = Vector3(0, 5, 0)
	if spawn_points and spawn_points.get_child_count() > 0:
		var index = id % spawn_points.get_child_count()
		spawn_pos = spawn_points.get_child(index).global_position
	
	player.position = spawn_pos # Use local position before adding to tree to avoid errors
	
	# CRITICAL: Set authority BEFORE adding to tree so _ready() sees correct authority
	player.set_multiplayer_authority(id)
	
	add_child(player)
