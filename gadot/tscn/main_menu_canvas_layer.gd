extends CanvasLayer
const CONSOLE_SCENE_PATH = "res://tscn/console/console.tscn"
const SETTINGS_SCENE_PATH = "res://tscn/settings/settings.tscn"
var console_instance: Node = null
var settings_instance: Node = null
@onready var popup_window: Window = $Popup_window
@onready var popup_window_text: RichTextLabel = $Popup_window/Popup_window_text
var settings_visibility = false

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
	if Globals.show_host_popup == true:
		popup_window.show()
		popup_window_text.text = "FYI," + '\n' + "Hosting a server with the 'Host' Button will share your IP address with other clients, and 'WizardsWithGuns.com'" + '\n' + "If you are not okay with this you can select 'Offline'"
	if Globals.show_host_popup == false:
		popup_window.hide()


	# Load the console scene
	var settings_scene = load(SETTINGS_SCENE_PATH) as PackedScene
	if settings_scene:
		# Instance the console scene
		settings_instance = settings_scene.instantiate()
		# Add it as a child to the current scene
		add_child(settings_instance)
		# Initially, set the console to be hidden
		settings_instance.visible = false




	


func _on_popup_window_close_requested() -> void:
	popup_window.hide()


func _on_button_pressed():
	Globals.exec("show_host_popup = false")
	popup_window.hide()
