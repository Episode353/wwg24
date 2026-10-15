extends MeshInstance3D

# Physics ticks it takes the back of the tracer to catch up to where the shot landed.
const LIFETIME_TICKS := 2

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _up := Vector3.UP
var _duration := 0.0
var _elapsed := 0.0
# The first drawn frame always shows the whole line, even if the shot happened mid-frame.
var _drawn_once := false


# Call after the tracer is in the tree.
func setup(from: Vector3, to: Vector3) -> void:
	var dir := to - from
	if dir.length() < 0.01:
		queue_free()
		return
	_from = from
	_to = to
	_up = Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	_duration = float(LIFETIME_TICKS) / float(Engine.physics_ticks_per_second)
	_place(_from)


func _process(delta: float) -> void:
	if not _drawn_once:
		_drawn_once = true
		return
	_elapsed += delta
	if _elapsed >= _duration:
		queue_free()
		return
	_place(_from.lerp(_to, _elapsed / _duration))


# The mesh is a unit-length box along -Z, so scaling Z by the distance makes it span both points.
func _place(start: Vector3) -> void:
	var dir := _to - start
	var length := dir.length()
	if length < 0.001:
		visible = false
		return
	global_transform = Transform3D(Basis.looking_at(dir / length, _up) * Basis.from_scale(Vector3(1, 1, length)), start.lerp(_to, 0.5))
