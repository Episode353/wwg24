extends Label3D
@onready var player: CharacterBody3D = $".."
@onready var weapon: Label3D = $"../Weapon"
@onready var weapons_manager: Node3D = $"../neck/head/main_camera/Weapons_Manager"

# Called when the node enters the scene tree for the first time.
func _ready():
	if is_multiplayer_authority() and !player.is_bot:
		self.hide()



# Called every frame
func _process(_delta):
	self.text = str(int(player.health))
	weapon.text = str(weapons_manager.current_weapon.weapon_name)
