extends Node3D

const GRASS_2_PLANE = preload("res://mat/grass/grass2.glb")
const GRASS_PLANE_010 = preload("res://mat/grass/grass.glb")

@export var spacing :float = 0.4
@export var rand_multiplier := 0.25
@export var scale_min: float = 0.05
@export var scale_max: float = 0.65
@export var grass_scale: float = 0

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
	var shader := load("res://sys/shaders/grass.gdshader")
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = shader

	var mesh_instance := find_first_mesh(self)
	if mesh_instance == null:
		return

	# Hide original mesh
	var debug_mat := StandardMaterial3D.new()
	debug_mat.albedo_color = Color(0.2, 0.7, 0.2, 0.0)
	debug_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debug_mat.flags_transparent = true
	debug_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mesh_instance.material_override = debug_mat

	# Bounds
	var aabb := mesh_instance.get_aabb()
	var min = aabb.position
	var max = min + aabb.size
	var top_y = max.y

	var rand = RandomNumberGenerator.new()
	rand.randomize()

	# Load both mesh resources from their scenes
	var grass_mesh_1 := get_mesh_from_scene(GRASS_2_PLANE, shader_mat)
	var grass_mesh_2 := get_mesh_from_scene(GRASS_PLANE_010, shader_mat)
	if grass_mesh_1 == null or grass_mesh_2 == null:
		push_error("Failed to extract grass mesh.")
		return

	# Two lists of transforms
	var transforms_1: Array[Transform3D] = []
	var transforms_2: Array[Transform3D] = []

	# Grid placement
	var start_x = min.x + spacing * 0.5
	var start_z = min.z + spacing * 0.5
	var end_x = max.x - spacing * 0.5
	var end_z = max.z - spacing * 0.5

	var mesh_center_x = min.x + (max.x - min.x) * 0.5
	var mesh_center_z = min.z + (max.z - min.z) * 0.5
	var grid_center_x = (start_x + end_x) * 0.5
	var grid_center_z = (start_z + end_z) * 0.5
	var center_offset_x = mesh_center_x - grid_center_x
	var center_offset_z = mesh_center_z - grid_center_z

	var min_val = min(scale_min, scale_max)
	var max_val = max(scale_min, scale_max)

	for x in rangef(start_x, end_x, spacing):
		for z in rangef(start_z, end_z, spacing):
			var jitter_x = rand.randf_range(-spacing * rand_multiplier, spacing * rand_multiplier)
			var jitter_z = rand.randf_range(-spacing * rand_multiplier, spacing * rand_multiplier)
			var pos = Vector3(x + center_offset_x + jitter_x, top_y, z + center_offset_z + jitter_z)

			var base_scale = rand.randf_range(min_val, max_val)
			var final_scale = base_scale * grass_scale
			var transform := Transform3D.IDENTITY
			transform.origin = pos

			var scale_basis = Basis().scaled(Vector3.ONE * final_scale)
			var rotation_y = Basis(Vector3.UP, rand.randf_range(0.0, TAU))
			transform.basis = rotation_y * scale_basis

			if rand.randi_range(0, 1) == 0:
				transforms_1.append(transform)
			else:
				transforms_2.append(transform)

	# Create two multimeshes
	create_multimesh(grass_mesh_1, transforms_1, shader_mat)
	create_multimesh(grass_mesh_2, transforms_2, shader_mat)

# Get the Mesh from a scene and apply material
func get_mesh_from_scene(scene_res: PackedScene, mat: ShaderMaterial) -> Mesh:
	var instance = scene_res.instantiate()
	var mesh = find_first_mesh(instance)
	if mesh:
		mesh.material_override = mat
		return mesh.mesh
	return null

# Build and add a MultiMeshInstance3D from transforms
func create_multimesh(mesh: Mesh, transforms: Array[Transform3D], mat: ShaderMaterial) -> void:
	var multimesh := MultiMesh.new()
	multimesh.mesh = mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = transforms.size()

	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = multimesh
	mmi.material_override = mat
	add_child(mmi)



func apply_shader_to_meshes(node: Node, mat: ShaderMaterial) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = mat
		else:
			apply_shader_to_meshes(child, mat)



func find_first_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var result = find_first_mesh(child)
		if result:
			return result
	return null

func rangef(start: float, stop: float, step: float) -> Array:
	var result := []
	var i := start
	while i < stop:
		result.append(i)
		i += step
	return result
	#
