extends Node

# Graphics quality levels
enum GraphicsQuality { VERY_LOW, LOW, MEDIUM, HIGH }

var current_quality = GraphicsQuality.MEDIUM
var quality_names = ["VERY LOW", "LOW", "MEDIUM", "HIGH"]

# Data-driven quality configurations
var quality_configs = {
	GraphicsQuality.VERY_LOW: {
		"scaling_3d_scale": 0.5,
		"scaling_3d_mode": Viewport.SCALING_3D_MODE_BILINEAR,
		"vsync": DisplayServer.VSYNC_DISABLED,
		"msaa_3d": RenderingServer.VIEWPORT_MSAA_DISABLED,
		"msaa_2d": RenderingServer.VIEWPORT_MSAA_DISABLED,
		"screen_space_aa": RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED,
		"use_taa": false,
		"shadow_atlas_size": 256,
		"particles_enabled": false,
		"snap_pixels": true,
		"physics_picking": false,
		"audio_3d": false,
		"debanding": false,
		"texture_filter": Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST,
		"occlusion_culling": false,
	},
	GraphicsQuality.LOW: {
		"scaling_3d_scale": 0.65,
		"scaling_3d_mode": Viewport.SCALING_3D_MODE_BILINEAR,
		"vsync": DisplayServer.VSYNC_DISABLED,
		"msaa_3d": RenderingServer.VIEWPORT_MSAA_DISABLED,
		"msaa_2d": RenderingServer.VIEWPORT_MSAA_DISABLED,
		"screen_space_aa": RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED,
		"use_taa": false,
		"shadow_atlas_size": 8192,
		"particles_enabled": true,
		"snap_pixels": true,
		"physics_picking": true,
		"audio_3d": true,
		"debanding": false,
		"texture_filter": Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST,
		"occlusion_culling": true,
	},
	GraphicsQuality.MEDIUM: {
		"scaling_3d_scale": 0.75,
		"scaling_3d_mode": Viewport.SCALING_3D_MODE_BILINEAR,
		"vsync": DisplayServer.VSYNC_DISABLED,
		"msaa_3d": RenderingServer.VIEWPORT_MSAA_2X,
		"msaa_2d": RenderingServer.VIEWPORT_MSAA_DISABLED,
		"screen_space_aa": RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA,
		"use_taa": false,
		"shadow_atlas_size": 1024,
		"particles_enabled": true,
		"snap_pixels": false,
		"physics_picking": true,
		"audio_3d": true,
		"debanding": true,
		"texture_filter": Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR,
		"occlusion_culling": true,
	},
	GraphicsQuality.HIGH: {
		"scaling_3d_scale": 1.0,
		"scaling_3d_mode": Viewport.SCALING_3D_MODE_BILINEAR,
		"vsync": DisplayServer.VSYNC_DISABLED,
		"msaa_3d": RenderingServer.VIEWPORT_MSAA_8X,
		"msaa_2d": RenderingServer.VIEWPORT_MSAA_4X,
		"screen_space_aa": RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA,
		"use_taa": false,
		"shadow_atlas_size": 4096,
		"particles_enabled": true,
		"snap_pixels": false,
		"physics_picking": true,
		"audio_3d": true,
		"debanding": true,
		"texture_filter": Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"occlusion_culling": true,
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
	var cfg = quality_configs[quality]
	
	print("Applying " + quality_names[quality] + " quality settings…")

	# Global settings (apply once)
	DisplayServer.window_set_vsync_mode(cfg["vsync"])
	RenderingServer.directional_shadow_atlas_set_size(cfg.shadow_atlas_size, false)
	
	# Apply viewport settings efficiently (single pass)
	apply_all_viewport_settings(cfg)
	
	# Only apply particle settings (lightweight)
	toggle_particles(cfg.particles_enabled)
	
	print("✓ " + quality_names[quality] + " quality applied")

func apply_all_viewport_settings(cfg: Dictionary):
	"""Efficiently apply settings to all viewports in a single pass"""
	var viewports_to_process = []
	
	# Add root viewport
	viewports_to_process.append(get_tree().root)
	
	# Find all SubViewports in one efficient search
	collect_subviewports(get_tree().root, viewports_to_process)
	
	# Apply settings to all collected viewports
	for viewport in viewports_to_process:
		apply_viewport_settings(viewport, cfg)

func collect_subviewports(node: Node, viewport_list: Array):
	"""Efficiently collect all SubViewports without redundant processing"""
	if node is SubViewport and node != get_tree().root:
		viewport_list.append(node)
	
	for child in node.get_children():
		collect_subviewports(child, viewport_list)

func apply_viewport_settings(viewport: Viewport, cfg: Dictionary):
	var rid = viewport.get_viewport_rid()
	
	# --- 3D Resolution Scaling ---
	viewport.scaling_3d_mode = cfg["scaling_3d_mode"]
	viewport.scaling_3d_scale = cfg["scaling_3d_scale"]
	
	# --- Anti-Aliasing ---
	RenderingServer.viewport_set_msaa_3d(rid, cfg["msaa_3d"])
	RenderingServer.viewport_set_msaa_2d(rid, cfg["msaa_2d"])
	RenderingServer.viewport_set_screen_space_aa(rid, cfg["screen_space_aa"])
	viewport.use_taa = cfg["use_taa"]
	
	# --- Viewport Properties ---
	viewport.snap_2d_transforms_to_pixel = cfg["snap_pixels"]
	viewport.snap_2d_vertices_to_pixel = cfg["snap_pixels"]
	viewport.physics_object_picking = cfg["physics_picking"]
	viewport.audio_listener_enable_3d = cfg["audio_3d"]
	viewport.use_debanding = cfg["debanding"]
	viewport.canvas_item_default_texture_filter = cfg["texture_filter"]
	
	# --- 3D Rendering ---
	RenderingServer.viewport_set_use_occlusion_culling(rid, cfg["occlusion_culling"])

func toggle_particles(enabled: bool):
	"""Lightweight particle toggling"""
	var particles = get_tree().get_nodes_in_group("particles")
	for particle in particles:
		if particle is GPUParticles3D or particle is GPUParticles2D:
			particle.emitting = enabled

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
