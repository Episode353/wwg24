extends Node3D

@export var use_spawn_position: bool = true
@export var disable_respawn: bool = true
@export var weapon: String = ""
@export var weapon_range: String = ""
@export var origin: String = "0 0 0"

func _ready():	
	if !is_multiplayer_authority(): return
	# Defer the size update to ensure all nodes are fully initialized.
	call_deferred("spawn_bot")
	
func spawn_bot():
	var world = get_tree().get_root().get_node("World")
	if world:
		if use_spawn_position:
			var pos3d: Vector3 = Vector3(global_position.x, global_position.y, global_position.z)
			world.rpc("add_bot", origin, use_spawn_position, weapon_range, weapon, disable_respawn, pos3d)
		if !use_spawn_position:
			world.rpc("add_bot", origin, use_spawn_position, weapon_range, weapon, disable_respawn, Vector3.ZERO)
