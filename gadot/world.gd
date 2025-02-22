

extends Node

@onready var hud: Control = $CanvasLayer/HUD
@onready var health_bar: ProgressBar = $CanvasLayer/HUD/HealthBar
@onready var mana_bar: ProgressBar = $CanvasLayer/HUD/ManaBar
@onready var tb_loader: Node = $NavigationRegion3D/TBLoader
@onready var server_connection_handler: Node = $ServerConnectionHandler
var server_info_timer: Timer
var server_info_resend_duration : int = 5
var external_ip : String = "NULL"
signal map_loaded
var waiting_players = []

const PORT : int = 7777
var enet_peer = ENetMultiplayerPeer.new()
var map_name = ""
func _unhandled_input(_event):
	if Globals.paused:
		return
	if Input.is_action_just_pressed("respawn"):
		var player_node = get_node_or_null(str(multiplayer.get_unique_id()))
		if player_node:
			respawn_player(player_node)
		else:
			print("Player node not found for respawn.")

		


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
	# Example of also stopping the timer if you're returning to main menu
	if server_info_timer:
		server_info_timer.stop()
		server_info_timer.queue_free()
		server_info_timer = null
	# Then do the rest of your main-menu logic
	var current_scene = get_tree().current_scene
	var new_scene = load("res://tscn/main_menu.tscn").instantiate()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	current_scene.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE




func start_offline(map: String):
	map_name = map
	hud.show()
	load_map(map_name)
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(Callable(self, "_on_peer_disconnected"))
	add_player(multiplayer.get_unique_id())

func start_host(map: String):
	# Set up your map, create the server, etc.
	hud.show()
	map_name = map
	load_map(map_name)

	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer

	# Connect multiplayer signals
	multiplayer.peer_connected.connect(Callable(self, "_on_peer_connected"))
	multiplayer.peer_disconnected.connect(Callable(self, "_on_peer_disconnected"))

	# Add the local player
	add_player(multiplayer.get_unique_id())

	# Example: setting up UPnP, etc.
	upnp_setup()

	# Now create a Timer to periodically send server info
	setup_server_info_timer()
	print("Host started on port %d. Timer set up to re-send server info periodically.")
	 #"For those about to rock / AC?DC"
	#for i in 70:
		#add_bot("0 0 0", false, "100", "ak47", false, Vector3.ZERO)
	#

func start_join(address: String):
	hud.show()

	# If the address might contain a colon, parse out the port
	var ip = address
	var port = PORT  # default fallback, e.g. 7777

	if address.find(":") != -1:
		var splitted = address.split(":")
		ip = splitted[0]
		port = int(splitted[1])
	enet_peer.create_client(ip, port)
	multiplayer.multiplayer_peer = enet_peer

	multiplayer.connect("network_peer_connected", Callable(self, "_on_peer_connected"))
	multiplayer.connect("network_peer_disconnected", Callable(self, "_on_peer_disconnected"))
	multiplayer.connect("server_disconnected", Callable(self, "_on_server_disconnected"))
	print("Connected server_disconnected signal")

	add_player(multiplayer.get_unique_id())


func load_map(load_map_name: String):
	for child in tb_loader.get_children():
		child.queue_free()
	tb_loader.map_resource = "tbmaps/" + load_map_name
	tb_loader.build_meshes()
	print(tb_loader.map_resource)
	$NavigationRegion3D.bake_navigation_mesh()
	Globals.map_loaded = true
	emit_signal("map_loaded")

@rpc("any_peer", "call_local")
func rebuild_map():
	tb_loader.build_meshes()
	$NavigationRegion3D.bake_navigation_mesh()
	# Remove all bots from the scene.
	for child in get_children():
		# Check if the child has an "is_bot" property and if it's true.
		# (Bots created in add_bot() have is_bot = true.)
		if child.has_method("get") and child.get("is_bot") == true:
			child.queue_free()

	
	

var next_bot_id: int = -1

