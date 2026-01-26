extends Node3D

var owner_player
var dmg: float = 0.0

@onready var label_3d: Label3D = $Label3D
@onready var timer: Timer = $Timer

@export var merge_distance := 7.0
@export var fade_start_ratio := 0.5
@export var shrink_to := 0.6

var _base_a := 1.0
var _base_outline_a := 1.0
var _base_scale := Vector3.ONE
var _merging := false

func _enter_tree(): visible = false

func _ready():
	_base_a = label_3d.modulate.a
	_base_outline_a = label_3d.outline_modulate.a
	_base_scale = scale
	_update_text()
	_try_merge() # merge before showing to avoid 1-frame flash
	if not is_queued_for_deletion(): visible = true

func _physics_process(_delta):
	_try_merge()
	_fade_and_shrink()

func _try_merge():
	if _merging or owner_player == null: return
	var p := get_parent()
	if p == null: return
	var my_id := get_instance_id()

	for n in p.get_children():
		if n == self or not n.has_method("_mark_merging") or n.owner_player != owner_player: continue
		if global_position.distance_to(n.global_position) > merge_distance: continue

		_merging = true

		# Newer node merges into older node (prevents mutual deletion)
		if my_id > n.get_instance_id():
			_mark_merging()
			n._absorb(dmg)
			queue_free()
			return

		n._mark_merging()
		_absorb(float(n.dmg))
		n.queue_free()
		_merging = false
		return

func _mark_merging(): _merging = true

func _absorb(amount: float):
	dmg += amount
	_update_text()
	_restart()

func _restart():
	timer.stop(); timer.start()
	var m := label_3d.modulate; m.a = _base_a; label_3d.modulate = m
	var o := label_3d.outline_modulate; o.a = _base_outline_a; label_3d.outline_modulate = o
	scale = _base_scale

func _fade_and_shrink():
	var wait := timer.wait_time
	if wait <= 0.0: return

	var progress := 1.0 - timer.time_left / wait
	if progress < fade_start_ratio: return

	var t := (progress - fade_start_ratio) / (1.0 - fade_start_ratio)

	# Main text fades normally
	var m := label_3d.modulate
	m.a = clampf(lerpf(_base_a, 0.0, t), 0.0, 1.0)
	label_3d.modulate = m

	# Outline fades slower (lagging behind)
	var outline_t := t * 0.2  # 20% speed
	var o := label_3d.outline_modulate
	o.a = clampf(lerpf(_base_outline_a, 0.0, outline_t), 0.0, 1.0)
	label_3d.outline_modulate = o

	# Shrink
	scale = _base_scale * lerpf(1.0, shrink_to, t)


func _update_text():
	label_3d.text = "-%s" % _fmt_dmg(dmg)

func _fmt_dmg(v: float) -> String:
	# If it's an integer (or very close), show no decimal.
	return str(int(round(v))) if is_equal_approx(v, round(v)) else str(v)

func _on_timer_timeout():
	queue_free()
