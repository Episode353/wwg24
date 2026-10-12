extends Node3D

# Godot compiles a shader when a camera actually draws it, not when the scene file is loaded.
# Shader scenes are drawn together in one frame. Meshes with no shader are not loaded.
# A stamp in user:// only remembers that these files were drawn. The skip also
# requires the GPU cache to still hold them, checked by drawing one lit cube.

const SCAN_DIRS: Array[String] = [
	"res://entities",
	"res://models",
	"res://sys",
	"res://tscn",
	"res://mat",
	"res://shaders",
	"res://addons/EffectBlocks",
]
const EXTRA_SCENES: Array[String] = [
	"res://manadrop.tscn",
]
const SKIP_SCENES: Array[String] = [
	"res://tscn/shader_precomp.tscn",
	"res://tscn/main_menu.tscn",
	"res://player.tscn",
	"res://world.tscn",
	# These are OS windows. Adding them to the tree opens the console and pause menu.
	"res://tscn/console/console.tscn",
	"res://tscn/settings/settings.tscn",
]
const SCENE_EXTS: Array[String] = [".tscn", ".glb", ".gltf", ".scn"]
const GRASS_MESHES: Array[String] = [
	"res://mat/grass/grass.glb",
	"res://mat/grass/grass2.glb",
]
const CELL_SIZE := 1.0
const PROGRESS_EVERY := 3
const WARMUP_STAMP := "user://shader_warmup.cfg"

@onready var camera: Camera3D = $Camera3D
@onready var background: ColorRect = $CanvasLayer/Background
@onready var loading_ui: Control = $CanvasLayer/Center
@onready var progress_bar: ProgressBar = $CanvasLayer/Center/Column/ProgressBar
@onready var title_label: Label = $CanvasLayer/Center/Column/Title
@onready var status_label: Label = $CanvasLayer/Center/Column/Status
@onready var count_label: Label = $CanvasLayer/Center/Column/Count
@onready var file_label: Label = $CanvasLayer/Center/Column/File
@onready var skip_button: Button = $CanvasLayer/Center/Column/Skip
@onready var skip_note: Label = $CanvasLayer/Center/Column/SkipNote

var _environment: Environment
var _env_node: WorldEnvironment
var _sun: DirectionalLight3D
var _omni: OmniLight3D
var _done := 0
var _color_ratio := 0.0
var _color_target := 0.0
var _skipped := false
var _left := false
var _loading_visible := false
var _rendering_ready := false
var _started_us := 0
var _frame_wait_us := 0
var _phase_us := {}
var _spawn_times: Array[Dictionary] = []


func _process(delta: float) -> void:
	if not _loading_visible:
		return
	# Ease toward the load progress so the shift reads as a fade, not a jump every few files.
	_color_ratio = lerpf(_color_ratio, _color_target, 1.0 - exp(-delta * 3.0))
	background.color = Globals.TEAM_COLORS[2].lerp(Globals.TEAM_COLORS[1], _color_ratio)


