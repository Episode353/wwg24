extends Node3D

# Radius of the explosion effect
@export var explosion_radius: float = 6.0
# Strength of the explosion force
@export var explosion_force: float = 10.0
# Additional upward force to ensure vertical movement
@export var upward_force: float = 5.0

# Maximum damage for a direct hit
@export var max_damage: float = 10.0
# Minimum damage at the edge of explosion radius
@export var min_damage: float = 0.0
var owner_player

@export var rigid_body_force_multiplier: float = 10.0

@onready var smoke = $Smoke

func apply_explosion_force_to_character(player):
	if player is CharacterBody3D:
		var direction = (player.global_transform.origin - global_transform.origin).normalized()
		var impulse = direction * explosion_force
		impulse.y += upward_force  # Add a slight upward force
		player.velocity += impulse

func apply_explosion_force_to_rigidbody(body):
	if body is RigidBody3D:
		var direction = (body.global_transform.origin - global_transform.origin).normalized()
		var force = direction * explosion_force * rigid_body_force_multiplier
		# Using add_force at the body's origin to mimic add_central_force
		body.apply_force(force, body.global_transform.origin)

func calculate_damage(distance: float) -> float:
	# If the distance is greater than the explosion radius, the player is outside the explosion range
	if distance > explosion_radius:
		return 0

	# Linear interpolation between max_damage and min_damage based on the distance
	var t = distance / explosion_radius
	var damage = max_damage - t * (max_damage - min_damage)

	# Ensure that the damage does not exceed max_damage or go below min_damage
	return clamp(damage, min_damage, max_damage)

func _ready():
	smoke.emitting = true
	if owner_player == null:
		return

	# Scan for all players within the explosion radius
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		var distance = player.global_transform.origin.distance_to(global_transform.origin)
		if distance <= explosion_radius:
			apply_explosion_force_to_character(player)
			if player != owner_player and player.has_method("receive_damage"):
				player.rpc("receive_damage", calculate_damage(distance))

	# Scan for destructible objects
	var objects = get_tree().get_nodes_in_group("destructable")
	for object in objects:
		var distance = object.global_transform.origin.distance_to(global_transform.origin)
		if distance <= explosion_radius and object.has_method("destruct"):
			object.rpc("destruct")

	# Scan for pushable RigidBody3D objects
	var bodies = get_tree().get_nodes_in_group("moveable")
	for body in bodies:
		var distance = body.global_transform.origin.distance_to(global_transform.origin)
		if distance <= explosion_radius:
			apply_explosion_force_to_rigidbody(body)
			
	

func _on_timer_timeout():
	queue_free()
