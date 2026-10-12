

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
const CENTER_ANNOUNCEMENT = preload("res://sys/hud/center_announcement.gd")
var _announcement: Control

const PORT : int = 7777
var enet_peer = ENetMultiplayerPeer.new()
var map_name = ""
func _unhandled_input(event):
	if Globals.paused:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1 and event.shift_pressed:
		reload_map_offline()
		return
	if Input.is_action_just_pressed("respawn"):
		if gamemode and not gamemode.allows_manual_respawn():
			return
		var player_node = get_node_or_null(str(multiplayer.get_unique_id()))
		if player_node:
			respawn_player(player_node)
		else:
			print("Player node not found for respawn.")

		


# Big centered text on this peer's HUD that fades in and out
func show_announcement(title: String, subtitle: String = "", color: Color = Color.WHITE, hold_time: float = 2.0) -> void:
	if not is_instance_valid(_announcement):
		_announcement = CENTER_ANNOUNCEMENT.new()
		hud.add_child(_announcement)
	_announcement.show_message(title, subtitle, color, hold_time)


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
	_close_network()
	Globals.map_loaded = false
	# Then do the rest of your main-menu logic
	var current_scene = get_tree().current_scene
	var new_scene = load("res://tscn/main_menu.tscn").instantiate()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	current_scene.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$CanvasLayer/menufadein.show()

# Shift+F1: disconnect, then let the main menu boot the same map as a fresh offline game
func reload_map_offline():
	if map_name == "":
		print("No map loaded, nothing to reload.")
		return
	print("Reloading map offline from scratch: ", map_name)
	if is_multiplayer_authority():
		rpc("_on_server_disconnected")
	rpc("kick_players")

	Globals.launch_map = map_name
	send_to_main_menu()

# Closes the server/client connection (freeing the port) and drops back to offline networking
func _close_network() -> void:
	if _join_timer:
		_join_timer.stop()
	var peer = multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		# Push any pending disconnect RPCs out before the connection is torn down
		peer.host.flush()
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _hosting_publicly:
		_hosting_publicly = false
		Globals.clear_local_host()





func start_offline(map: String):
	map_name = map
	hud.show()
	load_map(map_name)
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(Callable(self, "_on_peer_disconnected"))
	add_player(multiplayer.get_unique_id())

func start_host(map: String):
	# Set up your map, create the server, etc.
	var err = enet_peer.create_server(PORT)
	if err != OK:
		_fail_network("Could not host on port %d (error %s). Another game instance or program is probably already using it." % [PORT, err])
		return
	multiplayer.multiplayer_peer = enet_peer

	hud.show()
	map_name = map
	load_map(map_name)

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

const JOIN_TIMEOUT: float = 10.0
var _join_timer: Timer

func start_join(address: String):
	hud.show()
	Globals.map_loaded = false

	# If the address might contain a colon, parse out the port
	var ip = address.strip_edges()
	var port = PORT  # default fallback, e.g. 7777

	if ip.find(":") != -1:
		var splitted = ip.split(":")
		ip = splitted[0]
		port = int(splitted[1])
	if ip == "":
		ip = "127.0.0.1"
	# Most routers drop connections from inside the network to their own public IP
	if Globals.is_hosted_locally(ip, port):
		print("%s:%d is hosted on this machine, connecting through 127.0.0.1 instead" % [ip, port])
		ip = "127.0.0.1"

	var err = enet_peer.create_client(ip, port)
	if err != OK:
		_fail_network("Could not start connecting to %s:%d (error %s)." % [ip, port, err])
		return
	multiplayer.multiplayer_peer = enet_peer

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed.bind(ip, port))
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	# ENet can take ~30 seconds to give up on its own
	_join_timer = Timer.new()
	_join_timer.one_shot = true
	_join_timer.wait_time = JOIN_TIMEOUT
	_join_timer.timeout.connect(_on_connection_failed.bind(ip, port))
	add_child(_join_timer)
	_join_timer.start()
	print("Connecting to %s:%d..." % [ip, port])

	# The server spawns our player through the MultiplayerSpawner once we're connected

