extends Node3D

@export var energy: float = 1.0
@export var attenuation: float = 1.0
@export var range: float = 5.0
@export var specular: float = 0.5
# Change the type to String since TBLoader provides a string.
@export var light_color: String = "255 255 255"  # White by default.

@export var angles: String = "0 0 0"

@onready var spot_light_3d = $"."

func _ready() -> void:
	call_deferred("_update_spot_light")

func _update_spot_light() -> void:
	# Parse and convert the color string.
	spot_light_3d.light_color = parse_color(light_color)
	spot_light_3d.spot_range = range
	spot_light_3d.light_energy = energy
	spot_light_3d.spot_attenuation = attenuation
	spot_light_3d.light_specular = specular

	var angle_parts = angles.strip_edges().split(" ")
	if angle_parts.size() != 3:
		push_error("Angles must contain three numbers (Pitch Yaw Roll) separated by spaces. Given: " + angles)
	else:
		var pitch = angle_parts[0].to_float() + 180.0
		var yaw = angle_parts[1].to_float()
		var roll = angle_parts[2].to_float()
		self.rotation_degrees = Vector3(pitch, yaw, roll)

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
