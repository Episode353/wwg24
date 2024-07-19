extends Label


# Called when the node enters the scene tree for the first time.
func _ready():
	Engine.max_fps = 144


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var fps = Engine.get_frames_per_second()
	text = "FPS: " + str(fps)

