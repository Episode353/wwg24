extends Node3D

@export var target_position: String = ""  # e.g., "-184 56 -40"
@export var teleport_size: String = ""  # e.g., "10 10 10"

@onready var csg_box_3d = $CSGBox3D
@onready var collision_shape_3d = $Area3D/CollisionShape3D

func _ready():
	# Defer the size update to ensure all nodes are fully initialized.
	call_deferred("_update_teleport_size")

func _update_teleport_size():
	# Only update if teleport_size is provided.
	if teleport_size.strip_edges() == "":
		return

	# Split the string into its components.
	var parts = teleport_size.split(" ")
	if parts.size() != 3:
		push_error("Teleport size must contain three numbers separated by spaces. Given: " + teleport_size)
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
	position.y += y_size / 2.0

func _on_area_3d_body_entered(body):
	if not body.is_in_group("players"):
		return
	# The target_position is a string with TrenchBroom coordinates, e.g., "-184 56 -40"
	var pos_str = target_position
	var coords = pos_str.split(" ")
	
	if coords.size() == 3:
		# Parse the TrenchBroom coordinates.
		var tb_x = coords[0].to_float()
		var tb_y = coords[1].to_float()
		var tb_z = coords[2].to_float()
		
		# Apply the transformation:
		# Godot x = tb_y / 16
		# Godot y = tb_z / 16
		# Godot z = tb_x / 16
		var godot_position = Vector3(tb_y / 16.0, tb_z / 16.0, tb_x / 16.0)
		
		# Teleport the body to the new position.
		body.global_position = godot_position
		print("Teleporting player to: ", godot_position)
	else:
		push_error("Invalid target_position format. Expected three numbers.")
