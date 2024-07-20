extends Node

@onready var main_menu: Control = $CanvasLayer/MainMenu
@onready var address_entry: LineEdit = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var hud: Control = $CanvasLayer/HUD
@onready var health_bar: ProgressBar = $CanvasLayer/HUD/HealthBar
@onready var mana_bar: ProgressBar = $CanvasLayer/HUD/ManaBar
@onready var username_entry: LineEdit = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/UsernameEntry
@onready var tb_loader: Node = $TBLoader
@onready var pause_menu: Control = $"CanvasLayer/Pause Menu"

const PORT: int = 7777
var enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var map_name: String = ""

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
	if Input.is_action_just_pressed("main_menu"):
		toggle_pause_menu()

func toggle_pause_menu() -> void:
	pause_menu.visible = not pause_menu.visible
	
	if pause_menu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

@rpc("any_peer")
func kick_players() -> void:
	var peers: Array = multiplayer.get_peers()
	for peer_id: int in peers:
		rpc("remove_player", int(peer_id))

@rpc("any_peer", "call_local")
func remove_player(peer_id: int) -> void:
	var player: Node = get_node_or_null(str(peer_id))
	rpc("_on_peer_disconnected", peer_id)
	if player:
		player.queue_free()
		print("Removed player: ", peer_id)
	else:
		print("Player not found: ", peer_id)

func send_to_main_menu() -> void:
	var current_scene: Node = get_tree().current_scene
	var new_scene: Node = load("res://tscn/main_menu.tscn").instantiate()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	current_scene.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Input.is_action_just_pressed("fullscreen"):
		swap_fullscreen_mode()
	if Input.is_action_just_pressed("respawn"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().reload_current_scene()

func swap_fullscreen_mode() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func start_offline(map: String) -> void:
	map_name = map
	hud.show()
	load_map(map_name)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(Callable(self, "_on_peer_disconnected"))
	add_player(multiplayer.get_unique_id())

func start_host(map: String) -> void:
	map_name = map
	hud.show()
	load_map(map_name)
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(Callable(self, "_on_peer_connected"))
	multiplayer.peer_disconnected.connect(Callable(self, "_on_peer_disconnected"))
	add_player(multiplayer.get_unique_id())
	upnp_setup()

func start_join(address: String) -> void:
	hud.show()
	enet_peer.create_client(address, PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.connect("network_peer_connected", Callable(self, "_on_peer_connected"))
	multiplayer.connect("network_peer_disconnected", Callable(self, "_on_peer_disconnected"))
	multiplayer.connect("server_disconnected", Callable(self, "_on_server_disconnected"))
	print("Connected server_disconnected signal")
	add_player(multiplayer.get_unique_id())

func load_map(map_name: String) -> void:
	tb_loader.map_resource = "tbmaps/" + map_name
	tb_loader.build_meshes()
	print(tb_loader.map_resource)

func add_player(peer_id: int) -> void:
	var Player: PackedScene = preload("res://player.tscn")
	var spawnplayer: Node = Player.instantiate()
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

func spawn_player(player: Node) -> void:
	print("Spawning player: ", player.name)
	var spawn_points: Array = get_tree().get_nodes_in_group("info_player_start")
	print("Found ", spawn_points.size(), " spawn points in group 'info_player_start'")
	if spawn_points.size() == 0:
		print("No spawn points found in the group 'info_player_start'. Using default spawn position.")
		player.global_transform.origin = Vector3(0, 0, 0)
	else:
		var chosen_spawn_point: Node = spawn_points[randi() % spawn_points.size()]
		var start_position: Vector3 = chosen_spawn_point.global_transform.origin
		print("Chosen spawn point: ", chosen_spawn_point.name, " at position: ", start_position)
		player.global_transform.origin = start_position
	print("Player ", player.name, " spawned at position: ", player.global_transform.origin)

func respawn_player(player: Node) -> void:
	print("Respawning player: ", player.name)
	spawn_player(player)
	print("Player ", player.name, " respawned successfully.")

func update_health_bar(health_value: int) -> void:
	health_bar.value = health_value

func update_mana_bar(mana_value: int) -> void:
	mana_bar.value = mana_value

func _on_multiplayer_spawner_spawned(node: Node) -> void:
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health_bar)
		node.mana_changed.connect(update_mana_bar)

func upnp_setup() -> void:
	var upnp: UPNP = UPNP.new()
	var discover_result: int = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP Discover Failed! Error %s" % discover_result)
	var gateway: UPNPDevice = upnp.get_gateway()
	print("Gateway: %s" % gateway)
	assert(gateway and gateway.is_valid_gateway(), "UPNP Invalid Gateway!")
	var map_result: int = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP Port Mapping Failed! Error %s" % map_result)
	print("Success! Join Address: %s" % upnp.query_external_address())

func _ready() -> void:
	if map_name != "":
		load_map(map_name)
	var all_children: Array = get_all_children(tb_loader)
	for i: Node in all_children:
		i.add_to_group("tbloader")
		if i is CollisionObject3D:
			i.set_collision_layer_value(5, true)

func get_all_children(in_node: Node, arr: Array = []) -> Array:
	arr.push_back(in_node)
	for child in in_node.get_children():
		arr = get_all_children(child as Node, arr)
	return arr

@rpc("any_peer")
func _on_peer_connected(id: int) -> void:
	if id != multiplayer.get_unique_id():
		rpc_id(id, "_send_map_name", map_name)
	add_player(id)

@rpc("any_peer")
func _send_map_name(received_map_name: String) -> void:
	map_name = received_map_name
	load_map(map_name)

@rpc("any_peer", "call_local")
func _on_peer_disconnected(peer_id: int) -> void:
	print("_on_peer_disconnected", peer_id)

@rpc("any_peer", "call_remote")
func _on_server_disconnected() -> void:
	print("Server disconnected")
	send_to_main_menu()

func _on_button_pressed() -> void:
	if is_multiplayer_authority():
		rpc("_on_server_disconnected")
		rpc("kick_players")
		send_to_main_menu()
