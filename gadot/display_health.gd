extends Label3D
@onready var player = $".."


# Called every frame
func _process(_delta):
	self.text = str(int(player.health))
