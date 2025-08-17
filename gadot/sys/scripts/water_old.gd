extends Node

func _func_godot_build_complete() -> void:
	# Load shader from file
	var shader := load("res://sys/shaders/water.gdshader")  # Change path as needed
	if shader == null:
		push_error("Shader not found at specified path.")
		return
		
	var mat := ShaderMaterial.new()
	mat.shader = shader

	# Find the top bounds and size of the first MeshInstance3D
	var mesh_instance := find_first_mesh(self)
	if mesh_instance == null:
		return

	var aabb := mesh_instance.get_aabb()
	var plane_size = Vector2(aabb.size.x, aabb.size.z)
	var top_y = aabb.position.y + aabb.size.y
	var center_xz = Vector3(
		aabb.position.x + aabb.size.x / 2.0,
		0,
		aabb.position.z + aabb.size.z / 2.0
	)

	if mesh_instance.mesh is ArrayMesh:
		var old_mesh := mesh_instance.mesh as ArrayMesh
		var new_mesh := ArrayMesh.new()
		var arrays := old_mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]


		var top_faces := PackedVector3Array()
		var top_indices := PackedInt32Array()

		# Keep track of vertex reuse
		var vertex_map := {}
		var index_count := 0

		for i in range(0, indices.size(), 3):
			var i1 = indices[i]
			var i2 = indices[i + 1]
			var i3 = indices[i + 2]

			var v1 = vertices[i1]
			var v2 = vertices[i2]
			var v3 = vertices[i3]

			var normal = Plane(v1, v2, v3).normal
			if normal.dot(Vector3.UP) > 0.95:  # Almost horizontal up-facing triangle
				for vi in [v1, v2, v3]:
					if not vertex_map.has(vi):
						vertex_map[vi] = index_count
						top_faces.append(vi)
						top_indices.append(index_count)
						index_count += 1
					else:
						top_indices.append(vertex_map[vi])

		var new_arrays := []
		new_arrays.resize(Mesh.ARRAY_MAX)
		new_arrays[Mesh.ARRAY_VERTEX] = top_faces
		new_arrays[Mesh.ARRAY_INDEX] = top_indices
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)

		mesh_instance.mesh = new_mesh
		mesh_instance.material_override = mat
		mesh_instance.transform.origin.y += 0.35  # Adjust the value as needed



func find_first_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var result = find_first_mesh(child)
		if result:
			return result
	return null
