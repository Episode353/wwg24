extends StaticBody3D

const EMPTY_TEXTURE := "__TB_empty"
# Faces steeper than ~45 degrees get no grass
const UP_FACING_MIN_Y := 0.7
const EDGE_EPSILON := 0.0001
# Grass is split into square render chunks of this size (meters) so off-screen chunks get culled
const CHUNK_SIZE := 16.0
# Must be a power of two
const RANDOM_TABLE_SIZE := 4096
const NO_GROUND := -INF
const FLOATS_PER_BLADE := 12
const GRASS_SCENES = [preload("res://mat/grass/grass2.glb"), preload("res://mat/grass/grass.glb")]

@export var spacing :float = 0.4
@export var rand_multiplier := 0.25
@export var scale_min: float = 0.05
@export var scale_max: float = 0.65
@export var grass_scale: float = 0

@export var func_godot_properties: Dictionary

static var _grass_meshes: Array[Mesh] = []
static var _grass_material: ShaderMaterial
static var _random_table := PackedFloat32Array()

# Blades are drawn straight through the RenderingServer instead of MultiMeshInstance3D nodes,
# so navmesh baking (which parses visual meshes) never has to chew through every blade.
var _multimeshes: Array[MultiMesh] = []
var _instances: Array[RID] = []

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
	var mesh_instance := find_first_mesh(self)
	if mesh_instance == null:
		return

	# Textured brushes stay as solid, visible ground with grass on top.
	# Untextured brushes are just a grass area marker, so they are hidden and not solid.
	if is_untextured(mesh_instance.mesh):
		var debug_mat := StandardMaterial3D.new()
		debug_mat.albedo_color = Color(0.2, 0.7, 0.2, 0.0)
		debug_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		debug_mat.flags_transparent = true
		debug_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mesh_instance.material_override = debug_mat
		collision_layer = 0

	if spacing <= 0.0:
		push_error("Grass spacing must be greater than 0.")
		return
	if not _load_shared_resources():
		return

	clear_grass()
	var grid := build_height_grid(get_top_triangles(mesh_instance.mesh, transform_relative_to_self(mesh_instance)))
	if not grid.is_empty():
		create_grass_chunks(grid)

func _exit_tree() -> void:
	clear_grass()

func clear_grass() -> void:
	for instance in _instances:
		RenderingServer.free_rid(instance)
	_instances.clear()
	_multimeshes.clear()

# Grid of cells (spacing apart, aligned to this node's origin) holding the height of the highest
# brush top face under each cell centre, or NO_GROUND where there is no brush under it.
func build_height_grid(triangles: Array) -> Dictionary:
	if triangles.is_empty():
		return {}
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for tri in triangles:
		for p: Vector3 in tri:
			lo = lo.min(Vector2(p.x, p.z))
			hi = hi.max(Vector2(p.x, p.z))
	var i0 := _first_cell(lo.x)
	var i1 := _last_cell(hi.x)
	var j0 := _first_cell(lo.y)
	var j1 := _last_cell(hi.y)
	if i1 < i0 or j1 < j0:
		return {}
	var w := i1 - i0 + 1
	var h := j1 - j0 + 1

	var heights := PackedFloat32Array()
	heights.resize(w * h)
	heights.fill(NO_GROUND)

	# Scanline-fill each triangle into the grid, keeping the highest surface per cell
	for tri in triangles:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		var n := (b - a).cross(c - a)
		if is_zero_approx(n.y):
			continue
		# Plane of the triangle as y = px * x + pz * z + p0
		var px := -n.x / n.y
		var pz := -n.z / n.y
		var p0 := a.y - px * a.x - pz * a.z

		var row_first := maxi(_first_cell(minf(a.z, minf(b.z, c.z))), j0)
		var row_last := mini(_last_cell(maxf(a.z, maxf(b.z, c.z))), j1)
		for j in range(row_first, row_last + 1):
			var z := (j + 0.5) * spacing
			var span := Vector2(INF, -INF)
			span = _edge_span(a, b, z, span)
			span = _edge_span(b, c, z, span)
			span = _edge_span(c, a, z, span)
			if span.x > span.y:
				continue
			var col_first := maxi(_first_cell(span.x), i0)
			var col_last := mini(_last_cell(span.y), i1)
			var row_offset := (j - j0) * w - i0
			var row_height := pz * z + p0
			for i in range(col_first, col_last + 1):
				var y := row_height + px * (i + 0.5) * spacing
				if y > heights[row_offset + i]:
					heights[row_offset + i] = y

	return {"i0": i0, "j0": j0, "w": w, "h": h, "heights": heights}

