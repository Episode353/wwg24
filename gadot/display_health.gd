extends Label3D
@onready var player = $".."

# Called when the node enters the scene tree for the first time.
func _ready():
	if is_multiplayer_authority():
		self.hide()



# Called every frame
func _process(_delta):
	self.text = str(int(player.health))