func _ready() -> void:
	_started_us = Time.get_ticks_usec()
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	background.color = Color.BLACK
	loading_ui.hide()
	_style_loading_screen()
	skip_button.pressed.connect(_on_skip_pressed)

	var scan_start := Time.get_ticks_usec()
	var found_scenes: Array[String] = []
	var shaders: Array[String] = []
	for folder in SCAN_DIRS:
		_collect(folder, found_scenes, shaders)
	for path in EXTRA_SCENES:
		if not found_scenes.has(path) and FileAccess.file_exists(path):
			found_scenes.append(path)
	_phase_us["scan"] = Time.get_ticks_usec() - scan_start

	var filter_start := Time.get_ticks_usec()
	var scenes: Array[String] = []
	var skipped_plain := 0
	var skipped_broken := 0
	var skipped_meshes := 0
	for path in found_scenes:
		var reason := _skip_reason(path)
		if reason == "":
			scenes.append(path)
		elif reason == "broken":
			skipped_broken += 1
		elif reason == "mesh":
			skipped_meshes += 1
		else:
			skipped_plain += 1
	_phase_us["filter"] = Time.get_ticks_usec() - filter_start
	print("Shader warmup: %d scenes found, keeping %d. Skipped %d plain, %d meshes, %d broken." % [found_scenes.size(), scenes.size(), skipped_plain, skipped_meshes, skipped_broken])

	var stamp := _warmup_key(scenes, shaders)
	if _stamp_matches(stamp):
		print("Shader warmup: shader files match the last compile. Checking whether the GPU cache still has them.")
		if await _probe_driver_cache():
			_print_timing("cache hit")
			_leave()
			return
		print("Shader warmup: GPU cache is missing those pipelines. Compiling.")

	if not _loading_visible:
		_show_loading_screen()
	await _enable_game_rendering()
	if _skipped:
		_leave()
		return

	var total := scenes.size() + shaders.size()
	_set_progress(0, total, "")
	var before_load := _pipeline_snapshot()

	# Stay out of the tree until the one compile frame. A progress redraw would
	# otherwise render every scene loaded so far, over and over.
	var holder := Node3D.new()
	var cells: Array[Node3D] = []
	var rects: Array[ColorRect] = []
	var sky_paths: Array[String] = []

	var spawn_start := Time.get_ticks_usec()
	for path in scenes:
		if _skipped:
			break
		await _advance(total, path)
		if _skipped:
			break
		var file_start := Time.get_ticks_usec()
		var instance := _spawn_scene(path)
		_note_spawn(path, Time.get_ticks_usec() - file_start)
		if instance:
			cells.append(_wrap(holder, instance))
	_phase_us["spawn"] = Time.get_ticks_usec() - spawn_start
	print("Shader warmup: spawned %d scenes in %.0f ms" % [cells.size(), _phase_us["spawn"] / 1000.0])

	var shader_start := Time.get_ticks_usec()
	for path in shaders:
		if _skipped:
			break
		await _advance(total, path)
		if _skipped:
			break
		var file_start := Time.get_ticks_usec()
		var kind := _shader_type(path)
		if kind == "sky":
			sky_paths.append(path)
			_note_spawn(path, Time.get_ticks_usec() - file_start)
			continue
		if kind == "canvas_item":
			var rect := _make_canvas_rect(path)
			if rect:
				rects.append(rect)
			_note_spawn(path, Time.get_ticks_usec() - file_start)
			continue
		var visual := _make_shader_visual(holder, path, kind, cells)
		_note_spawn(path, Time.get_ticks_usec() - file_start)
		if visual:
			cells.append(visual)
	_phase_us["shaders"] = Time.get_ticks_usec() - shader_start
	print("Shader warmup: loaded %d shader files in %.0f ms" % [shaders.size(), _phase_us["shaders"] / 1000.0])

	if _skipped:
		print("Shader warmup skipped before the draw. Shaders will compile the first time they appear.")
		_print_timing("skipped")
		_leave()
		return

	add_child(holder)
	for rect in rects:
		$CanvasLayer.add_child(rect)
	_tile_canvas_rects(rects)
	if not sky_paths.is_empty():
		_apply_sky(sky_paths[0])
	_fit_cells(cells)
	_frame_grid(cells.size())
	_set_progress(total, total, "Drawing shaders")
	var after_load := _pipeline_snapshot()
	_log_pipeline_delta(before_load, after_load, "while loading files")
	print("Drawing ", cells.size(), " scenes and ", rects.size(), " canvas shaders")
	var draw_start := Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	_phase_us["draw"] = Time.get_ticks_usec() - draw_start
	var after_draw := _pipeline_snapshot()
	_log_pipeline_delta(after_load, after_draw, "while drawing")

	holder.queue_free()
	for rect in rects:
		rect.queue_free()
	var sky_start := Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	for i in range(1, sky_paths.size()):
		_apply_sky(sky_paths[i])
		await RenderingServer.frame_post_draw
	_phase_us["skies"] = Time.get_ticks_usec() - sky_start
	_write_stamp(stamp)
	_print_timing("compiled")
	_leave()


