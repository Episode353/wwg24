extends Node3D

# Define an enum with the possible weapon types.
enum Weapons {
	ak47,
	knife,
	rocket_launcher,
	shotgun,
	hegrenade,
	flamespell,
	salsa,
	keyboard
}

# This will appear in the Inspector as a dropdown with the above enum options.
@export var weapon: Weapons

@export var ammo: int = 30
@export var ammo_respawn_delay: float = 5.0

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass
