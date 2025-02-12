extends Window

signal console_loaded
@onready var console_window = $"."

@onready var output: RichTextLabel = $VBoxContainer/output
@onready var input: LineEdit = $VBoxContainer/input

var expression = Expression.new()
var command_history = []
var history_index = -1
var commands = {
	"help": {"func": func() -> String:
		return get_available_commands(),
		"args": 0},
	"greet": {"func": func(greet_name: String) -> String:
		return "Hello, %s!" % greet_name,
		"args": 1},
	"add": {"func": func(a: float, b: float) -> float:
		return a + b,
		"args": 2},
	"clear": {"func": func() -> String:
		output.text = ""
		return "Console cleared.",
		"args": 0},
	"quit": {"func": func() -> String:
		return quit_function(),
		"args": 0},
	"add_bot": {"func": func() -> String:
		var world = get_tree().get_root().get_node("World")
		var players = get_tree().get_nodes_in_group("players")
		var player = players[0]
		if world:
			world.rpc("add_bot", "0 0 0", true, "100", "ak47", false, Vector3.ZERO)
			return "Bot added successfully."
		else:
			return "Error: 'World' node not found."
		, "args": 0},
	"add_enemy": {"func": func() -> String:
		var players = get_tree().get_nodes_in_group("players")
		if players.size() == 0:
			return "Error: No player found."
		var player = players[0]
		var enemy_scene = load("res://sys/enemies/enemy.tscn")
		if enemy_scene == null:
			return "Error: Could not load enemy scene."
		var enemy = enemy_scene.instantiate()
		enemy.global_position = player.global_position
		var world = get_tree().get_root().get_node("World")
		if world:
			world.add_child(enemy)
			return "Enemy added successfully."
		else:
			return "Error: 'World' node not found."
		, "args": 0},
	"spawn_ball": {"func": func() -> String:
		var world = get_tree().get_root().get_node("World")
		var players = get_tree().get_nodes_in_group("players")
		var player = players[0]
		if world:
			world.rpc("spawn_ball", player.global_transform)
			return "Ball spawned successfully."
		else:
			return "Error: 'World' node not found."
		, "args": 0},
	"spawn_box": {"func": func() -> String:
		var world = get_tree().get_root().get_node("World")
		var players = get_tree().get_nodes_in_group("players")
		var player = players[0]
		if world:
			world.rpc("spawn_box", player.global_transform)
			return "Box spawned successfully."
		else:
			return "Error: 'World' node not found."
		, "args": 0},
	"all_weapons": {"func": func() -> String:
		var players = get_tree().get_nodes_in_group("players")
		if players.size() == 0:
			return "Error: No player found."
		var player = players[0]
		if player.has_node("Weapons_Manager"):
			var wm = player.get_node_or_null("Weapons_Manager")
			wm.rpc("add_all_weapons")
			return "All weapons granted."
		else:
			return "Error: Weapons Manager not found on the player."
		, "args": 0},
}






func _process(delta):
	if Input.is_action_just_pressed("console"):
		toggle_console()

func toggle_console():
	visible = not visible
	print("Console is now ", visible)

	# Update the global paused state
	Globals.paused = visible

	# Manage mouse mode based on console visibility
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Optionally, grab focus to the input field
		input.grab_focus()
	else:
		# Release focus from the input field
		input.release_focus()
		if get_tree().get_nodes_in_group("players").size() > 0:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED





var config_path = "config.json"
var config_data = {}

func _ready():
	input.text_submitted.connect(self._on_text_submitted)
	input.connect("gui_input", self._on_input_gui)
	
	# Load configuration
	load_config()
	
	# Emit the signal when the console is ready
	emit_signal("console_loaded")

func load_config():
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		if parse_result != OK:
			_output_error("Error parsing config.json: %s" % json.get_error_message())
		else:
			config_data = json.get_data()
			apply_config()
		file.close()
	else:
		_output_error("Error: Unable to open config file: %s" % config_path)

func save_config():
	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if file:
		var json = JSON.new()
		var json_string = json.stringify(config_data, "\t")
		if json_string == "":
			_output_error("Error stringifying config data.")
			return
		file.store_string(json_string)
		file.close()
	else:
		_output_error("Error: Unable to write to config file: %s" % config_path)

func apply_config():
	if "max_fps" in config_data:
		Engine.max_fps = int(config_data["max_fps"])
	
	if "camera_fov" in config_data:
		Globals.camera_fov = float(config_data["camera_fov"])
	
	if "mouse_sensitivity" in config_data:
		Globals.mouse_sensitivity = float(config_data["mouse_sensitivity"])
	
	if "username" in config_data:
		Globals.username = str(config_data["username"])
	
	if "show_host_popup" in config_data:
		Globals.show_host_popup = bool(config_data["show_host_popup"])
		
	if "master_volume" in config_data:
		Globals.master_volume = float(config_data["master_volume"])
		set_master_volume(Globals.master_volume)

	if "fullscreen" in config_data:
		Globals.fullscreen = bool(config_data["fullscreen"])
		if Globals.fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
