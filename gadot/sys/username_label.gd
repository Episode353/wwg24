extends Label3D
@onready var player = $".."


# Called when the node enters the scene tree for the first time.
func _ready():
	if !is_multiplayer_authority():
		self.text = player.player_username
	if is_multiplayer_authority():
		self.hide()
