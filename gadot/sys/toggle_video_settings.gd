extends Node

# Graphics quality levels
enum GraphicsQuality { VERY_LOW, LOW, MEDIUM, HIGH }

var current_quality = GraphicsQuality.MEDIUM
var quality_names = ["VERY LOW", "LOW", "MEDIUM", "HIGH"]

# Data-driven quality configurations
var quality_configs = {
	GraphicsQuality.VERY_LOW: {
		"scaling_3d_scale": 0.45,
		"scaling_3d_mode": Viewport.SCALING_3D_MODE_BILINEAR,  # bilinear undersampling
		"vsync": DisplayServer.VSYNC_DISABLED,
		"msaa_3d": RenderingServer.VIEWPORT_MSAA_DISABLED,
		"msaa_2d": RenderingServer.VIEWPORT_MSAA_DISABLED,
		"screen_space_aa": RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED,
		"use_taa": false,
		"shadow_atlas_size": 32,
		"shadows_enabled": false,
		"particles_enabled": false,
		"light_intensity": 0.3,
		"unshaded_materials": true,
		"snap_pixels": true,
		"physics_picking": false,
		"audio_3d": false,
		"debanding": false,
		"texture_filter": Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST,
		"occlusion_culling": false,
		"environment": {
			"ssao": false, "ssil": false, "sdfgi": false, "ssr": false,
			"volumetric_fog": false, "glow": false, "adjustment": false,
		}
	},
	GraphicsQuality.LOW: {
		"scaling_3d_scale": 0.65,
		"scaling_3d_mode": Viewport.SCALING_3D_MODE_BILINEAR,
		"vsync": DisplayServer.VSYNC_ENABLED,
		"msaa_3d": RenderingServer.VIEWPORT_MSAA_DISABLED,
		"msaa_2d": RenderingServer.VIEWPORT_MSAA_DISABLED,
		"screen_space_aa": RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED,
		"use_taa": false,
		"shadow_atlas_size": 512,
		"shadows_enabled": false,
		"particles_enabled": true,
		"light_intensity": 0.8,
		"unshaded_materials": false,
		"snap_pixels": true,
		"physics_picking": true,
		"audio_3d": true,
		"debanding": false,
		"texture_filter": Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST,
		"occlusion_culling": true,
		"environment": {
			"ssao": false, "ssil": false, "sdfgi": false, "ssr": false,
			"volumetric_fog": false, "glow": false, "adjustment": false,
		}
	},
	GraphicsQuality.MEDIUM: {
		"scaling_3d_scale": 0.85,
		"scaling_3d_mode": Viewport.SCALING_3D_MODE_BILINEAR,
		"vsync": DisplayServer.VSYNC_ENABLED,
		"msaa_3d": RenderingServer.VIEWPORT_MSAA_2X,
		"msaa_2d": RenderingServer.VIEWPORT_MSAA_DISABLED,
		"screen_space_aa": RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA,
		"use_taa": false,
		"shadow_atlas_size": 1024,
		"shadows_enabled": "basic",  # Only directional lights
		"particles_enabled": true,
		"light_intensity": 1.0,
		"unshaded_materials": false,
		"snap_pixels": false,
		"physics_picking": true,
		"audio_3d": true,
		"debanding": true,
		"texture_filter": Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR,
		"occlusion_culling": true,
		"environment": {
			"ssao": true, "ssil": false, "sdfgi": false, "ssr": false,
			"volumetric_fog": false, "glow": false, "adjustment": false,
		}
	},
	GraphicsQuality.HIGH: {
		"scaling_3d_scale": 1.0,
		"scaling_3d_mode": Viewport.SCALING_3D_MODE_BILINEAR,
		"vsync": DisplayServer.VSYNC_ENABLED,
		"msaa_3d": RenderingServer.VIEWPORT_MSAA_8X,  # Maximum MSAA
		"msaa_2d": RenderingServer.VIEWPORT_MSAA_4X,
		"screen_space_aa": RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA,
		"use_taa": false,  # Enable TAA for highest quality
		"shadow_atlas_size": 4096,
		"shadows_enabled": true,  # All lights
		"particles_enabled": true,
		"light_intensity": 1.0,
		"unshaded_materials": false,
		"snap_pixels": false,
		"physics_picking": true,
		"audio_3d": true,
		"debanding": true,
		"texture_filter": Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"occlusion_culling": true,
		"environment": {
			"ssao": true, "ssil": true, "sdfgi": true, "ssr": false,
			"volumetric_fog": true, "glow": true, "adjustment": true,
		}
	}
}

func _ready():
	apply_graphics_settings(current_quality)
	print("Graphics Toggle System Initialized - Starting with " + quality_names[current_quality])

func _input(event):
	if Input.is_action_just_pressed("jump"):
		cycle_graphics_quality()

func cycle_graphics_quality():
	current_quality = (current_quality + 1) % GraphicsQuality.size()
	apply_graphics_settings(current_quality)
	print("Switched to " + quality_names[current_quality] + " graphics quality")

func apply_graphics_settings(quality: GraphicsQuality):
	var config = quality_configs[quality]
	var viewport = get_viewport()
	var viewport_rid = viewport.get_viewport_rid()
	var cfg = quality_configs[quality]  # Dictionary
	var vp = get_tree().root

	var rid = vp.get_viewport_rid()

	print("Applying " + quality_names[quality] + " quality settings…")

	# --- 3D Resolution Scaling :contentReference[oaicite:0]{index=0}
	# Set scaling mode and scale
	vp.scaling_3d_mode = cfg["scaling_3d_mode"]
	vp.scaling_3d_scale = cfg["scaling_3d_scale"]
	DisplayServer.window_set_vsync_mode(cfg["vsync"])
	print("Scaling mode:", vp.scaling_3d_mode, " | Scale:", vp.scaling_3d_scale)

	# --- Anti-Aliasing
	RenderingServer.viewport_set_msaa_3d(rid, cfg["msaa_3d"])
	RenderingServer.viewport_set_msaa_2d(rid, cfg["msaa_2d"])
	RenderingServer.viewport_set_screen_space_aa(rid, cfg["screen_space_aa"])
	vp.use_taa = cfg["use_taa"]
	
	# === Shadows ===
	RenderingServer.directional_shadow_atlas_set_size(config.shadow_atlas_size, false)
	apply_shadow_settings(config.shadows_enabled)
	
	# === Lighting & Effects ===
	set_light_intensity(config.light_intensity)
	toggle_particles(config.particles_enabled)
	toggle_unshaded_materials(config.unshaded_materials)
	
	# === Viewport Properties ===
	viewport.snap_2d_transforms_to_pixel = config.snap_pixels
	viewport.snap_2d_vertices_to_pixel = config.snap_pixels
	viewport.physics_object_picking = config.physics_picking
	viewport.audio_listener_enable_3d = config.audio_3d
	viewport.use_debanding = config.debanding
	viewport.canvas_item_default_texture_filter = config.texture_filter
	
	# === 3D Rendering ===
	RenderingServer.viewport_set_use_occlusion_culling(viewport_rid, config.occlusion_culling)
	
	# === Environment Effects ===
	apply_environment_settings(config.environment)
	
	print("✓ " + quality_names[quality] + " quality applied")


func apply_shadow_settings(shadows_enabled):
	var lights = get_tree().get_nodes_in_group("lights")
	for light in lights:
		if not (light is DirectionalLight3D or light is OmniLight3D or light is SpotLight3D):
			continue
			
		if shadows_enabled == false:
			light.shadow_enabled = false
		elif shadows_enabled == "basic":
			light.shadow_enabled = light is DirectionalLight3D  # Only directional lights
		else:  # shadows_enabled == true
			light.shadow_enabled = true

