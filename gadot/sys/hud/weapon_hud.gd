extends Control

# One vertical list. Each row is the weapon name with its ammo on the right.
# The list sits in the bottom-right corner, opposite the health and mana bars, so extra
# weapons grow upward. The team tag sits on top of the list.

const FONT = preload("res://fonts/Spotify.ttf")
const OUTLINE_RATIO: float = 12.0 / 32.0
const PANEL_ALPHA: float = 0.85
const NEUTRAL_COLOR := Color(0.08, 0.08, 0.1, 0.8)
const RIGHT_RATIO: float = 0.02
const BOTTOM_MARGIN: float = 20.0
const PILL_GAP: float = 6.0
const LIST_WIDTH: float = 260.0
const ROW_HEIGHT: float = 28.0
const ROW_GAP: int = 3
const PAD: float = 4.0

var _list: Control
var _well: Panel
var _rows_box: VBoxContainer
var _highlight: Panel
var _team_pill: PanelContainer
var _team_label: Label
var _rows: Array[Label] = []
var _ammo_labels: Array[Label] = []
var _stack: Array[String] = []
var _current := ""
var _travel_time := 0.2
var _slide: Tween
var _flash: Tween
var _tints: Array[Tween] = []


func _ready() -> void:
	name = "WeaponHud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_place)

	_list = Control.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.visible = false
	add_child(_list)

	_well = Panel.new()
	_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_well.add_theme_stylebox_override("panel", _make_well_style())
	_list.add_child(_well)

	_highlight = Panel.new()
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.z_index = 1
	_highlight.add_theme_stylebox_override("panel", _make_highlight_style())
	_highlight.hide()
	_list.add_child(_highlight)

	_rows_box = VBoxContainer.new()
	_rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows_box.z_index = 2
	_rows_box.position = Vector2(PAD, PAD)
	_rows_box.add_theme_constant_override("separation", ROW_GAP)
	_list.add_child(_rows_box)

	_team_pill = _make_panel(NEUTRAL_COLOR)
	_team_label = _make_label(14)
	_team_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_team_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_team_pill.add_child(_team_label)
	add_child(_team_pill)
	_place()


func set_info(team_name: String, team_color: Color, weapon_name: String, ammo_text: String, stack: Array, travel_time: float = 0.2) -> void:
	_team_label.text = team_name.to_upper()
	var on_team := team_name != "Sandbox"
	_set_panel_color(_team_pill, team_color if on_team else Color(NEUTRAL_COLOR.r, NEUTRAL_COLOR.g, NEUTRAL_COLOR.b))

	var names: Array[String] = []
	for entry in stack:
		var carried := str(entry)
		if carried == "hands":
			continue
		names.append(carried)
	if names != _stack:
		_stack = names
		_rebuild_rows()
		_current = ""
	_show_ammo(weapon_name, ammo_text)
	# Weapon info is pushed every frame. Only move the light when the selection changes.
	if weapon_name == _current:
		return
	# travel_time is the put-away still left plus the new weapon's deploy, so the
	# light arrives as that weapon finishes coming out.
	_travel_time = maxf(travel_time, 0.05)
	_select(weapon_name, _current != "")
	_current = weapon_name


func _rebuild_rows() -> void:
	if _slide:
		_slide.kill()
	if _flash:
		_flash.kill()
	_kill_tints()
	for child in _rows_box.get_children():
		child.queue_free()
	_rows.clear()
	_ammo_labels.clear()
	var row_width := LIST_WIDTH - PAD * 2.0
	for weapon_name in _stack:
		var name_label := _make_label(15)
		name_label.text = _pretty(weapon_name)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var ammo_label := _make_label(15)
		ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ammo_label.custom_minimum_size.x = 72
		ammo_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		ammo_label.visible = false
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 8)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		line.add_child(ammo_label)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 10)
		# Room for the font outline so the number stays inside the bar.
		margin.add_theme_constant_override("margin_right", 14)
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.custom_minimum_size = Vector2(row_width, ROW_HEIGHT)
		margin.add_child(line)
		_rows_box.add_child(margin)
		_rows.append(name_label)
		_ammo_labels.append(ammo_label)
	var count := _rows.size()
	var height := 0.0
	if count > 0:
		height = PAD * 2.0 + count * ROW_HEIGHT + (count - 1) * ROW_GAP
	_list.custom_minimum_size = Vector2(LIST_WIDTH, height)
	_list.visible = count > 0
	_well.visible = count > 0
	_highlight.visible = false
	_place()


