extends Node2D
@onready var tb_loader = $"../TBLoader"

@onready var map_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/MapEntry
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
var selected_map_name = ""
@onready var menu_music = $"../Menu_music"



func _ready():
	if Globals.network_error != "":
		var dialog = AcceptDialog.new()
		dialog.title = "Connection problem"
		dialog.dialog_text = Globals.network_error
		Globals.network_error = ""
		add_child(dialog)
		dialog.popup_centered()

	# Populate map_entry with .map files from the res://tbmaps folder
	var dir = DirAccess.open("tbmaps")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".map"):
				map_entry.add_item(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	if map_entry.get_item_count() > 0:
		map_entry.select(0)
		selected_map_name = map_entry.get_item_text(0)
		print("Selected map: ", selected_map_name)
	else:
		print("No maps found in tbmaps")

	# Only consume the launch map once so returning to the menu doesn't relaunch it
	if Globals.launch_map != "":
		var launch_map = Globals.launch_map
		Globals.launch_map = ""
		if FileAccess.file_exists("tbmaps/" + launch_map):
			print("Launching straight into offline map: ", launch_map)
			selected_map_name = launch_map
			# Scripts look the world up by the name "World", so the old one must be gone before
			# the new one is added, otherwise the new one gets auto-renamed
			var old_world = get_tree().root.get_node_or_null("World")
			if old_world:
				await old_world.tree_exited
			# Deferred so the scene switch that created this menu has finished
			call_deferred("_on_offline_button_pressed")
			return
		push_error("Launch map not found: tbmaps/" + launch_map)

	load_map()

func _process(_delta):
	if menu_music.playing == false:
		menu_music.play()
		print("Track ended, Looping Track")

		
func _on_host_button_pressed():
	switch_scene_and_run_func("res://world.tscn", "start_host", "", selected_map_name)

func _on_join_button_pressed():
	var address = address_entry.text
	switch_scene_and_run_func("res://world.tscn", "start_join", address)

func _on_offline_button_pressed():
	switch_scene_and_run_func("res://world.tscn", "start_offline", "", selected_map_name)

func switch_scene_and_run_func(scene_path: String, func_name: String, param: String = "", map_name: String = ""):
	var new_scene = load(scene_path).instantiate()
	get_tree().current_scene.get_parent().add_child(new_scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = new_scene
	
	if func_name == "start_join":
		new_scene.call_deferred(func_name, param)
	else:
		new_scene.call_deferred(func_name, map_name)

func _on_map_entry_item_selected(index):
	selected_map_name = map_entry.get_item_text(index)

func load_map():
	tb_loader.build_meshes()
	print(tb_loader.map_resource)
