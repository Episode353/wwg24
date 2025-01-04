extends Node

@onready var hud = $CanvasLayer/HUD
@onready var health_bar = $CanvasLayer/HUD/HealthBar
@onready var mana_bar = $CanvasLayer/HUD/ManaBar
@onready var tb_loader = $TBLoader


const PORT = 7777
var enet_peer = ENetMultiplayerPeer.new()
var map_name = ""

func _unhandled_input(_event):
	if Input.is_action_just_pressed("quit"):
		close_game()
	if Input.is_action_just_pressed("fullscreen"):
		swap_fullscreen_mode()
	if Input.is_action_just_pressed("respawn"):
		var player_node = get_node_or_null(str(multiplayer.get_unique_id()))
		if player_node:
			respawn_player(player_node)
		else:
			print("Player node not found for respawn.")

		
func close_game():
	get_tree().quit()



@rpc("any_peer")
func kick_players():
	var peers = multiplayer.get_peers()
	for peer_id in peers:
		rpc("remove_player", peer_id)

@rpc("any_peer", "call_local")
func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	rpc("_on_peer_disconnected", peer_id)
	if player:
		player.queue_free()
		print("Removed player: ", peer_id)
	else:
		print("Player not found: ", peer_id)
		


func send_to_main_menu():
	var current_scene = get_tree().current_scene
	var new_scene = load("res://tscn/main_menu.tscn").instantiate()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	current_scene.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func swap_fullscreen_mode():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func start_offline(map: String):
	map_name = map
	hud.show()
	load_map(map_name)
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(Callable(self, "_on_peer_disconnected"))
	add_player(multiplayer.get_unique_id())

func start_host(map: String):
	map_name = map
	hud.show()
	load_map(map_name)
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(Callable(self, "_on_peer_connected"))
	multiplayer.peer_disconnected.connect(Callable(self, "_on_peer_disconnected"))
	add_player(multiplayer.get_unique_id())
	upnp_setup()
	display_to_killfeed("last_tagged_by", "Name")

func start_join(address: String):
	hud.show()
	enet_peer.create_client(address, PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.connect("network_peer_connected", Callable(self, "_on_peer_connected"))
	multiplayer.connect("network_peer_disconnected", Callable(self, "_on_peer_disconnected"))
	multiplayer.connect("server_disconnected", Callable(self, "_on_server_disconnected"))
	print("Connected server_disconnected signal")
	add_player(multiplayer.get_unique_id())

func load_map(load_map_name: String):
	tb_loader.map_resource = "tbmaps/" + load_map_name
	tb_loader.build_meshes()
	print(tb_loader.map_resource)

func add_player(peer_id):
	var Player = preload("res://player.tscn")
	var spawnplayer = Player.instantiate()
	spawnplayer.name = str(peer_id)
	print("Adding player with peer ID: ", peer_id)
	spawn_player(spawnplayer)
	add_child(spawnplayer)
	print("Player ", peer_id, " added to the scene at position: ", spawnplayer.global_transform.origin)
	if spawnplayer.is_multiplayer_authority():
		spawnplayer.health_changed.connect(update_health_bar)
		spawnplayer.mana_changed.connect(update_mana_bar)
		print("Connected health and mana signals for player ", peer_id)
	print("Player ", peer_id, " successfully added and initialized.")

func spawn_player(player):
	print("Spawning player: ", player.name)
	var spawn_points = get_tree().get_nodes_in_group("info_player_start")
	print("Found ", spawn_points.size(), " spawn points in group 'info_player_start'")
	if spawn_points.size() == 0:
		print("No spawn points found in the group 'info_player_start'. Using default spawn position.")
		player.global_transform.origin = Vector3(0, 0, 0)
	else:
		var chosen_spawn_point = spawn_points[randi() % spawn_points.size()]
		var start_position = chosen_spawn_point.global_transform
		print("Chosen spawn point: ", chosen_spawn_point.name, " at position: ", start_position)
		player.global_transform = start_position

func respawn_player(player):
	print("Respawning player: ", player.name)
	spawn_player(player)
	print("Player ", player.name, " respawned successfully.")

func update_health_bar(health_value):
	health_bar.value = health_value

func update_mana_bar(mana_value):
	mana_bar.value = mana_value
	

func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health_bar)
		node.mana_changed.connect(update_mana_bar)