# SSAO, fog, glow, and shadowed lights have to exist before the other meshes.
# Pipelines compiled without them are compiled again the first time the match uses them.
func _enable_game_rendering() -> void:
	if _rendering_ready:
		return
	_rendering_ready = true
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color.BLACK
	_environment.ssao_enabled = true
	_environment.glow_enabled = true
	_environment.volumetric_fog_enabled = true
	_environment.volumetric_fog_density = 0.01
	_environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	var env_node := WorldEnvironment.new()
	env_node.environment = _environment
	add_child(env_node)
	_env_node = env_node

	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 8192.0
	sun.rotation_degrees = Vector3(-50, -40, 0)
	add_child(sun)
	_sun = sun

	_omni = OmniLight3D.new()
	_omni.shadow_enabled = true
	_omni.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	add_child(_omni)

	var primer := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(0.5, 0.5, 0.5)
	primer.mesh = cube
	primer.position = Vector3(0, 0, -2)
	add_child(primer)
	_aim_at(primer.position)
	await RenderingServer.frame_post_draw
	primer.queue_free()


func _collect(folder: String, scenes: Array[String], shaders: Array[String]) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		push_warning("Shader warmup could not open %s" % folder)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var path := folder.path_join(file_name)
			if dir.current_is_dir():
				# Showcase scenes repeat the same effects as the asset scenes.
				if file_name == "scenes" and folder.ends_with("EffectBlocks"):
					file_name = dir.get_next()
					continue
				_collect(path, scenes, shaders)
			elif _ends_with_any(file_name, SCENE_EXTS) and not SKIP_SCENES.has(path):
				scenes.append(path)
			elif file_name.ends_with(".gdshader"):
				shaders.append(path)
		file_name = dir.get_next()
	dir.list_dir_end()


# "" means the scene can compile a shader. Anything else is a reason to skip it.
func _skip_reason(path: String) -> String:
	# Weapon and prop meshes are the slow loads, and none of them reference a shader.
	# Grass meshes are spawned later, when grass.gdshader is drawn.
	if path.ends_with(".glb") or path.ends_with(".gltf"):
		return "mesh"
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return "plain"
	# These scenes point at res://PolyBlocks, which is not in the project. Loading them
	# only prints errors. The real shader files are compiled on their own.
	if "res://PolyBlocks/" in text and ".gdshader" not in text:
		return "broken"
	if ".gdshader" in text or "ShaderMaterial" in text or "type=\"Shader\"" in text:
		return ""
	if "ParticleProcessMaterial" in text or "GPUParticles" in text or "CPUParticles" in text:
		return ""
	if _ext_material_has_shader(text):
		return ""
	return "plain"


func _ext_material_has_shader(text: String) -> bool:
	var search_from := 0
	while true:
		var idx := text.find("path=\"", search_from)
		if idx < 0:
			return false
		var start := idx + 6
		var end := text.find("\"", start)
		if end < 0:
			return false
		var res := text.substr(start, end - start)
		search_from = end + 1
		if not (res.ends_with(".tres") or res.ends_with(".material") or res.ends_with(".res")):
			continue
		if not FileAccess.file_exists(res):
			continue
		var inner := FileAccess.get_file_as_string(res)
		if ".gdshader" in inner or "ShaderMaterial" in inner:
			return true
	return false


