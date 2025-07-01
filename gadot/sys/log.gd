extends Node

var target_fps: int = Engine.max_fps if Engine.max_fps > 0 else 60  # Fallback to 60 if unlimited
const HISTORY_NUM_FRAMES = 120  # Keep 120 frames of history for better analysis
const LONG_HISTORY_NUM_FRAMES = 600  # Keep 10 seconds at 60fps for long-term analysis

# Color definitions for performance categorization
@export var bad_color: Color = Color.RED
@export var warning_color: Color = Color.YELLOW  
@export var good_color: Color = Color.GREEN
@export var excellent_color: Color = Color.CYAN

# Node references with null checking
@onready var nodes_counter: Label = $"../CanvasLayer/HUD/LOG/NodesCount"
@onready var fps_counter: Label = $"../CanvasLayer/HUD/LOG/FPSCount"
@onready var info: Label = $"../CanvasLayer/HUD/LOG/Info"
@onready var frame_time: Label = $"../CanvasLayer/HUD/LOG/FrameTime"

# Performance tracking variables
var frames_in_time: int = 0
var timer: float = 0
var info_update_timer: float = 0
var info_update_interval: float = 0.5  # Update info display every 0.5 seconds
var last_tick: int = 0

# Frame history for statistical analysis
var frame_history_total: Array[float] = []
var frame_history_cpu: Array[float] = []
var frame_history_gpu: Array[float] = []
var fps_history: Array[float] = []

# Long-term performance tracking
var long_frame_history: Array[float] = []
var performance_score_history: Array[float] = []

# Performance averages and statistics
var frametime_avg: float = 16.67
var frametime_cpu_avg: float = 8.0
var frametime_gpu_avg: float = 8.0
var frames_per_second: float = 60.0

# Advanced performance metrics
var frame_time_percentile_1: float = 0.0
var frame_time_percentile_95: float = 0.0
var frame_time_percentile_99: float = 0.0
var frame_consistency_score: float = 100.0
var performance_stability_score: float = 100.0
var overall_performance_score: float = 100.0

# Memory tracking
var memory_trend: Array[float] = []
var peak_memory_usage: float = 0.0
var memory_growth_rate: float = 0.0

# Rendering efficiency metrics
var draw_call_efficiency: float = 100.0
var triangle_per_draw_call: float = 0.0
var overdraw_estimation: float = 1.0

# Physics performance metrics
var physics_load_2d: float = 0.0
var physics_load_3d: float = 0.0
var physics_efficiency_2d: float = 100.0
var physics_efficiency_3d: float = 100.0

# Audio performance metrics
var audio_performance_score: float = 100.0
var audio_latency_trend: Array[float] = []

# Custom performance warnings
var performance_warnings: Array[String] = []
var critical_issues: Array[String] = []

# Color gradient for smooth performance visualization
var frame_time_gradient: Gradient = Gradient.new()

# Thread for expensive operations
var info_thread: Thread = Thread.new()
var system_info_loaded: bool = false
var base_system_info: String = ""

# Performance analysis settings
var enable_advanced_analysis: bool = true
var enable_performance_warnings: bool = true
var warning_threshold_fps: float = 0.8  # Warn if below 80% of target FPS
var critical_threshold_fps: float = 0.5  # Critical if below 50% of target FPS

# Logging settings
var enable_logging: bool = true
var log_file_path: String = "user://logs/performance.log"
var logging_timer: float = 0.0
var logging_interval: float = 5.0  # Log every 5 seconds
var log_file_initialized: bool = false

# Dynamic target FPS functions
func get_current_target_fps() -> int:
	# Update target_fps to current Engine.max_fps if it's set, otherwise use 60 as fallback
	if Engine.max_fps > 0:
		target_fps = Engine.max_fps
	else:
		target_fps = 60  # Fallback when max_fps is unlimited (0)
	return target_fps

func get_current_target_frame_time() -> float:
	return 1.0 / get_current_target_fps() * 1000.0

func _ready():
	# Initialize color gradient (inspired by the debug menu)
	setup_color_gradient()
	
	# Initialize frame history arrays
	fps_history.resize(HISTORY_NUM_FRAMES)
	frame_history_total.resize(HISTORY_NUM_FRAMES)
	frame_history_cpu.resize(HISTORY_NUM_FRAMES)
	frame_history_gpu.resize(HISTORY_NUM_FRAMES)
	long_frame_history.resize(LONG_HISTORY_NUM_FRAMES)
	performance_score_history.resize(HISTORY_NUM_FRAMES)
	memory_trend.resize(HISTORY_NUM_FRAMES)
	audio_latency_trend.resize(HISTORY_NUM_FRAMES)
	
	# Setup custom performance monitors
	setup_custom_monitors()
	
	# Debug: Check if all nodes exist
	print("=== NODE PATH DEBUG ===")
	print("nodes_counter: ", nodes_counter)
	print("frame_time: ", frame_time)
	print("fps_counter: ", fps_counter)
	print("info: ", info)
	print("=====================")
	
	# Warn about missing nodes
	if not nodes_counter:
		print("WARNING: nodes_counter node not found")
	if not frame_time:
		print("WARNING: frame_time node not found")
	if not fps_counter:
		print("WARNING: fps_counter node not found")
	if not info:
		print("WARNING: info node not found")
	
	# Enable GPU/CPU timing measurements
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	
	# Load system information in background thread
	if info:
		info.text = "Loading comprehensive system information..."
		info_thread.start(load_system_info_threaded)
	
	# Initialize last_tick
	last_tick = Time.get_ticks_usec()
	
	# Initialize logging system
	if enable_logging:
		initialize_log_file()

