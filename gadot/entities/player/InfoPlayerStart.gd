extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	print("info_player_start created at:", self.global_position)
	add_to_group("info_player_start")
