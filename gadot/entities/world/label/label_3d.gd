@tool
extends Node3D

var text: String = "NULL"
var billboard: String = "0"
var pixel_size: float = 0.005
var text_color: String = "255 255 255"
var font_size: String = "32"
var double_sided: String = "1"
@onready var label_3d: Label3D = $Label3D

@export var func_godot_properties: Dictionary

func _func_godot_apply_properties(props: Dictionary):
	var property_types := {}
	for p in get_property_list():
		property_types[p.name] = p.type

	for key in props.keys():
		if not property_types.has(key):
			continue

		var target_type = property_types[key]
		var value = props[key]

		match target_type:
			TYPE_INT:
				set(key, int(value))
			TYPE_FLOAT:
				set(key, float(value))
			TYPE_BOOL:
				set(key, value in ["1", "true", true])
			TYPE_STRING:
				set(key, str(value))
			_:
				set(key, value)  # Fallback: assign directly (e.g. dictionaries, arrays)

	call_deferred("_update_label")



func _update_label() -> void:
	if not is_instance_valid(label_3d):
		return
	label_3d.text = str(text)

	if billboard == "0":
		label_3d.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	elif billboard == "1":
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	elif billboard == "2":
		label_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y

	label_3d.double_sided = double_sided == "1"
	label_3d.pixel_size = float(pixel_size)
	label_3d.modulate = parse_color(text_color)
	label_3d.font_size = int(font_size)


func parse_color(color_str: String) -> Color:
	var parts = color_str.strip_edges().split(" ")
	if parts.size() != 3:
		push_error("Invalid color format: %s" % color_str)
		return Color.WHITE
	return Color(parts[0].to_float() / 255.0, parts[1].to_float() / 255.0, parts[2].to_float() / 255.0)
