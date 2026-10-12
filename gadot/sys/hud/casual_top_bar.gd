extends Control

# Top center scoreboard: team A score | timer + round info | team B score.
# Same font and outline style as the center announcements.
# A row of boxes under each team panel shows its players, filled while alive.

const FONT = preload("res://fonts/Spotify.ttf")
const OUTLINE_RATIO: float = 12.0 / 32.0
const TEAM_PANEL_WIDTH: float = 190.0
const CENTER_PANEL_WIDTH: float = 170.0
const PANEL_ALPHA: float = 0.85
const CENTER_COLOR := Color(0.08, 0.08, 0.1, 0.8)
const ALIVE_BOX_SIZE: float = 22.0
const ALIVE_BOX_SPACING: int = 6
const ALIVE_ROW_GAP: int = 6
const DEAD_BOX_COLOR := Color(0, 0, 0, 0.4)

var _team_a_panel: PanelContainer
var _team_a_name: Label
var _team_a_score: Label
var _team_b_panel: PanelContainer
var _team_b_name: Label
var _team_b_score: Label
var _round_label: Label
var _timer_label: Label
var _status_label: Label
var _team_a_alive: HBoxContainer
var _team_b_alive: HBoxContainer
var _center_spacer: Control
var _team_a_alive_style: StyleBoxFlat
var _team_a_dead_style: StyleBoxFlat
var _team_b_alive_style: StyleBoxFlat
var _team_b_dead_style: StyleBoxFlat


func _ready() -> void:
	name = "CasualTopBar"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", ALIVE_ROW_GAP)
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.offset_top = 8

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 0)
	column.add_child(row)

	# Team A: name then score, score next to the timer
	_team_a_panel = _make_panel(Color(1, 1, 1, PANEL_ALPHA), TEAM_PANEL_WIDTH, 10, 0)
	var team_a_row := _make_team_row()
	_team_a_name = _make_label(22)
	_team_a_score = _make_label(40)
	_team_a_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_team_a_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	team_a_row.add_child(_team_a_name)
	team_a_row.add_child(_team_a_score)
	_team_a_panel.add_child(team_a_row)

	var center := _make_panel(CENTER_COLOR, CENTER_PANEL_WIDTH, 0, 0)
	var center_column := VBoxContainer.new()
	center_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_column.add_theme_constant_override("separation", -6)
	_round_label = _make_label(16)
	_timer_label = _make_label(36)
	_status_label = _make_label(14)
	center_column.add_child(_round_label)
	center_column.add_child(_timer_label)
	center_column.add_child(_status_label)
	center.add_child(center_column)

	# Team B mirrored: score then name
	_team_b_panel = _make_panel(Color(1, 1, 1, PANEL_ALPHA), TEAM_PANEL_WIDTH, 0, 10)
	var team_b_row := _make_team_row()
	_team_b_score = _make_label(40)
	_team_b_name = _make_label(22)
	_team_b_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_team_b_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	team_b_row.add_child(_team_b_score)
	team_b_row.add_child(_team_b_name)
	_team_b_panel.add_child(team_b_row)

	row.add_child(_team_a_panel)
	row.add_child(center)
	row.add_child(_team_b_panel)

	# Alive boxes, each group kept as wide as the panel above it
	var alive_row := HBoxContainer.new()
	alive_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alive_row.add_theme_constant_override("separation", 0)
	column.add_child(alive_row)
	_team_a_alive = _make_alive_row()
	_center_spacer = Control.new()
	_center_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_team_b_alive = _make_alive_row()
	alive_row.add_child(_team_a_alive)
	alive_row.add_child(_center_spacer)
	alive_row.add_child(_team_b_alive)
	_team_a_panel.resized.connect(_match_width.bind(_team_a_alive, _team_a_panel))
	center.resized.connect(_match_width.bind(_center_spacer, center))
	_team_b_panel.resized.connect(_match_width.bind(_team_b_alive, _team_b_panel))

	_team_a_alive_style = _make_box_style(Color.WHITE, Color.BLACK)
	_team_a_dead_style = _make_box_style(DEAD_BOX_COLOR, Color.WHITE)
	_team_b_alive_style = _make_box_style(Color.WHITE, Color.BLACK)
	_team_b_dead_style = _make_box_style(DEAD_BOX_COLOR, Color.WHITE)


