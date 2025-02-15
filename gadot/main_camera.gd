extends Camera3D
@onready var player: CharacterBody3D = $"../../.."

# Called when the node enters the scene tree for the first time.
func _ready():
	# Set the camera's FOV to the global variable camera_fov
	if Globals.camera_fov != null:
		fov = Globals.camera_fov
	else:
		print("Warning: Globals.camera_fov is not defined.")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if player.is_bot: return
	# Optionally, update the FOV dynamically during the game
	if Globals.camera_fov != null:
		fov = Globals.camera_fov
