extends Node3D

# ============================================================================
# Node References (onready)
# ============================================================================
@onready var player: CharacterBody3D            = $".."
@onready var weapons_manager: Node3D   = $"../neck/head/main_camera/Weapons_Manager"
@onready var fps_rig: Node3D = $"../neck/head/main_camera/Weapons_Manager/FPS_RIG"
@onready var neck: Node3D              = $"../neck"
@onready var nav_agent: NavigationAgent3D         = $"../NavigationAgent3D"
@onready var bot_label: Label3D = $"../Bot_Label"
@onready var bot_debug_direction: CSGCylinder3D = $"../neck/head/main_camera/bot_debug_direction"


# ============================================================================
# Constants and Variables
# ============================================================================
var BOT_SPEED = 8.0
var shoot_cooldown_time := randf_range(0.5, 1.5)
var shoot_timer := 0.0
# Define a gravity constant (adjust as needed for your game)
const GRAVITY: float = -9.8


# Member variables
var frame_count: int = 0

# The reason we do this is because we want to limit how often we do a get_next path_position
# but we also dont want all the bots doing this calculaton on the same frame
# I found that 20 is the max we can go before their movement is weird
var path_position_often: int = randf_range(10, 20)
var next_location: Vector3 = Vector3.ZERO
# ============================================================================
# Lifecycle Functions
# ============================================================================

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialization code goes here.
	initialize_bot()
	pass

# Called every physics frame.
func _physics_process(delta: float) -> void:
	if player.is_bot:
		bot_physics_process(delta)

# ============================================================================
# Bot Initialization & Physics
# ============================================================================

# Initialize bot-specific settings.
func initialize_bot() -> void:
	if not player.is_bot:
		return
	# Show debug labels and directions.
	bot_label.show()
	bot_debug_direction.show()

	# Configure weapons manager for bots.
	weapons_manager.infinite_ammo = true
	weapons_manager.add_weapon(player.bot_starter_weapon)
	#fps_rig.show()  # Ensure FPS_RIG is visible



func bot_physics_process(delta: float) -> void:
	# Update target selection, aiming, and shooting.
	find_objects(delta)
	
	# Increment the frame counter.
	frame_count += 1
	# Update the next navigation point every four frames.
	if frame_count % path_position_often == 0:
		next_location = nav_agent.get_next_path_position()
	
	# Compute horizontal movement towards the next navigation point.
	var current_location: Vector3 = global_transform.origin
	var desired_direction: Vector3 = (next_location - current_location).normalized()

	# Calculate the desired horizontal velocity (ignoring vertical component).
	var desired_horizontal_velocity: Vector3 = desired_direction * BOT_SPEED

	# Separate current velocity into horizontal and vertical components.
	var current_velocity: Vector3 = player.velocity
	var current_vertical_velocity: float = current_velocity.y
	var current_horizontal_velocity: Vector3 = Vector3(current_velocity.x, 0, current_velocity.z)

	# Smoothly interpolate horizontal velocity.
	current_horizontal_velocity = current_horizontal_velocity.move_toward(desired_horizontal_velocity, 0.25)
	
	# Apply gravity to the vertical velocity.
	current_vertical_velocity += GRAVITY * delta
	
	# Combine horizontal and vertical components back into the full velocity.
	player.velocity = Vector3(current_horizontal_velocity.x, current_vertical_velocity, current_horizontal_velocity.z)

	# Move the player, allowing gravity to take effect.
	player.move_and_slide()

	# Synchronize transforms with remote peers.
	rpc("sync_bot_transform", player.global_transform)
	rpc("sync_neck_local_transform", neck.transform)


# ============================================================================
# Target Selection, Aiming, and Shooting
# ============================================================================

# Finds the closest non-bot player, updates the navigation target,
# aims the bot's neck, and shoots if within range.
func find_objects(delta: float) -> void:
	# Decrease shoot timer.
	shoot_timer = max(shoot_timer - delta, 0)
	
	# Get all players in the scene.
	var players = get_tree().get_nodes_in_group("players")
	
	var closest_player: CharacterBody3D = null
	var min_distance: float = INF
	var my_position: Vector3 = global_transform.origin

	# Identify the closest non-bot player.
	for other in players:
		if not (other is CharacterBody3D):
			continue
		if other.is_bot:
			continue
		
		var distance: float = my_position.distance_to(other.global_transform.origin)
		if distance < min_distance:
			min_distance = distance
			closest_player = other

	# If a valid target is found, update navigation, aim, and shoot.
	if closest_player:
		update_target_location(closest_player.global_transform.origin)
		
		# Aim at the target with an offset (e.g., 1.5 meters above the player's origin).
		var aim_offset: Vector3 = Vector3(0, 1.5, 0)
		var adjusted_target: Vector3 = closest_player.global_transform.origin + aim_offset
		var target_direction: Vector3 = (adjusted_target - neck.global_transform.origin).normalized()
		var target_basis: Basis = Basis().looking_at(target_direction, Vector3.UP)
		
		# Smoothly interpolate the neck's rotation towards the target.
		var current_basis: Basis = neck.global_transform.basis
		var max_rotation_speed: float = deg_to_rad(300)  # Higher value means faster head movement.
		var t: float = clamp(max_rotation_speed * delta, 0, 1)
		neck.global_transform.basis = current_basis.slerp(target_basis, t)
		
		# Synchronize the neck's transform on remote peers.
		rpc("sync_neck_local_transform", neck.transform)
		
		# Shoot if the target is within 5.0 units and the cooldown has elapsed.
		if min_distance < float(player.bot_weapon_range) and shoot_timer <= 0.0:
			weapons_manager.shoot()
			shoot_timer = shoot_cooldown_time

# Update the navigation agent's target position.
func update_target_location(target_location: Vector3) -> void:
	nav_agent.set_target_position(target_location)

# ============================================================================
# Remote Procedure Calls (RPCs)
# ============================================================================

# Sync the bot's overall transform with remote peers.
@rpc("any_peer", "call_local")
func sync_bot_transform(new_transform: Transform3D) -> void:
	player.global_transform = new_transform

# Sync the neck's local transform with remote peers.
@rpc("any_peer", "call_local")
func sync_neck_local_transform(new_transform: Transform3D) -> void:
	neck.transform = new_transform