# Cells cover [low, high): a cell centre exactly on the low edge is in, on the high edge is out,
# so neighbouring faces and the two triangles of one face never both claim a cell.
func _first_cell(low: float) -> int:
	return ceili(low / spacing - 0.5 - EDGE_EPSILON)

func _last_cell(high: float) -> int:
	return ceili(high / spacing - 0.5 - EDGE_EPSILON) - 1

# Widens span (min x, max x) with where the edge p-q crosses the row at z
func _edge_span(p: Vector3, q: Vector3, z: float, span: Vector2) -> Vector2:
	if (z < minf(p.z, q.z) - EDGE_EPSILON) or (z > maxf(p.z, q.z) + EDGE_EPSILON):
		return span
	if absf(q.z - p.z) < EDGE_EPSILON:
		return Vector2(minf(span.x, minf(p.x, q.x)), maxf(span.y, maxf(p.x, q.x)))
	var x := p.x + (clampf(z, minf(p.z, q.z), maxf(p.z, q.z)) - p.z) / (q.z - p.z) * (q.x - p.x)
	return Vector2(minf(span.x, x), maxf(span.y, x))

func create_grass_chunks(grid: Dictionary) -> void:
	var heights: PackedFloat32Array = grid.heights
	var i0: int = grid.i0
	var j0: int = grid.j0
	var w: int = grid.w
	var h: int = grid.h

	var chunk_cells := maxi(1, int(CHUNK_SIZE / spacing))
	var jitter := spacing * rand_multiplier
	var scale_low := minf(scale_min, scale_max) * grass_scale
	var scale_range := absf(scale_max - scale_min) * grass_scale
	var table := _random_table
	var mask := RANDOM_TABLE_SIZE - 1
	var scenario := get_world_3d().scenario
	var xform := global_transform

	for chunk_j in range(0, h, chunk_cells):
		for chunk_i in range(0, w, chunk_cells):
			var cells_w := mini(chunk_cells, w - chunk_i)
			var cells_h := mini(chunk_cells, h - chunk_j)
			# One buffer for both grass meshes: mesh 0 fills from the front, mesh 1 from the back
			var capacity := cells_w * cells_h
			var buffer := PackedFloat32Array()
			buffer.resize(capacity * FLOATS_PER_BLADE)
			buffer.fill(0.0)
			var count_front := 0
			var count_back := 0

			for local_j in cells_h:
				var j := chunk_j + local_j
				var row := j * w
				var cell_j := j + j0
				var z := (cell_j + 0.5) * spacing
				for local_i in cells_w:
					var i := chunk_i + local_i
					var y := heights[row + i]
					if y == NO_GROUND:
						continue
					var cell_i := i + i0
					# Per-cell hash so the grass looks the same on every rebuild and every peer
					var hash_value := (cell_i * 73856093) ^ (cell_j * 19349663)
					hash_value = (hash_value ^ (hash_value >> 13)) * 1274126177
					var blade_scale := scale_low + table[(hash_value >> 12) & mask] * scale_range
					var angle := table[(hash_value >> 24) & mask] * TAU
					var cos_scaled := cos(angle) * blade_scale
					var sin_scaled := sin(angle) * blade_scale

					var o: int
					if (hash_value >> 48) & 1:
						o = count_front * FLOATS_PER_BLADE
						count_front += 1
					else:
						count_back += 1
						o = (capacity - count_back) * FLOATS_PER_BLADE
					# Row-major 3x4 transform: Y rotation * uniform scale, then origin
					buffer[o] = cos_scaled
					buffer[o + 2] = sin_scaled
					buffer[o + 3] = (cell_i + 0.5) * spacing + (table[hash_value & mask] * 2.0 - 1.0) * jitter
					buffer[o + 5] = blade_scale
					buffer[o + 7] = y
					buffer[o + 8] = -sin_scaled
					buffer[o + 10] = cos_scaled
					buffer[o + 11] = z + (table[(hash_value >> 36) & mask] * 2.0 - 1.0) * jitter

			_add_multimesh(_grass_meshes[0], buffer.slice(0, count_front * FLOATS_PER_BLADE), count_front, scenario, xform)
			_add_multimesh(_grass_meshes[1], buffer.slice((capacity - count_back) * FLOATS_PER_BLADE), count_back, scenario, xform)

