extends Label3D
@onready var player: CharacterBody3D = $".."


# Called when the node enters the scene tree for the first time.
func _ready():
	if !is_multiplayer_authority():
		self.text = player.name
	if is_multiplayer_authority() and !player.is_bot:
		self.hide()
