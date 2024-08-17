extends ColorRect

@onready var menufadein = $"."



var fadeSpeed: float = 0.5  # Adjust the speed of the fade

func _process(delta: float) -> void:
	if menufadein.color.a > 0:
		menufadein.color.a -= fadeSpeed * delta  # Decrease alpha over time
	else:
		menufadein.color.a = 0  # Ensure alpha doesn't go below 0
