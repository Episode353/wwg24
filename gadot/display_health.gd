extends Label3D
@onready var player: CharacterBody3D = $".."

# Called when the node enters the scene tree for the first time.
func _ready():
	if is_multiplayer_authority() and !player.is_bot:
		self.hide()



# Called every frame
func _process(_delta):
	self.text = str(int(player.health))
