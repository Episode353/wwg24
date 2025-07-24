shader_type spatial;
render_mode cull_disabled, unshaded;

const vec3 TOP_COLOR = vec3(0.3529, 0.5098, 0.2157);    // rgb(90,130,55)
const vec3 BOTTOM_COLOR = vec3(0.0471, 0.0706, 0.0196); // rgb(12,18,5)


const float SWAY_STRENGTH = 0.2;
const float SWAY_SPEED = 1.5;
const float RANDOM_SCALE = 10.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec2 pos2D = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz;

	float angle = hash(pos2D) * 6.283185; // Random direction
	float strength = hash(pos2D * 1.3) * SWAY_STRENGTH;

	vec2 dir = vec2(cos(angle), sin(angle));

	// New: add a random phase offset and slight speed variation
	float phase_offset = hash(pos2D * 2.1) * 6.283185;
	float speed_variation = SWAY_SPEED * (0.8 + hash(pos2D * 3.3) * 0.4); // ±20%

	float offset = sin(TIME * speed_variation + phase_offset);

	VERTEX.xz += dir * offset * strength * UV.y;
}


void fragment() {
	// Vertical gradient from bottom (dark) to top (light)
	ALBEDO = mix(BOTTOM_COLOR, TOP_COLOR, UV.y);

	// Optional: correct normal for backfaces
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
