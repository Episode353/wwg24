extends CanvasLayer
const CONSOLE_SCENE_PATH = "res://tscn/console/console.tscn"
var console_instance: Node = null
@onready var popup_window: Window = $Popup_window
@onready var popup_window_text: RichTextLabel = $Popup_window/Popup_window_text


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
		popup_window_text.text = "Data about your comptuer is sent to" + '\n' + "'WizardsWithGuns.com'" + '\n' + "When you host a game"
	if Globals.show_host_popup == false:
		popup_window.hide()



func _process(_delta):
	if Input.is_action_just_pressed("console"):
		toggle_console()



func toggle_console():
	if console_instance:
		console_instance.visible = not console_instance.visible
		#pause_menu.visible = console_instance.visible
		Globals.paused = console_instance.visible
	


func _on_popup_window_close_requested() -> void:
	popup_window.hide()