func setup_custom_monitors():
	# Add custom performance monitors
	Performance.add_custom_monitor("Performance/FrameConsistency", Callable(self, "get_frame_consistency_score"))
	Performance.add_custom_monitor("Performance/OverallScore", Callable(self, "get_overall_performance_score"))
	Performance.add_custom_monitor("Performance/StabilityScore", Callable(self, "get_performance_stability_score"))
	Performance.add_custom_monitor("Memory/GrowthRate", Callable(self, "get_memory_growth_rate"))
	Performance.add_custom_monitor("Memory/PeakUsage", Callable(self, "get_peak_memory_usage"))
	Performance.add_custom_monitor("Rendering/TrianglesPerDrawCall", Callable(self, "get_triangles_per_draw_call"))
	Performance.add_custom_monitor("Rendering/DrawCallEfficiency", Callable(self, "get_draw_call_efficiency"))
	Performance.add_custom_monitor("Physics/Load2D", Callable(self, "get_physics_load_2d"))
	Performance.add_custom_monitor("Physics/Load3D", Callable(self, "get_physics_load_3d"))
	Performance.add_custom_monitor("Audio/PerformanceScore", Callable(self, "get_audio_performance_score"))

# Custom monitor getter functions
func get_frame_consistency_score() -> float:
	return frame_consistency_score

func get_overall_performance_score() -> float:
	return overall_performance_score

func get_performance_stability_score() -> float:
	return performance_stability_score

func get_memory_growth_rate() -> float:
	return memory_growth_rate

func get_peak_memory_usage() -> float:
	return peak_memory_usage

func get_triangles_per_draw_call() -> float:
	return triangle_per_draw_call

func get_draw_call_efficiency() -> float:
	return draw_call_efficiency

func get_physics_load_2d() -> float:
	return physics_load_2d

func get_physics_load_3d() -> float:
	return physics_load_3d

func get_audio_performance_score() -> float:
	return audio_performance_score

func setup_color_gradient():
	# Set up color gradient similar to the debug menu
	# Red (bad) -> Yellow (warning) -> Green (good) -> Cyan (excellent)
	frame_time_gradient.set_color(0, Color(0.937, 0.267, 0.267))    # Red
	frame_time_gradient.set_color(1, Color(0.220, 0.741, 0.973))    # Light blue
	frame_time_gradient.add_point(0.3333, Color(0.980, 0.800, 0.082))  # Yellow
	frame_time_gradient.add_point(0.6667, Color(0.502, 0.886, 0.373))  # Green

func load_system_info_threaded():
	# Disable thread safety checks for this thread (Godot 4.1+)
	if Engine.get_version_info()["hex"] >= 0x040100:
		Thread.set_thread_safety_checks_enabled(false)
	
	# Generate comprehensive system information
	base_system_info = generate_base_system_info()
	
	# Update info label on main thread
	call_deferred("update_info_label_complete")

func generate_base_system_info() -> String:
	var info_text = "=== SYSTEM HARDWARE INFO ===\n"
	
	# CPU Information
	var cpu_name = OS.get_processor_name().replace("(R)", "").replace("(TM)", "")
	info_text += "CPU: %s (%d threads)\n" % [cpu_name, OS.get_processor_count()]
	
	# OS Information
	var arch_string = "64-bit" if OS.has_feature("64") else "32-bit"
	var build_type = ""
	if OS.has_feature("editor"):
		build_type = "editor"
	elif OS.has_feature("debug"):
		build_type = "debug"
	else:
		build_type = "release"
	
	info_text += "OS: %s %s (%s)\n" % [OS.get_name(), arch_string, build_type]
	
	# Graphics Information
	var gpu_vendor = RenderingServer.get_video_adapter_vendor()
	var gpu_name = RenderingServer.get_video_adapter_name()
	var gpu_api = RenderingServer.get_video_adapter_api_version()
	
	# Clean up GPU name display
	if gpu_vendor.trim_suffix(" Corporation") in gpu_name:
		info_text += "GPU: %s (%s)\n" % [gpu_name.trim_suffix("/PCIe/SSE2"), gpu_api]
	else:
		info_text += "GPU: %s - %s (%s)\n" % [gpu_vendor, gpu_name.trim_suffix("/PCIe/SSE2"), gpu_api]
	
	# Rendering Information
	var rendering_method = ProjectSettings.get_setting_with_override("rendering/renderer/rendering_method")
	var rendering_driver = ProjectSettings.get_setting_with_override("rendering/rendering_device/driver")
	
	var api_string = get_graphics_api_string(rendering_method, rendering_driver)
	info_text += "Graphics API: %s\n" % api_string
	info_text += "Rendering Method: %s\n" % get_rendering_method_string(rendering_method)
	
	# Display Information
	var viewport = get_viewport()
	var screen_size = DisplayServer.screen_get_size()
	info_text += "Screen: %dx%d, Viewport: %dx%d\n" % [screen_size.x, screen_size.y, viewport.size.x, viewport.size.y]
	
	# V-Sync Information
	var vsync_string = get_vsync_string()
	if not vsync_string.is_empty():
		info_text += "V-Sync: %s\n" % vsync_string
	
	# Engine Information
	var version_info = Engine.get_version_info()
	info_text += "Engine: Godot %s.%s.%s\n" % [version_info.major, version_info.minor, version_info.patch]
	
	return info_text

func get_graphics_api_string(rendering_method: String, rendering_driver: String) -> String:
	if rendering_method != "gl_compatibility":
		match rendering_driver:
			"d3d12":
				return "Direct3D 12"
			"metal":
				return "Metal"
			"vulkan":
				if OS.has_feature("macos") or OS.has_feature("ios"):
					return "Vulkan via MoltenVK"
				else:
					return "Vulkan"
			_:
				return rendering_driver
	else:
		match rendering_driver:
			"opengl3_angle":
				return "OpenGL via ANGLE"
			"opengl3_es":
				return "OpenGL ES"
			"opengl3":
				if OS.has_feature("web"):
					return "WebGL"
				else:
					return "OpenGL"
			_:
				return "OpenGL"

