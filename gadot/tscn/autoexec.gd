extends Node

# Path to the autoexec.json file
const AUTOEXEC_PATH := "res://autoexec.json"
const AUTOEXEC_BACKUP_PATH := "res://autoexec_backup.json"

func _ready():
	backup_autoexec()
	execute_autoexec()

func execute_autoexec():
	var file = FileAccess.open(AUTOEXEC_PATH, FileAccess.READ)
	if not file:
		push_error("[Error] Unable to open autoexec.json at path: %s" % AUTOEXEC_PATH)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("[Error] Failed to parse autoexec.json: %s" % json.get_error_message())
		return
	
	var data = json.get_data()
	if data == null:
		push_error("[Error] autoexec.json contains no data.")
		return
	
	# Iterate through each category and bind the keys
	for category in data.keys():
		var bindings = data[category]
		for action in bindings.keys():
			var key = bindings[action]
			var result = bind_key(action, key)
			if result != "Success":
				push_error("[Error] Binding action '%s' to key '%s' failed: %s" % [action, key, result])
			else:
				print("[Info] Successfully bound action '%s' to key '%s'." % [action, key])

func bind_key(action: String, key: String) -> String:
	var all_actions = InputMap.get_actions()
	
	# Check if the action already exists
	if not all_actions.has(action):
		InputMap.add_action(action)
	
	# Erase any existing events for the action
	InputMap.action_erase_events(action)
	
	var key_event: InputEvent
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
				key_event.button_index = MOUSE_BUTTON_WHEEL_UP
			"mouse_scroll_down":
				key_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
			_:
				return "Invalid mouse button: %s" % key
	else:
		key_event = InputEventKey.new()
		var keycode = OS.find_keycode_from_string(key)
		#if keycode == Key.KEY_INVALID:
			#return "Invalid key string: %s" % key
		key_event.keycode = keycode
	
	InputMap.action_add_event(action, key_event)
	return "Success"
#
func backup_autoexec():
	var original_file = FileAccess.open(AUTOEXEC_PATH, FileAccess.READ)
	var backup_file = FileAccess.open(AUTOEXEC_BACKUP_PATH, FileAccess.WRITE)
	if original_file and backup_file:
		var content = original_file.get_as_text()
		backup_file.store_string(content)
		original_file.close()
		backup_file.close()
		print("[Info] autoexec.json has been backed up to autoexec_backup.json.")
	else:
		push_error("[Error] Failed to create a backup of autoexec.json.")
