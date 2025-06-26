extends Node3D

# Folder where the .tscn files reside
var entities_folder_path: String = "res://entities/"
var models_folder_path: String = "res://models/"
var sys_folder_path: String = "res://models/"
var compile_count: int = 0
# Duration (in seconds) to wait before switching scene
var switch_scene_wait_duration: float = 0.000000001
var shader_wait_duration: float = 0

# Enabling this makes shader comp take longer and shows progress
var show_progress: bool = false

func _ready() -> void:
	await load_all_scenes_from_folder(entities_folder_path)
	await load_all_scenes_from_folder(models_folder_path)
	await load_all_scenes_from_folder(sys_folder_path)
	# Now that all scenes have been loaded, wait the switch_scene_wait_duration seconds, then switch scene.
	await get_tree().create_timer(switch_scene_wait_duration).timeout
	switch_scene("res://tscn/main_menu.tscn")

# Recursively load all .tscn files in the given folder and its subfolders
func load_all_scenes_from_folder(current_path: String) -> void:
	var dir := DirAccess.open(current_path)
	if dir:
		dir.list_dir_begin()
		while true:
			var file_name: String = dir.get_next()
			if file_name == "":
				break
			if file_name == "." or file_name == "..":
				continue
			var file_path = current_path + "/" + file_name
			if dir.current_is_dir():
				# Recursively search in subfolders
				await load_all_scenes_from_folder(file_path)
			else:
				if file_name.ends_with(".tscn"):
					var scene_resource = load(file_path)
					if scene_resource:
						var instance: Node = scene_resource.instantiate()
						add_child(instance)
						print("Compiling Shaders for: ", file_path)
						$Label.text += "."
						compile_count += 1
						$"Compile Count Text".text = str(compile_count)
						if show_progress:
							await get_tree().create_timer(shader_wait_duration).timeout
					else:
						print("Failed to load scene: ", file_path)
		dir.list_dir_end()
	else:
		print("Could not open folder: ", current_path)

func switch_scene(new_scene_path: String) -> void:
	# Load and instantiate the new scene
	var new_scene_resource = load(new_scene_path)
	if new_scene_resource:
		var new_scene = new_scene_resource.instantiate()
		# Add the new scene as a sibling to the current one
		get_tree().root.add_child(new_scene)
		# Remove the current scene from the tree
		get_tree().current_scene.queue_free()
		get_tree().current_scene = new_scene
		print("Switched to scene: ", new_scene_path)
	else:
		print("Failed to load scene for switching: ", new_scene_path)
