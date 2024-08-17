extends Node3D

# Radius of the explosion effect
@export var explosion_radius: float = 6.0
# Strength of the explosion force


# Maximum damage for a direct hit
@export var max_damage: float = 10.0
# Minimum damage at the edge of explosion radius
@export var min_damage: float = 0.0
var owner_player

@onready var smoke = $Smoke



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
	# Scan for all players within the explosion radius
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		var distance = player.global_transform.origin.distance_to(global_transform.origin)
		if distance <= explosion_radius:
			if player != owner_player:
				player.rpc("receive_damage", calculate_damage(distance))
	



func _on_timer_timeout():
	queue_free()
