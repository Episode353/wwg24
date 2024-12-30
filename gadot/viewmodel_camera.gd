extends Camera3D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Set the camera's FOV to the global variable camera_fov
	if Globals.viewmodel_camera_fov != null:
		fov = Globals.viewmodel_camera_fov
	else:
		print("Warning: Globals.viewmodel_camera_fov is not defined.")


