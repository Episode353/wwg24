class_name Console
extends CanvasLayer

signal console_loaded  # Define a custom signal

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
		$VBoxContainer/output.text = ""
		return "Console cleared.",
		"args": 0},
	"quit": {"func": func() -> String:
		return quit_function(),
		"args": 0},
	"bind": {"func": func(action, key):
		return bind_key(action, key),
		"args": 2}
}

func _ready():
	$VBoxContainer/input.text_submitted.connect(self._on_text_submitted)
	$VBoxContainer/input.connect("gui_input", self._on_input_gui)

	# Emit the signal when the console is ready
	emit_signal("console_loaded")

	# Example usage of the config file execution
	execute_config_file("res://config.txt")

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
	else:
		_output_error("Unknown command: %s" % cmd)
	
	# Clear the input field
	$VBoxContainer/input.text = ""

func _output_command(command, result):
	$VBoxContainer/output.text += "> " + command + "\n"
	$VBoxContainer/output.text += str(result) + "\n"

func _output_error(error_text):
	$VBoxContainer/output.text += "[Error] " + error_text + "\n"

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
		$VBoxContainer/input.text = command_history[history_index]
		$VBoxContainer/input.caret_column = $VBoxContainer/input.text.length()
	else:
		$VBoxContainer/input.text = ""

# Custom function to be run by the command
func quit_function() -> String:
	# Perform some custom logic here
	get_tree().quit()
	return "Quitting"

# Function to dynamically return all available commands
func get_available_commands() -> String:
	var command_list = ""
	for cmd in commands.keys():
		command_list += "- " + cmd + ", "
	command_list += "\n"
	return command_list

func bind_key(action: String, key: String) -> String:
	var all_actions = InputMap.get_actions()
	var key_event
	
	# Check if the action already exists
	if not action in all_actions:
		InputMap.add_action(action)

	# Clear all events from the action
	InputMap.action_erase_events(action)

	if key.begins_with("mouse"):
		key_event = InputEventMouseButton.new()
		match key:
			"mouse1":
				key_event.button_index = MOUSE_BUTTON_LEFT
			"mouse2":
				key_event.button_index = MOUSE_BUTTON_RIGHT
			"mouse3":
				key_event.button_index = MOUSE_BUTTON_MIDDLE
			"mouse_scroll_up":
				key_event.button_index = 4 # MOUSE_BUTTON_WHEEL_UP
			"mouse_scroll_down":
				key_event.button_index = 5 # MOUSE_BUTTON_WHEEL_DOWN
			_:
				return "Error: '%s' is not a valid mouse button." % key
	else:
		key_event = InputEventKey.new()
		key_event.keycode = OS.find_keycode_from_string(key)
	
	InputMap.action_add_event(action, key_event)
	return "Bound %s to %s" % [action, key]


# Function to handle variable assignment
func _handle_variable_assignment(command: String):
	var tokens = command.split("=")
	if tokens.size() == 2:
		var variable_name = tokens[0].strip_edges()
		var value = tokens[1].strip_edges()
		
		if variable_name == "max_fps":
			Engine.max_fps = int(value)
			print(command, "Set Engine.max_fps to %d" % Engine.max_fps)
		
		elif variable_name == "camera_fov":
			Globals.camera_fov = float(value)
			print(command, "Set camera_fov to %f" % Globals.camera_fov)
			
		elif variable_name == "mouse_sensitivity":
			Globals.mouse_sensitivity = float(value)
			print(command, "Set mouse_sensitivity to %f" % Globals.mouse_sensitivity)
			
		elif variable_name == "username":
			Globals.username = str(value)
			print(command, "Set username to %s" % Globals.username)

		elif variable_name == "master_volume":
			Globals.master_volume = float(value)
			
			# Map the value from 0-1 to -40 to +6 dB
			var min_db = -40
			var max_db = 6
			var db_value = min_db + (Globals.master_volume * (max_db - min_db))
			
			# Set the audio bus volume
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db_value)
			
			print("%s Set master_volume to %f dB (%f scaled)" % [command, db_value, Globals.master_volume])


		# Handle other global variables if needed
		else:
			_output_error("Invalid variable assignment: %s" % variable_name)
	else:
		_output_error("Invalid assignment format.")


# Function to execute each command in the config file
func execute_config_file(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		while not file.eof_reached():
			var line = file.get_line().strip_edges()
			# Ignore lines starting with a hashtag (#)
			if line != "" and line[0] != "#":
				_on_text_submitted(line)
		file.close()
	else:
		_output_error("Error: Unable to open config file: %s" % file_path)
