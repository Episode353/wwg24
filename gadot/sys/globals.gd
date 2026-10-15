# Globals.gd
extends Node

# Server Information
const PORT_UDP_COMM: int = 7777
# Bump whenever networking changes; hosts and clients on different values refuse each other
# instead of connecting and silently desyncing (e.g. players frozen at spawn)
const NET_PROTOCOL: int = 5
const IP_SERVER_BROWSER: String = "www.wizardswithguns.com"

# Team colours, keyed by team number (1 = Wizards / Team A, 2 = Humans / Team B)
const TEAM_COLORS: Dictionary = {
	1: Color(0.422, 0.119, 0.668, 1.0), # Wizards: purple
	2: Color(0.596, 0.464, 0.176, 1.0), # Humans: skin tone
}


var camera_fov = 85
var max_fps = 60  # Default FPS limit
var mouse_sensitivity = 0.1
var master_volume = -4
var paused = false
var username = null
var show_host_popup = true
var fullscreen = false
var self_harm = true # If True, players can harm themselves
var bots_fight = true # If True, players can harm themselves
var map_loaded = false
var graphics_options: int = 2  # 0 = VERY_LOW, 1 = LOW, 2 = MEDIUM, 3 = HIGH
var show_bot_path = true # Do we shoe the debug paths of bots?
var hot_reload_map = true # If True, the current map rebuilds in place whenever its .map file is saved (editor builds only)
var launch_map = "" # Set by WWG_LAUNCH_MAP (TrenchBroom); main menu boots straight into it offline
var network_error = "" # Why the last host/join attempt failed; the main menu shows it once and clears it

# Lets other game instances on this machine know which public address we're hosting on
const LOCAL_HOST_FILE = "user://local_host.json"
const LOCAL_HOST_STALE_SECONDS = 20.0 # The host refreshes the file every few seconds while it's running

func set_local_host(ip: String, port: int) -> void:
	var file = FileAccess.open(LOCAL_HOST_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"ip": ip, "port": port, "time": Time.get_unix_time_from_system()}))

func clear_local_host() -> void:
	if FileAccess.file_exists(LOCAL_HOST_FILE):
		DirAccess.remove_absolute(LOCAL_HOST_FILE)

# True while a map change is tearing the current World down and opening a new one.
# A second change_level in that window must not start another copy.
var _session_relaunching := false

# Closes the current match and opens a brand new World: host, join, or offline.
# The old World has to leave the tree first. Scripts find it by the name "World",
# and a second copy would be renamed, so the new one is added only after tree_exited.
func relaunch_session(mode: String, arg: String, migration: bool = false) -> void:
	if _session_relaunching:
		return
	_session_relaunching = true
	var world = get_tree().root.get_node_or_null("World")
	if is_instance_valid(world):
		if world.has_method("_close_network"):
			world._close_network()
		world.queue_free()
		await world.tree_exited
	var new_world = load("res://world.tscn").instantiate()
	if migration and mode == "host":
		new_world._host_is_migration = true
	if migration and mode == "join":
		new_world._join_is_migration = true
	get_tree().root.add_child(new_world)
	get_tree().current_scene = new_world
	match mode:
		"host":
			new_world.call_deferred("start_host", arg)
		"join":
			new_world.call_deferred("start_join", arg)
		_:
			new_world.call_deferred("start_offline", arg)
	_session_relaunching = false

func is_hosted_locally(ip: String, port: int) -> bool:
	if not FileAccess.file_exists(LOCAL_HOST_FILE):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(LOCAL_HOST_FILE))
	if not data is Dictionary:
		return false
	if str(data.get("ip", "")) != ip or int(data.get("port", 0)) != port:
		return false
	return Time.get_unix_time_from_system() - float(data.get("time", 0)) < LOCAL_HOST_STALE_SECONDS

func _ready():
	# Only the TrenchBroom launch sets this. A "--map=" run argument used to do it too, and an old
	# copy of that argument stuck in the editor kept skipping the main menu on every Play.
	launch_map = OS.get_environment("WWG_LAUNCH_MAP")
	if launch_map != "":
		launch_map = launch_map.get_file()
		if not launch_map.ends_with(".map"):
			launch_map += ".map"

# The server runs on the same loop that draws this window. While the window is in the
# background, the graphics driver can sit inside the present call until Windows composites
# that window again, and Godot also sleeps the loop when the window is minimized. Either
# way the host stops sending bot and player updates. Checked every frame because the
# focus signal does not fire for an embedded editor game view.
var _sim_unfocused := false
var _saved_update_mode := -1
# The shader warmup waits on drawn frames, so it would stall until the window got focus again.
var warmup_running := false

func _process(_delta: float) -> void:
	var minimized := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED
	var background := (not DisplayServer.window_is_focused() or minimized) and not warmup_running
	if background == _sim_unfocused:
		return
	_sim_unfocused = background
	var rid := get_tree().root.get_viewport_rid()
	if background:
		_saved_update_mode = RenderingServer.viewport_get_update_mode(rid)
		RenderingServer.render_loop_enabled = false
		RenderingServer.viewport_set_update_mode(rid, RenderingServer.VIEWPORT_UPDATE_DISABLED)
		OS.low_processor_usage_mode = false
		# Rendering is off, so cap the loop. Uncapped it spins a core at well over 100k FPS.
		Engine.max_fps = 60
		print("Window in the background: server keeps simulating, drawing is paused.")
	else:
		RenderingServer.render_loop_enabled = true
		if _saved_update_mode >= 0:
			RenderingServer.viewport_set_update_mode(rid, _saved_update_mode)
		Engine.max_fps = int(max_fps) if max_fps > 0 else 0

func _unhandled_input(_event):
	if Input.is_action_just_pressed("fullscreen"):
		var mode = DisplayServer.window_get_mode()
		var is_fullscreen = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		exec("fullscreen = " + str(!is_fullscreen))
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
		
const CONSOLE_SCENE_PATH = "res://tscn/console/console.tscn"
var console_instance: Node = null
func exec(command: String):
	var console_scene = load(CONSOLE_SCENE_PATH) as PackedScene
	if console_scene:
		# Instance the console scene
		console_instance = console_scene.instantiate()
		# Add it as a child to the current scene
		add_child(console_instance)
		# Initially, set the console to be hidden
		console_instance.visible = false
		console_instance._handle_variable_assignment(command)
		# Remove the console after the command is processed to save on memmory
		console_instance.queue_free()
