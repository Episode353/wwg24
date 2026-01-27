extends Node3D

# ============================================================================
# Node References
# ============================================================================
@onready var player: CharacterBody3D = $".."
@onready var weapons_manager: Node3D = $"../neck/head/main_camera/Weapons_Manager"
@onready var neck: Node3D = $"../neck"
@onready var nav_agent: NavigationAgent3D = $"../NavigationAgent3D"
@onready var bot_label: Label3D = $"../Bot_Label"
@onready var bot_debug_direction: CSGCylinder3D = $"../neck/head/main_camera/bot_debug_direction"

# ============================================================================
# Constants
# ============================================================================
const BOT_SPEED = 8.0
const GRAVITY = -9.8
const MAX_SHOOT_DISTANCE = 20.0
const HEALTH_THRESHOLD = 50
const MANA_THRESHOLD = 15

# ============================================================================
# Bot State System
# ============================================================================
enum BotState {
	COMBAT,
	SEEKING_HEALTH,
	SEEKING_AMMO,
	SEEKING_MANA
}

var current_state: BotState = BotState.COMBAT
var bot_id: int = 0
var frame_count: int = 0

# ============================================================================
# Staggered Update System
# ============================================================================
var scan_frequency: int
var aim_frequency: int
var movement_frequency: int
var state_check_frequency: int

# ============================================================================
# Cached Targets
# ============================================================================
var target_player: CharacterBody3D = null
var target_health_pack: Node3D = null
var target_ammo_pack: Node3D = null
var target_mana_pack: Node3D = null
var movement_target: Vector3 = Vector3.ZERO

# ============================================================================
# Combat Variables
# ============================================================================
var shoot_timer: float = 0.0
var shoot_cooldown: float = 0.3
var spell_timer: float = 0.0
var spell_duration: float = 2.0

# ============================================================================
# Bot Counter for Staggering
# ============================================================================
static var bot_counter: int = 0
@onready var the_power: Node3D = $"../neck/head/main_camera/Weapons_Manager/FPS_RIG/the_power"

# ============================================================================
# Initialization
# ============================================================================
func _ready() -> void:
	if !player.is_bot:
		return
		
	# Setup bot ID and staggered frequencies
	bot_id = bot_counter
	bot_counter += 1
	
	# Stagger update frequencies based on bot ID
	scan_frequency = 5 + (bot_id % 3)
	aim_frequency = 2 + (bot_id % 2)
	movement_frequency = 3 + (bot_id % 2)
	state_check_frequency = 4 + (bot_id % 3)
	
	initialize_bot()

func initialize_bot() -> void:
	bot_label.show()
	
	weapons_manager.infinite_ammo = true
	weapons_manager.add_weapon(player.bot_starter_weapon)
	
	# Show Bot Debug Information
	#bot_debug_direction.show()
	#nav_agent.debug_enabled = Globals.show_bot_path
	
	# Initialize movement target
	movement_target = get_wander_position()

func _physics_process(delta: float) -> void:
	if !player.is_bot:
		return
	
	frame_count += 1
	shoot_timer = max(shoot_timer - delta, 0.0)
	spell_timer += delta
	
	# Handle spell switching for wand
	handle_spell_switching()
	
	# Fire damage calculation
	player.calculate_fire_damage()
	
	# Staggered updates
	if frame_count % state_check_frequency == 0:
		update_bot_state()
	
	if frame_count % scan_frequency == 0:
		scan_for_targets()
	
	if frame_count % aim_frequency == 0:
		update_aiming(delta)
	
	if frame_count % movement_frequency == 0:
		update_movement_target()
	
	# Always handle combat and movement
	handle_combat(delta)
	handle_movement(delta)
	
	# Debug output occasionally
	if frame_count % 120 == 0:  # Every 2 seconds at 60fps
		print("Bot ", bot_id, " State: ", BotState.keys()[current_state], " Target: ", movement_target)
	
	# Network sync
	if frame_count % 5 == 0:
		sync_transforms()

# ============================================================================
# State Management
# ============================================================================
func update_bot_state() -> void:
	var current_health = player.health
	var current_mana = player.mana
	var has_ammo = weapons_manager.current_weapon.current_ammo > 0
	var has_reserve_ammo = weapons_manager.current_weapon.reserve_ammo > 0
	
	# Priority order: Health -> Ammo -> Mana -> Combat
	if current_health < HEALTH_THRESHOLD:
		set_state(BotState.SEEKING_HEALTH)
	elif not has_ammo and not has_reserve_ammo and not weapons_manager.current_weapon.disable_ammo:
		set_state(BotState.SEEKING_AMMO)
	elif current_mana < MANA_THRESHOLD:
		set_state(BotState.SEEKING_MANA)
	else:
		set_state(BotState.COMBAT)

