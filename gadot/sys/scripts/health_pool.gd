
extends Node
# @tool  # <- enable if you want this to run in-editor

const WATER_SCENE_PATH := "res://addons/EffectBlocks/assets/water/health_pool.tscn"



# ---- exported params (match FGD key names exactly) ----
@export var water_color: Color = Color(0.294, 0.094, 0.973, 1.0)      # vec4 in shader uses alpha from transparency below
@export var ripple_color: Color = Color(0.329, 1.0, 1.0, 1.0)

@export var wave_strength : float = 0.2
@export var wave_speed : float = 0.05
@export var water_transparency : float = 0.8
@export var water_roughness : float = 1.0
@export var water_depth_fade : float = 0.5

@export var edge_size := 2.0
@export var edge_intensity := 2.0
@export var ripple_intensity := 0.6
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





func _func_godot_build_complete() -> void:
	var old_mesh := _find_first_mesh(self)
	if old_mesh == null:
		push_error("No MeshInstance3D found to replace.")
		return

	var packed := load(WATER_SCENE_PATH)
	if packed == null or not (packed is PackedScene):
		push_error("Could not load water scene: %s" % WATER_SCENE_PATH)
		return

	var inst := (packed as PackedScene).instantiate()
	if inst == null:
		push_error("Failed to instance water scene.")
		return

	# Find MeshInstance3D named "Water" inside the instanced scene
	var water_mesh := _find_mesh_named(inst, "Water")
	if water_mesh == null:
		if inst is MeshInstance3D and inst.name == "Water":
			water_mesh = inst
		else:
			push_error("No MeshInstance3D named 'Water' in water.tscn.")
			inst.queue_free()
			return

	# Put the new scene alongside the old mesh so transforms are comparable
	var parent := old_mesh.get_parent()
	if parent == null:
		push_error("Old mesh has no parent; cannot insert replacement.")
		inst.queue_free()
		return
	parent.add_child(inst)
	inst.owner = old_mesh.owner

	# 1) Copy pose (position + rotation + current scale pivot)
	water_mesh.global_transform = old_mesh.global_transform

	# 2) Match world-space size (scale) to the old mesh
	var old_size: Vector3 = _world_aabb_size(old_mesh)
	var new_size: Vector3 = _world_aabb_size(water_mesh)

	var scale_mult := Vector3.ONE
	if new_size.x != 0.0: scale_mult.x = old_size.x / new_size.x
	if new_size.y != 0.0: scale_mult.y = old_size.y / new_size.y
	if new_size.z != 0.0: scale_mult.z = old_size.z / new_size.z
	water_mesh.scale = water_mesh.scale * scale_mult

	# 3) Pin the TOP faces together (do this AFTER scaling)
	var old_top: float = _world_aabb_top(old_mesh)
	var new_top: float = _world_aabb_top(water_mesh)
	var dy: float = old_top - new_top
	if absf(dy) > 0.0001:
		water_mesh.global_position += Vector3(0.0, dy, 0.0)

	# --- Make the original brush transparent blue and add it to "water" group ---
	var mat := StandardMaterial3D.new()
	mat.albedo_color = water_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	#mat.cull_mode = BaseMaterial3D.CULL_DISABLED       # optional: show both sides
	mat.roughness = 0.5                                 # optional: a little shiny
	# If you want it to ignore lighting and be a flat blue, uncomment:
	# mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Apply to the whole mesh
	old_mesh.material_override = mat

	# --- Create a matching Water Area (for overlap detection) ---
	var aabb: AABB = old_mesh.get_aabb()

	var water_area := Area3D.new()
	water_area.name = "WaterArea"
	water_area.monitoring = true
	water_area.monitorable = true
	# Optional: set custom collision layer/mask here if you use them
	# water_area.collision_layer = 1 << 2
	# water_area.collision_mask  = 0xFFFFFFFF

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = aabb.size  # local-space size
	shape.shape = box
	# Center the shape in the mesh's local AABB
	shape.position = aabb.position + (aabb.size * 0.5)

	# Place the Area with the same global transform as the original mesh
	var p := old_mesh.get_parent()
	p.add_child(water_area)
	water_area.owner = old_mesh.owner
	water_area.global_transform = old_mesh.global_transform
	water_area.add_child(shape)
	shape.owner = old_mesh.owner
	
	

	# Add to "water" group for easy queries/signals
	if not water_area.is_in_group("health_pool"):
		water_area.add_to_group("health_pool", true)



	# 4) Remove the original mesh
	#old_mesh.queue_free()


# --------------------- helpers ---------------------

func _world_aabb_top(n: MeshInstance3D) -> float:
	var aabb: AABB = n.get_aabb()
	var corners: PackedVector3Array = _aabb_corners(aabb)
	var t: Transform3D = n.global_transform
	var top: float = -INF
	for c: Vector3 in corners:
		var y: float = (t * c).y
		if y > top:
			top = y
	return top

func _find_first_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var deeper := _find_first_mesh(child)
		if deeper: return deeper
	return null

func _find_mesh_named(root: Node, wanted: String) -> MeshInstance3D:
	if root is MeshInstance3D and root.name == wanted:
		return root
	for c in root.get_children():
		var found := _find_mesh_named(c, wanted)
		if found: return found
	return null

func _world_aabb_size(n: MeshInstance3D) -> Vector3:
	var aabb: AABB = n.get_aabb()
	var corners: PackedVector3Array = _aabb_corners(aabb)
	var t: Transform3D = n.global_transform
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	for c: Vector3 in corners:
		var w: Vector3 = t * c
		min_v = Vector3(min(min_v.x, w.x), min(min_v.y, w.y), min(min_v.z, w.z))
		max_v = Vector3(max(max_v.x, w.x), max(max_v.y, w.y), max(max_v.z, w.z))
	return max_v - min_v

func _world_aabb_center(n: MeshInstance3D) -> Vector3:
	var aabb: AABB = n.get_aabb()
	var corners: PackedVector3Array = _aabb_corners(aabb)
	var t: Transform3D = n.global_transform
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	for c: Vector3 in corners:
		var w: Vector3 = t * c
		min_v = Vector3(min(min_v.x, w.x), min(min_v.y, w.y), min(min_v.z, w.z))
		max_v = Vector3(max(max_v.x, w.x), max(max_v.y, w.y), max(max_v.z, w.z))
	return (min_v + max_v) * 0.5

func _aabb_corners(aabb: AABB) -> PackedVector3Array:
	var p: Vector3 = aabb.position
	var s: Vector3 = aabb.size
	return PackedVector3Array([
		p,
		p + Vector3(s.x, 0, 0),
		p + Vector3(0, s.y, 0),
		p + Vector3(0, 0, s.z),
		p + Vector3(s.x, s.y, 0),
		p + Vector3(s.x, 0, s.z),
		p + Vector3(0, s.y, s.z),
		p + s
	])