@rpc("any_peer", "call_local")
func add_bot(origin, use_spawn_position, weapon_range, weapon, disable_respawn, spawn_position: Vector3 = Vector3.ZERO):
	var Player = preload("res://player.tscn")
	var bot_instance = Player.instantiate()
	print(spawn_position)

	# Assign a unique bot ID from our counter.
	var bot_peer_id = next_bot_id
	next_bot_id -= 1  # Prepare the next unique ID

	bot_instance.name = str(bot_peer_id)
	bot_instance.is_bot = true
	bot_instance.bot_origin = origin
	bot_instance.disable_respawn = disable_respawn
	bot_instance.use_spawn_position = use_spawn_position
	bot_instance.bot_starter_weapon = weapon
	bot_instance.bot_weapon_range = weapon_range
	bot_instance.rpc("set_is_bot", true)
	bot_instance.set_multiplayer_authority(bot_peer_id)
	bot_instance.peer_id = bot_peer_id
	bot_instance.add_to_group("bots")  # <-- Add the bot to a "bots" group

	if spawn_position == Vector3.ZERO:
		spawn_player(bot_instance)
	else:
		bot_instance.global_transform.origin = spawn_position
		if bot_instance is RigidBody3D:
			bot_instance.linear_velocity = Vector3.ZERO
			bot_instance.angular_velocity = Vector3.ZERO
			bot_instance.velocity = Vector3.ZERO

	add_child(bot_instance)
	print("Bot added to the scene with unique id: ", bot_peer_id, " at position: ", bot_instance.global_transform.origin)








func add_player(peer_id):
	var Player = preload("res://player.tscn")
	var spawnplayer = Player.instantiate()
	spawnplayer.name = str(peer_id)
	print("Adding player with peer ID: ", peer_id)
	# Always assign the server (local) as the authority:
	spawnplayer.set_multiplayer_authority(peer_id)
	spawnplayer.peer_id = peer_id
	if Globals.map_loaded:
		spawn_player(spawnplayer)
		add_child(spawnplayer)
		if spawnplayer.is_multiplayer_authority():
			spawnplayer.health_changed.connect(update_health_bar)
			spawnplayer.mana_changed.connect(update_mana_bar)
	else:
		waiting_players.append(spawnplayer)
		print("Map not loaded yet. Delaying spawn for player: ", peer_id)


func _on_map_loaded():
	for spawnplayer in waiting_players:
		spawn_player(spawnplayer)
		add_child(spawnplayer)
		print("Delayed player ", spawnplayer.name, " spawned at position: ", spawnplayer.global_transform.origin)
		if spawnplayer.is_multiplayer_authority():
			spawnplayer.health_changed.connect(update_health_bar)
			spawnplayer.mana_changed.connect(update_mana_bar)
	waiting_players.clear()



func spawn_player(player):
	print("Spawning player: ", player.name)
	
	if player.use_spawn_position:
		# Use the player's bot_origin string to set its position.
		var origin_str = player.bot_origin.strip_edges()
		var parts = origin_str.split(" ")
		if parts.size() != 3:
			push_error("Invalid bot_origin format for player. Expected three numbers separated by spaces, got: " + origin_str)
			player.global_transform.origin = Vector3.ZERO
		else:
			# Convert the string values to floats.
			var tb_x = parts[0].to_float()
			var tb_y = parts[1].to_float()
			var tb_z = parts[2].to_float()
			
			# Apply the transformation formula:
			# Godot x = tb_y / 16, Godot y = tb_z / 16, Godot z = tb_x / 16
			var godot_position = Vector3(tb_y / 16.0, tb_z / 16.0, tb_x / 16.0)
			player.global_transform.origin = godot_position
			print("Spawning player at bot_origin (converted): ", godot_position)
	else:
		# Get spawn points from the group "info_player_start"
		var spawn_points = get_tree().get_nodes_in_group("info_player_start")
		print("Found ", spawn_points.size(), " spawn points in group 'info_player_start'")
		
		if spawn_points.size() == 0:
			print("No spawn points found in the group 'info_player_start'. Using default spawn position.")
			player.global_transform.origin = Vector3.ZERO
		else:
			var chosen_spawn_point = spawn_points[randi() % spawn_points.size()]
			var start_transform = chosen_spawn_point.global_transform
			print("Chosen spawn point: ", chosen_spawn_point.name, " at position: ", start_transform)
			player.global_transform = start_transform
	 
	# Reset the player's velocities if it is a RigidBody3D.
	if player is RigidBody3D:
		player.linear_velocity = Vector3.ZERO
		player.angular_velocity = Vector3.ZERO
		# In some cases, you may have a custom 'velocity' property.
		if "velocity" in player:
			player.velocity = Vector3.ZERO



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
	external_ip = upnp.query_external_address()
	print("----------------------------")
	print("|")
	print("Gateway: %s" % gateway)
	print("Success! Join Address: %s" % external_ip)
	print("IP adress has been copied to clipboard")
	print("|")
	print("----------------------------")
	server_connection_handler.send_server_info(external_ip)
	DisplayServer.clipboard_set(external_ip)

