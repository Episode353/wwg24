extends Camera3D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Set the camera's FOV to the global variable camera_fov
	if Globals.camera_fov != null:
		fov = Globals.camera_fov
	else:
		print("Warning: Globals.camera_fov is not defined.")
	
	# Stop the viewmodel objects from being visible on the opposite players screen!
	if !is_multiplayer_authority():
		self.set_cull_mask_value(2, false)