func get_rendering_method_string(method: String) -> String:
	match method:
		"forward_plus":
			return "Forward+"
		"mobile":
			return "Forward Mobile"
		"gl_compatibility":
			return "Compatibility"
		_:
			return method

func get_vsync_string() -> String:
	match DisplayServer.window_get_vsync_mode():
		DisplayServer.VSYNC_ENABLED:
			return "V-Sync"
		DisplayServer.VSYNC_ADAPTIVE:
			return "Adaptive V-Sync"
		DisplayServer.VSYNC_MAILBOX:
			return "Mailbox V-Sync"
		_:
			return "Disabled"

func update_info_label_complete():
	system_info_loaded = true
	update_comprehensive_info()
	
	# Update log file with system info
	if enable_logging:
		update_log_system_info()

func calculate_advanced_metrics():
	if not enable_advanced_analysis:
		return
	
	# Calculate frame time percentiles
	if frame_history_total.size() > 10:
		var sorted_frames = frame_history_total.duplicate()
		sorted_frames.sort()
		var size = sorted_frames.size()
		
		frame_time_percentile_1 = sorted_frames[int(size * 0.01)]
		frame_time_percentile_95 = sorted_frames[int(size * 0.95)]
		frame_time_percentile_99 = sorted_frames[int(size * 0.99)]
		
		# Calculate frame consistency (lower variance = higher consistency)
		var variance = calculate_variance(frame_history_total, frametime_avg)
		frame_consistency_score = max(0, 100 - (variance * 2))  # Scale variance to 0-100
		
		# Calculate stability score based on long-term performance
		if long_frame_history.size() > 60:
			var recent_avg = 0.0
			var older_avg = 0.0
			var recent_count = min(60, long_frame_history.size())
			
			for i in range(recent_count):
				recent_avg += long_frame_history[long_frame_history.size() - 1 - i]
			recent_avg /= recent_count
			
			var older_count = min(60, long_frame_history.size() - recent_count)
			if older_count > 0:
				for i in range(older_count):
					older_avg += long_frame_history[long_frame_history.size() - recent_count - 1 - i]
				older_avg /= older_count
				
				var stability_diff = abs(recent_avg - older_avg) / max(recent_avg, older_avg)
				performance_stability_score = max(0, 100 - (stability_diff * 200))
	
	# Calculate memory metrics
	var current_memory = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
	memory_trend.push_back(current_memory)
	if memory_trend.size() > HISTORY_NUM_FRAMES:
		memory_trend.pop_front()
	
	peak_memory_usage = max(peak_memory_usage, current_memory)
	
	# Calculate memory growth rate
	if memory_trend.size() > 30:
		var recent_avg = 0.0
		var old_avg = 0.0
		for i in range(15):
			recent_avg += memory_trend[memory_trend.size() - 1 - i]
			old_avg += memory_trend[memory_trend.size() - 15 - 1 - i]
		recent_avg /= 15
		old_avg /= 15
		memory_growth_rate = (recent_avg - old_avg) / max(old_avg, 1.0) * 100  # Percentage growth
	
	# Calculate rendering efficiency
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var objects = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	
	if draw_calls > 0:
		triangle_per_draw_call = primitives / draw_calls
		# Ideal is around 1000+ triangles per draw call
		draw_call_efficiency = min(100, (triangle_per_draw_call / 1000.0) * 100)
	
	# Estimate overdraw (rough approximation)
	var screen_pixels = get_viewport().size.x * get_viewport().size.y
	if screen_pixels > 0 and primitives > 0:
		# Very rough estimate - assumes triangles cover screen area on average
		overdraw_estimation = (primitives * 50) / screen_pixels  # Assume 50 pixels per triangle average
	
	# Calculate physics load
	var physics_time_2d = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var physics_time_3d = physics_time_2d  # Godot combines 2D and 3D physics time
	var target_frame_time = get_current_target_frame_time()
	
	physics_load_2d = (physics_time_2d / target_frame_time) * 100
	physics_load_3d = physics_load_2d  # Same calculation for now
	
	# Physics efficiency based on object count vs time
	var physics_2d_objects = Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)
	var physics_3d_objects = Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	
	if physics_2d_objects > 0:
		physics_efficiency_2d = min(100, (physics_2d_objects / max(physics_time_2d, 0.1)) * 10)
	if physics_3d_objects > 0:
		physics_efficiency_3d = min(100, (physics_3d_objects / max(physics_time_3d, 0.1)) * 10)
	
	# Calculate audio performance
	var audio_latency = Performance.get_monitor(Performance.AUDIO_OUTPUT_LATENCY) * 1000.0
	audio_latency_trend.push_back(audio_latency)
	if audio_latency_trend.size() > HISTORY_NUM_FRAMES:
		audio_latency_trend.pop_front()
	
	# Good audio latency is typically under 20ms
	audio_performance_score = max(0, 100 - ((audio_latency - 20) * 2))
	
	# Calculate overall performance score
	var target_fps = get_current_target_fps()
	var fps_score = min(100, (frames_per_second / target_fps) * 100)
	var memory_score = max(0, 100 - (current_memory / 1024.0))  # Penalty for high memory usage
	
	overall_performance_score = (fps_score * 0.4 + 
								frame_consistency_score * 0.2 + 
								performance_stability_score * 0.2 + 
								memory_score * 0.1 + 
								audio_performance_score * 0.1)
	
	# Update performance score history
	performance_score_history.push_back(overall_performance_score)
	if performance_score_history.size() > HISTORY_NUM_FRAMES:
		performance_score_history.pop_front()

func calculate_variance(data: Array[float], mean: float) -> float:
	if data.size() == 0:
		return 0.0
	
	var sum_sq_diff = 0.0
	for value in data:
		var diff = value - mean
		sum_sq_diff += diff * diff
	
	return sum_sq_diff / data.size()