func _on_connected_to_server() -> void:
	_join_timer.stop()
	print("Connected to server, waiting for the map name...")
	rpc_id(1, "_check_protocol", Globals.NET_PROTOCOL)
	get_tree().create_timer(PROTOCOL_CHECK_TIMEOUT).timeout.connect(_on_protocol_check_timeout)

# ---- Version check: the host kicks clients that don't send a matching NET_PROTOCOL in time,
# and clients leave hosts that never confirm theirs (older builds don't know about the check)
const PROTOCOL_CHECK_TIMEOUT: float = 10.0
const VERSION_MISMATCH_MESSAGE = "Your game version doesn't match the host's. Both players need the latest version."
var _protocol_accepted: bool = false
var _verified_peers: Dictionary = {}

@rpc("any_peer", "reliable")
func _check_protocol(protocol: int) -> void:
	if not multiplayer.is_server():
		return
	var id = multiplayer.get_remote_sender_id()
	if protocol == Globals.NET_PROTOCOL:
		_verified_peers[id] = true
		rpc_id(id, "_on_protocol_accepted")
	else:
		_kick_peer(id, VERSION_MISMATCH_MESSAGE)

func _kick_if_unverified(id: int) -> void:
	if not _verified_peers.has(id) and id in multiplayer.get_peers():
		_kick_peer(id, VERSION_MISMATCH_MESSAGE)

func _kick_peer(id: int, reason: String) -> void:
	print("Kicking peer %d: %s" % [id, reason])
	rpc_id(id, "_on_kicked", reason)
	# "Later" so the reason above is delivered before the disconnect
	enet_peer.get_peer(id).peer_disconnect_later()

@rpc("authority", "reliable")
func _on_protocol_accepted() -> void:
	_protocol_accepted = true

@rpc("authority", "reliable")
func _on_kicked(reason: String) -> void:
	Globals.network_error = reason

func _on_protocol_check_timeout() -> void:
	if not _protocol_accepted and multiplayer.multiplayer_peer == enet_peer:
		_fail_network(VERSION_MISMATCH_MESSAGE)

func _on_connection_failed(ip: String, port: int) -> void:
	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_fail_network("Could not connect to %s:%d. The host may be offline, behind a firewall/VPN, or its port %d isn't forwarded." % [ip, port, port])

# Returns to the main menu, which shows the reason in a popup
func _fail_network(reason: String) -> void:
	push_warning(reason)
	Globals.network_error = reason
	send_to_main_menu()


#func load_map(load_map_name: String):
	#for child in tb_loader.get_children():
		#child.queue_free()
	#tb_loader.map_resource = "tbmaps/" + load_map_name
	#tb_loader.build_meshes()
	#print(tb_loader.map_resource)
	#$NavigationRegion3D.bake_navigation_mesh()
	#Globals.map_loaded = true
	#emit_signal("map_loaded")
@onready var func_godot_map: FuncGodotMap = $NavigationRegion3D/FuncGodotMap

func load_map(map_name: String) -> void:
	# IMPORTANT: Set map_loaded to false immediately to prevent premature spawning
	Globals.map_loaded = false
	
	# Disconnect any existing signal connections
	if func_godot_map.build_complete.is_connected(_on_build_complete):
		func_godot_map.build_complete.disconnect(_on_build_complete)
	
	for child in tb_loader.get_children():
		child.queue_free()
	
	func_godot_map.local_map_file = "tbmaps/" + map_name
	func_godot_map.verify_and_build()
	
	# Connect and await
	func_godot_map.build_complete.connect(_on_build_complete, CONNECT_ONE_SHOT)
	await func_godot_map.build_complete
	
	print("Map built, now baking navigation...")
	$NavigationRegion3D.bake_navigation_mesh()
	_setup_gamemode()
	Globals.map_loaded = true
	emit_signal("map_loaded")
	_start_map_watcher()

func _on_build_complete():
	# Handle completion here if needed
	pass

# Map hot reload: when the current .map file changes on disk (e.g. saved in TrenchBroom),
# rebuild just the map in place so edits show up live without moving any players.
const MAP_WATCH_INTERVAL: float = 0.5
var _map_watch_timer: Timer
var _map_watch_mtime: int = 0
var _map_watch_pending: bool = false

