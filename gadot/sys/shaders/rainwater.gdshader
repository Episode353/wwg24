// Transparent foggy water shader with ripples
// Shows blurred background through transparent water surface
// CC0, modified from shadecore_dev's original shader

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, depth_test_disabled, diffuse_burley, specular_schlick_ggx;

// Screen texture uniform for Godot 4.4+
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

group_uniforms RippleEffect;

/** Max ripple travel distance. Integer. [color=red]High performance impact.[/color] */
uniform float ripple_max_radius : hint_range(0.0, 5.0, 1.0) = 2.0;

/** Ripple scale modifier. */
uniform float ripple_scale : hint_range(0.1, 10.0, 0.1) = 1.0;

/** Ripple travel speed. */
uniform float ripple_speed : hint_range(0.1, 2.0, 0.01) = 0.5;

/** Ripple intensity/strength. */
uniform float ripple_intensity : hint_range(0.01, 2.0, 0.01) = 0.5;

group_uniforms Transparency;

/** Overall transparency of the water surface. */
uniform float water_opacity : hint_range(0.0, 1.0, 0.01) = 0.3;

/** Blur strength for background. */
uniform float blur_strength : hint_range(0.0, 0.02, 0.001) = 0.008;

/** Fog tint color for the blurred background. */
uniform vec3 fog_tint : source_color = vec3(0.7, 0.8, 0.9);

/** How much fog tint to apply. */
uniform float fog_strength : hint_range(0.0, 1.0, 0.01) = 0.4;

group_uniforms Colors;

/** Water surface tint color. */
uniform vec3 water_tint : source_color = vec3(0.4, 0.7, 1.0);

/** Ripple highlight color (wave peaks). */
uniform vec3 ripple_bright_color : source_color = vec3(0.9, 0.95, 1.0);

/** Ripple shadow color (wave troughs). */
uniform vec3 ripple_dark_color : source_color = vec3(0.2, 0.4, 0.6);

group_uniforms SurfaceProperties;

/** Normal distortion strength for refraction effect. */
uniform float distortion_strength : hint_range(0.0, 0.1, 0.001) = 0.02;

/** Surface roughness. */
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.1;

const float HASHSCALE1 = 0.1031;
const vec3 HASHSCALE3 = vec3(0.1031, 0.1030, 0.0973);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * HASHSCALE1);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * HASHSCALE3);
	p3 += dot(p3, p3.yzx+19.19);
	return fract((p3.xx+p3.yz)*p3.zy);
}

// Returns ripple strength for color mixing
float get_ripple_strength(vec2 world_pos) {
	float resolution = 10.0 * exp2(-3.0);
	vec2 uv = world_pos / ripple_scale * resolution;
	vec2 p0 = floor(uv);

	float total_ripple_effect = 0.0;
	
	for (float j = -ripple_max_radius; j <= ripple_max_radius; ++j)
	{
		for (float i = -ripple_max_radius; i <= ripple_max_radius; ++i)
		{
			vec2 pi = p0 + vec2(i, j);
			vec2 hsh = hash22(pi);
			vec2 p = pi + hash22(hsh);

			float t = fract(ripple_speed * TIME + hash12(hsh));
			vec2 v = p - uv;
			float d = length(v) - (float(ripple_max_radius) + 1.0) * t;

			// Create wave pattern
			float wave = sin(31.0 * d) * smoothstep(-0.6, -0.3, d) * smoothstep(0., -0.3, d);
			float wave_strength = wave * (1.0 - t) * (1.0 - t);
			
			total_ripple_effect += wave_strength;
		}
	}
	
	total_ripple_effect /= float((ripple_max_radius * 2.0 + 1.0) * (ripple_max_radius * 2.0 + 1.0));

	// Dynamic intensity
	float dynamic_intensity = mix(0.5, ripple_intensity, smoothstep(0.1, 0.6, abs(fract(0.05 * TIME + 0.5) * 2.0 - 1.0)));
	
	return total_ripple_effect * dynamic_intensity * 20.0; // Massively amplified
}

