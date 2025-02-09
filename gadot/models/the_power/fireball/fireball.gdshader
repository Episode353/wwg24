shader_type spatial;
render_mode cull_disabled, blend_add, unshaded;

//speed of noise scroll
uniform float time_speed = 1.0;
//twisting motion of the flame
uniform float spin = 0.0;
//flame brightness
uniform float flame_brightness = 0.6;
uniform float color_intensity = 0.0;
//affects the frequency of the noise, higher values makes the flame streak vertically
uniform float horizontal_frequency = 1.0;
//affects the frequency of the noise, higher values makes the flame streak vertically(kinda ugly)
uniform float vertical_frequency = 1.0;
//overall size muliplier
uniform float size = -0.3;
//banding bias, affects total size, find balance of core size and size to find ideal band width and size
uniform float core_size = 1.0;
//noise texture
uniform sampler2D noise_texture;
//preset colors
uniform vec4 color1 : source_color = vec4(0.286, 0.22, 0.733, 1.0);  // Core of the flame (orange)
uniform vec4 color2 : source_color = vec4(0.98, 0.38, 0.34, 1.0);
uniform vec4 color3 : source_color = vec4(0.98, 0.95, 0.53, 1.0);
uniform vec4 color4 : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
// Time factor to animate the noise
	float time = TIME * time_speed;

// Calculate dot product between normal and view direction
	float normal_facing = dot(NORMAL, VIEW);
// Calculates the noise value
	float noise_value = texture(noise_texture,vec2(UV.x * horizontal_frequency + spin * (time /2.0), (UV.y * vertical_frequency) + time)).r;
// Adds the noise to the determined normal value
	normal_facing += (noise_value -0.5 + size) * 0.3;
// Band value to be split
	float band = normal_facing * 3.0 * core_size;
	vec4 flame_color = vec4(0,0,0,0);
	if (band <= 1.5) {
		ALPHA = 0.0;
	}
	else if(band <= 2.0){
// This modifies the colors within the bands to be influenced by the next inner band. Makes it look like there is bloom within the bands.
		flame_color = mix(color1, color2, -0.01 / (band-2.01));
	}
	else if (band <= 2.5) {
		flame_color = color2;
		flame_color = mix(color2, color3, -0.01 / (band-2.51));
	}
	else if (band <= 2.9) {
		flame_color = color3;
		flame_color = mix(color3, color4, -0.01 / (band-2.91));
	}
	else if (band >= 0.0) {
		flame_color = color4;

	}
//sets the final color using the brightness and color intensity, helps combat the transparency caused by blend_add
	ALBEDO = flame_brightness * (vec3(1.0, 1.0, 1.0) - (flame_color.xyz * -color_intensity)) * flame_color.xyz;
}
