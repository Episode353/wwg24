extends Node3D

# Radius of the explosion effect
@export var explosion_radius: float = 6.0
# Strength of the explosion force
@onready var explosion = $"."

# Maximum damage for a direct hit
@export var max_damage: float = 10.0
# Minimum damage at the edge of explosion radius
@export var min_damage: float = 0.0
var times_moved = 0
var owner_player
@onready var collision_shape_3d = $CollisionShape3D
@onready var rigid_body_3d = $"."
@onready var flames = $Explosion/flames


@onready var timer = $Explosion/Timer
@onready var raycast = $Explosion/RayCast3D  # Raycast node to detect the ground



func calculate_damage(distance: float) -> float:
	# If the distance is greater than the explosion radius, the player is outside the explosion range
	if distance > explosion_radius:
		return 0
	
	# Linear interpolation between max_damage and min_damage based on the distance
	var t = distance / explosion_radius
	var damage = max_damage - t * (max_damage - min_damage)
	
	# Ensure that the damage does not exceed max_damage or go below min_damage
	return clamp(damage, min_damage, max_damage)

func _process(_delta):
	if raycast.is_colliding() and (times_moved < 10):
		# Get the collision point and set the object's position to that point
		var collision_point = raycast.get_collision_point()
		global_transform.origin.y = collision_point.y + 0.1
		times_moved += 1
		
	if timer.time_left < 1:
			flames.emitting = false

func _ready():
	# Add a random value to the timer's wait time
	var random_add = randf_range(5.0, 10.0)
	timer.wait_time += random_add
	timer.start()



func _on_timer_timeout():
	queue_free()