vec2 get_ripple_distortion(vec2 world_pos) {
	float resolution = 10.0 * exp2(-3.0);
	vec2 uv = world_pos / ripple_scale * resolution;
	vec2 p0 = floor(uv);

	vec2 distortion = vec2(0.0);
	
	for (float j = -ripple_max_radius; j <= ripple_max_radius; ++j)
	{
		for (float i = -ripple_max_radius; i <= ripple_max_radius; ++i)
		{
			vec2 pi = p0 + vec2(i, j);
			vec2 hsh = hash22(pi);
			vec2 p = pi + hash22(hsh);

			float t = fract(ripple_speed * TIME + hash12(hsh));
			vec2 v = p - uv;
			float d = length(v) - (float(ripple_max_radius) + 1.0) * t;

			float wave = sin(31.0 * d) * smoothstep(-0.6, -0.3, d) * smoothstep(0., -0.3, d);
			float wave_strength = wave * (1.0 - t) * (1.0 - t);
			
			if (length(v) > 0.0) {
				distortion += normalize(v) * wave_strength * 0.1;
			}
		}
	}
	
	distortion /= float((ripple_max_radius * 2.0 + 1.0) * (ripple_max_radius * 2.0 + 1.0));
	distortion *= ripple_intensity * distortion_strength * 5.0; // Much stronger distortion
	
	return distortion;
}

varying vec3 world_position;
varying vec4 screen_position;

void vertex() {
	world_position = VERTEX;
	screen_position = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	// Get ripple effects
	float ripple_effect = get_ripple_strength(world_position.xz);
	vec2 ripple_distortion = get_ripple_distortion(world_position.xz);
	
	// Calculate screen UV for background sampling
	vec2 screen_uv = screen_position.xy / screen_position.w;
	screen_uv = screen_uv * 0.5 + 0.5;
	
	// Apply ripple distortion to screen sampling
	vec2 distorted_uv = screen_uv + ripple_distortion;
	
	// Sample background with blur effect
	vec3 background_color = vec3(0.0);
	float blur_samples = 9.0;
	float blur_step = blur_strength / blur_samples;
	
	// Simple box blur
	for (float x = -4.0; x <= 4.0; x += 1.0) {
		for (float y = -4.0; y <= 4.0; y += 1.0) {
			vec2 offset = vec2(x, y) * blur_step;
			background_color += textureLod(SCREEN_TEXTURE, distorted_uv + offset, 0.0).rgb;
		}
	}
	background_color /= (blur_samples * blur_samples);
	
	// Apply fog tint to background
	background_color = mix(background_color, fog_tint, fog_strength);
	
	// Create EXTREMELY visible water surface color with ripples
	float color_mask = sin(ripple_effect * 4.0) * 2.0; // Double frequency and amplitude
	color_mask = clamp(color_mask, -2.0, 2.0);
	
	vec3 surface_color;
	if (color_mask > 0.3) {
		// Much more dramatic bright areas
		float bright_factor = smoothstep(0.3, 2.0, color_mask);
		surface_color = mix(water_tint, ripple_bright_color, bright_factor * 1.0);
	} else if (color_mask < -0.3) {
		// Much more dramatic dark areas
		float dark_factor = smoothstep(-2.0, -0.3, color_mask);
		surface_color = mix(ripple_dark_color, water_tint, dark_factor * 0.5);
	} else {
		surface_color = water_tint;
	}
	
	// Add extreme contrast based on ripple activity
	float ripple_contrast = clamp(abs(ripple_effect) * 2.0, 0.0, 1.0);
	if (ripple_contrast > 0.1) {
		// Very aggressive color mixing for high visibility
		vec3 extreme_color = color_mask > 0.0 ? ripple_bright_color : ripple_dark_color;
		surface_color = mix(surface_color, extreme_color, ripple_contrast * 0.8);
	}
	
	// Mix background with water surface
	vec3 final_color = mix(background_color, surface_color, water_opacity);
	
	// Add slight transparency variation based on ripples
	float ripple_alpha_variation = abs(ripple_effect) * 0.1;
	float final_alpha = clamp(water_opacity + ripple_alpha_variation, 0.0, 1.0);
	
	ALBEDO = final_color;
	ALPHA = final_alpha;
	ROUGHNESS = roughness;
}