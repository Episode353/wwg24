extends Control
@export var radius: float = 200.0
@export var normal_color: Color = Color("666666")
@export var hover_color: Color = Color("aaaaaa")
@export var selected_color: Color = Color("44ff44")
@export var separation_distance: float = 6.0
@export var inner_radius: float = 35.0  # Minimum distance from center to activate selection
@onready var wand_radial_selection: Control = $"../.."
@onready var panel: Panel = $".."
var selected_index: int = -1
var hovered_index: int = -1
var active: bool = false
var segments := []  # Store each segment's polygon and related data
var weapons_manager: Node = null
var spell_names := []  # Store the spell names from Weapons_Manager

func _ready():
	hide_menu()
	find_weapons_manager()
	setup_spells()
	create_segments()

# Method 1: Use multiplayer authority check
func find_weapons_manager():
	# Find all weapons managers in the scene
	var all_weapons_managers = get_tree().get_nodes_in_group("weapons_manager")
	
	for manager in all_weapons_managers:
		# Check if this weapons manager belongs to the local player
		if manager.is_multiplayer_authority():
			weapons_manager = manager
			print("Found local player's weapons manager: ", weapons_manager)
			return
	
	print("Warning: Local player's Weapons_Manager not found!")

func find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var result = find_node_recursive(child, target_name)
		if result:
			return result
	return null

func setup_spells():
	if weapons_manager and weapons_manager.has_method("get_wand_spells"):
		spell_names = weapons_manager.get_wand_spells()
	else:
		print("Warning: Weapons_Manager or get_wand_spells method not found!")
	
func _input(event):
	if not is_multiplayer_authority(): return
	if event.is_action_pressed("alt_fire"):
		init_data()
		if weapons_manager.current_weapon:
			print(weapons_manager.current_weapon.weapon_name)
			if weapons_manager.current_weapon.weapon_name == "wand":
				show_menu()
	elif event.is_action_released("alt_fire"):
		hide_menu()

func init_data():
	find_weapons_manager()
	setup_spells()
	create_segments()

func show_menu():
	wand_radial_selection.show()
	panel.show()
	visible = true
	active = true
	hovered_index = -1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Restore selection visually
	for s in segments:
		s.poly.color = selected_color if s.index == selected_index else normal_color

func hide_menu():
	wand_radial_selection.hide()
	panel.hide()
	visible = false
	active = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if hovered_index != -1 and hovered_index < spell_names.size():
		# Override previous selection
		selected_index = hovered_index
		var selected_spell = spell_names[selected_index]
		
		# Set the spell in Weapons_Manager
		if weapons_manager and weapons_manager.has_method("set_wand_spell"):
			weapons_manager.set_wand_spell(selected_spell)
		
		# Reset all, then apply selected color
		for s in segments:
			s.poly.color = selected_color if s.index == selected_index else normal_color

func create_segments():
	# Remove old segments
	for c in get_children():
		c.queue_free()
	segments.clear()
	
	var segment_count = spell_names.size()
	if segment_count == 0:
		return
	
	for i in range(segment_count):
		var angle_start = TAU * i / segment_count
		var angle_end = TAU * (i + 1) / segment_count
		var mid_angle = (angle_start + angle_end) / 2.0
		var arc_polygon = make_arc_polygon(angle_start, angle_end)
		
		var segment = Node2D.new()
		add_child(segment)
		
		var center_offset = Vector2(cos(mid_angle), sin(mid_angle)) * separation_distance
		segment.position = get_rect().size / 2 + center_offset
		
		var poly = Polygon2D.new()
		poly.polygon = arc_polygon
		poly.color = normal_color
		segment.add_child(poly)
		
		# Add text label for the spell name
		var label = Label.new()
		label.text = spell_names[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Position label at mid radius
		var label_radius = (radius + inner_radius) / 2
		var label_pos = Vector2(cos(mid_angle), sin(mid_angle)) * label_radius
		label.position = label_pos - Vector2(50, 10)  # Offset for centering
		label.size = Vector2(100, 20)
		segment.add_child(label)
		
		segments.append({
			"polygon": arc_polygon,
			"node": segment,
			"poly": poly,
			"index": i,
			"offset": segment.position,
			"angle_start": angle_start,
			"angle_end": angle_end,
			"spell_name": spell_names[i]
		})

func make_arc_polygon(start_angle: float, end_angle: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var steps = 32
	
	# Create outer arc points
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var angle = lerp(start_angle, end_angle, t)
		var point = Vector2(cos(angle), sin(angle)) * radius
		points.append(point)
	
	# Create inner arc points (in reverse order to complete the polygon)
	for i in range(steps, -1, -1):
		var t = float(i) / float(steps)
		var angle = lerp(start_angle, end_angle, t)
		var point = Vector2(cos(angle), sin(angle)) * inner_radius
		points.append(point)
	
	return points

func get_segment_from_angle(mouse_pos: Vector2) -> int:
	var center = get_rect().size / 2
	var direction = mouse_pos - center
	var distance = direction.length()
	
	# Don't select anything if too close to center
	if distance < inner_radius:
		return -1
	
	# Calculate angle from center to mouse
	var angle = atan2(direction.y, direction.x)
	# Normalize angle to 0-TAU range
	if angle < 0:
		angle += TAU
	
	# Find which segment this angle belongs to
	for s in segments:
		var start_angle = s.angle_start
		var end_angle = s.angle_end
		
		# Handle wraparound case (segment crosses 0 angle)
		if end_angle < start_angle:
			if angle >= start_angle or angle <= end_angle:
				return s.index
		else:
			if angle >= start_angle and angle <= end_angle:
				return s.index
	
	return -1

func _process(delta):
	if not active:
		return
	
	var mouse_pos = get_local_mouse_position()
	var found_index = -1
	
	# First try to find segment by polygon intersection (for precise selection within segments)
	for s in segments:
		var global_mouse = mouse_pos - get_rect().size / 2 - Vector2(cos((s.angle_start + s.angle_end) / 2) * separation_distance, sin((s.angle_start + s.angle_end) / 2) * separation_distance)
		if Geometry2D.is_point_in_polygon(global_mouse, s.polygon):
			found_index = s.index
			break

	
	# If not found within any segment, use angle-based selection
	if found_index == -1:
		found_index = get_segment_from_angle(mouse_pos)
	
	# Update hover state
	if found_index != hovered_index:
		if hovered_index != -1 and hovered_index < segments.size() and hovered_index != selected_index:
			segments[hovered_index].poly.color = normal_color
		
		hovered_index = found_index
		
		if hovered_index != -1 and hovered_index != selected_index:
			segments[hovered_index].poly.color = hover_color
