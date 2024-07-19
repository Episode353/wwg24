extends TextureRect

# Set the desired scale factor
var scale_factor = Vector2(0.03, 0.03)

func _process(delta):
	# Get the screen size
	var screen_size = get_viewport_rect().size

	# Set the scale of the TextureRect
	scale = scale_factor

	# Set the position of the TextureRect to the center of the screen
	position.x = (screen_size.x - texture.get_size().x * scale.x) / 2
	position.y = (screen_size.y - texture.get_size().y * scale.y) / 2