func set_light_intensity(intensity: float):
	var lights = get_tree().get_nodes_in_group("lights")
	for light in lights:
		if light is DirectionalLight3D or light is OmniLight3D or light is SpotLight3D:
			light.light_energy = intensity

func toggle_particles(enabled: bool):
	var particles = get_tree().get_nodes_in_group("particles")
	for particle in particles:
		if particle is GPUParticles3D or particle is GPUParticles2D:
			particle.emitting = enabled

func toggle_unshaded_materials(unshaded: bool):
	var meshes = get_tree().get_nodes_in_group("meshes")
	for mesh_instance in meshes:
		if mesh_instance is MeshInstance3D:
			var material = mesh_instance.get_surface_override_material(0)
			if material is StandardMaterial3D:
				material.flags_unshaded = unshaded

func apply_environment_settings(env_config):
	var cameras = get_tree().get_nodes_in_group("cameras")
	for camera in cameras:
		if not camera is Camera3D or not camera.environment:
			continue

		var env = camera.environment

		# --- SSAO ---
		env.ssao_enabled = env_config.ssao
		if env_config.ssao:
			env.ssao_radius = 0.8
			env.ssao_intensity = 1.0

		# --- SSIL ---
		env.ssil_enabled = env_config.ssil
		if env_config.ssil:
			env.ssil_radius = 5.0
			env.ssil_intensity = 1.0

		# --- SDFGI ---
		env.sdfgi_enabled = env_config.sdfgi
		if env_config.sdfgi:
			env.sdfgi_cascades = 4
			env.sdfgi_min_cell_size = 0.2

		# --- SSR ---
		env.ssr_enabled = env_config.ssr
		if env_config.ssr:
			env.ssr_max_steps = 64
			env.ssr_fade_in = 0.15
			env.ssr_fade_out = 2.0

		# --- Volumetric Fog ---
		env.volumetric_fog_enabled = env_config.volumetric_fog
		if env_config.volumetric_fog:
			env.volumetric_fog_density = 0.1
			env.volumetric_fog_albedo = Color.WHITE
			env.volumetric_fog_length = 64.0

		# --- Glow ---
		env.glow_enabled = env_config.glow
		if env_config.glow:
			env.glow_intensity = 0.8
			env.glow_strength = 1.0
			env.glow_levels = 0b0111000

		# --- Adjustment ---
		env.adjustment_enabled = env_config.adjustment

		# --- General ---
		env.tonemap_mode = env_config.tonemap
		env.background_mode = env_config.background
		env.ambient_light_energy = env_config.ambient_energy

		# --- Ambient Source ---
		if env_config.background == Environment.BG_SKY:
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		else:
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.reflection_source = Environment.REFLECTION_SOURCE_DISABLED
			env.background_color = Color(0.05, 0.05, 0.05)



# === PUBLIC API FUNCTIONS ===
func set_graphics_quality_very_low():
	current_quality = GraphicsQuality.VERY_LOW
	apply_graphics_settings(current_quality)

func set_graphics_quality_low():
	current_quality = GraphicsQuality.LOW
	apply_graphics_settings(current_quality)

func set_graphics_quality_medium():
	current_quality = GraphicsQuality.MEDIUM
	apply_graphics_settings(current_quality)

func set_graphics_quality_high():
	current_quality = GraphicsQuality.HIGH
	apply_graphics_settings(current_quality)

func set_graphics_quality(quality: GraphicsQuality):
	current_quality = quality
	Globals.exec("graphics_options = " +  str(quality))
	print("graphics_options =", quality)
	apply_graphics_settings(quality)
	self.selected = quality

func get_current_graphics_quality() -> GraphicsQuality:
	return current_quality

func get_current_graphics_quality_name() -> String:
	return quality_names[current_quality]

# === UI INTEGRATION ===
func _on_item_selected(index: int) -> void:
	if index >= 0 and index < GraphicsQuality.size():
		set_graphics_quality(index as GraphicsQuality)
		
	else:
		print("Invalid graphics quality index: ", index)
		set_graphics_quality_medium()