func setup_server_info_timer():
	if is_multiplayer_authority():
		# If it already exists (just in case), clean it up
		if server_info_timer and server_info_timer.is_inside_tree():
			server_info_timer.stop()
			server_info_timer.queue_free()

		server_info_timer = Timer.new()
		server_info_timer.wait_time = server_info_resend_duration
		server_info_timer.one_shot = false
		# Connect the Timer’s timeout to our function that re-sends info
		server_info_timer.connect("timeout", Callable(self, "_on_server_info_timer_timeout"))
		add_child(server_info_timer)
		server_info_timer.start()


func _on_server_info_timer_timeout():
	# Only send if we are indeed the server/host
	if is_multiplayer_authority():
		server_connection_handler.send_server_info(external_ip)
		print("Resending server info to master server at address:", external_ip)
	else:
		# If for some reason we lost authority, stop the timer
		if server_info_timer:
			server_info_timer.stop()

func _ready():
	connect("map_loaded", Callable (self, "_on_map_loaded"))
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

	# If the host (our local ID) is disconnecting, stop sending updates
	if peer_id == multiplayer.get_unique_id():
		if server_info_timer:
			server_info_timer.stop()
			server_info_timer.queue_free()
			server_info_timer = null
		print("Host disconnected. Stopped sending server info.")

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
	killfeed_label.text = display_name + " was killed by " + last_tagged_by

	# Add the label to the killfeed container
	killfeed_container.add_child(killfeed_label)
	
@rpc("any_peer", "call_local")
func spawn_ball(desired_transform):
	# Load the ball scene.
	var ball_scene = preload("res://entities/props/grabbable/ball.tscn")
	var ball_instance = ball_scene.instantiate()
	
	# Set the spawn transform.
	ball_instance.global_transform = desired_transform

	
	# Optionally, if your ball has a script that manages its synchronization,
	# ensure it’s properly configured here.
	
	# Add the ball to the scene so that all peers will have it.
	add_child(ball_instance)
	print("Ball spawned at: ", ball_instance.global_transform.origin)
	

@rpc("any_peer", "call_local")
func spawn_box(desired_transform):
	# Load the ball scene.
	var ball_scene = preload("res://entities/props/grabbable/box.tscn")
	var ball_instance = ball_scene.instantiate()
	
	# Set the spawn transform.
	ball_instance.global_transform = desired_transform
	
	# Set the server as the authority (or whichever peer should own it).
	#ball_instance.set_multiplayer_authority(1)
	
	# Optionally, if your ball has a script that manages its synchronization,
	# ensure it’s properly configured here.
	
	# Add the ball to the scene so that all peers will have it.
	add_child(ball_instance)
	print("Ball spawned at: ", ball_instance.global_transform.origin)
	
# Only the server should call change_level().
func change_level(new_map_name: String) -> void:
	# Make sure only the server initiates the level change.
	if not is_multiplayer_authority():
		return
	# Tell all connected peers (including ourself if needed) to change level.
	rpc("change_level_rpc", new_map_name)
	# Change the level on the server.
	_do_change_level(new_map_name)

@rpc("any_peer", "call_local")
func change_level_rpc(new_map_name: String) -> void:
	# On clients, only execute if not the server (so the server doesn’t run it twice).
	if is_multiplayer_authority():
		return
	_do_change_level(new_map_name)

func _do_change_level(new_map_name: String) -> void:		
	# Update the map name and load the new map
	map_name = new_map_name
	load_map(map_name)
	
	# Respawn (reposition) all players
	# (Assuming your players are added to the "players" group)
	for node in get_tree().get_nodes_in_group("players"):
		var player = node as CharacterBody3D
		if player:
			print("DOING THE MAP CHANGE WITH YOUR HOMIE", player)
			spawn_player(player)