func update_performance_warnings():
	if not enable_performance_warnings:
		return
	
	performance_warnings.clear()
	critical_issues.clear()
	
	var current_target_fps = get_current_target_fps()
	
	# FPS warnings
	if frames_per_second < current_target_fps * critical_threshold_fps:
		critical_issues.append("CRITICAL: FPS severely below target (%.1f/%.0f)" % [frames_per_second, current_target_fps])
	elif frames_per_second < current_target_fps * warning_threshold_fps:
		performance_warnings.append("WARNING: FPS below target (%.1f/%.0f)" % [frames_per_second, current_target_fps])
	
	# Frame consistency warnings
	if frame_consistency_score < 50:
		critical_issues.append("CRITICAL: Poor frame consistency (%.1f%%)" % frame_consistency_score)
	elif frame_consistency_score < 75:
		performance_warnings.append("WARNING: Inconsistent frame times (%.1f%%)" % frame_consistency_score)
	
	# Memory warnings
	var current_memory = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
	if current_memory > 2048:  # Over 2GB
		critical_issues.append("CRITICAL: High memory usage (%.0fMB)" % current_memory)
	elif current_memory > 1024:  # Over 1GB
		performance_warnings.append("WARNING: High memory usage (%.0fMB)" % current_memory)
	
	if memory_growth_rate > 5:  # Growing by more than 5% per measurement
		performance_warnings.append("WARNING: Memory growing rapidly (+%.1f%%)" % memory_growth_rate)
	
	# Rendering warnings
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if draw_calls > 2000:
		critical_issues.append("CRITICAL: Excessive draw calls (%d)" % draw_calls)
	elif draw_calls > 1000:
		performance_warnings.append("WARNING: High draw calls (%d)" % draw_calls)
	
	if draw_call_efficiency < 25:
		performance_warnings.append("WARNING: Inefficient draw calls (%.1f%% efficiency)" % draw_call_efficiency)
	
	# Physics warnings
	if physics_load_2d > 50 or physics_load_3d > 50:
		performance_warnings.append("WARNING: High physics load (%.1f%%)" % max(physics_load_2d, physics_load_3d))
	
	# Audio warnings
	var audio_latency = Performance.get_monitor(Performance.AUDIO_OUTPUT_LATENCY) * 1000.0
	if audio_latency > 100:
		critical_issues.append("CRITICAL: High audio latency (%.1fms)" % audio_latency)
	elif audio_latency > 50:
		performance_warnings.append("WARNING: High audio latency (%.1fms)" % audio_latency)

func update_comprehensive_info():
	if not info or not system_info_loaded:
		return
	
	var comprehensive_info = base_system_info + "\n"
	comprehensive_info += generate_performance_metrics()
	
	# Add advanced metrics if enabled
	if enable_advanced_analysis:
		comprehensive_info += generate_advanced_metrics()
	
	# Add performance warnings
	if enable_performance_warnings and (performance_warnings.size() > 0 or critical_issues.size() > 0):
		comprehensive_info += generate_warnings_section()
	
	info.text = comprehensive_info