func _map_file_path() -> String:
	return "res://tbmaps/" + map_name

func _start_map_watcher() -> void:
	# Exported builds read maps from the .pck, so there is nothing on disk to watch
	if not OS.has_feature("editor"):
		return
	_map_watch_mtime = FileAccess.get_modified_time(_map_file_path())
	_map_watch_pending = false
	if _map_watch_timer:
		return
	_map_watch_timer = Timer.new()
	_map_watch_timer.wait_time = MAP_WATCH_INTERVAL
	_map_watch_timer.timeout.connect(_on_map_watch_timeout)
	add_child(_map_watch_timer)
	_map_watch_timer.start()

func _on_map_watch_timeout() -> void:
	if not Globals.hot_reload_map or map_name == "" or not Globals.map_loaded:
		return
	var mtime := FileAccess.get_modified_time(_map_file_path())
	if mtime == 0:
		return
	if mtime != _map_watch_mtime:
		# Wait until the file stops changing so we never parse a half-written save
		_map_watch_mtime = mtime
		_map_watch_pending = true
	elif _map_watch_pending:
		_map_watch_pending = false
		hot_reload_map()

func hot_reload_map() -> void:
	if map_name == "" or not Globals.map_loaded:
		return
	print("Hot reloading map: ", map_name)
	# Bot spawner entities spawn their bots again when the map is rebuilt; gamemode bots (team != 0) stay
	if multiplayer.is_server():
		for bot in get_tree().get_nodes_in_group("bots"):
			if bot.team == 0:
				bot.queue_free()

	Globals.map_loaded = false
	# A blocking build finishes within this frame, so physics never steps without the map and nobody falls through
	func_godot_map.block_until_complete = true
	func_godot_map.local_map_file = "tbmaps/" + map_name
	func_godot_map.verify_and_build()
	func_godot_map.block_until_complete = false

	var nav_region: NavigationRegion3D = $NavigationRegion3D
	if nav_region.is_baking():
		await nav_region.bake_finished
	nav_region.bake_navigation_mesh()
	Globals.map_loaded = true
	emit_signal("map_loaded")
	_map_watch_mtime = FileAccess.get_modified_time(_map_file_path())

const CasualGamemode = preload("res://sys/gamemode/casual_gamemode.gd")
var gamemode: Node = null # Null means sandbox mode

# Reads the map's gamemode_definition entity (if any) and starts the matching gamemode
func _setup_gamemode() -> void:
	if gamemode:
		gamemode.cleanup()
		# Removed right away so the new one can take the "Gamemode" name (RPCs rely on the path)
		remove_child(gamemode)
		gamemode.queue_free()
		gamemode = null

	var definition: Node = null
	for node in get_tree().get_nodes_in_group("gamemode_definition"):
		if not node.is_queued_for_deletion():
			definition = node
			break
	if definition == null:
		print("No gamemode_definition in map, running sandbox mode.")
		return

	match definition.game_type:
		1:
			gamemode = CasualGamemode.new()
			gamemode.name = "Gamemode"
			gamemode.configure(definition)
			add_child(gamemode)
			for player in get_tree().get_nodes_in_group("players"):
				if player is CharacterBody3D and not player.is_bot:
					gamemode.register_player(player)
		0:
			print("gamemode_definition game_type is 0, running sandbox mode.")
		_:
			print("Gamemode type ", definition.game_type, " is not implemented yet, running sandbox mode.")




@rpc("any_peer", "call_local")
func rebuild_map():
	hot_reload_map()



var next_bot_id: int = -1

@rpc("any_peer", "call_local", "reliable")
func add_bot(origin, use_spawn_position, weapon_range, weapon, disable_respawn, spawn_position: Vector3 = Vector3.ZERO, team: int = 0):
	# The host runs every bot, clients get them through the MultiplayerSpawner
	if not multiplayer.is_server():
		return
	print("Bot Config - Origin: ", origin, " | Use Spawn Pos: ", use_spawn_position, " | Weapon Range: ", weapon_range, " | Weapon: ", weapon, " | Disable Respawn: ", disable_respawn, " | Spawn Pos: ", spawn_position)
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
	bot_instance.team = team
	bot_instance.peer_id = bot_peer_id

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
		_send_placement(spawnplayer)
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
		_send_placement(spawnplayer)
		print("Delayed player ", spawnplayer.name, " spawned at position: ", spawnplayer.global_transform.origin)
		if spawnplayer.is_multiplayer_authority():
			spawnplayer.health_changed.connect(update_health_bar)
			spawnplayer.mana_changed.connect(update_mana_bar)
	waiting_players.clear()

