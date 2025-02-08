extends Node3D

@export var target_position: String = ""  # e.g., "-184 56 -40"
@export var teleport_size: String = ""  # e.g., "-184 56 -40"
@onready var csg_box_3d = $CSGBox3D
@onready var collision_shape_3d = $Area3D/CollisionShape3D


func _on_area_3d_body_entered(body):
	if !body.is_in_group("players"):
		return
	# The target_position is a string with TrenchBroom coordinates, e.g., "-184 56 -40"
	var pos_str = target_position
	var coords = pos_str.split(" ")
	
	if coords.size() == 3:
		# Parse the TrenchBroom coordinates
		var tb_x = coords[0].to_float()
		var tb_y = coords[1].to_float()
		var tb_z = coords[2].to_float()
		
		# Apply the transformation:
		# Godot x = tb_y / 16
		# Godot y = tb_z / 16
		# Godot z = tb_x / 16
		var godot_position = Vector3(tb_y / 16.0, tb_z / 16.0, tb_x / 16.0)
		
		# Teleport the body to the new position
		body.global_position = godot_position
		print("Teleporting player to: ", godot_position)
	else:
		push_error("Invalid target_position format. Expected three numbers.")