func generate_performance_metrics() -> String:
	var perf_info = "=== PERFORMANCE METRICS ===\n"
	
	# Frame Statistics - More compact
	var current_target_fps = get_current_target_fps()
	if Engine.max_fps > 0:
		var current_target_frame_time = get_current_target_frame_time()
		perf_info += "FPS: %.1f/%.0f | Frame: %.1f/%.1fms | CPU: %.1fms GPU: %.1fms\n" % [frames_per_second, current_target_fps, frametime_avg, current_target_frame_time, frametime_cpu_avg, frametime_gpu_avg]
	else:
		perf_info += "FPS: %.1f (Unlimited) | Frame: %.1fms | CPU: %.1fms GPU: %.1fms\n" % [frames_per_second, frametime_avg, frametime_cpu_avg, frametime_gpu_avg]
	
	if frame_history_total.size() > 10:
		var min_frametime = frame_history_total.min()
		var max_frametime = frame_history_total.max()
		perf_info += "Range: %.1f-%.1f FPS | %.1f-%.1fms\n" % [1000.0/max_frametime, 1000.0/min_frametime, min_frametime, max_frametime]
	
	# Engine Timing - Compact
	perf_info += "Engine FPS: %.1f | Process: %.1fms | Physics: %.1fms | Nav: %.1fms\n" % [Performance.get_monitor(Performance.TIME_FPS), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0]
	
	# Memory - Compact
	var static_mem = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
	var static_mem_max = Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1024.0 / 1024.0
	var message_buffer_max = Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX) / 1024.0 / 1024.0
	perf_info += "Memory: %.0f/%.0fMB (Peak: %.0fMB) | Buffer: %.1fMB | Growth: %+.1f%%\n" % [static_mem, static_mem_max, peak_memory_usage, message_buffer_max, memory_growth_rate]
	
	# Rendering - Compact
	var total_objects = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var video_mem = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1024.0 / 1024.0
	var texture_mem = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1024.0 / 1024.0
	var buffer_mem = Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1024.0 / 1024.0
	
	perf_info += "Render: %d objs | %d draws (%.1f tri/call) | %d prims\n" % [total_objects, draw_calls, triangle_per_draw_call, primitives]
	perf_info += "VRAM: %.0fMB | Tex: %.0fMB | Buf: %.0fMB | Efficiency: %.1f%%\n" % [video_mem, texture_mem, buffer_mem, draw_call_efficiency]
	
	# Physics - Compact (only if active)
	var physics_2d_active = Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)
	var physics_3d_active = Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	if physics_2d_active > 0 or physics_3d_active > 0:
		var physics_2d_collision = Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)
		var physics_2d_islands = Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT)
		var physics_3d_collision = Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)
		var physics_3d_islands = Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)
		perf_info += "Physics 2D: %d objs | %d pairs | %d islands | Load: %.1f%%\n" % [physics_2d_active, physics_2d_collision, physics_2d_islands, physics_load_2d]
		perf_info += "Physics 3D: %d objs | %d pairs | %d islands | Load: %.1f%%\n" % [physics_3d_active, physics_3d_collision, physics_3d_islands, physics_load_3d]
	
	# Audio - Enhanced
	var audio_latency = Performance.get_monitor(Performance.AUDIO_OUTPUT_LATENCY) * 1000.0
	perf_info += "Audio: %.1fms latency | Performance: %.1f%%\n" % [audio_latency, audio_performance_score]
	
	# Navigation - Compact (only if active) - FULL INFO
	var nav_active_maps = Performance.get_monitor(Performance.NAVIGATION_ACTIVE_MAPS)
	var nav_agents = Performance.get_monitor(Performance.NAVIGATION_AGENT_COUNT)
	var nav_regions = Performance.get_monitor(Performance.NAVIGATION_REGION_COUNT)
	if nav_agents > 0 or nav_regions > 0 or nav_active_maps > 2:
		var nav_links = Performance.get_monitor(Performance.NAVIGATION_LINK_COUNT)
		var nav_polygons = Performance.get_monitor(Performance.NAVIGATION_POLYGON_COUNT)
		var nav_edges = Performance.get_monitor(Performance.NAVIGATION_EDGE_COUNT)
		var nav_edge_merges = Performance.get_monitor(Performance.NAVIGATION_EDGE_MERGE_COUNT)
		var nav_edge_connections = Performance.get_monitor(Performance.NAVIGATION_EDGE_CONNECTION_COUNT)
		var nav_edge_free = Performance.get_monitor(Performance.NAVIGATION_EDGE_FREE_COUNT)
		var nav_obstacles = Performance.get_monitor(Performance.NAVIGATION_OBSTACLE_COUNT)
		perf_info += "Nav: %d maps | %d agents | %d regions | %d polys | %d obstacles\n" % [nav_active_maps, nav_agents, nav_regions, nav_polygons, nav_obstacles]
		perf_info += "Nav Edges: %d total | %d links | %d merged | %d connected | %d free\n" % [nav_edges, nav_links, nav_edge_merges, nav_edge_connections, nav_edge_free]
	
	# Pipeline - Compact (only if active)
	var pipeline_canvas = Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)
	var pipeline_mesh = Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)
	var pipeline_surface = Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)
	var pipeline_draw = Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
	var pipeline_specialization = Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)
	if pipeline_canvas > 0 or pipeline_mesh > 0 or pipeline_surface > 0 or pipeline_draw > 0:
		perf_info += "Pipeline: C:%d M:%d S:%d D:%d Spec:%d\n" % [pipeline_canvas, pipeline_mesh, pipeline_surface, pipeline_draw, pipeline_specialization]
	
	# Scene Stats - Compact - FULL INFO
	var node_count = count_nodes(get_tree().root)
	var object_count = Performance.get_monitor(Performance.OBJECT_COUNT)
	var resource_count = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var nodes_in_group = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphan_count = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	perf_info += "Scene: %d nodes | %d objs | %d res | %d grouped | %d orphans\n" % [node_count, object_count, resource_count, nodes_in_group, orphan_count]
	
	# FPS Limiting - Compact
	var fps_info = "Limits: "
	if Engine.max_fps > 0:
		fps_info += "Engine %dFPS" % Engine.max_fps
	else:
		fps_info += "Unlimited"
	
	if OS.low_processor_usage_mode:
		var low_proc_fps = roundi(1000000.0 / OS.low_processor_usage_mode_sleep_usec)
		fps_info += " | LowCPU %dFPS" % low_proc_fps
	
	var vsync_mode = DisplayServer.window_get_vsync_mode()
	if vsync_mode != DisplayServer.VSYNC_DISABLED:
		fps_info += " | " + get_vsync_string()
	
	perf_info += fps_info + "\n"
	
	# Frame Info - One line
	perf_info += "Frames: %d drawn | %d process | %d physics\n" % [Engine.get_frames_drawn(), Engine.get_process_frames(), Engine.get_physics_frames()]
	
	# Logging status
	if enable_logging:
		var log_size_kb = get_log_file_size() / 1024.0
		perf_info += "Logging: ON (%.1fKB, every %.1fs) | Path: %s\n" % [log_size_kb, logging_interval, log_file_path.get_file()]
	else:
		perf_info += "Logging: OFF\n"
	
	return perf_info

func generate_advanced_metrics() -> String:
	var advanced_info = "\n=== ADVANCED METRICS ===\n"
	
	# Performance Scores
	advanced_info += "Performance Score: %.1f%% | Consistency: %.1f%% | Stability: %.1f%%\n" % [overall_performance_score, frame_consistency_score, performance_stability_score]
	
	# Frame Time Analysis
	if frame_history_total.size() > 10:
		advanced_info += "Frame Times - 1%%: %.1fms | 95%%: %.1fms | 99%%: %.1fms\n" % [frame_time_percentile_1, frame_time_percentile_95, frame_time_percentile_99]
	
	# Rendering Analysis
	if overdraw_estimation > 0:
		advanced_info += "Overdraw Estimate: %.1fx | Triangles/Draw: %.1f\n" % [overdraw_estimation, triangle_per_draw_call]
	
	# Physics Analysis
	if physics_load_2d > 0 or physics_load_3d > 0:
		advanced_info += "Physics Efficiency 2D: %.1f%% | 3D: %.1f%%\n" % [physics_efficiency_2d, physics_efficiency_3d]
	
	return advanced_info

func generate_warnings_section() -> String:
	var warnings_info = "\n=== PERFORMANCE WARNINGS ===\n"
	
	# Critical issues first
	for issue in critical_issues:
		warnings_info += "🔴 " + issue + "\n"
	
	# Then regular warnings
	for warning in performance_warnings:
		warnings_info += "⚠️ " + warning + "\n"
	
	if critical_issues.size() == 0 and performance_warnings.size() == 0:
		warnings_info += "✅ No performance issues detected\n"
	
	return warnings_info

