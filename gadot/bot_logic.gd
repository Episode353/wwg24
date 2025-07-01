extends Node3D

# ============================================================================
# Node References (onready)
# ============================================================================
@onready var player: CharacterBody3D = $".."
@onready var weapons_manager: Node3D = $"../neck/head/main_camera/Weapons_Manager"
@onready var fps_rig: Node3D = $"../neck/head/main_camera/Weapons_Manager/FPS_RIG"
@onready var neck: Node3D = $"../neck"
@onready var nav_agent: NavigationAgent3D = $"../NavigationAgent3D"
@onready var bot_label: Label3D = $"../Bot_Label"
@onready var bot_debug_direction: CSGCylinder3D = $"../neck/head/main_camera/bot_debug_direction"

# ============================================================================
# Constants and Variables
# ============================================================================
var BOT_SPEED = 8.0
var shoot_cooldown_time := randf_range(0.1, 0.5)
var shoot_timer := 0.0
const GRAVITY: float = -9.8
const MAX_SHOOT_DISTANCE := 20.0
const MAX_SHOOT_DISTANCE_SQUARED := MAX_SHOOT_DISTANCE * MAX_SHOOT_DISTANCE
var retreat_health: int = 50

# Member variables
var frame_count: int = 0
var path_position_often: int = int(randf_range(10, 20))
var next_location: Vector3 = Vector3.ZERO
var bot_id: int = 0  # Unique ID for staggering updates

# ============================================================================
# ENHANCED OPTIMIZATION VARIABLES
# ============================================================================
# Staggered update frequencies to spread load across frames
var base_sync_frequency: int = 12
var base_scan_frequency: int = 20
var health_scan_frequency: int = 8
var aim_update_frequency: int = 3

# Actual frequencies (will be staggered)
var sync_frequency: int
var scan_frequency: int
var health_scan_frequency_actual: int
var aim_update_frequency_actual: int

# Cached data with better management
var cached_players: Array = []
var cached_health_packs: Array = []
var cached_valid_health_packs: Array = []  # Pre-filtered valid health packs
var last_player_scan_frame: int = 0
var last_health_scan_frame: int = 0
var closest_cached_player: CharacterBody3D = null
var closest_cached_health_pack: Node3D = null
var cached_health_pack_position: Vector3 = Vector3.ZERO

# Performance caches
var cached_my_position: Vector3 = Vector3.ZERO
var cached_player_distance_squared: float = INF
var cached_health_distance_squared: float = INF
var should_update_aim: bool = false
var should_update_health_target: bool = false

# Pre-allocated arrays to avoid memory allocation
var temp_players: Array = []
var temp_health_packs: Array = []

# Combat state caching
var is_in_combat: bool = false
var is_retreating: bool = false
var last_retreat_state: bool = false

# Stuck detection and fallback
var retreat_start_frame: int = 0
var last_position: Vector3 = Vector3.ZERO
var stuck_frame_count: int = 0
var stuck_threshold_frames: int = 180  # 3 seconds at 60fps
var fallback_mode: bool = false
var fallback_target: Vector3 = Vector3.ZERO
var last_health_pack_check_frame: int = 0

# Static shared data for all bots (memory optimization)
static var shared_health_packs: Array = []
static var shared_health_packs_frame: int = 0
static var bot_counter: int = 0

# ============================================================================
# Lifecycle Functions
# ============================================================================

func _ready() -> void:
	frame_count = 0
	last_player_scan_frame = 0
	last_health_scan_frame = 0
	
	# Assign unique bot ID for staggered updates
	bot_id = bot_counter
	bot_counter += 1
	
	# Stagger update frequencies based on bot ID to spread load
	sync_frequency = base_sync_frequency + (bot_id % 5)
	scan_frequency = base_scan_frequency + (bot_id % 8)
	health_scan_frequency_actual = health_scan_frequency + (bot_id % 4)
	aim_update_frequency_actual = aim_update_frequency + (bot_id % 2)
	
	initialize_bot()

func _physics_process(delta: float) -> void:
	if player.is_bot:
		bot_physics_process(delta)

# ============================================================================
# Bot Initialization & Physics
# ============================================================================

func initialize_bot() -> void:
	if not player.is_bot:
		return
	bot_label.show()
	bot_debug_direction.show()
	weapons_manager.infinite_ammo = true
	weapons_manager.add_weapon(player.bot_starter_weapon)
	
	# Pre-allocate arrays
	temp_players.clear()
	temp_health_packs.clear()

