# load_map_entity.gd
extends Node

@export var load_map: String = ""
@export var size: String = ""
@onready var csg_box_3d = $CSGBox3D
@onready var collision_shape_3d = $Area3D/CollisionShape3D


func _update_teleport_size():
	# Only update if teleport_size is provided.
	if size.strip_edges() == "":
		return

	# Split the string into its components.
	var parts = size.split(" ")
	if parts.size() != 3:
		push_error("Map Change Size must contain three numbers separated by spaces. Given: " + size)
		return

	# Convert each part to a float.
	var x_size = parts[0].to_float()
	var y_size = parts[1].to_float()
	var z_size = parts[2].to_float()

		
	# Update the visual CSGBox3D size.
	csg_box_3d.size = Vector3(x_size, y_size, z_size)

	# Update the collision shape.
	# Assumes the CollisionShape3D node uses a BoxShape3D resource.

	# Divide the dimensions by 2 to get the correct extents.
	collision_shape_3d.scale = Vector3(x_size, y_size, z_size)



		
	#Move both up so they are on the floor
	self.position.y += y_size / 2.0

func set_load_map(value: String) -> void:
	load_map = value
	if is_inside_tree():
		_update_label()

func _ready() -> void:
	call_deferred("_update_label")
	call_deferred("_update_teleport_size")

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
	