func _show_ammo(weapon_name: String, ammo_text: String) -> void:
	var index := _stack.find(weapon_name)
	for i in _ammo_labels.size():
		var show := i == index and ammo_text != ""
		_ammo_labels[i].visible = show
		_ammo_labels[i].text = ammo_text if show else ""


func _select(weapon_name: String, animate: bool) -> void:
	var index := _stack.find(weapon_name)
	if index < 0:
		_highlight.hide()
		_tint_rows(-1, false)
		return
	var was_showing := _highlight.visible
	_highlight.show()
	_highlight.size = Vector2(LIST_WIDTH - PAD * 2.0, ROW_HEIGHT)
	var target := Vector2(PAD, PAD + index * (ROW_HEIGHT + ROW_GAP))
	_tint_rows(index, animate and was_showing)
	if not animate or not was_showing:
		if _slide:
			_slide.kill()
		if _flash:
			_flash.kill()
		_highlight.position = target
		_highlight.modulate = Color.WHITE
		return
	if _slide:
		_slide.kill()
	if _flash:
		_flash.kill()
	# Continue from wherever the light is now, so a second scroll bends toward the new row
	# instead of restarting from the weapon still in hand.
	_slide = create_tween()
	_slide.tween_property(_highlight, "position", target, _travel_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_flash = create_tween()
	_flash.tween_property(_highlight, "modulate", Color(1.85, 1.75, 1.45), 0.06)
	_flash.tween_property(_highlight, "modulate", Color.WHITE, 0.22)


func _tint_rows(selected: int, animate: bool) -> void:
	_kill_tints()
	for i in _rows.size():
		var color := Color.WHITE if i == selected else Color(1, 1, 1, 0.42)
		_tint_label(_rows[i], color, animate)
		_tint_label(_ammo_labels[i], color, animate)


func _tint_label(label: Label, color: Color, animate: bool) -> void:
	var settings := label.label_settings
	if animate:
		var tint := create_tween()
		tint.tween_property(settings, "font_color", color, _travel_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_tints.append(tint)
	else:
		settings.font_color = color


func _kill_tints() -> void:
	for tint in _tints:
		if tint and tint.is_valid():
			tint.kill()
	_tints.clear()


# Bottom-right of the list stays this far in from the screen edges. Taller lists grow up.
func _place() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var height := _list.custom_minimum_size.y
	var right := size.x * (1.0 - RIGHT_RATIO)
	var bottom := size.y - BOTTOM_MARGIN
	_list.position = Vector2(right - LIST_WIDTH, bottom - height)
	_list.size = Vector2(LIST_WIDTH, height)
	_well.position = Vector2.ZERO
	_well.size = _list.size
	_rows_box.position = Vector2(PAD, PAD)
	_rows_box.size = Vector2(LIST_WIDTH - PAD * 2.0, maxf(height - PAD * 2.0, 0.0))

	var pill := Vector2(150, 24)
	var pill_bottom := bottom
	if _list.visible:
		pill_bottom -= height + PILL_GAP
	_team_pill.position = Vector2(right - pill.x, pill_bottom - pill.y)
	_team_pill.size = pill


func _pretty(weapon_name: String) -> String:
	return weapon_name.replace("_", " ").to_upper()


func _make_well_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.72)
	style.set_corner_radius_all(8)
	return style


func _make_highlight_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.93, 0.84, 0.95)
	style.set_corner_radius_all(5)
	return style


func _make_panel(color: Color) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, PANEL_ALPHA)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 2
	style.content_margin_bottom = 2

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _set_panel_color(panel: PanelContainer, color: Color) -> void:
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = Color(color, PANEL_ALPHA)


func _make_label(font_size: int) -> Label:
	var settings := LabelSettings.new()
	settings.font = FONT
	settings.font_size = font_size
	settings.font_color = Color.WHITE
	settings.outline_size = maxi(1, roundi(font_size * OUTLINE_RATIO))
	settings.outline_color = Color.BLACK

	var label := Label.new()
	label.label_settings = settings
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