func _warmup_key(scenes: Array[String], shaders: Array[String]) -> String:
	var paths: Array[String] = []
	paths.append_array(scenes)
	paths.append_array(shaders)
	paths.sort()
	var parts: PackedStringArray = []
	for path in paths:
		var size := -1
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			size = file.get_length()
			file.close()
		parts.append("%s|%d|%d" % [path, FileAccess.get_modified_time(path), size])
	var info := Engine.get_version_info()
	var version := "%s.%s.%s-%s" % [info.major, info.minor, info.patch, info.status]
	var driver := ""
	for part in OS.get_video_adapter_driver_info():
		driver += str(part) + ","
	return "%s|%s|%s|%d" % [version, RenderingServer.get_video_adapter_name(), driver, hash("\n".join(parts))]


func _stamp_matches(key: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(WARMUP_STAMP) != OK:
		print("Shader warmup: no saved compile stamp, running a full pass")
		return false
	if str(cfg.get_value("warmup", "key", "")) == key:
		return true
	print("Shader warmup: compile stamp does not match (a shader file, the engine, or the GPU changed)")
	return false


# True when a previous compile is still in the driver cache. The stamp only
# remembers that we drew these files. Deleting the NVIDIA cache leaves the stamp.
func _probe_driver_cache() -> bool:
	var before := _pipeline_snapshot()
	await _enable_game_rendering()
	await RenderingServer.frame_post_draw
	var after := _pipeline_snapshot()
	_log_pipeline_delta(before, after, "driver cache probe")
	if after.is_empty():
		var intact := _driver_folder_intact()
		print("Shader warmup: pipeline counters unavailable, driver folder %s" % ["still present" if intact else "missing or wiped"])
		return intact
	if _pipelines_grew(before, after):
		return false
	print("Shader warmup: driver cache still has these pipelines")
	return true


func _pipelines_grew(before: Dictionary, after: Dictionary) -> bool:
	for key in after.keys():
		if float(after[key]) > float(before.get(key, 0.0)):
			return true
	return false


func _driver_cache_dirs() -> Array[String]:
	var local := OS.get_environment("LOCALAPPDATA").replace("\\", "/")
	if local.is_empty():
		return []
	return [
		local.path_join("NVIDIA/GLCache"),
		local.path_join("NVIDIA/DXCache"),
		local.path_join("NVIDIA Corporation/NV_Cache"),
		local.path_join("AMD/VkCache"),
		local.path_join("AMD/GLCache"),
		local.path_join("AMD/DxCache"),
		local.path_join("D3DSCache"),
		local.path_join("Intel/ShaderCache"),
	]


func _driver_cache_count() -> int:
	var total := 0
	for path in _driver_cache_dirs():
		total += _count_cache_files(path, 0)
	return total


func _count_cache_files(path: String, depth: int) -> int:
	if depth > 3:
		return 0
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	var count := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "" and count < 2000:
		if not file_name.begins_with("."):
			if dir.current_is_dir():
				count += _count_cache_files(path.path_join(file_name), depth + 1)
			else:
				count += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	return count


func _driver_folder_intact() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(WARMUP_STAMP) != OK:
		return false
	var saved := int(cfg.get_value("warmup", "cache_files", -1))
	var now := _driver_cache_count()
	print("Shader warmup: driver cache files %d now, %d when last compiled" % [now, saved])
	# A tiny saved count is not evidence. A big drop means the folder was deleted.
	if saved < 8:
		return false
	return now >= int(float(saved) * 0.5)


func _write_stamp(key: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("warmup", "key", key)
	cfg.set_value("warmup", "cache_files", _driver_cache_count())
	cfg.save(WARMUP_STAMP)
	print("Shader warmup: saved compile stamp to ", WARMUP_STAMP)


func _note_spawn(path: String, elapsed_us: int) -> void:
	_spawn_times.append({"path": path, "us": elapsed_us})
	if elapsed_us >= 50000:
		print("Shader warmup slow file: %.0f ms  %s" % [elapsed_us / 1000.0, path])


func _print_timing(note: String) -> void:
	var total_us := Time.get_ticks_usec() - _started_us
	print("Shader warmup timing (%s): total %.0f ms" % [note, total_us / 1000.0])
	for phase in _phase_us.keys():
		print("  %s: %.0f ms" % [phase, float(_phase_us[phase]) / 1000.0])
	print("  progress frames: %.0f ms" % [_frame_wait_us / 1000.0])
	if _spawn_times.is_empty():
		return
	_spawn_times.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["us"]) > int(b["us"])
	)
	print("  slowest files:")
	for i in mini(8, _spawn_times.size()):
		print("    %.0f ms  %s" % [float(_spawn_times[i]["us"]) / 1000.0, _spawn_times[i]["path"]])


