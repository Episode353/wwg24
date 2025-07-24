// Based of carpenterblue's shader: https://godotshaders.com/shader/decal-shader-for-4-3-compatibility-renderer-transparency-support-no-repeat/
shader_type spatial;
render_mode cull_back;


uniform float blend_material : hint_range(0.0, 1.0, 0.01) = float(1.0);

group_uniforms albedo;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, repeat_disable;

group_uniforms normal_mapping;
uniform sampler2D normal_map_texture : hint_normal, repeat_disable;

group_uniforms height_mapping ;
uniform sampler2D texture_heightmap : source_color, repeat_disable;
uniform float heightmap_scale : hint_range(0.0, 64.0, 0.01);
uniform bool use_heightmap = false;
const int HEIGHTMAP_MAX_LAYERS = 16; 
const int HEIGHTMAP_MIN_LAYERS = 4; 

uniform float roughness : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0.0;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture;
const float CUBE_HALF_SIZE = 0.5;
const float DISTANCE = 0.1;

varying mat4 INV_MODEL_MATRIX;
varying float final_roughness;

void vertex(){
	INV_MODEL_MATRIX = inverse(MODEL_MATRIX);
}

// Credit: https://stackoverflow.com/questions/32227283/getting-world-position-from-depth-buffer-value
vec3 world_pos_from_depth(float depth, vec2 screen_uv, mat4 inverse_proj, mat4 inverse_view) {
	float z = depth;
	
	vec4 clipSpacePosition = vec4(screen_uv * 2.0 - 1.0, z, 1.0);
	vec4 viewSpacePosition = inverse_proj * clipSpacePosition;
	
	viewSpacePosition /= viewSpacePosition.w;
	
	vec4 worldSpacePosition = inverse_view * viewSpacePosition;
	
	return worldSpacePosition.xyz;
}

vec2 apply_heightmap(vec2 uvs, vec3 view_dir, float camera_distance){
	
	if ((use_heightmap == true) && (camera_distance < 5.0)) {
		float num_layers = mix(float(HEIGHTMAP_MAX_LAYERS), float(HEIGHTMAP_MIN_LAYERS), min(abs(dot(vec3(0.0, 0.0, 1.0), view_dir)) + min(camera_distance, 1.0), 1.0));
		float layer_depth = 1.0 / num_layers;
		float current_layer_depth = 0.0;
		vec2 p = view_dir.xy * heightmap_scale * 0.01;
		vec2 delta = p / num_layers;
		vec2 ofs = uvs;
		float depth = 1.0 - texture(texture_heightmap, ofs).r;
		
		float current_depth = 0.0;
		while (current_depth < depth) {
			ofs -= delta;
			depth = 1.0 - texture(texture_heightmap, ofs).r;
		
			current_depth += layer_depth;
		}
		
		vec2 prev_ofs = ofs + delta;
		float after_depth = depth - current_depth;
		float before_depth = (1.0 - texture(texture_heightmap, prev_ofs).r) - current_depth + layer_depth;
		
		float weight = after_depth / (after_depth - before_depth);
		ofs = mix(ofs, prev_ofs, weight);
		return ofs;
	}
	return uvs;
}

void fragment() {
	vec3 view_dir = normalize(normalize(-VERTEX + EYE_OFFSET) * mat3(TANGENT, -BINORMAL, NORMAL));
	
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 world_pos = world_pos_from_depth(depth, SCREEN_UV, INV_PROJECTION_MATRIX, (INV_VIEW_MATRIX));
	vec4 test_pos = (INV_MODEL_MATRIX * vec4(world_pos, 1.0));
	
	
	if (abs(test_pos.x) > CUBE_HALF_SIZE || abs(test_pos.y) > CUBE_HALF_SIZE || abs(test_pos.z) > DISTANCE){
		discard;
	}
	
	vec2 decal_uvs = (test_pos.xy * vec2(1.0, -1.0)) + 0.5;
	decal_uvs = apply_heightmap(decal_uvs, view_dir, distance(CAMERA_POSITION_WORLD, NODE_POSITION_WORLD));
	
	vec4 color = texture(albedo_texture, decal_uvs) * albedo_color;
	ALBEDO = color.rgb;
	ALPHA = color.a;
	
	vec4 normals_view_remapped = (texture(NORMAL_TEXTURE, SCREEN_UV));
	
	float new_blend_material = blend_material;
	
	if (use_heightmap == true) {
		new_blend_material *= max(dot(view_dir, normals_view_remapped.xyz), 0.0);
	}
	
	
	METALLIC = metallic;
	
	NORMAL = ((normals_view_remapped.xyz * 2.0) - 1.0);
	NORMAL_MAP = texture(normal_map_texture, UV).xyz;
	
	ROUGHNESS = mix(roughness, normals_view_remapped.w, new_blend_material);
	final_roughness = ROUGHNESS;
}