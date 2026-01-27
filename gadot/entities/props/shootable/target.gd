extends Node3D

@export var base_normalize_speed: float = 0.001   # very slow starting speed
@export var accel_factor: float = 10.0            # how fast it ramps up
@export var max_speed: float = 50.0               # clamp so it doesn't go insane

var normal_scale: Vector3 = Vector3.ONE
var normalize_time: float = 0.0
var is_normalizing: bool = false

func _physics_process(delta: float) -> void:
	if not is_normalizing:
		return

	normalize_time += delta

	# Exponentially increasing speed
	var speed := base_normalize_speed * exp(accel_factor * normalize_time)
	speed = min(speed, max_speed)

	scale.x = move_toward(scale.x, normal_scale.x, speed * delta)
	scale.y = move_toward(scale.y, normal_scale.y, speed * delta)
	scale.z = move_toward(scale.z, normal_scale.z, speed * delta)

	# Snap when close
	if scale.is_equal_approx(normal_scale):
		scale = normal_scale
		is_normalizing = false

@rpc("any_peer", "call_local")
func destruct() -> void:
	scale = Vector3(
		randf_range(0.00, 1.5),
		randf_range(0.00, 1.5),
		randf_range(0.00, 1.5)
	)

	normalize_time = 0.0
	is_normalizing = true