func _spawn_scene(path: String) -> Node:
	var packed = load(path)
	if packed == null or not packed is PackedScene:
		push_warning("Shader warmup skipped %s" % path)
		return null
	var instance: Node = (packed as PackedScene).instantiate()
	_prepare(instance)
	_release_main_cameras(instance)
	return instance


func _wrap(holder: Node3D, instance: Node) -> Node3D:
	var wrapper := Node3D.new()
	holder.add_child(wrapper)
	wrapper.add_child(instance)
	return wrapper


func _make_canvas_rect(path: String) -> ColorRect:
	var mat := _load_shader_material(path)
	if mat == null:
		return null
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = -1
	rect.material = mat
	return rect


func _make_shader_visual(holder: Node3D, path: String, kind: String, cells: Array[Node3D]) -> Node3D:
	var mat := _load_shader_material(path)
	if mat == null:
		return null
	if kind == "particles":
		var particles := GPUParticles3D.new()
		particles.amount = 8
		particles.emitting = true
		particles.preprocess = 0.05
		particles.process_material = mat
		var particle_quad := QuadMesh.new()
		particle_quad.size = Vector2(0.4, 0.4)
		particles.draw_pass_1 = particle_quad
		holder.add_child(particles)
		return particles
	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.material = mat
	mesh_instance.mesh = quad
	holder.add_child(mesh_instance)
	if path.ends_with("grass.gdshader"):
		for grass_path in GRASS_MESHES:
			var grass := _spawn_scene(grass_path)
			if grass:
				_apply_material_override(grass, mat)
				cells.append(_wrap(holder, grass))
	return mesh_instance


func _load_shader_material(path: String) -> ShaderMaterial:
	var shader: Shader = load(path)
	if shader == null:
		push_warning("Shader warmup skipped %s" % path)
		return null
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _apply_sky(path: String) -> void:
	var mat := _load_shader_material(path)
	if mat == null:
		return
	var sky := Sky.new()
	sky.sky_material = mat
	_environment.sky = sky
	_environment.background_mode = Environment.BG_SKY


func _tile_canvas_rects(rects: Array[ColorRect]) -> void:
	if rects.is_empty():
		return
	var view_size := get_viewport().get_visible_rect().size
	if view_size.x < 1.0 or view_size.y < 1.0:
		view_size = Vector2(1280, 720)
	var cols := maxi(1, ceili(sqrt(float(rects.size()))))
	var rows := maxi(1, ceili(float(rects.size()) / float(cols)))
	var cell := Vector2(view_size.x / float(cols), view_size.y / float(rows))
	for i in rects.size():
		var rect := rects[i]
		var col := i % cols
		var row := int(i / cols)
		rect.position = Vector2(col, row) * cell
		rect.size = cell


func _close_warmup_environment() -> void:
	if is_instance_valid(_env_node):
		_env_node.queue_free()
	if is_instance_valid(_sun):
		_sun.queue_free()
	if is_instance_valid(_omni):
		_omni.queue_free()


func _fit_cells(cells: Array[Node3D]) -> void:
	# Uniform scale instead of measuring every mesh. The heavy scenes are not in this
	# set, and walking their AABBs was most of the time after the shaders were cached.
	var cols := _column_count(cells.size())
	var fitted := Vector3.ONE * 0.2
	for i in cells.size():
		var body := cells[i]
		body.scale = fitted
		body.position = _cell_center(i, cols)


