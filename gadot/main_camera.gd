extends Camera3D
@onready var player: CharacterBody3D = $"../../.."

var _was_in_water: bool = false
var _env_underwater: Environment
var _overlay_rect: ColorRect
var _overlay_mat: ShaderMaterial

func _ready() -> void:
	# FOV
	if Globals.camera_fov != null:
		fov = Globals.camera_fov
	else:
		print("Warning: Globals.camera_fov is not defined.")
	# Build FX
	_build_underwater_environment()
	_build_underwater_overlay()

func _process(_delta: float) -> void:
	if player.is_bot:
		return
	if Globals.camera_fov != null:
		fov = Globals.camera_fov

func _physics_process(_delta: float) -> void:
	var in_water: bool = _is_point_in_water(global_position)
	player.is_underwater = in_water
	if in_water != _was_in_water:
		_set_underwater_effects_enabled(in_water)
		print("in water" if in_water else "not in water")
		_was_in_water = in_water

# -------------------- EFFECTS --------------------

func _build_underwater_environment() -> void:
	_env_underwater = Environment.new()

	# Optional grading (works only if adjustment_enabled is true)
	_env_underwater.adjustment_enabled = true
	_env_underwater.adjustment_saturation = 0.85
	_env_underwater.adjustment_contrast = 1.05

	# Underwater fog using your #1a6666 tone
	_env_underwater.fog_enabled = true
	_env_underwater.fog_density = 0.04
	_env_underwater.fog_light_color = Color8(0x1a, 0x66, 0x66)

	# Optional tone mapper (safe in Godot 4)
	# _env_underwater.tone_mapper = Environment.TONE_MAPPER_ACES



func _build_underwater_overlay() -> void:
	# Fullscreen ripple/tint overlay using SCREEN_TEXTURE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_speed = 1.0;
uniform float ripple_scale = 40.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME * time_speed;

	// two sine ripples combined, scaled small so it's subtle
	float n = sin((uv.y + t) * ripple_scale) * 0.002
			+ sin((uv.x * 1.2 - t * 0.8) * ripple_scale) * 0.002;

	uv += n * intensity;

	vec4 col = texture(SCREEN_TEXTURE, uv);

	// slight teal tint toward #1a6666
	vec3 tint = vec3(0.10196, 0.4, 0.4); // approx #1a6666 normalized
	col.rgb = mix(col.rgb, tint, 0.25 * intensity);

	// gentle desaturation
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
	_overlay_rect.color = Color(1, 1, 1, 0) # not used, shader writes final color
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

func _set_underwater_effects_enabled(enable: bool) -> void:
	# Camera environment override on/off
	environment = _env_underwater if enable else null

	# Smoothly tween overlay intensity
	var target: float = 1.0 if enable else 0.0
	var tw := create_tween()
	tw.tween_method(_set_overlay_intensity, _get_overlay_intensity(), target, 0.35) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)

func _set_overlay_intensity(v: float) -> void:
	_overlay_mat.set_shader_parameter("intensity", v)

func _get_overlay_intensity() -> float:
	return float(_overlay_mat.get_shader_parameter("intensity"))

# -------------------- WATER CHECK --------------------

func _is_point_in_water(point: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var params := PhysicsPointQueryParameters3D.new()
	params.position = point
	params.collide_with_areas = true
	params.collide_with_bodies = false
	# params.collision_mask = 1 << WATER_LAYER_BIT  # set if you use a dedicated layer
	var hits: Array[Dictionary] = space.intersect_point(params, 16)
	for h: Dictionary in hits:
		var area: Area3D = h.get("collider") as Area3D
		if area and area.is_in_group("water"):
			return true
	return false