func bot_physics_process(delta: float) -> void:
	# Cache position once per frame
	cached_my_position = global_transform.origin
	
	# Update state flags
	var current_health = player.health
	is_retreating = current_health < retreat_health
	is_in_combat = closest_cached_player != null
	
	# Reset fallback mode if health is restored
	if not is_retreating and fallback_mode:
		fallback_mode = false
		print("Bot ", bot_id, " exiting fallback mode - health restored")
	
	# Only update targets when state changes or at intervals
	var state_changed = is_retreating != last_retreat_state
	last_retreat_state = is_retreating
	
	if state_changed:
		should_update_aim = true
		should_update_health_target = true
		if is_retreating:
			print("Bot ", bot_id, " entering retreat mode with health: ", current_health)
		else:
			print("Bot ", bot_id, " exiting retreat mode with health: ", current_health)
	
	# Update target selection, aiming, and shooting
	find_objects(delta)
	
	frame_count += 1
	
	# Update navigation less frequently
	if frame_count % path_position_often == 0:
		next_location = nav_agent.get_next_path_position()
	
	# Optimized movement calculation (cached when possible)
	update_movement(delta)
	
	# Staggered network sync
	if frame_count % sync_frequency == 0:
		rpc("sync_bot_transform", player.global_transform)
		rpc("sync_neck_local_transform", neck.transform)

func update_movement(delta: float) -> void:
	var desired_direction: Vector3 = (next_location - cached_my_position).normalized()
	var desired_horizontal_velocity: Vector3 = desired_direction * BOT_SPEED
	
	var current_velocity: Vector3 = player.velocity
	var current_horizontal_velocity: Vector3 = Vector3(current_velocity.x, 0, current_velocity.z)
	
	current_horizontal_velocity = current_horizontal_velocity.move_toward(desired_horizontal_velocity, 0.25)
	current_velocity.y += GRAVITY * delta
	
	player.velocity = Vector3(current_horizontal_velocity.x, current_velocity.y, current_horizontal_velocity.z)
	player.move_and_slide()

# ============================================================================
# IMPROVED Health Pack Detection
# ============================================================================

# Optimized health drop detection using shared cache
func get_health_packs_optimized() -> Array:
	# Use shared cache to avoid multiple bots scanning simultaneously
	if frame_count - shared_health_packs_frame < 10:  # Cache for 10 frames
		return shared_health_packs
	
	# Update shared cache
	shared_health_packs.clear()
	var root = get_tree().root
	_find_nodes_named("HealthDrop", root, shared_health_packs)
	shared_health_packs_frame = frame_count
	
	return shared_health_packs

func _find_nodes_named(target_name: String, node: Node, result: Array) -> void:
	if node.name == target_name:
		result.append(node)
	for child in node.get_children():
		_find_nodes_named(target_name, child, result)

# ============================================================================
# Target Selection, Aiming, and Shooting
# ============================================================================

func find_objects(delta: float) -> void:
	shoot_timer = max(shoot_timer - delta, 0)
	
	# Handle retreat logic with improved health pack targeting
	if is_retreating:
		handle_retreat_behavior()
		return
	
	# Combat behavior
	handle_combat_behavior(delta)

func handle_retreat_behavior() -> void:
	# More frequent health pack scanning when retreating
	if should_update_health_target or (frame_count - last_health_scan_frame >= health_scan_frequency_actual):
		cached_health_packs = get_health_packs_optimized()
		
		# Pre-filter valid health packs to avoid repeated validity checks
		cached_valid_health_packs.clear()
		for health in cached_health_packs:
			if is_instance_valid(health) and health is Node3D:
				cached_valid_health_packs.append(health)
		
		# Find the ACTUAL closest health pack every time during retreat
		var closest_pack = find_closest_reachable_health_pack()
		
		if closest_pack != closest_cached_health_pack or should_update_health_target:
			closest_cached_health_pack = closest_pack
			should_update_health_target = false
			
			if closest_cached_health_pack:
				cached_health_pack_position = closest_cached_health_pack.global_transform.origin
				cached_health_distance_squared = cached_my_position.distance_squared_to(cached_health_pack_position)
				
				print("Bot ", bot_id, " retreating to health pack at: ", cached_health_pack_position, 
					  " Distance: ", sqrt(cached_health_distance_squared))
			else:
				print("Bot ", bot_id, " - No reachable health packs found, entering fallback behavior")
		
		last_health_scan_frame = frame_count
	
	# Handle navigation with stuck detection and fallback
	handle_retreat_navigation()

