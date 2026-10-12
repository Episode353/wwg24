extends Control

# Big centered text that fades in, holds and fades out. Styled like the world Label3D (Spotify font, black outline).

const FONT = preload("res://fonts/Spotify.ttf")
const TITLE_SIZE: int = 72
const SUBTITLE_SIZE: int = 36
# Same outline-to-font ratio as the Label3D defaults (outline 12 on font 32)
const OUTLINE_RATIO: float = 12.0 / 32.0
const FADE_IN_TIME: float = 0.3
const FADE_OUT_TIME: float = 0.6
const DEFAULT_HOLD_TIME: float = 2.0

var _title: Label
var _subtitle: Label
var _tween: Tween


func _ready() -> void:
	name = "CenterAnnouncement"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	_title = _make_label(TITLE_SIZE)
	_subtitle = _make_label(SUBTITLE_SIZE)
	box.add_child(_title)
	box.add_child(_subtitle)
	modulate.a = 0.0
	hide()


func _make_label(font_size: int) -> Label:
	var settings := LabelSettings.new()
	settings.font = FONT
	settings.font_size = font_size
	settings.outline_size = roundi(font_size * OUTLINE_RATIO)
	settings.outline_color = Color.BLACK

	var label := Label.new()
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# Replaces whatever is showing
func show_message(title: String, subtitle: String = "", color: Color = Color.WHITE, hold_time: float = DEFAULT_HOLD_TIME) -> void:
	_title.text = title
	_title.label_settings.font_color = color
	_subtitle.text = subtitle
	_subtitle.visible = subtitle != ""

	if _tween:
		_tween.kill()
	show()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_TIME * (1.0 - modulate.a))
	_tween.tween_interval(hold_time)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
	_tween.tween_callback(hide)
