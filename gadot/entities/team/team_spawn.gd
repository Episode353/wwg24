extends Node3D

# Bit values of the "weapons" flags on team_a_spawn / team_b_spawn in Godot.fgd and team_*_spawn.tres
const WEAPON_FLAGS: Dictionary = {
	1: "ak47",
	2: "shotgun",
	4: "knife",
	8: "hegrenade",
	16: "rocket_launcher",
	32: "salsa",
	64: "keyboard",
	128: "wand",
}

# 1 = Wizards (Team A), 2 = Humans (Team B)
@export var team: int = 1
# Bitmask of WEAPON_FLAGS, filled in by func_godot from the map entity
@export var weapons: int = 0

func _ready():
	add_to_group("team_a_spawn" if team == 1 else "team_b_spawn")
	# The debug cube must not exist while the navmesh bakes, or it cuts a hole in the navmesh right where bots spawn
	var world = get_tree().root.get_node_or_null("World")
	if world and not Globals.map_loaded:
		world.map_loaded.connect(_add_debug_cube, CONNECT_ONE_SHOT)
	else:
		_add_debug_cube()

func get_weapon_names() -> Array[String]:
	var names: Array[String] = []
	for bit in WEAPON_FLAGS:
		if weapons & bit:
			names.append(WEAPON_FLAGS[bit])
	return names

func _add_debug_cube() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Globals.TEAM_COLORS.get(team, Color.WHITE)

	var body := CSGBox3D.new()
	body.name = "DebugCube"
	body.size = Vector3(0.1, 0.1, 0.1)
	body.position = Vector3(0, 0.05, 0)
	body.material = material
	add_child(body)

	# Shows which way players face when spawning here
	var facing := CSGBox3D.new()
	facing.name = "FacingCube"
	facing.size = Vector3(0.1, 0.1, 0.5)
	facing.position = Vector3(0, 1.6, -0.75)
	facing.material = material
	add_child(facing)
