extends CharacterBody3D



@onready var nav_agent = $NavigationAgent3D
var SPEED = 3.0

func _physics_process(delta):
	find_objects()
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	var new_velocity = (next_location - current_location).normalized() * SPEED
	velocity = new_velocity
	move_and_slide()
	
func update_target_location(target_location):
	print(target_location)
	nav_agent.set_target_position(target_location)

func find_objects():
	var players = get_tree().get_nodes_in_group("players")
		
	var closest_player = null
	var min_distance = INF  # Start with a very high value.
	var my_position = global_transform.origin

	# Iterate over all players to find the closest one.
	for player in players:
		# Skip self to avoid counting the current player.
		if player.is_bot:
			continue
		
		var player_position = player.global_transform.origin
		var distance = my_position.distance_to(player_position)
		
		if distance < min_distance:
			min_distance = distance
			closest_player = player

	# If a closest player was found, update the navigation target.
	if closest_player:
		update_target_location(closest_player.global_transform.origin)