# Function to handle variable assignment and update config.json
func _handle_variable_assignment(command: String):
	var tokens = command.split("=")
	if tokens.size() == 2:
		var variable_name = tokens[0].strip_edges()
		var value_str = tokens[1].strip_edges()
		var value

		# Determine the type based on existing config or define types here
		match variable_name:
			"max_fps":
				if not is_valid_int(value_str):
					_output_error("Invalid value for max_fps. It must be an integer.")
					return
				value = int(value_str)
				Engine.max_fps = value
			"camera_fov":
				if not is_valid_float(value_str):
					_output_error("Invalid value for camera_fov. It must be a float.")
					return
				value = float(value_str)
				Globals.camera_fov = value
			"mouse_sensitivity":
				if not is_valid_float(value_str):
					_output_error("Invalid value for mouse_sensitivity. It must be a float.")
					return
				value = float(value_str)
				Globals.mouse_sensitivity = value
			"username":
				value = value_str
				Globals.username = value
			"show_host_popup":
				if value_str.to_lower() not in ["true", "false"]:
					_output_error("Invalid value for show_host_popup. It must be 'true' or 'false'.")
					return
				value = value_str.to_lower() == "true"
				Globals.show_host_popup = value
			"master_volume":
				if not is_valid_float(value_str):
					_output_error("Invalid value for master_volume. It must be a float between 0 and 1.")
					return
				value = float(value_str)
				if value < 0.0 or value > 1.0:
					_output_error("master_volume must be between 0 and 1.")
					return
				Globals.master_volume = value
				set_master_volume(value)
			"fullscreen":
				if value_str.to_lower() not in ["true", "false"]:
					_output_error("Invalid value for fullscreen. It must be 'true' or 'false'.")
					return
				value = value_str.to_lower() == "true"
				if value:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				else:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			_:
				_output_error("Invalid variable assignment: %s" % variable_name)
				return
		
		# Update the config data and save
		config_data[variable_name] = value
		save_config()
		
		_output_command(command, "set %s to %s." % [variable_name, str(value)])
	else:
		_output_error("Invalid assignment format. Use 'variable = value'.")


func set_master_volume(volume: float):
	var min_db = -40
	var max_db = 6
	var db_value = min_db + (volume * (max_db - min_db))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db_value)

func _on_text_submitted(command):
	command = command.strip_edges()
	if command == "":
		return
	
	command_history.append(command)
	history_index = len(command_history)
	
	var tokens = command.split(" ")
	var cmd = tokens[0].to_lower()
	var args = tokens.slice(1, tokens.size())
	
	if commands.has(cmd):
		var command_info = commands[cmd]
		var func_ref = command_info["func"]
		var expected_arg_count = command_info["args"]

		if args.size() == expected_arg_count:
			var result = func_ref.callv(args)
			_output_command(command, result)
		else:
			_output_error("Error: '%s' command requires %d arguments." % [cmd, expected_arg_count])
	elif "=" in command:  # Detecting variable assignment
		_handle_variable_assignment(command)
	elif config_data.has(command):  # If it's a variable name, return its value
		var value = config_data[command]
		_output_command(command, "%s = %s" % [command, str(value)])
	else:
		_output_error("Unknown command or variable: %s" % cmd)
	
	# Clear the input field
	input.text = ""


func _output_command(command, result):
	output.text += "> " + command + "\n"
	output.text += str(result) + "\n"

func _output_error(error_text):
	output.text += "[Error] " + error_text + "\n"

func _on_input_gui(event):
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_UP:
				_navigate_history(-1)
			elif event.keycode == KEY_DOWN:
				_navigate_history(1)

func _navigate_history(direction):
	history_index += direction
	history_index = clamp(history_index, 0, len(command_history))
	if history_index < len(command_history) and history_index >= 0:
		input.text = command_history[history_index]
		input.caret_column = input.text.length()
	else:
		input.text = ""

# Custom function to be run by the command
func quit_function() -> String:
	get_tree().quit()
	return "Quitting"

# Function to dynamically return all available commands
func get_available_commands() -> String:
	var command_list = ""
	for cmd in commands.keys():
		command_list += "- " + cmd + ", "
	command_list += "\n"
	return command_list



func is_valid_int(value: String) -> bool:
	return value.is_valid_int()

func is_valid_float(value: String) -> bool:
	return value.is_valid_float()

# Removed execute_config_file as it's handled in load_config()

func _on_visibility_changed() -> void:
	if self.visible:
		input.grab_focus()
	else:
		input.release_focus()

func _on_close_requested() -> void:
	self.hide()
