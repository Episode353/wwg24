extends ColorRect

@onready var menufadein = $"."
var inital_delay = 100 #How many frames to keep the screen black after the map loads


var fadeSpeed: float = 1  # Adjust the speed of the fade

func _process(delta: float) -> void:
	if inital_delay > 0:
		inital_delay -= 1
	if inital_delay < 0:
		inital_delay = 1
	if menufadein.color.a > 0 and inital_delay == 0 and Globals.map_loaded == true:
		var new_color = menufadein.color
		new_color.a = max(new_color.a - fadeSpeed * delta, 0)  # ensure alpha doesn't go below 0
		menufadein.color = new_color
