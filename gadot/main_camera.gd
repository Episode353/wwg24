extends Camera3D
@onready var player: CharacterBody3D = $"../../.."

# --- Config ---
const HYSTERESIS_TICKS: int = 4
const LAYER17_MASK: int = 1 << 16  # Visibility Layer 17

# --- State ---
var _was_in_water: bool = false
var _out_of_water_ticks: int = 0
var _env_underwater: Environment
var _overlay_rect: ColorRect
var _overlay_mat: ShaderMaterial
var _overlay_tween: Tween

func _ready() -> void:
	# Apply FOV if provided
	if Globals.camera_fov != null:
		fov = float(Globals.camera_fov)
	else:
		print("Warning: Globals.camera_fov is not defined.")
	# Build FX once
	_build_underwater_environment()
	_build_underwater_overlay()
	# Start with Layer 17 visible (assuming we spawn above water)
	_set_layer17_visible(true)

func _process(_delta: float) -> void:
	# Keep FOV synced if the game changes it dynamically
	if player != null and player.is_bot == true:
		return
	if Globals.camera_fov != null:
		fov = float(Globals.camera_fov)

func _physics_process(_delta: float) -> void:
	var in_water: bool = _is_point_in_water(global_position)
	if player != null:
		player.is_underwater = in_water

	if in_water == true:
		# Entered or staying in water
		if _was_in_water == false:
			# Transition: above -> below
			_apply_underwater_state(true)  # hides layer 17
			print("in water")
		_out_of_water_ticks = 0
	else:
		# Left water: count ticks before transitioning out
		if _was_in_water == true:
			_out_of_water_ticks += 1
			if _out_of_water_ticks >= HYSTERESIS_TICKS:
				_apply_underwater_state(false)  # shows layer 17
				print("not in water")
				_was_in_water = false

	# Latch state until hysteresis completes
	if in_water == true:
		_was_in_water = true

# -------------------- EFFECTS --------------------

func _apply_underwater_state(enable: bool) -> void:
	# Camera environment override (only when changed)
	if enable == true:
		if environment != _env_underwater:
			environment = _env_underwater
	else:
		if environment != null:
			environment = null

	# Layer 17: show when NOT underwater
	_set_layer17_visible(enable == false)

	# Smooth overlay tween (cancel previous to avoid stacking)
	if _overlay_tween != null and _overlay_tween.is_running() == true:
		_overlay_tween.kill()

	var target: float = 1.0 if enable == true else 0.0
	_overlay_tween = create_tween()
	_overlay_tween.tween_method(_set_overlay_intensity, _get_overlay_intensity(), target, 0.35) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)

func _build_underwater_environment() -> void:
	_env_underwater = Environment.new()
	_env_underwater.adjustment_enabled = true
	_env_underwater.adjustment_saturation = 0.85
	_env_underwater.adjustment_contrast = 1.05

	_env_underwater.fog_enabled = true
	_env_underwater.fog_density = 0.04
	_env_underwater.fog_light_color = Color8(0x1a, 0x66, 0x66)

func _build_underwater_overlay() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_speed = 1.0;
uniform float ripple_scale = 40.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME * time_speed;
	float n = sin((uv.y + t) * ripple_scale) * 0.002
			+ sin((uv.x * 1.2 - t * 0.8) * ripple_scale) * 0.002;
	uv += n * intensity;

	vec4 col = texture(SCREEN_TEXTURE, uv);
	vec3 tint = vec3(0.10196, 0.4, 0.4); // approx #1a6666
	col.rgb = mix(col.rgb, tint, 0.25 * intensity);

	float g = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(col.rgb, vec3(g), 0.10 * intensity);

	COLOR = col;
}
"""
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = shader
	_overlay_mat.set_shader_parameter("intensity", 0.0)

	var layer := CanvasLayer.new()
	add_child(layer)

	_overlay_rect = ColorRect.new()
	_overlay_rect.color = Color(1.0, 1.0, 1.0, 0.0) # shader writes final color
	_overlay_rect.material = _overlay_mat
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_rect.anchor_left = 0.0
	_overlay_rect.anchor_top = 0.0
	_overlay_rect.anchor_right = 1.0
	_overlay_rect.anchor_bottom = 1.0
	_overlay_rect.offset_left = 0
	_overlay_rect.offset_top = 0
	_overlay_rect.offset_right = 0
	_overlay_rect.offset_bottom = 0
	layer.add_child(_overlay_rect)

func _set_overlay_intensity(v: float) -> void:
	if _overlay_mat != null:
		_overlay_mat.set_shader_parameter("intensity", v)

func _get_overlay_intensity() -> float:
	if _overlay_mat != null:
		return float(_overlay_mat.get_shader_parameter("intensity"))
	return 0.0

func _set_layer17_visible(visible: bool) -> void:
	if visible == true:
		if (cull_mask & LAYER17_MASK) == 0:
			cull_mask |= LAYER17_MASK
	else:
		if (cull_mask & LAYER17_MASK) != 0:
			cull_mask &= ~LAYER17_MASK

# -------------------- WATER CHECK --------------------

func _is_point_in_water(point: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var params := PhysicsPointQueryParameters3D.new()
	params.position = point
	params.collide_with_areas = true
	params.collide_with_bodies = false
	# params.collision_mask = 1 << WATER_LAYER_BIT
	var hits: Array[Dictionary] = space.intersect_point(params, 16)
	for h: Dictionary in hits:
		var area: Area3D = h.get("collider") as Area3D
		if area != null and area.is_in_group("water") == true:
			return true
	return false
