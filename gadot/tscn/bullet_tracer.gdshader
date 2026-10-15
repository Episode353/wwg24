shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.35);
// Alpha left at the back of the streak, relative to the front where the shot landed.
uniform float tail_alpha : hint_range(0.0, 1.0) = 0.25;
// Higher values make the soft edges thinner and the bright core sharper.
uniform float edge_softness : hint_range(0.5, 4.0) = 1.5;
// Half-width in radians of view, so distant tracers stay about 1.5 px wide instead of breaking into dashes.
uniform float min_half_angle = 0.0012;
// A shot that hits the viewer ends at their face, where even a few centimeters fills the screen.
// The tracer is invisible closer than near_fade_start and fully visible past near_fade_end (meters).
uniform float near_fade_start = 1.0;
uniform float near_fade_end = 4.0;

varying float across;
varying float along;
varying vec3 world_pos;

// The mesh is a flat strip: X is its width in meters and Z runs -0.5 (front) to 0.5 (back)
// before the node scales Z to the shot length. It is turned around its length to face the camera.
void vertex() {
	vec3 axis = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	vec3 center = (MODEL_MATRIX * vec4(0.0, 0.0, VERTEX.z, 1.0)).xyz;
	vec3 to_camera = CAMERA_POSITION_WORLD - center;
	vec3 side = cross(axis, to_camera);
	float side_length = length(side);
	// Looking straight down the line leaves no sideways direction, so use the camera's right.
	if (side_length < 0.0001 * length(to_camera) + 0.000001) {
		side = normalize(INV_VIEW_MATRIX[0].xyz);
	} else {
		side /= side_length;
	}
	float half_width = max(abs(VERTEX.x), length(to_camera) * min_half_angle);
	world_pos = center + side * half_width * sign(VERTEX.x);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_pos, 1.0);
	across = sign(VERTEX.x);
	along = VERTEX.z + 0.5;
}

// With MSAA a pixel can be shaded from just outside the strip, where across goes past 1.
// pow() of a negative number is NaN, and the game's post shaders smear a NaN pixel into black blocks.
void fragment() {
	float edge = pow(clamp(1.0 - abs(across), 0.0, 1.0), edge_softness);
	float near_fade = smoothstep(near_fade_start, near_fade_end, distance(world_pos, CAMERA_POSITION_WORLD));
	ALBEDO = color.rgb;
	ALPHA = clamp(color.a * edge * mix(1.0, tail_alpha, clamp(along, 0.0, 1.0)) * near_fade, 0.0, 1.0);
}
