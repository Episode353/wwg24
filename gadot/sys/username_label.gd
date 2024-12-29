extends Label3D
@onready var player = $".."


# Called when the node enters the scene tree for the first time.
func _ready():
	self.text = player.name


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
