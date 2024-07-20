extends Node2D

@onready var map_entry: ItemList = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/MapEntry
@onready var address_entry: LineEdit = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
var selected_map_name: String = ""

func _ready() -> void:
	# Populate map_entry with .map files from the res://tbmaps folder
	var dir: DirAccess = DirAccess.open("res://tbmaps")
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
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

func _on_host_button_pressed() -> void:
	switch_scene_and_run_func("res://world.tscn", "start_host", "", selected_map_name)

func _on_join_button_pressed() -> void:
	var address: String = address_entry.text
	switch_scene_and_run_func("res://world.tscn", "start_join", address)

func _on_offline_button_pressed() -> void:
	switch_scene_and_run_func("res://world.tscn", "start_offline", "", selected_map_name)

func switch_scene_and_run_func(scene_path: String, func_name: String, param: String = "", map_name: String = "") -> void:
	var new_scene: Node = load(scene_path).instantiate() as Node
	get_tree().current_scene.get_parent().add_child(new_scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = new_scene
	
	if func_name == "start_join":
		new_scene.call_deferred(func_name, param)
	else:
		new_scene.call_deferred(func_name, map_name)

func _on_map_entry_item_selected(index: int) -> void:
	selected_map_name = map_entry.get_item_text(index)
	print("Selected map: ", selected_map_name)
