# load_map_entity.gd
extends Node

@export var load_map: String = ""

func set_load_map(value: String) -> void:
	load_map = value
	if is_inside_tree():
		_update_label()

func _ready() -> void:
	call_deferred("_update_label")

func _update_label() -> void:
	$Label3D.text = "Load Map: " + load_map

func _on_area_3d_body_entered(body):
	if !is_multiplayer_authority():
		return
	if !body.is_in_group("players"):
		print("Cannot load map, entered body is not a player")
		return
	if load_map != "":
		world_load_map(load_map)
		# Call your map-loading code here.
	else:
		print("Map Not Found")
		
func world_load_map(send_map_name):
	var world = get_tree().get_root().get_node("World")
	world.change_level(send_map_name)
	
