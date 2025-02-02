# Globals.gd
extends Node

# Server Information
const PORT_UDP_COMM: int = 7777
const IP_SERVER_BROWSER: String = "www.wizardswithguns.com"

var camera_fov = 85
var max_fps = 60  # Default FPS limit
var mouse_sensitivity = 0.1
var master_volume = -4
var paused = false
var username = null
var show_host_popup = true
var fullscreen = false
var self_harm = true # If True, players can harm themselves

func _unhandled_input(_event):
	if Input.is_action_just_pressed("fullscreen"):
		exec("fullscreen = " + str(!fullscreen))
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