# The MultiplayerSpawner only replicates spawn positions of nodes the server owns,
# so a client-owned player has to be told where the server placed it
var _pending_placements: Dictionary = {}

func _send_placement(player: Node) -> void:
	var owner_id = player.get_multiplayer_authority()
	if multiplayer.is_server() and not player.is_bot and owner_id != multiplayer.get_unique_id():
		rpc_id(owner_id, "_place_player", str(player.name), player.global_transform)

@rpc("authority", "call_remote", "reliable")
func _place_player(player_name: String, xform: Transform3D) -> void:
	var player = get_node_or_null(player_name)
	if player:
		player.global_transform = xform
		if "velocity" in player:
			player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
	else:
		_pending_placements[player_name] = xform



func spawn_player(player):
	print("Spawning player: ", player.name)
	if gamemode:
		gamemode.register_player(player)
	
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
	elif gamemode and player.team != 0:
		var spawn_point = gamemode.get_spawn_point(player)
		player.global_transform = spawn_point.global_transform if spawn_point else Transform3D.IDENTITY
		gamemode.apply_loadout(player, spawn_point)
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
	 
	if player is RigidBody3D:
		player.linear_velocity = Vector3.ZERO
		player.angular_velocity = Vector3.ZERO
	if "velocity" in player:
		player.velocity = Vector3.ZERO
	# Without this, physics interpolation keeps drawing the old spot, which is very visible
	# when the window was in the background and the next frame is a long time later
	if player.is_inside_tree():
		player.reset_physics_interpolation()
		if multiplayer.is_server() and not player.is_bot and player.get_multiplayer_authority() != multiplayer.get_unique_id() and player.has_method("lock_remote_placement"):
			player.lock_remote_placement()



func respawn_player(player):
	print("Respawning player: ", player.name)
	spawn_player(player)
	print("Player ", player.name, " respawned successfully.")

func update_health_bar(health_value):
	health_bar.value = health_value

func update_mana_bar(mana_value):
	mana_bar.value = mana_value
	

func _on_multiplayer_spawner_spawned(node):
	if _pending_placements.has(str(node.name)):
		node.global_transform = _pending_placements[str(node.name)]
		_pending_placements.erase(str(node.name))
		node.reset_physics_interpolation()
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health_bar)
		node.mana_changed.connect(update_mana_bar)

var _upnp_thread: Thread
var _hosting_publicly: bool = false

# UPnP discovery blocks for seconds (and fails on most VPNs), so it runs on a thread.
# If it fails the server keeps running for LAN / same-machine players, it just isn't listed publicly.
func upnp_setup():
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_worker)

func _upnp_worker() -> void:
	var upnp = UPNP.new()
	var discover_result = upnp.discover()
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		call_deferred("_on_upnp_finished", "", "UPnP discovery failed (error %s)" % discover_result)
		return
	var gateway = upnp.get_gateway()
	if !gateway or !gateway.is_valid_gateway():
		call_deferred("_on_upnp_finished", "", "no valid UPnP gateway found")
		return
	var map_result = upnp.add_port_mapping(PORT)
	if map_result != UPNP.UPNP_RESULT_SUCCESS:
		call_deferred("_on_upnp_finished", "", "UPnP port mapping failed (error %s)" % map_result)
		return
	call_deferred("_on_upnp_finished", upnp.query_external_address(), "")

