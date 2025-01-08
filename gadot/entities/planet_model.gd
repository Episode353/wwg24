extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Rotate a random value between 0 and 360 degrees (converted to radians).
	pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Rotate slightly each frame.
	self.rotate_y(0.0005 * delta)