func set_teams(name_a: String, color_a: Color, name_b: String, color_b: Color) -> void:
	_team_a_name.text = name_a.to_upper()
	_team_b_name.text = name_b.to_upper()
	_set_panel_color(_team_a_panel, color_a)
	_set_panel_color(_team_b_panel, color_b)
	_team_a_alive_style.bg_color = color_a
	_team_a_dead_style.border_color = color_a
	_team_b_alive_style.bg_color = color_b
	_team_b_dead_style.border_color = color_b


func set_scores(score_a: int, score_b: int) -> void:
	_team_a_score.text = str(score_a)
	_team_b_score.text = str(score_b)


# x = alive players, y = total players on the team
func set_alive(alive_a: Vector2i, alive_b: Vector2i) -> void:
	_update_alive_boxes(_team_a_alive, alive_a, false, _team_a_alive_style, _team_a_dead_style)
	_update_alive_boxes(_team_b_alive, alive_b, true, _team_b_alive_style, _team_b_dead_style)


func set_center(round_text: String, seconds: int, status_text: String) -> void:
	_round_label.text = round_text
	_timer_label.text = "%d:%02d" % [floori(seconds / 60.0), seconds % 60]
	_status_label.text = status_text
	_status_label.visible = status_text != ""


# Filled boxes sit on the outer edge of the scoreboard, so team B fills from the right
func _update_alive_boxes(box_row: HBoxContainer, counts: Vector2i, fill_from_right: bool, alive_style: StyleBoxFlat, dead_style: StyleBoxFlat) -> void:
	while box_row.get_child_count() < counts.y:
		var box := Panel.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.custom_minimum_size = Vector2(ALIVE_BOX_SIZE, ALIVE_BOX_SIZE)
		box_row.add_child(box)
	while box_row.get_child_count() > counts.y:
		var extra := box_row.get_child(box_row.get_child_count() - 1)
		box_row.remove_child(extra)
		extra.queue_free()

	for i in counts.y:
		var slot := counts.y - 1 - i if fill_from_right else i
		var style := alive_style if slot < counts.x else dead_style
		var box := box_row.get_child(i) as Panel
		if box.get_theme_stylebox("panel") != style:
			box.add_theme_stylebox_override("panel", style)


func _match_width(target: Control, source: Control) -> void:
	target.custom_minimum_size.x = source.size.x


func _make_panel(color: Color, width: float, left_radius: int, right_radius: int) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = left_radius
	style.corner_radius_bottom_left = left_radius
	style.corner_radius_top_right = right_radius
	style.corner_radius_bottom_right = right_radius
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size.x = width
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_team_row() -> HBoxContainer:
	var team_row := HBoxContainer.new()
	team_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	team_row.alignment = BoxContainer.ALIGNMENT_CENTER
	team_row.add_theme_constant_override("separation", 12)
	return team_row


func _make_alive_row() -> HBoxContainer:
	var box_row := HBoxContainer.new()
	box_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box_row.add_theme_constant_override("separation", ALIVE_BOX_SPACING)
	return box_row


func _make_box_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style


func _set_panel_color(panel: PanelContainer, color: Color) -> void:
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = Color(color, PANEL_ALPHA)


func _make_label(font_size: int) -> Label:
	var settings := LabelSettings.new()
	settings.font = FONT
	settings.font_size = font_size
	settings.outline_size = roundi(font_size * OUTLINE_RATIO)
	settings.outline_color = Color.BLACK

	var label := Label.new()
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