func set_state(new_state: BotState) -> void:
	if current_state != new_state:
		current_state = new_state
		print("Bot ", bot_id, " changing state to: ", BotState.keys()[new_state])
		
		# Handle state transition actions
		match new_state:
			BotState.COMBAT:
				handle_state_transition_to_combat()

func handle_state_transition_to_combat() -> void:
	# Check if we need to reload after getting ammo
	var weapon = weapons_manager.current_weapon
	if weapon.current_ammo == 0 and weapon.reserve_ammo > 0:
		weapons_manager.reload()
		print("Bot ", bot_id, " reloading after getting ammo")

# ============================================================================
# Target Scanning
# ============================================================================
func scan_for_targets() -> void:
	match current_state:
		BotState.COMBAT:
			scan_for_players()
		BotState.SEEKING_HEALTH:
			scan_for_health_packs()
		BotState.SEEKING_AMMO:
			scan_for_ammo_packs()
		BotState.SEEKING_MANA:
			scan_for_mana_packs()
	
	# Always scan for players for combat
	if current_state != BotState.COMBAT:
		scan_for_players()

func scan_for_players() -> void:
	var players = get_tree().get_nodes_in_group("players")
	target_player = find_closest_valid_target(players, func(p): return is_valid_player_target(p))

func scan_for_health_packs() -> void:
	var health_packs = get_tree().get_nodes_in_group("HealthDrop")
	target_health_pack = find_closest_valid_target(health_packs, func(h): return is_instance_valid(h))

func scan_for_ammo_packs() -> void:
	var ammo_packs = get_tree().get_nodes_in_group("ammo_pack")
	target_ammo_pack = find_closest_valid_target(ammo_packs, func(a): return is_instance_valid(a))

func scan_for_mana_packs() -> void:
	var mana_packs = get_tree().get_nodes_in_group("mana_drop")
	target_mana_pack = find_closest_valid_target(mana_packs, func(m): return is_instance_valid(m))

func find_closest_valid_target(targets: Array, validation_func: Callable) -> Node3D:
	var closest_target: Node3D = null
	var min_distance_squared: float = INF
	var my_position = global_transform.origin
	
	for target in targets:
		if not validation_func.call(target):
			continue
			
		var distance_squared = my_position.distance_squared_to(target.global_transform.origin)
		if distance_squared < min_distance_squared:
			min_distance_squared = distance_squared
			closest_target = target
	
	return closest_target

func is_valid_player_target(other_player: Node3D) -> bool:
	if not (other_player is CharacterBody3D) or other_player == player:
		return false
	if not is_instance_valid(other_player):
		return false
	if other_player.is_bot and not Globals.bots_fight:
		return false
	return true

# ============================================================================
# Movement System
# ============================================================================
func update_movement_target() -> void:
	var my_pos = global_transform.origin
	
	match current_state:
		BotState.COMBAT:
			if target_player and is_instance_valid(target_player):
				movement_target = get_combat_position(target_player.global_transform.origin)
			else:
				movement_target = get_wander_position()
		
		BotState.SEEKING_HEALTH:
			if target_health_pack and is_instance_valid(target_health_pack):
				movement_target = target_health_pack.global_transform.origin
			else:
				movement_target = get_wander_position()  # Fallback if no health pack found
		
		BotState.SEEKING_AMMO:
			if target_ammo_pack and is_instance_valid(target_ammo_pack):
				movement_target = target_ammo_pack.global_transform.origin
			else:
				movement_target = get_wander_position()  # Fallback if no ammo pack found
		
		BotState.SEEKING_MANA:
			if target_mana_pack and is_instance_valid(target_mana_pack):
				movement_target = target_mana_pack.global_transform.origin
			else:
				movement_target = get_wander_position()  # Fallback if no mana pack found

func get_combat_position(target_pos: Vector3) -> Vector3:
	var my_pos = global_transform.origin
	var to_target = my_pos.direction_to(target_pos)
	var strafe_dir = to_target.cross(Vector3.UP).normalized()
	var strafe_distance = 3.0
	var strafe_offset = strafe_dir * sin(float(frame_count) * 0.1) * strafe_distance
	return target_pos + strafe_offset

func get_wander_position() -> Vector3:
	var my_pos = global_transform.origin
	var random_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	return my_pos + random_direction * 5.0

