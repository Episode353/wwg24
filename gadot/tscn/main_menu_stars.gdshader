shader_type sky;

uniform int vertical_sections = 21;
uniform float star_size = 0.001;   // Brighter stars
uniform float star_falloff = 3.; // Softer brightness drop-off

uniform float margin = 0.05; // How far the star is from the edge of it's section. Avoids artifacts at the edge of sections.

vec2 get_partition(vec2 sky_coords) {
	// Separate the sphere into sections of roughly equal width and height.
	float y = sky_coords.y * 2. - 1.;
	float section_y = ceil(abs(y) * float(vertical_sections)) / float(vertical_sections);
	float horizontal_sections = max(4., ceil(float(vertical_sections) * 4. * cos(section_y * PI / 2.)));
	horizontal_sections = horizontal_sections > 0. ? horizontal_sections : 1.;
	return vec2(sky_coords.x * horizontal_sections, y * float(vertical_sections));
}

vec2 rand_vec2(vec2 xy) {
    float rand1 = fract(sin(dot(xy, vec2(11.9131, 81.2317))) *  57183.77193);
    float rand2 = fract(sin(dot(xy, vec2(16.8131, 91.2327))) *  37113.66193);
	return vec2(rand1, rand2) * ( 1. - margin * 2.) + margin;
}

float random_brightness(vec2 partition_index) {
    // Generate a random float in the range [0.1, 0.5] for brightness
    return fract(sin(dot(partition_index, vec2(34.123, 45.231))) * 43758.5453) * (0.5 - 0.1) + 0.5;
}

float star_brightness(vec2 sky_coords) {
    vec2 partitions = get_partition(sky_coords);
    vec2 partition_index = floor(partitions);
    vec2 inner_coord = fract(partitions);
    vec2 star_coord = rand_vec2(partition_index);
    float dist = length(inner_coord - star_coord);
    float random_brightness_factor = random_brightness(partition_index); // Get random brightness factor
    return pow(star_size / dist, star_falloff) * random_brightness_factor;
}



vec3 random_star_color(vec2 partition_index) {
    float r = fract(sin(dot(partition_index, vec2(12.9898, 78.233))) * 43758.5453);
    float g = fract(sin(dot(partition_index, vec2(39.3468, 11.1358))) * 23758.5453);
    float b = fract(sin(dot(partition_index, vec2(93.1432, 71.4123))) * 13758.5453);
    return vec3(r, g, b) * 0.01 + 0.01; // Adjust range to avoid very dim colors
}

void sky() {
    vec2 partitions = get_partition(SKY_COORDS);
    vec3 star_color = random_star_color(floor(partitions));
    float brightness = star_brightness(SKY_COORDS);
    COLOR = brightness * star_color;
}
