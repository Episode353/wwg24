shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_speed = 1.0;
uniform float ripple_scale = 40.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

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
