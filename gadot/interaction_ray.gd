extends RayCast3D
@onready var main_camera = $".."
@onready var interaction_ray = $"."
var grabbed_object = null
var is_holding_object = false
var old_pos: = Vector3()
var new_pos: = Vector3()

# The maximum ammount the grabbed_object can move per frame
var move_speed: float = 20.0

# This number will controll how "Heavy" the object feels when it is let go
# Higher number means the object will move less, lower number means it will move more
var grabbed_object_velocity_scale: float = 0.5

func _process(delta):
	process_input()
	place_grabbable_objects(delta)

func place_grabbable_objects(delta):
	if is_holding_object and grabbed_object != null:
		# 1) Store the old position 
		old_pos = grabbed_object.global_transform.origin

		# 2) Calculate desired new position in front of the camera
		var forward_direction: Vector3 = -main_camera.global_transform.basis.z
		var target_position: Vector3 = main_camera.global_transform.origin + forward_direction * 2

		# 2a) Move the object smoothly (if you still want that smooth effect)
		new_pos = old_pos.move_toward(target_position, move_speed * delta)

		# 3) Update the object's transform
		var temp_transform = grabbed_object.global_transform
		temp_transform.origin = new_pos
		grabbed_object.global_transform = temp_transform

		# 4) Compute velocity from the movement this frame
		var frame_velocity = ((new_pos - old_pos) / delta) * grabbed_object_velocity_scale
		grabbed_object.linear_velocity = frame_velocity

		# (Optional) Re-align the object, e.g., "look_at" etc.
		grabbed_object.look_at(main_camera.global_transform.origin, Vector3.UP)
		
		# If the object is too far away, let go of the object
		if (grabbed_object.global_transform.origin - global_transform.origin).length() > 4:
			release_grabbed_object()

func release_grabbed_object():
	grabbed_object = null
	is_holding_object = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func process_input():
# Interact with objects
	if Input.is_action_just_pressed("interact"):
		
		# If the player is holding an object when they press the iteract key, let go of the object
		if grabbed_object != null:
			release_grabbed_object()
			return
		
		# If the player isnt holding an object, read the raycast
		var hit_object = interaction_ray.get_collider()
		if !hit_object:
			return # If the raycast doesnt hit anything return and do nothing
			
		# Calculate distance between this player (script presumably attached to the player) and hit_object
		var distance = (hit_object.global_transform.origin - global_transform.origin).length()

		# Check if it's farther than e.g., 5 units
		if distance > 5:
			return # Too far to interact
		
		# If the raycast hits something lets move the object!
		if hit_object.get_parent().is_in_group("grabbable"):
			is_holding_object = true
			grabbed_object = hit_object
