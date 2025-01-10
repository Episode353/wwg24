extends Node

# Path to your console scene
const CONSOLE_SCENE_PATH = "res://tscn/console/console.tscn"

var console_instance: Node = null
var pause_menu_visibility = false
@onready var pause_menu = $"Pause Menu"

func _unhandled_input(_event):
	if Input.is_action_just_pressed("main_menu"):
		toggle_pause_menu()

func toggle_pause_menu():
	pause_menu_visibility = not pause_menu_visibility
	print("Pause Menu is ", pause_menu_visibility)
	# Toggle visibility of the pause menu
	pause_menu.visible = pause_menu_visibility

	# Toggle visibility of the console
	if console_instance:
		console_instance.visible = pause_menu_visibility

	# Set the mouse mode based on the visibility of the pause menu
	if pause_menu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _ready():
	# Load the console scene
	var console_scene = load(CONSOLE_SCENE_PATH) as PackedScene
	if console_scene:
		# Instance the console scene
		console_instance = console_scene.instantiate()
		# Add it as a child to the current scene
		add_child(console_instance)
		# Initially, set the console to be hidden
		console_instance.visible = false

func _process(_delta):
	if Input.is_action_just_pressed("console"):
		toggle_console()

func toggle_console():
	if console_instance:
		# Show the console and the pause menu
		console_instance.visible = not console_instance.visible
		pause_menu.visible = console_instance.visible
	Globals.paused = console_instance.visible
	print(Globals.paused)
		
	# Set the mouse mode based on the visibility of the console
	if console_instance.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