# ========== LOGGING SYSTEM ==========

func initialize_log_file():
	print("Initializing performance log...")
	
	# Create logs directory if it doesn't exist
	var dir = DirAccess.open("user://")
	if not dir:
		print("ERROR: Cannot access user:// directory")
		enable_logging = false
		return
	
	if not dir.dir_exists("logs"):
		var error = dir.make_dir("logs")
		if error != OK:
			print("ERROR: Failed to create logs directory. Error: ", error)
			enable_logging = false
			return
		print("Created logs directory at user://logs/")
	
	# Delete existing log file if it exists
	if FileAccess.file_exists(log_file_path):
		var error = dir.remove(log_file_path)
		if error != OK:
			print("WARNING: Failed to remove existing log file. Error: ", error)
		else:
			print("Cleared existing performance log file")
	
	# Create new log file and write header
	var file = FileAccess.open(log_file_path, FileAccess.WRITE)
	var error = FileAccess.get_open_error()
	if error != OK:
		print("ERROR: Failed to create performance log file. Error: ", error)
		enable_logging = false
		return
	
	# Write log header with timestamp and system info
	var header = "=".repeat(80) + "\n"
	header += "PERFORMANCE LOG - " + Time.get_datetime_string_from_system() + "\n"
	header += "=".repeat(80) + "\n\n"
	
	# Wait for system info to be loaded, or use placeholder
	if system_info_loaded:
		header += base_system_info
	else:
		header += "=== SYSTEM HARDWARE INFO ===\n"
		header += "Loading system information...\n"
	
	header += "\n" + "=".repeat(80) + "\n"
	header += "PERFORMANCE DATA LOG (Updated every " + str(logging_interval) + " seconds)\n"
	header += "=".repeat(80) + "\n\n"
	
	file.store_string(header)
	file.flush()  # Ensure data is written to disk
	file.close()
	
	# Verify file was created
	if FileAccess.file_exists(log_file_path):
		log_file_initialized = true
		print("Performance logging initialized successfully: ", log_file_path)
	else:
		print("ERROR: Log file was not created successfully")
		enable_logging = false

func update_log_system_info():
	# Update the log file with system info once it's loaded
	if not enable_logging or not log_file_initialized or not system_info_loaded:
		return
	
	print("Updating log file with system information...")
	
	var file = FileAccess.open(log_file_path, FileAccess.READ)
	if not file:
		print("ERROR: Cannot read log file for system info update")
		return
	
	var content = file.get_as_text()
	file.close()
	
	# Replace the placeholder system info with actual info
	if "Loading system information..." in content:
		content = content.replace("Loading system information...", base_system_info.strip_edges())
		
		file = FileAccess.open(log_file_path, FileAccess.WRITE)
		if file:
			file.store_string(content)
			file.flush()
			file.close()
			print("Updated log file with system information")
		else:
			print("ERROR: Failed to write system info to log file")

func log_performance_data():
	if not enable_logging or not log_file_initialized:
		return
	
	print("Logging performance data...")
	
	# Read existing content
	var existing_content = ""
	if FileAccess.file_exists(log_file_path):
		var read_file = FileAccess.open(log_file_path, FileAccess.READ)
		if read_file:
			existing_content = read_file.get_as_text()
			read_file.close()
		else:
			print("WARNING: Could not read existing log file")
	
	# Create timestamp entry
	var timestamp = Time.get_datetime_string_from_system()
	var log_entry = "\n[" + timestamp + "]\n"
	
	# Add basic performance metrics
	var current_target_fps = get_current_target_fps()
	log_entry += "FPS: %.1f" % frames_per_second
	if Engine.max_fps > 0:
		log_entry += "/%.0f" % current_target_fps
	else:
		log_entry += " (Unlimited)"
	log_entry += " | Frame: %.1fms (CPU: %.1fms, GPU: %.1fms)\n" % [frametime_avg, frametime_cpu_avg, frametime_gpu_avg]
	
	# Add performance scores
	log_entry += "Performance Score: %.1f%% | Consistency: %.1f%% | Stability: %.1f%%\n" % [overall_performance_score, frame_consistency_score, performance_stability_score]
	
	# Add memory info
	var static_mem = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
	log_entry += "Memory: %.0fMB (Peak: %.0fMB, Growth: %+.1f%%)\n" % [static_mem, peak_memory_usage, memory_growth_rate]
	
	# Add rendering info
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var video_mem = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1024.0 / 1024.0
	log_entry += "Rendering: %d draws | %d prims | %.0fMB VRAM | %.1f tri/call | %.1f%% efficiency\n" % [draw_calls, primitives, video_mem, triangle_per_draw_call, draw_call_efficiency]
	
	# Add physics info (if active)
	var physics_2d_active = Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)
	var physics_3d_active = Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	if physics_2d_active > 0 or physics_3d_active > 0:
		log_entry += "Physics: 2D=%d objs (%.1f%% load) | 3D=%d objs (%.1f%% load)\n" % [physics_2d_active, physics_load_2d, physics_3d_active, physics_load_3d]
	
	# Add audio info
	var audio_latency = Performance.get_monitor(Performance.AUDIO_OUTPUT_LATENCY) * 1000.0
	log_entry += "Audio: %.1fms latency (%.1f%% performance)\n" % [audio_latency, audio_performance_score]
	
	# Add node count and objects
	var node_count = count_nodes(get_tree().root)
	var object_count = Performance.get_monitor(Performance.OBJECT_COUNT)
	var orphan_count = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	log_entry += "Scene: %d nodes | %d objects | %d orphans\n" % [node_count, object_count, orphan_count]
	
	# Add advanced metrics if available
	if enable_advanced_analysis and frame_history_total.size() > 10:
		log_entry += "Frame Times - 1%%: %.1fms | 95%%: %.1fms | 99%%: %.1fms\n" % [frame_time_percentile_1, frame_time_percentile_95, frame_time_percentile_99]
	
	# Add warnings and issues
	if enable_performance_warnings:
		if critical_issues.size() > 0:
			log_entry += "CRITICAL ISSUES (%d): " % critical_issues.size()
			for i in range(min(3, critical_issues.size())):  # Log first 3 critical issues
				log_entry += critical_issues[i]
				if i < min(2, critical_issues.size() - 1):
					log_entry += " | "
			log_entry += "\n"
		
		if performance_warnings.size() > 0:
			log_entry += "WARNINGS (%d): " % performance_warnings.size()
			for i in range(min(3, performance_warnings.size())):  # Log first 3 warnings
				log_entry += performance_warnings[i]
				if i < min(2, performance_warnings.size() - 1):
					log_entry += " | "
			log_entry += "\n"
	
	# Write complete content back to file
	var complete_content = existing_content + log_entry
	var file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if not file:
		print("ERROR: Failed to open log file for writing. Error: ", FileAccess.get_open_error())
		return
	
	file.store_string(complete_content)
	file.flush()  # Force write to disk
	file.close()
	
	# Verify the write was successful
	var verification_file = FileAccess.open(log_file_path, FileAccess.READ)
	if verification_file:
		var file_size = verification_file.get_length()
		verification_file.close()
		print("Performance data logged successfully (File size: %d bytes, FPS: %.1f)" % [file_size, frames_per_second])
	else:
		print("ERROR: Failed to verify log file write")