func handle_combat_behavior(delta: float) -> void:
	# Optimized player scanning with staggering
	if frame_count - last_player_scan_frame >= scan_frequency:
		cached_players = get_tree().get_nodes_in_group("players")
		var player_result = find_closest_valid_player_optimized()
		closest_cached_player = player_result[0]
		cached_player_distance_squared = player_result[1]
		last_player_scan_frame = frame_count
		should_update_aim = true

	if closest_cached_player and is_instance_valid(closest_cached_player):
		var target_pos = closest_cached_player.global_transform.origin
		update_target_location(target_pos)
		
		# Staggered aiming updates
		if should_update_aim or (frame_count % aim_update_frequency_actual == 0):
			update_aiming(delta)
			should_update_aim = false
		
		# Optimized shooting logic
		var weapon_range_squared = float(player.bot_weapon_range) * float(player.bot_weapon_range)
		if cached_player_distance_squared < weapon_range_squared \
				and cached_player_distance_squared < MAX_SHOOT_DISTANCE_SQUARED \
				and shoot_timer <= 0.0 \
				and is_well_aimed():
			
			if randf() > 0.1:
				weapons_manager.shoot()
				shoot_timer = shoot_cooldown_time
	else:
		# Player is no longer valid, clear cache
		closest_cached_player = null
		cached_player_distance_squared = INF

# FIXED: Find closest health pack that's actually reachable
func find_closest_reachable_health_pack() -> Node3D:
	var closest_health_pack: Node3D = null
	var closest_dist_squared := INF
	
	# Use pre-filtered valid health packs
	for health in cached_valid_health_packs:
		var health_pos = health.global_transform.origin
		var dist_squared = cached_my_position.distance_squared_to(health_pos)
		
		# Quick distance check first
		if dist_squared < closest_dist_squared:
			# Test if we can actually reach this health pack
			if can_reach_target(health_pos):
				closest_dist_squared = dist_squared
				closest_health_pack = health
	
	return closest_health_pack

# Check if a target position is reachable via navigation
func can_reach_target(target_pos: Vector3) -> bool:
	# Simple distance and line-of-sight check
	var distance = cached_my_position.distance_to(target_pos)
	
	# If too far, probably not worth trying
	if distance > 50.0:
		return false
	
	# Check for major obstacles using a raycast
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		cached_my_position + Vector3(0, 1, 0),  # Start slightly above ground
		target_pos + Vector3(0, 1, 0)           # End slightly above ground
	)
	query.exclude = [player]  # Don't hit ourselves
	
	var result = space_state.intersect_ray(query)
	
	# If no collision, path is likely clear
	if not result:
		return true
	
	# If collision is close to the target, it might still be reachable
	var collision_distance = cached_my_position.distance_to(result.position)
	var target_distance = cached_my_position.distance_to(target_pos)
	
	# If collision is within 3 units of target, consider it reachable
	return (target_distance - collision_distance) < 3.0

# Handle retreat navigation with stuck detection and fallback
func handle_retreat_navigation() -> void:
	# Initialize retreat timing
	if not last_retreat_state and is_retreating:
		retreat_start_frame = frame_count
		last_position = cached_my_position
		stuck_frame_count = 0
		fallback_mode = false
	
	# Check if bot is stuck (not moving significantly)
	var position_change = cached_my_position.distance_to(last_position)
	if position_change < 0.5:  # Less than 0.5 units movement
		stuck_frame_count += 1
	else:
		stuck_frame_count = 0
		last_position = cached_my_position
	
	# Enter fallback mode if stuck too long or no valid health pack
	var stuck_too_long = stuck_frame_count > stuck_threshold_frames
	var no_health_pack = closest_cached_health_pack == null
	var been_retreating_too_long = (frame_count - retreat_start_frame) > 900  # 15 seconds at 60fps
	
	if stuck_too_long or no_health_pack or been_retreating_too_long:
		if not fallback_mode:
			print("Bot ", bot_id, " entering fallback mode - stuck: ", stuck_too_long, 
				  " no health: ", no_health_pack, " timeout: ", been_retreating_too_long)
			enter_fallback_mode()
		handle_fallback_behavior()
		return
	
	# Normal retreat behavior
	if closest_cached_health_pack and is_instance_valid(closest_cached_health_pack):
		# Periodically re-verify the health pack is still reachable
		if frame_count - last_health_pack_check_frame > 120:  # Check every 2 seconds at 60fps
			if not can_reach_target(closest_cached_health_pack.global_transform.origin):
				print("Bot ", bot_id, " - Current health pack became unreachable, searching for new one")
				should_update_health_target = true
				return
			last_health_pack_check_frame = frame_count
		
		# Update target position
		var current_health_pos = closest_cached_health_pack.global_transform.origin
		var current_distance_squared = cached_my_position.distance_squared_to(current_health_pos)
		
		# If the distance has changed significantly, update our target
		if abs(current_distance_squared - cached_health_distance_squared) > 4.0:
			cached_health_pack_position = current_health_pos
			cached_health_distance_squared = current_distance_squared
		
		player.wish_jump = true
		update_target_location(cached_health_pack_position)
		
		# Check if we're getting close enough to the health pack
		if current_distance_squared < 9.0:  # Within 3 units
			print("Bot ", bot_id, " is close to health pack, stopping retreat navigation")
	else:
		# Health pack is no longer valid, force rescan
		should_update_health_target = true