# Square-ish grid, then pull the camera back until that rectangle fits the frustum.
func _frame_grid(count: int) -> void:
	camera.current = true
	camera.fov = 50
	if count <= 0:
		_aim_at(Vector3(0, 0, -2))
		return
	var cols := _column_count(count)
	var rows := maxi(1, ceili(float(count) / float(cols)))
	var width := float(cols) * CELL_SIZE
	var height := float(rows) * CELL_SIZE
	var center := Vector3(width * 0.5, height * 0.5, 0)
	var aspect := get_viewport().get_visible_rect().size.aspect()
	if aspect <= 0.0:
		aspect = 16.0 / 9.0
	var vertical_half := deg_to_rad(camera.fov * 0.5)
	var horizontal_half := atan(tan(vertical_half) * aspect)
	var padding := 1.08
	var distance_v := (height * 0.5) / tan(vertical_half) * padding
	var distance_h := (width * 0.5) / tan(horizontal_half) * padding
	var distance := maxf(distance_v, distance_h)
	camera.global_position = center + Vector3(0, 0, distance)
	camera.look_at(center, Vector3.UP)
	_omni.global_position = camera.global_position


func _column_count(count: int) -> int:
	return maxi(1, ceili(sqrt(float(maxi(count, 1)))))


func _cell_center(index: int, cols: int) -> Vector3:
	var col := index % cols
	var row := int(index / cols)
	return Vector3((float(col) + 0.5) * CELL_SIZE, (float(row) + 0.5) * CELL_SIZE, 0)


func _prepare(node: Node) -> void:
	node.set_script(null)
	if node is RigidBody3D:
		(node as RigidBody3D).freeze = true
	elif node is GPUParticles3D:
		var particles := node as GPUParticles3D
		particles.visible = true
		particles.emitting = true
		if particles.preprocess <= 0.0:
			particles.preprocess = 0.05
	elif node is CPUParticles3D:
		var particles := node as CPUParticles3D
		particles.visible = true
		particles.emitting = true
	elif node is GPUParticles2D:
		var particles := node as GPUParticles2D
		particles.visible = true
		particles.emitting = true
	elif node is CPUParticles2D:
		var particles := node as CPUParticles2D
		particles.visible = true
		particles.emitting = true
	elif node is VisualInstance3D:
		(node as VisualInstance3D).visible = true
	elif node is Window:
		# A visible Window becomes its own OS window the moment it enters the tree.
		(node as Window).visible = false
	elif node is CanvasItem:
		(node as CanvasItem).visible = true
	elif node is SubViewport:
		(node as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for child in node.get_children():
		_prepare(child)


func _release_main_cameras(node: Node) -> void:
	if node is Camera3D and not _inside_subviewport(node):
		(node as Camera3D).current = false
	for child in node.get_children():
		_release_main_cameras(child)


func _inside_subviewport(node: Node) -> bool:
	var parent := node.get_parent()
	while parent:
		if parent is SubViewport:
			return true
		parent = parent.get_parent()
	return false


func _apply_material_override(node: Node, mat: Material) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).material_override = mat
	for child in node.get_children():
		_apply_material_override(child, mat)


func _aim_at(point: Vector3) -> void:
	_omni.global_position = point + Vector3(0, 1, 0)
	camera.global_position = point + Vector3(0, 0.2, 2)
	camera.look_at(point)