func get_log_file_size() -> int:
	if not FileAccess.file_exists(log_file_path):
		return 0
	
	var file = FileAccess.open(log_file_path, FileAccess.READ)
	if not file:
		return 0
	
	var size = file.get_length()
	file.close()
	return size

func _input(event):
	# Toggle info visibility with F3
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		if info:
			info.visible = !info.visible

func _process(delta: float) -> void:
	frames_in_time += 1
	timer += delta
	info_update_timer += delta
	logging_timer += delta
	
	# Update frame timing using high-precision measurements
	update_frame_timing()
	
	# Calculate advanced metrics
	calculate_advanced_metrics()
	
	# Update performance warnings
	update_performance_warnings()
	
	# Update display every second
	if timer >= 1.0:
		var calculated_fps = roundi(frames_in_time / timer)
		update_fps_counter(calculated_fps)
		update_nodes_counter()
		frames_in_time = 0
		timer = 0
	
	# Update frame time display every frame
	update_frame_time_display()
	
	# Update comprehensive info display
	if info_update_timer >= info_update_interval:
		update_comprehensive_info()
		info_update_timer = 0.0
	
	# Log performance data at specified interval
	if enable_logging and logging_timer >= logging_interval:
		log_performance_data()
		logging_timer = 0.0

func update_frame_timing():
	# Calculate precise frame time using ticks (like the debug menu)
	var current_tick = Time.get_ticks_usec()
	var frametime = (current_tick - last_tick) * 0.001  # Convert to milliseconds
	
	# Update frame history
	frame_history_total.push_back(frametime)
	if frame_history_total.size() > HISTORY_NUM_FRAMES:
		frame_history_total.pop_front()
	
	# Update long-term history
	long_frame_history.push_back(frametime)
	if long_frame_history.size() > LONG_HISTORY_NUM_FRAMES:
		long_frame_history.pop_front()
	
	# Get CPU and GPU timing
	var viewport_rid = get_viewport().get_viewport_rid()
	var frametime_cpu = RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) + RenderingServer.get_frame_setup_time_cpu()
	var frametime_gpu = RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
	
	frame_history_cpu.push_back(frametime_cpu)
	if frame_history_cpu.size() > HISTORY_NUM_FRAMES:
		frame_history_cpu.pop_front()
	
	frame_history_gpu.push_back(frametime_gpu)
	if frame_history_gpu.size() > HISTORY_NUM_FRAMES:
		frame_history_gpu.pop_front()
	
	# Calculate averages
	if frame_history_total.size() > 0:
		frametime_avg = frame_history_total.reduce(func(a, b): return a + b) / frame_history_total.size()
		frames_per_second = 1000.0 / frametime_avg
	
	if frame_history_cpu.size() > 0:
		frametime_cpu_avg = frame_history_cpu.reduce(func(a, b): return a + b) / frame_history_cpu.size()
	
	if frame_history_gpu.size() > 0:
		frametime_gpu_avg = frame_history_gpu.reduce(func(a, b): return a + b) / frame_history_gpu.size()
	
	last_tick = current_tick

func update_fps_counter(fps: int) -> void:
	if not fps_counter:
		return
	
	var current_target_fps = get_current_target_fps()
	
	# Display FPS with target (or "Unlimited" if no cap)
	if Engine.max_fps > 0:
		fps_counter.text = "FPS: %d / %d" % [fps, current_target_fps]
	else:
		fps_counter.text = "FPS: %d (Unlimited)" % fps
	
	# Use color based on overall performance score
	var color: Color
	if overall_performance_score >= 85:
		color = excellent_color
	elif overall_performance_score >= 50:
		color = good_color
	elif overall_performance_score >= 30:
		color = warning_color
	else:
		color = bad_color
	
	set_label_color(fps_counter, color)

