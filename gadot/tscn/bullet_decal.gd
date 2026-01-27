extends Node3D

@export var collision_mask: int = 0xFFFFFFFF
@export var cast_length: float = 0.25 # how far the decal checks for geometry

@onready var ray_cast_3d: RayCast3D = $RayCast3D

var wall_dir: Vector3 = Vector3.ZERO # global direction FROM decal INTO the wall (normalized)

func set_wall_normal(wall_normal: Vector3) -> void:
	wall_dir = (-wall_normal).normalized()
	_configure_raycast_from_wall_dir()

func _ready() -> void:
	ray_cast_3d.enabled = true
	ray_cast_3d.collision_mask = collision_mask
	ray_cast_3d.collide_with_bodies = true
	ray_cast_3d.collide_with_areas = true
	ray_cast_3d.exclude_parent = true
	ray_cast_3d.hit_from_inside = true

	# Ensure the ray actually casts (RayCast3D won't collide if target_position is zero)
	if ray_cast_3d.target_position.length() < 0.001:
		ray_cast_3d.target_position = Vector3(0, 0, -cast_length)

	if wall_dir != Vector3.ZERO:
		_configure_raycast_from_wall_dir()

func _physics_process(_delta: float) -> void:
	# If nobody ever called set_wall_normal(), still raycast using current orientation.
	if wall_dir == Vector3.ZERO and ray_cast_3d.target_position.length() < 0.001:
		ray_cast_3d.target_position = Vector3(0, 0, -cast_length)

	ray_cast_3d.force_raycast_update()

	if not ray_cast_3d.is_colliding():
		queue_free()
		return

	var c := ray_cast_3d.get_collider()
	if _is_bullet_decal(c) or not _is_valid_geometry(c):
		queue_free()
		return

func _configure_raycast_from_wall_dir() -> void:
	if wall_dir == Vector3.ZERO:
		return

	# looking_at() needs a non-parallel "up" vector (floors/ceilings otherwise break)
	var up := Vector3.UP
	if abs(wall_dir.dot(up)) > 0.98:
		up = Vector3.FORWARD  # fallback up for near-vertical casts

	# Point RayCast's local -Z along wall_dir
	ray_cast_3d.global_basis = Basis().looking_at(wall_dir, up)

	# Keep the ray length consistent (casts along local -Z)
	ray_cast_3d.target_position = Vector3(0, 0, -cast_length)

func _is_bullet_decal(obj: Object) -> bool:
	var n := obj as Node
	while n:
		if n.is_in_group("bullet_decal"):
			return true
		n = n.get_parent()
	return false

func _is_valid_geometry(obj: Object) -> bool:
	if obj is CollisionShape3D or obj is MeshInstance3D:
		return true

	var n := obj as Node
	if n == null:
		return false

	var p := n
	while p:
		if p is CollisionShape3D or p is MeshInstance3D:
			return true
		p = p.get_parent()

	for child in n.get_children():
		if child is CollisionShape3D:
			return true

	return false