func handle_movement(delta: float) -> void:
	if movement_target == Vector3.ZERO:
		# Emergency fallback - just wander
		movement_target = get_wander_position()
	
	# Simple safety check - if target is too far, get a closer one
	var my_pos = global_transform.origin
	var distance_to_target = my_pos.distance_to(movement_target)
	
	if distance_to_target > 50.0:  # Target too far, get closer target
		movement_target = my_pos + (movement_target - my_pos).normalized() * 20.0
	
	# Use navigation agent
	nav_agent.set_target_position(movement_target)
	
	# Get next position from nav agent
	var next_position = nav_agent.get_next_path_position()
	var direction = (next_position - my_pos).normalized()
	
	# Simple safety check - make sure we're not moving into void
	if not is_safe_direction(my_pos, direction):
		# Try a slightly different direction
		var alt_directions = [
			direction.rotated(Vector3.UP, deg_to_rad(30)),
			direction.rotated(Vector3.UP, deg_to_rad(-30)),
			direction.rotated(Vector3.UP, deg_to_rad(60)),
			direction.rotated(Vector3.UP, deg_to_rad(-60))
		]
		
		for alt_dir in alt_directions:
			if is_safe_direction(my_pos, alt_dir):
				direction = alt_dir
				break
	
	# Apply movement
	var desired_velocity = direction * BOT_SPEED
	var current_velocity = player.velocity
	var horizontal_velocity = Vector3(current_velocity.x, 0, current_velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, 0.5)  # Faster lerp
	
	current_velocity.y += GRAVITY * delta
	player.velocity = Vector3(horizontal_velocity.x, current_velocity.y, horizontal_velocity.z)
	player.move_and_slide()

func is_safe_direction(from_pos: Vector3, direction: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state
	
	# Check for walls (shorter distance, more forgiving)
	var wall_query = PhysicsRayQueryParameters3D.create(
		from_pos + Vector3(0, 1, 0),
		from_pos + direction.normalized() * 1.0 + Vector3(0, 1, 0)
	)
	wall_query.exclude = [player]
	var wall_result = space_state.intersect_ray(wall_query)
	
	if wall_result:
		return false  # Wall detected
	
	# Check for ledges (more forgiving)
	var ground_check_pos = from_pos + direction.normalized() * 1.5
	var ledge_query = PhysicsRayQueryParameters3D.create(
		ground_check_pos + Vector3(0, 0.5, 0),
		ground_check_pos - Vector3(0, 3, 0)
	)
	ledge_query.exclude = [player]
	var ground_result = space_state.intersect_ray(ledge_query)
	
	return ground_result != null  # Ground found = safe

# ============================================================================
# Combat System
# ============================================================================
func handle_combat(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		return
	
	# Check if we can shoot
	var distance_to_target = global_transform.origin.distance_to(target_player.global_transform.origin)
	var weapon_range = float(player.bot_weapon_range)
	
	if distance_to_target <= weapon_range and distance_to_target <= MAX_SHOOT_DISTANCE:
		if shoot_timer <= 0.0 and is_well_aimed():
			if randf() > 0.20:  # Small chance to miss
				bot_shoot()
				shoot_timer = shoot_cooldown
				
func bot_shoot() -> void:
	weapons_manager.shoot()
	
	if weapons_manager.current_weapon.weapon_name == "keyboard":
		var spell_names = the_power.spell_sequences.keys()
		if spell_names.size() > 0:
			var random_spell = spell_names[randi() % spell_names.size()]
			the_power.activate_spell(random_spell)
			print(random_spell)


func update_aiming(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		return
	
	var aim_offset = Vector3(0, 1.75, 0)
	var target_pos = target_player.global_transform.origin + aim_offset
	var from_pos = neck.global_transform.origin
	
	# Smooth look_at
	var target_transform = neck.global_transform.looking_at(target_pos, Vector3.UP)
	neck.global_transform.basis = neck.global_transform.basis.slerp(target_transform.basis, delta * 5.0)

func is_well_aimed() -> bool:
	if not target_player or not is_instance_valid(target_player):
		return false
	
	var aim_offset = Vector3(0, 1.5, 0)
	var target_pos = target_player.global_transform.origin + aim_offset
	var from_pos = neck.global_transform.origin
	
	var neck_forward = -neck.global_transform.basis.z
	var target_direction = (target_pos - from_pos).normalized()
	
	return neck_forward.dot(target_direction) > 0.85

# ============================================================================
# Utility Functions
# ============================================================================
func handle_spell_switching() -> void:
	if weapons_manager.current_weapon.weapon_name == "wand" and spell_timer >= spell_duration:
		spell_timer = 0.0
		var spells = weapons_manager.get_wand_spells()
		if spells.size() > 0:
			weapons_manager.set_wand_spell(spells[randi() % spells.size()])

func sync_transforms() -> void:
	rpc("sync_bot_transform", player.global_transform)
	rpc("sync_neck_local_transform", neck.transform)

# ============================================================================
# Network RPCs
# ============================================================================
@rpc("any_peer", "call_local")
func sync_bot_transform(new_transform: Transform3D) -> void:
	player.global_transform = new_transform

@rpc("any_peer", "call_local")
func sync_neck_local_transform(new_transform: Transform3D) -> void:
	neck.transform = new_transform