func enter_fallback_mode() -> void:
	fallback_mode = true
	
	# Generate a random fallback position away from current location
	var random_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	fallback_target = cached_my_position + random_direction * 15.0  # Move 15 units away
	
	# Ensure the fallback target is on the navigation mesh
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		fallback_target + Vector3(0, 5, 0), 
		fallback_target - Vector3(0, 10, 0)
	)
	var result = space_state.intersect_ray(query)
	if result:
		fallback_target.y = result.position.y + 1.0  # Slightly above ground
	
	print("Bot ", bot_id, " fallback target set to: ", fallback_target)

func handle_fallback_behavior() -> void:
	# In fallback mode, just move to the fallback position and keep scanning for health packs
	update_target_location(fallback_target)
	player.wish_jump = true
	
	# Continue scanning for health packs while in fallback mode
	should_update_health_target = true
	
	# If we've reached the fallback target, generate a new one
	if cached_my_position.distance_to(fallback_target) < 3.0:
		enter_fallback_mode()  # Generate new fallback target

# Optimized aiming function with reduced calculations
func update_aiming(delta: float) -> void:
	if not closest_cached_player or not is_instance_valid(closest_cached_player):
		return
		
	var aim_offset: Vector3 = Vector3(0, 1.5, 0)
	var adjusted_target: Vector3 = closest_cached_player.global_transform.origin + aim_offset
	var target_direction: Vector3 = (adjusted_target - neck.global_transform.origin).normalized()
	var target_basis: Basis = Basis().looking_at(target_direction, Vector3.UP)
	
	var current_basis: Basis = neck.global_transform.basis
	var max_rotation_speed: float = deg_to_rad(200)
	var t: float = clamp(max_rotation_speed * delta, 0, 1)
	neck.global_transform.basis = current_basis.slerp(target_basis, t)

# Optimized aim checking with cached calculations
func is_well_aimed() -> bool:
	if not closest_cached_player or not is_instance_valid(closest_cached_player):
		return false
		
	var neck_forward = -neck.global_transform.basis.z
	var target_direction: Vector3 = (closest_cached_player.global_transform.origin + Vector3(0, 1.5, 0) - neck.global_transform.origin).normalized()
	return neck_forward.dot(target_direction) > 0.96

# Optimized player finding with better caching
func find_closest_valid_player_optimized() -> Array:
	var closest_player: CharacterBody3D = null
	var min_distance_squared: float = INF
	
	for other in cached_players:
		if not (other is CharacterBody3D) or other == player or not is_instance_valid(other):
			continue
		
		if other.is_bot and not Globals.bots_fight:
			continue
		
		var distance_squared: float = cached_my_position.distance_squared_to(other.global_transform.origin)
		if distance_squared < min_distance_squared:
			min_distance_squared = distance_squared
			closest_player = other
	
	return [closest_player, min_distance_squared]

func update_target_location(target_location: Vector3) -> void:
	nav_agent.set_target_position(target_location)

# ============================================================================
# Remote Procedure Calls (RPCs)
# ============================================================================

@rpc("any_peer", "call_local")
func sync_bot_transform(new_transform: Transform3D) -> void:
	player.global_transform = new_transform

@rpc("any_peer", "call_local")
func sync_neck_local_transform(new_transform: Transform3D) -> void:
	neck.transform = new_transform
