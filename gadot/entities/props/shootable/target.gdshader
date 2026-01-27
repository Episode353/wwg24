shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// --- Fill + wire params ---
uniform vec4 fill_color      : source_color = vec4(0.06, 0.06, 0.09, 1.0);
uniform vec4 wire_color      : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float wire_thickness : hint_range(0.0, 5.0) = 1.25; // higher = thicker
uniform float wire_softness  : hint_range(0.0, 2.0) = 1.0;  // higher = softer edges
uniform float wire_strength  : hint_range(0.0, 1.0) = 1.0;  // 0 disables lines

// --- Your motion params ---
uniform float shake_power = 0.02;
uniform float shake_rate : hint_range(0.0, 1.0) = 0.5;
uniform float shake_speed = 5.0;
uniform float shake_block_size = 25.0;

uniform bool spin_enabled = false;
uniform float spin_speed = 1.0;
uniform int spin_axis : hint_enum("X,Y,Z") = 1;

uniform bool wobble_enabled = false;
uniform float wobble_amount = 0.03;
uniform float wobble_speed = 2.0;

// --- Varyings ---
varying float g_enable;
varying vec3  v_bary;

float n1(float x) { return fract(sin(x * 91.32) * 43758.5453); }

mat3 rotationX(float a) {
	float c = cos(a), s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}
mat3 rotationY(float a) {
	float c = cos(a), s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}
mat3 rotationZ(float a) {
	float c = cos(a), s = sin(a);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

void vertex() {
	float t = mod(TIME, 5.0);

	// ---- barycentric coords per triangle vertex ----
	// NOTE: Works best when mesh is NON-INDEXED (unique vertices per face).
	int m = int(VERTEX_ID) % 3;
	v_bary = (m == 0) ? vec3(1.0, 0.0, 0.0)
	       : (m == 1) ? vec3(0.0, 1.0, 0.0)
	                  : vec3(0.0, 0.0, 1.0);

	// Spin
	if (spin_enabled) {
		float tspin = TIME * spin_speed;

		mat3 rot = rotationX(tspin) * float(spin_axis == 0) +
		           rotationY(tspin) * float(spin_axis == 1) +
		           rotationZ(tspin) * float(spin_axis == 2);

		VERTEX = rot * VERTEX;
	}

	// Wobble
	if (wobble_enabled) {
		float wob = sin(TIME * wobble_speed) * wobble_amount * 0.05;
		VERTEX += vec3(0.0, wob, 0.0);
	}

	// Shake enable gate
	float flicker = n1(floor(t * shake_speed));
	g_enable = float(flicker < shake_rate);

	float block = floor(VERTEX.y * shake_block_size) / shake_block_size;
	float shift = (n1(block + t) - 0.5) * shake_power * g_enable;
	VERTEX.x += shift * 0.25;
}

float wire_mask_from_bary(vec3 bary, float thickness, float softness) {
	// Distance to nearest triangle edge in barycentric space
	float d = min(bary.x, min(bary.y, bary.z));

	// Screen-space adaptive width (anti-aliased)
	float fw = fwidth(d);
	float w  = fw * max(thickness, 0.0001);
	float s  = fw * max(softness, 0.0001);

	// 1 at edges, 0 in interior
	return 1.0 - smoothstep(w, w + s, d);
}

void fragment() {
	float t = mod(TIME, 5.0);
	float block = floor(UV.y * shake_block_size) / shake_block_size;
	float shift = (n1(block + t) - 0.5) * shake_power * g_enable;

	// Base fill
	vec3 base = fill_color.rgb;

	// Your “flicker” / enable coloring (optional)
	base = mix(base, base * 1.05, g_enable);

	// Wireframe overlay mask
	float w = wire_mask_from_bary(v_bary, wire_thickness, wire_softness) * wire_strength;

	// Slight pulse from your shift (optional)
	vec3 wc = mix(wire_color.rgb, wire_color.rgb * 1.1, g_enable);
	wc *= 1.0 + shift * 2.0;

	ALBEDO = mix(base, wc, w);
}
