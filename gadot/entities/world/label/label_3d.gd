extends Node3D


@export var text: String = "NULL"  # White by default.
@export var billboard: String = "0"  # White by default.
@export var pixel_size: float = 0.005  # White by default.
@export var text_color: String = "255 255 255"  # White by default.
@export var font_size: String = "32"  # White by default.
@export var double_sided: String = "1"  # White by default.


@onready var label_3d: Label3D = $Label3D



func _ready() -> void:
	call_deferred("_update_label")

func _update_label() -> void:
	label_3d.text = str(text)
	
	if billboard == "0":
		label_3d.billboard =BaseMaterial3D.BILLBOARD_DISABLED
	if billboard == "1":
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if billboard == "2":
		label_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		
	if double_sided == "1":
		label_3d.double_sided = true
	if double_sided == "0":
		label_3d.double_sided = false
		
	label_3d.pixel_size = float(pixel_size)
	label_3d.modulate = parse_color(text_color)
	label_3d.font_size = int(font_size)
	
# Helper function to convert a string like "255 128 0" into a normalized Color.
func parse_color(color_str: String) -> Color:
	var parts = color_str.strip_edges().split(" ")
	if parts.size() != 3:
		push_error("Invalid color format. Expected 3 components, got: " + str(parts))
		return Color(1, 1, 1)  # Fallback to white.
	
	# Convert each component from 0–255 range to 0–1.
	var r = parts[0].to_float() / 255.0
	var g = parts[1].to_float() / 255.0
	var b = parts[2].to_float() / 255.0
	return Color(r, g, b)