func upnp_setup():
	var upnp = UPNP.new()
	var discover_result = upnp.discover()
	
	# Check for UPNP discovery failure (Error 27)
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		print("UPNP Discover Failed! Error %s" % discover_result)
		send_to_main_menu()  # Send to main menu
		return  # Do nothing further if discovery fails
	
	var gateway = upnp.get_gateway()
	
	if !gateway or !gateway.is_valid_gateway():
		print("UPNP Invalid Gateway!")
		send_to_main_menu()  # Send to main menu
		return  # Do nothing further if gateway is invalid

	var map_result = upnp.add_port_mapping(PORT)
	
	if map_result != UPNP.UPNP_RESULT_SUCCESS:
		print("UPNP Port Mapping Failed! Error %s" % map_result)
		send_to_main_menu()  # Send to main menu
		return  # Do nothing further if port mapping fails

	print("----------------------------")
	print("|")
	print("Gateway: %s" % gateway)
	print("Success! Join Address: %s" % upnp.query_external_address())
	print("IP adress has been copied to clipboard")
	print("|")
	print("----------------------------")
	DisplayServer.clipboard_set(upnp.query_external_address())

func _ready():
	if map_name != "":
		load_map(map_name)
	var all_children = get_all_children(tb_loader)
	for i in all_children:
		i.add_to_group("tbloader")
		if i is CollisionObject3D:
			i.set_collision_layer_value(5, true)

func get_all_children(in_node, arr := []):
	arr.push_back(in_node)
	for child in in_node.get_children():
		arr = get_all_children(child, arr)
	return arr

@rpc("any_peer")
func _on_peer_connected(id):
	if id != multiplayer.get_unique_id():
		rpc_id(id, "_send_map_name", map_name)
	add_player(id)

@rpc("any_peer")
func _send_map_name(received_map_name: String):
	map_name = received_map_name
	load_map(map_name)
	
@rpc("any_peer", "call_local")
func _on_peer_disconnected(peer_id):
	print("_on_peer_disconnected", peer_id)

@rpc("reliable")
func _on_server_disconnected():
	print("Server disconnected")
	send_to_main_menu()

@onready var current_weapon_label = $CanvasLayer/HUD/VBoxContainer/HBoxContainer/CurrentWeapon
@onready var current_ammo_label = $CanvasLayer/HUD/VBoxContainer/HBoxContainer2/CurrentAmmo
@onready var weapon_stack_label = $CanvasLayer/HUD/VBoxContainer/HBoxContainer3/WeaponStack

var current_weapon_name = ""
var current_weapon_ammo = 0
var current_weapon_reserve_ammo = 0
var weapon_stack = []

# Handle updates for weapon info sent from weapons_manager.gd
@rpc("reliable", "call_local")
func update_weapon_info(weapon_name: String, ammo: int, reserve_ammo: int, stack: Array):
	current_weapon_name = weapon_name
	current_weapon_ammo = ammo
	current_weapon_reserve_ammo = reserve_ammo
	weapon_stack = stack
	update_weapon_hud()  # Update the HUD elements


func update_weapon_hud():
	current_weapon_label.text = current_weapon_name
	current_ammo_label.text = str(current_weapon_ammo) + "/" + str(current_weapon_reserve_ammo)
	
	# Format weapon_stack to make it more readable
	var formatted_stack = ""
	for weapon in weapon_stack:
		formatted_stack += weapon + ", "  # Add each weapon on a new line
	
	weapon_stack_label.text = formatted_stack.strip_edges()  # Remove any unnecessary trailing newline

func _on_button_pressed():
	if is_multiplayer_authority():
		rpc("_on_server_disconnected")
	rpc("kick_players")
	send_to_main_menu()
	
	
# We Put the killfeed code here because we let the players RPC when to display to the killfeed
# And then the world will call everyone and tell them about it.
@onready var killfeed_container = $CanvasLayer/HUD/KillfeedContainter
@onready var killfeed_object_scene = preload("res://tscn/killfeed_object/killfeed_object.tscn")  # Load the killfeed object scene

# Display kills on the killfeed
@rpc("any_peer", "call_local")
func display_to_killfeed(last_tagged_by, display_name):
	print("Kill feed update: ", last_tagged_by, " killed ", display_name)

	# Instantiate the killfeed object
	var killfeed_label = killfeed_object_scene.instantiate()
	
	# Set the text of the killfeed label
	killfeed_label.text = name + " was killed by " + last_tagged_by

	# Add the label to the killfeed container
	killfeed_container.add_child(killfeed_label)






