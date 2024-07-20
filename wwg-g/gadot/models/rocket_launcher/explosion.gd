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
var owner_player: Node3D

@onready var smoke: GPUParticles3D = $Smoke

func apply_explosion_force(player: CharacterBody3D) -> void:
	var direction: Vector3 = (player.global_transform.origin - global_transform.origin).normalized()
	var impulse: Vector3 = direction * explosion_force
	impulse.y += upward_force  # Add a slight upward force
	player.velocity += impulse

func calculate_damage(distance: float) -> float:
	# If the distance is greater than the explosion radius, the player is outside the explosion range
	if distance > explosion_radius:
		return 0.0
	
	# Linear interpolation between max_damage and min_damage based on the distance
	var t: float = distance / explosion_radius
	var damage: float = max_damage - t * (max_damage - min_damage)
	
	# Ensure that the damage does not exceed max_damage or go below min_damage
	return clamp(damage, min_damage, max_damage)

func _ready() -> void:
	smoke.emitting = true
	# Scan for all players within the explosion radius
	var players: Array = get_tree().get_nodes_in_group("players")
	for player: Node in players:
		var character: CharacterBody3D = player as CharacterBody3D
		if character:
			var distance: float = character.global_transform.origin.distance_to(global_transform.origin)
			if distance <= explosion_radius:
				apply_explosion_force(character)
				if character != owner_player:
					character.rpc("receive_damage", calculate_damage(distance))

func _on_timer_timeout() -> void:
	queue_free()
