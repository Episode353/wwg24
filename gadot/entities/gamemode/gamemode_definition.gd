extends Node3D

# Values are filled in by func_godot from the map entity (defaults live in gamemode_definition.tres)
# 0: None, 1: Casual, 2: Deathmatch
@export var game_type: int = 0
@export var rounds: int = 5
@export var players_per_team: int = 4
@export var waiting_for_players: int = 10
# 0: Disabled, 1: Enabled
@export var friendly_fire: int = 1

func _ready():
	add_to_group("gamemode_definition")
