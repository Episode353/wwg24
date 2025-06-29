shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

// IMPACT POINTS CAN BE MANIPULATED WITH GDSCRIPT. (HIT POINTS, FOR EXAMPLE)
// TO HIDE ANY POINT, JUST MOVE IT FAR ENOUGH OUT OF THE WAY LOL
// MAKE UNIQUE MATERIALS TO HAVE SEPERATE POINTS PER GLASS OBJECT

//PARAMS
uniform bool shatter = true; //activate shatter
uniform float fracture_scale = 1.5; // Controls cell size
uniform float roughness : hint_range(0.0, 1.0) = 0.675;
uniform float transparency : hint_range(0.0, 1.0) = 0.675;
uniform float normal_offset_multiplier : hint_range(0.0, 1.0) = 0.375; // Multiplier to control normal intensity and angle
uniform float glass_tint : hint_range(0.0,1.0) = 0.675;

uniform float edge_thickness : hint_range(0.0675, 0.25);          // How thick the Fracture edges appear
uniform float impact_range : hint_range(0.0, 999.0) = 1.25; // How far the impact effect spreads (deletes cells)
uniform float compression_strength : hint_range(-1.125, 0.0) = -1.125;    // How much Voronoi scales down near impact

// Impact points: array of 3 world-space impact points
uniform vec3 impact_points[3]; //3 points MAX. no more, no less


// Hash function for randomness
float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// Get deterministic feature point of a Voronoi cell
vec3 get_feature_point(vec3 cell) {
	vec3 f = cell + vec3(hash(cell.xyz), hash(cell.yzx), hash(cell.zxy));
	return f;
}

// Compute 3D Voronoi edges & mark cell for discard if any impact point is near.
// Also output the cell's "center" (nearest feature point) via out parameter.
vec3 voronoi_color(vec3 world_pos, out bool should_discard, out vec3 cell_feature) {
	vec3 cell = floor(world_pos);
	vec3 feature = get_feature_point(cell);

	float minDist2 = 1e10;
	float secondMinDist2 = 1e10;
	vec3 nearestFeature = vec3(0.0);

	// Search 3x3x3 neighborhood for nearest feature points
	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec3 neighbor = cell + vec3(float(i), float(j), float(k));
				vec3 f = get_feature_point(neighbor);
				vec3 diff = world_pos - f;
				float d2 = dot(diff, diff);

				if (d2 < minDist2) {
					secondMinDist2 = minDist2;
					minDist2 = d2;
					nearestFeature = f;
				} else if (d2 < secondMinDist2) {
					secondMinDist2 = d2;
				}
			}
		}
	}
	// Compute edge thickness value
	float edgeVal = smoothstep(0.0, edge_thickness, secondMinDist2 - minDist2);
	// Save the cell's center (feature)
	cell_feature = nearestFeature;
	// Loop over all impact points: if the cell's nearest feature is within range of any impact, mark for discard.
	should_discard = false;
	for (int i = 0; i < 3; i++) {
		if (length(nearestFeature - impact_points[i] * fracture_scale) < impact_range * fracture_scale) {
			should_discard = true;
			break;
		}
	}
	return should_discard ? vec3(0.0) : vec3(edgeVal);
}


// Bump-to-Normal function
vec3 bump_to_normal(vec3 voronoi_tex, float bump_strength) {
	// We need to perturb the normal based on the texture
	// First, calculate the texture's derivative (bump) in x and y directions
	vec2 dX = dFdx(voronoi_tex.xy);
	vec2 dY = dFdy(voronoi_tex.xy);
	// Convert these derivatives into a bump map
	float bump_x = dX.x * bump_strength;
	float bump_y = dY.y * bump_strength;
	// Use the derivatives to perturb the normal from the surface
	// We assume a flat surface with normal (0.0, 0.0, 1.0)
	vec3 normal = normalize(vec3(bump_x, bump_y, 1.0));
	// Normalize the resulting normal to ensure it's a unit vector
	return normalize(normal);
}



// Vertex Shader
varying vec3 world_vertex;

void vertex() {
	if (shatter){
		world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}
}

// Fragment Shader
void fragment() {
	if (shatter){

		// Determine the nearest impact for compression
		int nearest_index = 0;
		float min_dist = 1e10;
		for (int i = 0; i < 3; i++) {
		float d = length(world_vertex - impact_points[i]);
		if (d < min_dist) {
			min_dist = d;
			nearest_index = i;
			}
		}
		vec3 nearestImpact = impact_points[nearest_index];

		// Calculate compression factor: cells closer to the impact compress more (i.e. become smaller)
		float scale_factor = 1.0 - clamp((impact_range - min_dist) / impact_range, 0.0, 1.0) * compression_strength;

		// Compress world space coordinates toward the nearest impact point
		vec3 compressed_pos = mix(world_vertex, nearestImpact, 1.0 - scale_factor);

		// Convert to Voronoi space by applying the global voronoi_scale
		vec3 scaled_world_pos = compressed_pos * fracture_scale;

		// Compute Voronoi color and retrieve the cell's feature point
		bool should_discard = true;
		vec3 cell_feature;
		vec3 voronoi_tex = voronoi_color(scaled_world_pos, should_discard, cell_feature);
		voronoi_tex*=pow(voronoi_tex,vec3(0.01));
		if (should_discard) {
			discard;
		}

		// --- Generate a flat normal per Voronoi cell based on its feature point ---
		vec3 random_normal = normalize(vec3(
			hash(cell_feature + vec3(1.0)),
			hash(cell_feature + vec3(2.0)),
			hash(cell_feature + vec3(3.0))
		));

		// --- Adjust the normal direction using the multiplier ---
		vec3 adjusted_normal = mix(vec3(0.0, 0.0, 1.0), random_normal, normal_offset_multiplier);

		// --- Normalize the result ---
		vec3 shattered_normal = normalize(adjusted_normal);

		// --- Calculate edge bump normal using Voronoi edge ---
		vec3 edge_normal = bump_to_normal(voronoi_tex,normal_offset_multiplier);
		vec3 final_normal = normalize(shattered_normal + edge_normal);

		//FINALIZING THE (SHATTERED) MATERIAL VALUES
		//MOST OF THIS IS A BUNCH OF DIARRHEA MATH. WASN'T EVEN TRYING.
		METALLIC = 1.0;
		ROUGHNESS = clamp((normal_offset_multiplier*0.375) / voronoi_tex.r*0.0125,0.0675,0.5);
		ROUGHNESS *= roughness;
		SPECULAR = 1.0;
		ALPHA = transparency;
		NORMAL_MAP += final_normal*NORMAL;
		ALBEDO = vec3(glass_tint)+1.0;
		ALBEDO -= voronoi_tex*0.5;
	}else{

		//FINALIZING THE PLAIN GLASS MATERIAL VALUES
		METALLIC = 1.0;
		ROUGHNESS = roughness*0.125;
		SPECULAR = 1.0;
		ALPHA = transparency;
		ALBEDO = vec3(glass_tint)+0.4;
	}
}