func _add_multimesh(mesh: Mesh, buffer: PackedFloat32Array, count: int, scenario: RID, xform: Transform3D) -> void:
	if count == 0:
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	multimesh.buffer = buffer
	var instance := RenderingServer.instance_create2(multimesh.get_rid(), scenario)
	RenderingServer.instance_set_transform(instance, xform)
	RenderingServer.instance_geometry_set_material_override(instance, _grass_material.get_rid())
	_multimeshes.append(multimesh)
	_instances.append(instance)

static func _load_shared_resources() -> bool:
	if _grass_meshes.is_empty():
		for scene: PackedScene in GRASS_SCENES:
			var instance := scene.instantiate()
			var mesh_node := find_first_mesh(instance)
			if mesh_node:
				_grass_meshes.append(mesh_node.mesh)
			instance.free()
		if _grass_meshes.size() != GRASS_SCENES.size():
			_grass_meshes.clear()
			push_error("Failed to extract grass mesh.")
			return false
	if _grass_material == null:
		_grass_material = ShaderMaterial.new()
		_grass_material.shader = load("res://sys/shaders/grass.gdshader")
	if _random_table.is_empty():
		var rand := RandomNumberGenerator.new()
		rand.seed = 1337
		_random_table.resize(RANDOM_TABLE_SIZE)
		for k in RANDOM_TABLE_SIZE:
			_random_table[k] = rand.randf()
	return true

# Upward facing triangles of the mesh (brush tops and walkable slopes), in this node's space
func get_top_triangles(mesh: Mesh, xform: Transform3D) -> Array:
	var triangles := []
	var normal_basis := xform.basis.inverse().transposed()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices = PackedInt32Array(range(vertices.size()))

		for k in range(0, indices.size() - 2, 3):
			var a := xform * vertices[indices[k]]
			var b := xform * vertices[indices[k + 1]]
			var c := xform * vertices[indices[k + 2]]
			var normal: Vector3
			if normals.size() == vertices.size():
				normal = normal_basis * (normals[indices[k]] + normals[indices[k + 1]] + normals[indices[k + 2]])
			else:
				normal = (b - a).cross(c - a).abs()
			if normal.normalized().y >= UP_FACING_MIN_Y:
				triangles.append([a, b, c])
	return triangles

func transform_relative_to_self(node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current != self and current is Node3D:
		xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform

# func_godot names each mesh surface after the brush texture it came from
func is_untextured(mesh: Mesh) -> bool:
	if not mesh is ArrayMesh:
		return false
	for i in mesh.get_surface_count():
		if mesh.surface_get_name(i) != EMPTY_TEXTURE:
			return false
	return true

static func find_first_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var result = find_first_mesh(child)
		if result:
			return result
	return null