func _on_upnp_finished(ip: String, error: String) -> void:
	if _upnp_thread == null:
		return
	_upnp_thread.wait_to_finish()
	_upnp_thread = null
	if multiplayer.multiplayer_peer != enet_peer:
		return  # Stopped hosting while UPnP was still running
	if ip == "":
		print("----------------------------")
		print("Not listed on the server browser: %s." % error)
		print("Players on this machine can join 127.0.0.1, players on your network can join one of: ", _lan_addresses())
		print("----------------------------")
		return
	external_ip = ip
	_hosting_publicly = true
	Globals.set_local_host(external_ip, PORT)
	print("----------------------------")
	print("|")
	print("Success! Join Address: %s" % external_ip)
	print("IP adress has been copied to clipboard")
	print("|")
	print("----------------------------")
	server_connection_handler.send_server_info(external_ip)
	DisplayServer.clipboard_set(external_ip)

func _lan_addresses() -> Array:
	var addresses = []
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
			addresses.append(address)
	return addresses

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
		if not _hosting_publicly:
			return
		Globals.set_local_host(external_ip, PORT)
		server_connection_handler.send_server_info(external_ip)
		print("Resending server info to master server at address:", external_ip)
	else:
		# If for some reason we lost authority, stop the timer
		if server_info_timer:
			server_info_timer.stop()

func _ready():
	_ensure_weapon_hud()
	connect("map_loaded", Callable (self, "_on_map_loaded"))
	if map_name != "":
		load_map(map_name)
	var all_children = get_all_children(tb_loader)
	for i in all_children:
		i.add_to_group("tbloader")
		if i is CollisionObject3D:
			i.set_collision_layer_value(5, true)

func _exit_tree():
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if _hosting_publicly:
		_hosting_publicly = false
		Globals.clear_local_host()

func get_all_children(in_node, arr := []):
	arr.push_back(in_node)
	for child in in_node.get_children():
		arr = get_all_children(child, arr)
	return arr

@rpc("any_peer")
func _on_peer_connected(id):
	if id != multiplayer.get_unique_id():
		rpc_id(id, "_send_map_name", map_name)
		get_tree().create_timer(PROTOCOL_CHECK_TIMEOUT).timeout.connect(_kick_if_unverified.bind(id))
	add_player(id)

@rpc("any_peer")
func _send_map_name(received_map_name: String):
	map_name = received_map_name
	load_map(map_name)
	
@rpc("any_peer", "call_local")
func _on_peer_disconnected(peer_id):
	print("_on_peer_disconnected", peer_id)
	_verified_peers.erase(peer_id)
	if gamemode:
		gamemode.unregister_player(str(peer_id))
	# The MultiplayerSpawner removes it on the other clients too
	if multiplayer.is_server():
		var player = get_node_or_null(str(peer_id))
		if player:
			player.queue_free()

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

const WEAPON_HUD = preload("res://sys/hud/weapon_hud.gd")
var _weapon_hud: Control

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


func _ensure_weapon_hud() -> void:
	if is_instance_valid(_weapon_hud):
		return
	var old_labels := get_node_or_null("CanvasLayer/HUD/VBoxContainer")
	if old_labels:
		old_labels.hide()
	_weapon_hud = WEAPON_HUD.new()
	hud.add_child(_weapon_hud)


func update_weapon_hud():
	_ensure_weapon_hud()
	var team_name := "Sandbox"
	var team_color := Color(0.08, 0.08, 0.1)
	var player := get_node_or_null(str(multiplayer.get_unique_id()))
	if player and "team" in player and int(player.team) != 0:
		var team_id := int(player.team)
		if gamemode and gamemode.has_method("_team_name"):
			team_name = gamemode._team_name(team_id)
		if Globals.TEAM_COLORS.has(team_id):
			team_color = Globals.TEAM_COLORS[team_id]
	var ammo_text := ""
	var hide_ammo := false
	if player and "weapons_manager" in player and player.weapons_manager and player.weapons_manager.current_weapon:
		hide_ammo = player.weapons_manager.current_weapon.disable_ammo
	if not hide_ammo:
		if player and "weapons_manager" in player and player.weapons_manager and player.weapons_manager.current_weapon and player.weapons_manager.current_weapon.weapon_name == "hegrenade":
			ammo_text = str(current_weapon_ammo)
		else:
			ammo_text = "%d / %d" % [current_weapon_ammo, current_weapon_reserve_ammo]
	_weapon_hud.set_info(team_name, team_color, current_weapon_name, ammo_text, weapon_stack)

@rpc("any_peer", "call_local")
func disconnect_me():
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
