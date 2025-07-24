extends Node3D

@export var use_spawn_position: bool = true
@export var disable_respawn: bool = true
@export var weapon: String = ""
@export var weapon_range: String = ""
@export var origin: String = "0 0 0"

	
func spawn_bot():
	var world = get_tree().get_root().get_node("World")
	if world:
		if use_spawn_position:
			var pos3d: Vector3 = Vector3(global_position.x, global_position.y, global_position.z)
			world.rpc("add_bot", origin, use_spawn_position, weapon_range, weapon, disable_respawn, pos3d)
		if !use_spawn_position:
			world.rpc("add_bot", origin, use_spawn_position, weapon_range, weapon, disable_respawn, Vector3.ZERO)

@export var func_godot_properties: Dictionary

func _func_godot_apply_properties(props: Dictionary):
	var property_types := {}
	for p in get_property_list():
		property_types[p.name] = p.type

	for key in props.keys():
		if not property_types.has(key):
			continue

		var target_type = property_types[key]
		var value = props[key]

		match target_type:
			TYPE_INT:
				set(key, int(value))
			TYPE_FLOAT:
				set(key, float(value))
			TYPE_BOOL:
				set(key, value in ["1", "true", true])
			TYPE_STRING:
				set(key, str(value))
			_:
				set(key, value)  # Fallback: assign directly (e.g. dictionaries, arrays)
	call_deferred("spawn_bot")	
