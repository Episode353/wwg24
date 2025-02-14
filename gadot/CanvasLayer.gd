extends Node

# Path to your console scene
const CONSOLE_SCENE_PATH = "res://tscn/console/console.tscn"
const SETTINGS_SCENE_PATH = "res://tscn/settings/settings.tscn"
var settings_instance: Node = null
const AUDIO_CONTROLLER_PATH = "res://sys/voip/audio_controller.tscn"
var audio_controller_instance: Node = null
var console_instance: Node = null


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


	# Load the console scene
	var settings_scene = load(SETTINGS_SCENE_PATH) as PackedScene
	if settings_scene:
		# Instance the console scene
		settings_instance = settings_scene.instantiate()
		# Add it as a child to the current scene
		add_child(settings_instance)
		# Initially, set the console to be hidden
		settings_instance.visible = false

		# Load the console scene
	var audio_controller_scene = load(AUDIO_CONTROLLER_PATH) as PackedScene
	if audio_controller_scene:
		# Instance the console scene
		audio_controller_instance = audio_controller_scene.instantiate()
		# Add it as a child to the current scene
		add_child(audio_controller_instance)
