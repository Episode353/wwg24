extends Node

# Variables for timing and fade effect
var time_elapsed: float = 0.0
var fade_duration: float = 2.0  # Time for fading
var destroy_delay: float = 1.0  # Time before object is freed after fade

# Reference to the label node
@onready var killfeed = $"."


var initial_opacity: float = 1.0  # Starting opacity

# Called every physics frame
func _physics_process(delta: float) -> void:
	time_elapsed += delta
	
	# Check if it's time to start fading
	if time_elapsed >= fade_duration:
		var fade_time = time_elapsed - fade_duration
		# Fade out the opacity based on the time elapsed since fade started
		killfeed.modulate.a = max(0.0, initial_opacity - fade_time / destroy_delay)
		
		# If the label is fully faded, queue free the object
		if time_elapsed >= fade_duration + destroy_delay:
			queue_free()