func update_frame_time_display() -> void:
	if not frame_time:
		return
	
	# Display total, CPU, and GPU frame times with consistency info
	if Engine.max_fps > 0:
		var current_target_frame_time = get_current_target_frame_time()
		frame_time.text = "Frame: %.1fms (CPU: %.1fms, GPU: %.1fms) | Target: %.1fms | Consistency: %.0f%%" % [frametime_avg, frametime_cpu_avg, frametime_gpu_avg, current_target_frame_time, frame_consistency_score]
		
		# Color based on consistency score
		var color: Color
		if frame_consistency_score >= 85:
			color = excellent_color
		elif frame_consistency_score >= 70:
			color = good_color
		elif frame_consistency_score >= 50:
			color = warning_color
		else:
			color = bad_color
		
		set_label_color(frame_time, color)
	else:
		frame_time.text = "Frame: %.1fms (CPU: %.1fms, GPU: %.1fms) | Unlimited | Consistency: %.0f%%" % [frametime_avg, frametime_cpu_avg, frametime_gpu_avg, frame_consistency_score]
		
		# Use consistency score for coloring when unlimited
		var color: Color
		if frame_consistency_score >= 85:
			color = excellent_color
		elif frame_consistency_score >= 70:
			color = good_color
		elif frame_consistency_score >= 50:
			color = warning_color
		else:
			color = bad_color
		
		set_label_color(frame_time, color)

func update_nodes_counter() -> void:
	if not nodes_counter:
		return
	
	var node_count = count_nodes(get_tree().root)
	var orphan_count = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	
	if orphan_count > 0:
		nodes_counter.text = "Nodes: %d (Orphans: %d)" % [node_count, orphan_count]
	else:
		nodes_counter.text = "Nodes: %d" % node_count
	
	# Color code based on node count and orphan count
	var color: Color
	if orphan_count > 10:
		color = bad_color  # Too many orphan nodes
	elif node_count <= 100:
		color = excellent_color
	elif node_count <= 500:
		color = good_color
	elif node_count <= 1000:
		color = warning_color
	else:
		color = bad_color
	
	set_label_color(nodes_counter, color)

func count_nodes(node: Node) -> int:
	var count: int = 1  # Count the current node
	
	# Add all children recursively
	for child in node.get_children(true):
		count += count_nodes(child)
	
	return count

func get_performance_color_gradient(value: float, min_val: float, max_val: float) -> Color:
	# Map value to 0-1 range and sample gradient
	var normalized = remap(clampf(value, min_val, max_val), min_val, max_val, 0.0, 1.0)
	return frame_time_gradient.sample(normalized)

func set_label_color(label: Label, color: Color):
	if not label:
		return
	
	# Don't change the info label's color - keep it static
	if label.name == "Info":
		return
	
	# Ensure label_settings exists
	if not label.label_settings:
		label.label_settings = LabelSettings.new()
	
	label.label_settings.font_color = color

# Get comprehensive performance data for external logging
func get_performance_data() -> Dictionary:
	var stats = {
		"fps": frames_per_second,
		"frame_time_avg": frametime_avg,
		"frame_time_cpu": frametime_cpu_avg,
		"frame_time_gpu": frametime_gpu_avg,
		"node_count": count_nodes(get_tree().root),
		"memory_static": Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0,
		"memory_static_max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1024.0 / 1024.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"physics_2d_objects": Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		"physics_3d_objects": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		
		# Advanced metrics
		"overall_performance_score": overall_performance_score,
		"frame_consistency_score": frame_consistency_score,
		"performance_stability_score": performance_stability_score,
		"memory_growth_rate": memory_growth_rate,
		"peak_memory_usage": peak_memory_usage,
		"draw_call_efficiency": draw_call_efficiency,
		"triangle_per_draw_call": triangle_per_draw_call,
		"physics_load_2d": physics_load_2d,
		"physics_load_3d": physics_load_3d,
		"audio_performance_score": audio_performance_score,
		"performance_warnings_count": performance_warnings.size(),
		"critical_issues_count": critical_issues.size()
	}
	
	# Add percentile statistics if we have enough data
	if frame_history_total.size() > 10:
		stats["frame_time_min"] = frame_history_total.min()
		stats["frame_time_max"] = frame_history_total.max()
		stats["fps_min"] = 1000.0 / frame_history_total.max()
		stats["fps_max"] = 1000.0 / frame_history_total.min()
		stats["frame_time_percentile_1"] = frame_time_percentile_1
		stats["frame_time_percentile_95"] = frame_time_percentile_95
		stats["frame_time_percentile_99"] = frame_time_percentile_99
	
	return stats

# Export performance data to JSON file
func export_performance_log(filepath: String = "user://performance_log.json") -> bool:
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if not file:
		print("Failed to create performance log file at: ", filepath)
		return false
	
	var log_data = {
		"timestamp": Time.get_datetime_string_from_system(),
		"system_info": base_system_info,
		"performance_data": get_performance_data(),
		"warnings": performance_warnings,
		"critical_issues": critical_issues
	}
	
	file.store_string(JSON.stringify(log_data, "\t"))
	file.close()
	print("Performance log exported to: ", filepath)
	return true

func _exit_tree():
	if info_thread.is_started():
		info_thread.wait_to_finish()

# Debug function to print the scene tree structure
func debug_scene_tree(node: Node = null, indent: String = ""):
	if node == null:
		node = get_tree().root
	
	print(indent + node.name + " (" + node.get_class() + ")")
	
	for child in node.get_children():
		debug_scene_tree(child, indent + "  ")

# Public API for enabling/disabling features
func set_advanced_analysis(enabled: bool):
	enable_advanced_analysis = enabled

func set_performance_warnings(enabled: bool):
	enable_performance_warnings = enabled

func set_warning_thresholds(warning_fps: float, critical_fps: float):
	warning_threshold_fps = warning_fps
	critical_threshold_fps = critical_fps

func set_logging_enabled(enabled: bool):
	enable_logging = enabled
	if enabled and not log_file_initialized:
		initialize_log_file()

func set_logging_interval(seconds: float):
	logging_interval = max(1.0, seconds)  # Minimum 1 second
	print("Logging interval set to %.1f seconds" % logging_interval)

func get_log_file_path() -> String:
	return log_file_path

func clear_log_file():
	if enable_logging:
		initialize_log_file()
		print("Performance log file cleared and reinitialized")
