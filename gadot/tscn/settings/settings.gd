extends Window
const CONSOLE_SCENE_PATH = "res://tscn/console/console.tscn"
var console_instance: Node = null

var pause_menu_visibility = false
@onready var pause_menu = $".."
@onready var world = get_tree().get_root().get_node("World")
@onready var volume_label = $"MarginContainer/VBoxContainer/Volume Label"
@onready var volume_slider = $"MarginContainer/VBoxContainer/Volume Slider"
@onready var max_fps_label = $"MarginContainer/VBoxContainer/Max Fps Label"
@onready var max_fps_slider = $"MarginContainer/VBoxContainer/Max Fps Slider"
@onready var mouse_sensitivity_label = $"MarginContainer/VBoxContainer/Mouse Sensitivity Label"
@onready var mouse_sensitivity_slider = $"MarginContainer/VBoxContainer/Mouse Sensitivity Slider"
@onready var disconnect_button = $"MarginContainer/VBoxContainer/Disconnect Button"

func _ready():
	call_deferred("initalize_settings_values")


func initalize_settings_values():
	set_process_input(true)
	set_process_unhandled_input(true)

	if world:
		disconnect_button.show()
	else:
		disconnect_button.hide()
	volume_label.text = "Volume = " + str(Globals.master_volume)
	volume_slider.value = Globals.master_volume
	
	max_fps_label.text = "Max FPS = " + str(Globals.max_fps)
	max_fps_slider.value = Globals.max_fps
	
	mouse_sensitivity_label.text = "Mouse Sensitivity = " + str(Globals.mouse_sensitivity)
	mouse_sensitivity_slider.value = Globals.mouse_sensitivity 


func _on_mouse_sensitivity_slider_value_changed(value):
	Globals.exec("mouse_sensitivity = " +  str(value))
	print("mouse_sensitivity = " +  str(value))
	mouse_sensitivity_label.text = "Mouse Sensitivity = " + str(value)

func _on_max_fps_slider_value_changed(value):
	var int_value = int(value)  # Convert the slider value to an integer
	Globals.exec("max_fps = " + str(int_value))
	print("max_fps = " + str(int_value))
	max_fps_label.text = "Max FPS = " + str(int_value)

func _process(delta):
	# Use is_action_just_pressed to ensure a single press toggles the menu.
	if Input.is_action_just_pressed("main_menu"):
		toggle_pause_menu()


func toggle_pause_menu():
	visible = not visible
	print("Settings is now ", visible)

	# Update the global paused state
	Globals.paused = visible
	
	if world:
		# Set the mouse mode based on the visibility of the pause menu
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_disconnect_button_pressed():
	if is_multiplayer_authority():
		world.rpc("_on_server_disconnected")
	world.rpc("kick_players")
	world.send_to_main_menu()


func _on_volume_slider_value_changed(value):
	Globals.exec("master_volume = " +  str(value))
	print("master_volume = " +  str(value))
	volume_label.text = "Volume = " + str(value)


func _on_close_requested():
	toggle_pause_menu()