func _shader_type(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "spatial"
	var lines_left := 40
	while lines_left > 0 and not file.eof_reached():
		var line := file.get_line().strip_edges()
		lines_left -= 1
		if line.begins_with("shader_type"):
			return line.trim_prefix("shader_type").strip_edges().trim_suffix(";")
	return "spatial"


func _advance(total: int, path: String) -> void:
	_done += 1
	_set_progress(_done, total, path)
	if _done % PROGRESS_EVERY == 0:
		var wait_start := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		_frame_wait_us += Time.get_ticks_usec() - wait_start


func _show_loading_screen() -> void:
	_loading_visible = true
	_color_ratio = 0.0
	_color_target = 0.0
	background.color = Globals.TEAM_COLORS[2]
	loading_ui.show()


func _on_skip_pressed() -> void:
	if _left:
		return
	_skipped = true
	skip_button.disabled = true
	skip_button.text = "Skipping"
	status_label.text = "Skipping shader compile"


func _leave() -> void:
	if _left:
		return
	_left = true
	_close_warmup_environment()
	await RenderingServer.frame_post_draw
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
	switch_scene("res://tscn/main_menu.tscn")


func _style_loading_screen() -> void:
	var font = load("res://fonts/Daydream.ttf")
	if font:
		title_label.add_theme_font_override("font", font)
		count_label.add_theme_font_override("font", font)
		skip_button.add_theme_font_override("font", font)
		skip_note.add_theme_font_override("font", font)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.05, 0.12, 0.72)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.1, 0.22, 0.9)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.28, 0.16, 0.36, 1)
	skip_button.add_theme_stylebox_override("normal", normal)
	skip_button.add_theme_stylebox_override("hover", hover)
	skip_button.add_theme_stylebox_override("pressed", pressed)
	skip_button.add_theme_stylebox_override("disabled", normal)
	skip_button.add_theme_color_override("font_color", Color(0.97, 0.93, 0.86, 1))
	skip_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color(0.05, 0.03, 0.08, 0.45)
	empty.set_corner_radius_all(8)
	empty.set_content_margin_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.97, 0.93, 0.86, 1)
	fill.set_corner_radius_all(6)
	progress_bar.add_theme_stylebox_override("background", empty)
	progress_bar.add_theme_stylebox_override("fill", fill)


func _pipeline_snapshot() -> Dictionary:
	var counts := {}
	var names := Performance.get_custom_monitor_names()
	for monitor_name in names:
		if "pipeline" in String(monitor_name).to_lower():
			counts[String(monitor_name)] = Performance.get_custom_monitor(monitor_name)
	if counts.is_empty():
		print("Shader warmup: no pipeline monitors. Custom monitors: ", names)
	return counts


func _log_pipeline_delta(before: Dictionary, after: Dictionary, tag: String) -> void:
	if after.is_empty():
		return
	var changed := false
	for key in after.keys():
		var previous: float = float(before.get(key, 0))
		var current: float = float(after[key])
		var delta := int(current - previous)
		print("Shader warmup %s: %s %d -> %d (%+d)" % [tag, key, int(previous), int(current), delta])
		if delta != 0:
			changed = true
	if not changed:
		print("Shader warmup: no new pipelines ", tag, ". This pass used the cache.")


func _set_progress(done: int, total: int, path: String) -> void:
	var safe_total := maxi(total, 1)
	_color_target = clampf(float(done) / float(safe_total), 0.0, 1.0)
	progress_bar.max_value = safe_total
	progress_bar.value = done
	var percent := int(round(float(done) / float(safe_total) * 100.0))
	status_label.text = "Preparing shaders  %d%%" % percent
	count_label.text = "%d / %d" % [done, total]
	file_label.text = path.get_file()


func _ends_with_any(file_name: String, exts: Array[String]) -> bool:
	for ext in exts:
		if file_name.ends_with(ext):
			return true
	return false


func switch_scene(new_scene_path: String) -> void:
	var new_scene_resource = load(new_scene_path)
	if new_scene_resource == null:
		print("Failed to load scene for switching: ", new_scene_path)
		return
	var new_scene = new_scene_resource.instantiate()
	var root := get_tree().root
	root.add_child(new_scene)
	if new_scene.get_parent() != root:
		new_scene.free()
		push_error("Could not open %s" % new_scene_path)
		return
	var old_scene := get_tree().current_scene
	get_tree().current_scene = new_scene
	if old_scene and old_scene != new_scene:
		old_scene.queue_free()
	print("Switched to scene: ", new_scene_path)
