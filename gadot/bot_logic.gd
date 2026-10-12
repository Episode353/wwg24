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
const HEALTH_THRESHOLD = 50
const MANA_THRESHOLD = 15

# Navigation
const REPATH_DISTANCE = 1.0 # Goal has to move this far before the path is recalculated
const REPATH_INTERVAL = 0.5 # ...and at most this often
const WAYPOINT_DISTANCE = 0.5
const ARRIVE_DISTANCE = 2.0
const STUCK_CHECK_TIME = 1.5
const STUCK_MIN_MOVE = 0.5
const SIDESTEP_TIME = 1.5
const WANDER_MIN = 6.0
const WANDER_MAX = 15.0
const WANDER_TIMEOUT = 8.0
const HUNT_TIMEOUT = 20.0
const PACK_RETRY_TIME = 20.0 # How long an unreachable or used-up pickup is ignored
const PACK_WAIT_TIME = 3.0 # Standing on a pickup this long without gaining anything means it's used up

# Awareness
const SIGHT_RANGE = 60.0
const VIEW_CONE_DOT = 0.5 # cos(60 degrees), a 120 degree cone
const CLOSE_AWARENESS = 6.0 # Enemies this close are noticed in any direction
const MEMORY_TIME = 5.0
const SHARE_RANGE = 25.0
const SIGHT_MASK = 1 # World brushes; players are not on this layer so they don't block sight
const EYE_HEIGHT = 1.8
const CHEST_HEIGHT = 1.4
const AIM_DOT = 0.85 # Projectiles and melee fire within ~32 degrees of the target
const HITSCAN_AIM_DOT = 0.98 # Guns fire a single ray, so only within ~11 degrees
const AIM_TURN_SPEED = 5.0

# Confidence
const CONFIDENCE_INTERVAL = 0.5
const NEARBY_TEAMMATE_RANGE = 12.0
const LAST_ALIVE_CONFIDENCE = 0.35
const FALLBACK_CONFIDENCE = 0.25

# Round plans
enum RoundPlan { NONE, RUSHER, FLANKER, HOLDER }
# Weights for [Rusher, Flanker, Holder]
const PLAN_WEIGHTS: Dictionary = {
	"knife": [0.5, 0.4, 0.1],
	"hands": [0.5, 0.4, 0.1],
	"shotgun": [0.45, 0.4, 0.15],
	"ak47": [0.15, 0.35, 0.5],
	"rocket_launcher": [0.15, 0.35, 0.5],
	"wand": [0.2, 0.35, 0.45],
}
const DEFAULT_PLAN_WEIGHTS: Array = [0.3, 0.35, 0.35]
const MAX_START_DELAY = 1.2
const FLANK_MIN_SIDE = 12.0
const HOLD_MIN_SIDE = 3.0
const HOLD_MAX_SIDE = 20.0
const HOLD_TIME_MIN = 15.0
const HOLD_TIME_MAX = 35.0
const POINT_SAMPLE_TRIES = 60

# Weapon choice
const MELEE_ENGAGE_MAX = 3.0 # Weapons with a bot_engage_distance up to this are melee (knife, hands)
const MELEE_EXIT_FACTOR = 2.0 # Back to the ranged weapon once the enemy is this many knife reaches away
const WEAPON_SWITCH_COOLDOWN = 1.0

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
var target_visible: bool = false
var target_health_pack: Node3D = null
var target_ammo_pack: Node3D = null
var target_mana_pack: Node3D = null
# Pickup instance id -> time the bot gave up on it
var _bad_packs: Dictionary = {}
var _pack_wait_start: float = -1.0
var _pack_wait_value: float = 0.0

# ============================================================================
# Movement
# ============================================================================
var movement_target: Vector3 = Vector3.ZERO # Always on the navmesh (when there is one)
var _has_goal: bool = false
var _goal_kind: String = ""
var _goal_timer: float = 0.0
var _applied_target: Vector3 = Vector3.ZERO
var _target_applied: bool = false
var _repath_timer: float = REPATH_INTERVAL
var _path_index: int = 0
var _avoidance_velocity: Vector3 = Vector3.ZERO
var _avoidance_frame: int = -100
var _stuck_timer: float = 0.0
var _stuck_origin: Vector3 = Vector3.ZERO
var _stuck_strikes: int = 0
var _sidestep_timer: float = 0.0
var _sidestep_target: Vector3 = Vector3.ZERO
var _look_point: Vector3 = Vector3.ZERO
var _has_look_point: bool = false
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0
static var stuck_events: int = 0

# ============================================================================
# Awareness
# ============================================================================
# Enemy name -> {"node", "pos", "time"}
var known_enemies: Dictionary = {}
var last_sighting: Vector3 = Vector3.ZERO
var has_last_sighting: bool = false

# ============================================================================
# Confidence and round plan
# ============================================================================
var confidence: float = 0.5
var _confidence_timer: float = 0.0
var round_plan: RoundPlan = RoundPlan.NONE
var plan_phase: int = 0 # 0 = heading to waypoint, 1 = holding / heading to enemy spawn, 2 = hunting
var plan_waypoint: Vector3 = Vector3.ZERO
var start_delay: float = 0.0
var hold_time: float = 0.0
var _round_time: float = 0.0
var _home_center: Vector3 = Vector3.ZERO
var _enemy_center: Vector3 = Vector3.ZERO

# ============================================================================
# Combat Variables
# ============================================================================
var shoot_timer: float = 0.0
var shoot_cooldown: float = 0.3
var spell_timer: float = 0.0
var spell_duration: float = 2.0
var ranged_weapon: String = "" # Weapon to go back to after a knife fight
var _weapon_switch_timer: float = 0.0

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
	
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	nav_agent.path_changed.connect(func(): _path_index = 0)
	# Don't ride on other players like a moving platform: at round start a bot can spawn where a
	# teammate stood during warmup and get carried across the map when that teammate is moved
	player.platform_floor_layers &= ~player.collision_layer
	initialize_bot()

func initialize_bot() -> void:
	bot_label.show()
	
	weapons_manager.infinite_ammo = true
	weapons_manager.add_weapon(player.bot_starter_weapon)
	# The host runs the AI, clients only show the movement it sends
	if not player.is_multiplayer_authority():
		return
	
	# Tight corners instead of cutting through walls
	nav_agent.simplify_epsilon = 0.25
	nav_agent.path_desired_distance = 0.5
	nav_agent.avoidance_enabled = true
	
	# Show Bot Debug Information
	#bot_debug_direction.show()
	#nav_agent.debug_enabled = Globals.show_bot_path
	
	_reset_memory()
	_clear_goal()
	round_plan = RoundPlan.NONE
	start_delay = 0.0
	ranged_weapon = ""
	_weapon_switch_timer = 0.0

# Called by the gamemode after the bot is placed at its spawn for a new round
func start_round_plan() -> void:
	if not player.is_multiplayer_authority():
		return
	_reset_memory()
	_clear_goal()
	_round_time = 0.0
	round_plan = RoundPlan.NONE
	plan_phase = 0
	if not _in_team_game():
		return

	var gamemode = player.world.gamemode
	var enemy_team := 2 if player.team == 1 else 1
	_home_center = gamemode.get_spawn_center(player.team)
	_enemy_center = gamemode.get_spawn_center(enemy_team)
	start_delay = randf_range(0.0, MAX_START_DELAY)
	hold_time = randf_range(HOLD_TIME_MIN, HOLD_TIME_MAX)
	update_confidence()

	round_plan = _choose_plan()
	if not _pick_plan_waypoint():
		round_plan = RoundPlan.RUSHER
	print("Bot ", bot_id, " (team ", player.team, ") round plan: ", RoundPlan.keys()[round_plan])

func _physics_process(delta: float) -> void:
	if !player.is_bot or not player.is_multiplayer_authority():
		return
	if player.is_dead:
		# Living bots shouldn't steer around a ghost
		if nav_agent.avoidance_enabled:
			nav_agent.avoidance_enabled = false
		return
	
	frame_count += 1
	shoot_timer = max(shoot_timer - delta, 0.0)
	_weapon_switch_timer = max(_weapon_switch_timer - delta, 0.0)
	spell_timer += delta
	_round_time += delta
	start_delay = max(start_delay - delta, 0.0)
	_goal_timer -= delta
	_strafe_timer -= delta
	
	_confidence_timer -= delta
	if _confidence_timer <= 0.0:
		_confidence_timer = CONFIDENCE_INTERVAL
		update_confidence()
	
	# Handle spell switching for wand
	handle_spell_switching()
	
	# Staggered updates
	if frame_count % state_check_frequency == 0:
		update_bot_state()
	
	if frame_count % scan_frequency == 0:
		scan_for_targets()
		update_weapon_choice()
	
	if frame_count % aim_frequency == 0:
		update_aiming(delta)
	
	if frame_count % movement_frequency == 0:
		update_movement_target()
	
	# Always handle combat and movement
	handle_combat(delta)
	handle_movement(delta)
	
	# Debug output occasionally
	if frame_count % 120 == 0:  # Every 2 seconds at 60fps
		print("Bot ", bot_id, " State: ", BotState.keys()[current_state], " Plan: ", RoundPlan.keys()[round_plan], " Target: ", movement_target)

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
		BotState.SEEKING_HEALTH:
			scan_for_health_packs()
		BotState.SEEKING_AMMO:
			scan_for_ammo_packs()
		BotState.SEEKING_MANA:
			scan_for_mana_packs()
	
	# Always look for enemies
	scan_for_players()

# Picks the closest enemy the bot can actually see; otherwise the most recently known one
func scan_for_players() -> void:
	var my_pos := player.global_position
	var eye := my_pos + Vector3(0, EYE_HEIGHT, 0)
	var forward := -neck.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var closest: CharacterBody3D = null
	var closest_distance := INF
	for other in get_tree().get_nodes_in_group("players"):
		if not is_valid_player_target(other) or not can_see(other, eye, forward):
			continue
		remember_enemy(other, other.global_position)
		share_sighting(other)
		var distance := my_pos.distance_to(other.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = other

	forget_old_enemies()
	if closest:
		target_player = closest
		target_visible = true
		return

	target_visible = false
	target_player = null
	var newest_time := -INF
	for entry in known_enemies.values():
		if entry.time > newest_time:
			newest_time = entry.time
			target_player = entry.node

func can_see(other: Node3D, eye: Vector3, forward: Vector3) -> bool:
	var to_other := other.global_position - player.global_position
	var distance := to_other.length()
	if distance > SIGHT_RANGE:
		return false
	if distance > CLOSE_AWARENESS:
		var flat := Vector3(to_other.x, 0, to_other.z).normalized()
		if forward.dot(flat) < VIEW_CONE_DOT:
			return false
	var query := PhysicsRayQueryParameters3D.create(eye, other.global_position + Vector3(0, CHEST_HEIGHT, 0), SIGHT_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func scan_for_health_packs() -> void:
	target_health_pack = find_reachable_pack("HealthDrop")

func scan_for_ammo_packs() -> void:
	target_ammo_pack = find_reachable_pack("ammo_pack")

func scan_for_mana_packs() -> void:
	target_mana_pack = find_reachable_pack("mana_drop")

# Closest pickup in the group that the navmesh can actually walk to
func find_reachable_pack(group: String) -> Node3D:
	var packs: Array = get_tree().get_nodes_in_group(group).filter(_is_usable_pack)
	while not packs.is_empty():
		var pack := find_closest_valid_target(packs, func(_p): return true)
		if _path_reaches(get_pack_position(pack)):
			return pack
		_bad_packs[pack.get_instance_id()] = _now()
		packs.erase(pack)
	return null

func _is_usable_pack(pack) -> bool:
	if not is_instance_valid(pack):
		return false
	var id: int = pack.get_instance_id()
	if _bad_packs.has(id):
		if _now() - _bad_packs[id] < PACK_RETRY_TIME:
			return false
		_bad_packs.erase(id)
	return true

# Health pools are a water mesh whose origin sits at a corner, so aim for the middle of it
func get_pack_position(pack: Node3D) -> Vector3:
	if pack is MeshInstance3D:
		return pack.global_transform * pack.get_aabb().get_center()
	return pack.global_position

# Collected pickups stay in their group while waiting to respawn; give up on one if standing on it
# doesn't raise the stat we're after (a health pool keeps counting as long as it heals)
func _pack_used_up(pack: Node3D) -> bool:
	if _flat_distance(get_pack_position(pack)) > ARRIVE_DISTANCE:
		_pack_wait_start = -1.0
		return false
	var value := _seek_stat()
	if _pack_wait_start < 0.0 or value > _pack_wait_value:
		_pack_wait_start = _now()
		_pack_wait_value = value
		return false
	if _now() - _pack_wait_start < PACK_WAIT_TIME:
		return false
	_bad_packs[pack.get_instance_id()] = _now()
	_pack_wait_start = -1.0
	return true

func _seek_stat() -> float:
	match current_state:
		BotState.SEEKING_HEALTH:
			return float(player.health)
		BotState.SEEKING_MANA:
			return float(player.mana)
		BotState.SEEKING_AMMO:
			return float(weapons_manager.current_weapon.current_ammo + weapons_manager.current_weapon.reserve_ammo)
	return 0.0

# Untyped: the cached pickup may already be freed
func _current_pack():
	match current_state:
		BotState.SEEKING_HEALTH:
			return target_health_pack
		BotState.SEEKING_AMMO:
			return target_ammo_pack
		BotState.SEEKING_MANA:
			return target_mana_pack
	return null

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

# Untyped: may be handed a freed node from memory or a cached target
func is_valid_player_target(other_player) -> bool:
	if not is_instance_valid(other_player):
		return false
	if not (other_player is CharacterBody3D) or other_player == player:
		return false
	if other_player.is_bot and not Globals.bots_fight:
		return false
	if other_player.is_dead:
		return false
	if player.world.gamemode and player.world.gamemode.is_teammate(player, other_player):
		return false
	return true

# ============================================================================
# Awareness
# ============================================================================
func remember_enemy(enemy: Node3D, enemy_pos: Vector3) -> void:
	known_enemies[str(enemy.name)] = {"node": enemy, "pos": enemy_pos, "time": _now()}
	last_sighting = enemy_pos
	has_last_sighting = true

func forget_old_enemies() -> void:
	var now := _now()
	for enemy_name in known_enemies.keys():
		var entry: Dictionary = known_enemies[enemy_name]
		if now - entry.time > MEMORY_TIME or not is_valid_player_target(entry.node):
			known_enemies.erase(enemy_name)

# Tells bot teammates nearby where an enemy is, so they react together
func share_sighting(enemy: Node3D) -> void:
	if not _in_team_game():
		return
	for mate in get_tree().get_nodes_in_group("bots"):
		if mate == player or not is_instance_valid(mate) or mate.is_dead or mate.team != player.team:
			continue
		if mate.global_position.distance_to(player.global_position) <= SHARE_RANGE:
			mate.bot_logic.receive_intel(enemy, enemy.global_position)

func receive_intel(enemy: Node3D, enemy_pos: Vector3) -> void:
	if player.is_dead or not is_valid_player_target(enemy):
		return
	remember_enemy(enemy, enemy_pos)
	if not target_visible:
		target_player = enemy

# Called from Player.receive_damage: turn towards whoever shot us
func on_damaged(attacker_name: String) -> void:
	if attacker_name == "" or attacker_name == str(player.name) or player.is_dead:
		return
	var attacker = player.world.get_node_or_null(attacker_name)
	if not is_valid_player_target(attacker):
		return
	remember_enemy(attacker, attacker.global_position)
	if not target_visible:
		target_player = attacker

func get_target_position() -> Vector3:
	if target_visible or not known_enemies.has(str(target_player.name)):
		return target_player.global_position
	return known_enemies[str(target_player.name)].pos

func _reset_memory() -> void:
	known_enemies.clear()
	target_player = null
	target_visible = false
	has_last_sighting = false

# ============================================================================
# Confidence
# ============================================================================
func update_confidence() -> void:
	var health_part := clampf(float(player.health) / float(player.max_health), 0.0, 1.0)
	var numbers_part := 0.5
	var nearby_part := 0.0
	var counts := _alive_counts()
	if counts.x + counts.y > 0:
		numbers_part = float(counts.x) / float(counts.x + counts.y)
	if _in_team_game():
		var nearby := 0
		for mate in get_tree().get_nodes_in_group("players"):
			if mate == player or not is_instance_valid(mate) or not "team" in mate or mate.is_dead or mate.team != player.team:
				continue
			if mate.global_position.distance_to(player.global_position) <= NEARBY_TEAMMATE_RANGE:
				nearby += 1
		nearby_part = minf(nearby / 2.0, 1.0)

	confidence = 0.45 * health_part + 0.35 * numbers_part + 0.2 * nearby_part
	if _in_team_game() and counts.x == 1 and counts.y > 0:
		confidence = minf(confidence, LAST_ALIVE_CONFIDENCE)

func get_preferred_distance() -> float:
	return weapons_manager.current_weapon.bot_preferred_distance * lerpf(1.5, 0.75, confidence)

# x = closest distance the bot wants to be, y = furthest
func get_distance_band() -> Vector2:
	var weapon = weapons_manager.current_weapon
	var preferred := get_preferred_distance()
	var near := maxf(preferred * 0.75, weapon.bot_min_distance)
	var far := maxf(preferred * 1.25, near + 1.0)
	return Vector2(near, far)

func get_engage_distance() -> float:
	var engage: float = weapons_manager.current_weapon.bot_engage_distance
	# Sandbox bots placed with bot_spawn keep their per-entity range as an upper limit
	var entity_range: float = String(player.bot_weapon_range).to_float()
	if player.team == 0 and entity_range > 0.0:
		engage = minf(engage, entity_range)
	return engage

# ============================================================================
# Round plans
# ============================================================================
func _choose_plan() -> RoundPlan:
	var weights: Array = PLAN_WEIGHTS.get(weapons_manager.current_weapon.weapon_name, DEFAULT_PLAN_WEIGHTS)
	var roll: float = randf() * (weights[0] + weights[1] + weights[2])
	if roll < weights[0]:
		return RoundPlan.RUSHER
	if roll < weights[0] + weights[1]:
		return RoundPlan.FLANKER
	return RoundPlan.HOLDER

# Flankers and Holders need a waypoint; false if the map has no suitable spot
func _pick_plan_waypoint() -> bool:
	match round_plan:
		RoundPlan.FLANKER:
			return _sample_plan_point(0.3, 0.8, FLANK_MIN_SIDE, INF) or _sample_plan_point(0.3, 0.8, FLANK_MIN_SIDE * 0.5, INF)
		RoundPlan.HOLDER:
			return _sample_plan_point(0.1, 0.45, HOLD_MIN_SIDE, HOLD_MAX_SIDE)
	return true

# Random reachable navmesh point between t_min and t_max of the way from home to the enemy spawn,
# and between side_min and side_max meters to the side of that line
func _sample_plan_point(t_min: float, t_max: float, side_min: float, side_max: float) -> bool:
	var nav_map := nav_agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return false
	var line := _enemy_center - _home_center
	line.y = 0.0
	var length := line.length()
	if length < 1.0:
		return false
	var axis := line / length
	var side_axis := axis.cross(Vector3.UP)
	var preferred_side := 1.0 if randf() < 0.5 else -1.0

	for i in POINT_SAMPLE_TRIES:
		var point := NavigationServer3D.map_get_random_point(nav_map, nav_agent.navigation_layers, true)
		var offset := point - _home_center
		offset.y = 0.0
		var t := offset.dot(axis) / length
		var side := offset.dot(side_axis)
		if t < t_min or t > t_max or absf(side) < side_min or absf(side) > side_max:
			continue
		# First half of the tries sticks to one side so flankers spread out
		if i < POINT_SAMPLE_TRIES / 2 and signf(side) != preferred_side:
			continue
		if not _is_reachable(point):
			continue
		plan_waypoint = point
		return true
	return false

func _update_plan_goal() -> void:
	match round_plan:
		RoundPlan.HOLDER:
			var counts := _alive_counts()
			var wait := hold_time * lerpf(1.3, 0.7, confidence)
			if counts.x > counts.y:
				wait *= 0.5
			if _round_time >= wait:
				round_plan = RoundPlan.RUSHER
				plan_phase = 0
				return
			if plan_phase == 0:
				set_goal(plan_waypoint, "plan")
				if _reached_goal():
					plan_phase = 1
			if plan_phase == 1:
				_clear_goal()
				_look_point = _enemy_center
				_has_look_point = true
		RoundPlan.FLANKER:
			if plan_phase == 0:
				set_goal(plan_waypoint, "plan")
				if _reached_goal():
					plan_phase = 1
			elif plan_phase == 1:
				set_goal(_enemy_center, "plan")
				if _reached_goal():
					plan_phase = 2
			else:
				_update_hunt_goal()
		RoundPlan.RUSHER:
			if plan_phase < 2:
				set_goal(_enemy_center, "plan")
				if _reached_goal():
					plan_phase = 2
			else:
				_update_hunt_goal()

# Plan done and nobody found: search random reachable spots on the map
func _update_hunt_goal() -> void:
	if _goal_kind == "hunt" and not _reached_goal() and _goal_timer > 0.0:
		return
	var nav_map := nav_agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return
	for i in 10:
		var point := NavigationServer3D.map_get_random_point(nav_map, nav_agent.navigation_layers, true)
		if _is_reachable(point):
			set_goal(point, "hunt")
			_goal_timer = HUNT_TIMEOUT
			return

# ============================================================================
# Movement System
# ============================================================================
func update_movement_target() -> void:
	_has_look_point = false
	match current_state:
		BotState.COMBAT:
			_update_combat_goal()
		
		BotState.SEEKING_HEALTH, BotState.SEEKING_AMMO, BotState.SEEKING_MANA:
			var pack = _current_pack()
			if _is_usable_pack(pack) and not _pack_used_up(pack):
				set_goal(get_pack_position(pack), "pack")
			else:
				_update_combat_goal()  # No reachable pickup: keep fighting / following the plan

func _update_combat_goal() -> void:
	if target_player and is_instance_valid(target_player):
		_update_engage_goal()
		return
	if has_last_sighting:
		if _flat_distance(last_sighting) < ARRIVE_DISTANCE:
			has_last_sighting = false
		else:
			set_goal(last_sighting, "sighting")
			return
	if round_plan != RoundPlan.NONE:
		_update_plan_goal()
	else:
		_update_wander_goal()

# Keeps the bot inside its weapon's distance band, or falls back when losing badly
func _update_engage_goal() -> void:
	var my_pos := player.global_position
	var enemy_pos := get_target_position()

	if _should_fall_back():
		set_goal(_get_fallback_position(), "fallback")
		return
	if not target_visible:
		set_goal(enemy_pos, "chase")
		return

	var distance := _flat_distance(enemy_pos)
	var band := get_distance_band()
	var to_enemy := enemy_pos - my_pos
	to_enemy.y = 0.0
	to_enemy = to_enemy.normalized()

	if distance > band.y:
		set_goal(enemy_pos, "chase")
	elif distance < band.x:
		set_goal(my_pos - to_enemy * (band.x - distance + 2.0), "back_off")
	else:
		if _strafe_timer <= 0.0:
			_strafe_timer = randf_range(1.0, 2.5)
			_strafe_sign = -_strafe_sign
		var strafe_distance := clampf(get_preferred_distance() * 0.5, 1.5, 4.0)
		var side := to_enemy.cross(Vector3.UP) * _strafe_sign
		var goal := snap_to_navmesh(my_pos + side * strafe_distance)
		if _flat_distance(goal) < 1.0:
			# Wall on that side, go the other way
			_strafe_sign = -_strafe_sign
			goal = snap_to_navmesh(my_pos - side * strafe_distance)
		set_goal(goal, "strafe")

func _should_fall_back() -> bool:
	if not _in_team_game() or confidence >= FALLBACK_CONFIDENCE:
		return false
	var counts := _alive_counts()
	return counts.x < counts.y

func _get_fallback_position() -> Vector3:
	var closest_distance := INF
	var closest := _home_center
	for mate in get_tree().get_nodes_in_group("players"):
		if mate == player or not is_instance_valid(mate) or not "team" in mate or mate.is_dead or mate.team != player.team:
			continue
		var distance: float = mate.global_position.distance_to(player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = mate.global_position
	return closest

func _update_wander_goal() -> void:
	if _goal_kind == "wander" and not _reached_goal() and _goal_timer > 0.0:
		return
	var direction := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	set_goal(player.global_position + direction * randf_range(WANDER_MIN, WANDER_MAX), "wander")
	_goal_timer = WANDER_TIMEOUT

func set_goal(goal: Vector3, kind: String) -> void:
	movement_target = snap_to_navmesh(goal)
	_has_goal = true
	_goal_kind = kind

func _clear_goal() -> void:
	_has_goal = false
	_goal_kind = ""
	_sidestep_timer = 0.0

func _reached_goal() -> bool:
	return _has_goal and _flat_distance(movement_target) < ARRIVE_DISTANCE

func snap_to_navmesh(point: Vector3) -> Vector3:
	var nav_map := nav_agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return point
	return NavigationServer3D.map_get_closest_point(nav_map, point)

func _is_reachable(point: Vector3) -> bool:
	var nav_map := nav_agent.get_navigation_map()
	var path := NavigationServer3D.map_get_path(nav_map, snap_to_navmesh(player.global_position), point, true, nav_agent.navigation_layers)
	return path.size() > 0 and path[path.size() - 1].distance_to(point) < 1.0

# Looser than _is_reachable, for points that aren't on the navmesh themselves (pickups float above it)
func _path_reaches(point: Vector3) -> bool:
	var nav_map := nav_agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return true
	var path := NavigationServer3D.map_get_path(nav_map, snap_to_navmesh(player.global_position), point, true, nav_agent.navigation_layers)
	if path.is_empty():
		return false
	var end: Vector3 = path[path.size() - 1]
	return Vector2(end.x - point.x, end.z - point.z).length() < 2.0 and absf(end.y - point.y) < 3.0

# Only recalculates the path when the goal moved noticeably, and not more often than REPATH_INTERVAL
func _apply_nav_target(target: Vector3) -> void:
	if _target_applied and (_applied_target.distance_to(target) <= REPATH_DISTANCE or _repath_timer < REPATH_INTERVAL):
		return
	nav_agent.target_position = target
	_applied_target = target
	_target_applied = true
	_repath_timer = 0.0

func handle_movement(delta: float) -> void:
	_repath_timer += delta
	var my_pos := player.global_position
	var wants_to_move := false

	if _sidestep_timer > 0.0:
		_sidestep_timer -= delta
		_apply_nav_target(_sidestep_target)
		wants_to_move = true
		if _flat_distance(_sidestep_target) < 1.0:
			_sidestep_timer = 0.0
	elif _has_goal and start_delay <= 0.0:
		_apply_nav_target(movement_target)
		wants_to_move = true

	var desired := Vector3.ZERO
	var has_waypoint := false
	if wants_to_move:
		var next_position = _next_waypoint()
		has_waypoint = next_position != null
		if has_waypoint:
			var direction: Vector3 = next_position - my_pos
			direction.y = 0.0
			desired = ledge_guard(my_pos, direction.normalized()) * BOT_SPEED

	var horizontal_target := desired
	nav_agent.velocity = desired
	# Use the avoidance result when the navigation server is providing one
	if Engine.get_physics_frames() - _avoidance_frame <= 2 and desired != Vector3.ZERO:
		horizontal_target = Vector3(_avoidance_velocity.x, 0, _avoidance_velocity.z)

	var current_velocity = player.velocity
	var horizontal_velocity = Vector3(current_velocity.x, 0, current_velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(horizontal_target, 0.5)
	current_velocity.y += GRAVITY * delta
	player.velocity = Vector3(horizontal_velocity.x, current_velocity.y, horizontal_velocity.z)
	player.move_and_slide()

	# A path the ledge guard refuses to follow counts as stuck too
	_update_stuck_detection(delta, has_waypoint)

# Next point on the agent's path, or null when the end is reached.
# Waypoints are compared on the XZ plane: the navmesh floats ~0.5m above the floor, so the agent's
# own 3D waypoint check can fail to advance and leave the bot standing still.
func _next_waypoint():
	nav_agent.get_next_path_position() # Lets the agent recalculate its path when the target changed
	var path := nav_agent.get_current_navigation_path()
	while _path_index < path.size() and _flat_distance(path[_path_index]) < WAYPOINT_DISTANCE:
		_path_index += 1
	if _path_index >= path.size():
		return null
	return path[_path_index]

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	_avoidance_velocity = safe_velocity
	_avoidance_frame = Engine.get_physics_frames()

func _update_stuck_detection(delta: float, trying_to_move: bool) -> void:
	if not trying_to_move:
		_stuck_timer = 0.0
		_stuck_origin = player.global_position
		return
	_stuck_timer += delta
	if _stuck_timer < STUCK_CHECK_TIME:
		return
	if _flat_distance(_stuck_origin) < STUCK_MIN_MOVE:
		_on_stuck()
	else:
		_stuck_strikes = 0
	_stuck_timer = 0.0
	_stuck_origin = player.global_position

# First try a sidestep to a nearby navmesh point; if that doesn't help, drop the goal
func _on_stuck() -> void:
	stuck_events += 1
	_stuck_strikes += 1
	if _stuck_strikes == 1:
		var direction := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		_sidestep_target = snap_to_navmesh(player.global_position + direction * randf_range(2.0, 4.0))
		_sidestep_timer = SIDESTEP_TIME
		_target_applied = false
		return

	_stuck_strikes = 0
	_sidestep_timer = 0.0
	_target_applied = false
	match _goal_kind:
		"pack":
			var pack = _current_pack()
			if is_instance_valid(pack):
				_bad_packs[pack.get_instance_id()] = _now()
		"chase", "sighting":
			if is_instance_valid(target_player) and not target_visible:
				known_enemies.erase(str(target_player.name))
				target_player = null
			has_last_sighting = false
		"plan":
			if round_plan == RoundPlan.HOLDER:
				# Hold wherever it got to if no other spot works
				if not _pick_plan_waypoint():
					plan_phase = 1
			elif round_plan == RoundPlan.RUSHER or plan_phase != 0 or not _pick_plan_waypoint():
				plan_phase = 2
	_clear_goal()

# Steers away from drops the navmesh path doesn't know about (strafing, avoidance pushes)
func ledge_guard(from_pos: Vector3, direction: Vector3) -> Vector3:
	if has_ground_ahead(from_pos, direction):
		return direction
	for angle in [30, -30, 60, -60]:
		var alt_direction := direction.rotated(Vector3.UP, deg_to_rad(angle))
		if has_ground_ahead(from_pos, alt_direction):
			return alt_direction
	return Vector3.ZERO

func has_ground_ahead(from_pos: Vector3, direction: Vector3) -> bool:
	var ground_check_pos = from_pos + direction.normalized() * 1.5
	var ledge_query = PhysicsRayQueryParameters3D.create(
		ground_check_pos + Vector3(0, 0.5, 0),
		ground_check_pos - Vector3(0, 3, 0)
	)
	ledge_query.exclude = [player]
	return not get_world_3d().direct_space_state.intersect_ray(ledge_query).is_empty()

# ============================================================================
# Weapon Choice
# ============================================================================
func is_melee_weapon(weapon_name: String) -> bool:
	var weapon = weapons_manager.weapon_list.get(weapon_name)
	return weapon == null or weapon.bot_engage_distance <= MELEE_ENGAGE_MAX

# Weapon a bot spawns holding: a random ranged one from the loadout, the knife only if there is nothing else
func pick_spawn_weapon(weapon_names: Array) -> String:
	var usable := weapon_names.filter(func(weapon_name): return weapon_name != "hands" and weapons_manager.weapon_list.has(weapon_name))
	var ranged := usable.filter(func(weapon_name): return not is_melee_weapon(weapon_name))
	if not ranged.is_empty():
		return ranged.pick_random()
	return usable[0] if not usable.is_empty() else ""

func _best_held_weapon(melee: bool) -> String:
	var best := ""
	var best_engage := -INF
	for weapon_name in weapons_manager.weapon_stack:
		if weapon_name == "hands" or is_melee_weapon(weapon_name) != melee:
			continue
		var engage: float = weapons_manager.weapon_list[weapon_name].bot_engage_distance
		if engage > best_engage:
			best_engage = engage
			best = weapon_name
	return best

# Fights with the ranged weapon; pulls the knife only when an enemy is within knife reach
func update_weapon_choice() -> void:
	var current = weapons_manager.current_weapon
	if current == null or _weapon_switch_timer > 0.0:
		return
	if current.weapon_name != "hands" and not is_melee_weapon(current.weapon_name):
		ranged_weapon = current.weapon_name
	if not weapons_manager.weapon_stack.has(ranged_weapon):
		ranged_weapon = _best_held_weapon(false)
	var melee := _best_held_weapon(true)

	var wanted := ranged_weapon if ranged_weapon != "" else melee
	if ranged_weapon != "" and melee != "" and target_visible and is_valid_player_target(target_player):
		var reach: float = weapons_manager.weapon_list[melee].bot_engage_distance
		var distance := _flat_distance(target_player.global_position)
		var holding_melee: bool = current.weapon_name == melee
		if distance <= reach or (holding_melee and distance <= reach * MELEE_EXIT_FACTOR):
			wanted = melee

	if wanted != "" and wanted != current.weapon_name:
		weapons_manager.equip_weapon(wanted)
		_weapon_switch_timer = WEAPON_SWITCH_COOLDOWN

# ============================================================================
# Combat System
# ============================================================================
func handle_combat(delta: float) -> void:
	# Only shoot at enemies we can actually see
	if not target_visible or not is_valid_player_target(target_player):
		return
	var distance_to_target = global_transform.origin.distance_to(target_player.global_transform.origin)
	if distance_to_target <= get_engage_distance():
		if shoot_timer <= 0.0 and is_well_aimed():
			if randf() > 0.20:  # Small chance to miss
				bot_shoot()
				shoot_timer = get_shoot_cooldown()

# Uses the weapon's fire_rate when it has one. Auto-fire guns with no rate fall back to a short gap;
# everything else uses the default cooldown. shoot() still refuses a shot while its animation is playing.
func get_shoot_cooldown() -> float:
	var weapon = weapons_manager.current_weapon
	if weapon.fire_rate > 0.0:
		return weapon.fire_rate
	if weapon.auto_fire:
		return 0.1
	return shoot_cooldown
				
func bot_shoot() -> void:
	weapons_manager.shoot()
	
	if weapons_manager.current_weapon.weapon_name == "keyboard":
		var spell_names = the_power.spell_sequences.keys()
		if spell_names.size() > 0:
			var random_spell = spell_names[randi() % spell_names.size()]
			the_power.activate_spell(random_spell)
			print(random_spell)


# Aims at the target, otherwise looks where a Holder is watching or where the bot is walking
func update_aiming(delta: float) -> void:
	var look_at_pos: Vector3
	if target_player and is_instance_valid(target_player):
		look_at_pos = get_target_position() + Vector3(0, CHEST_HEIGHT, 0)
	elif _has_look_point:
		look_at_pos = _look_point + Vector3(0, EYE_HEIGHT, 0)
	else:
		var flat_velocity := Vector3(player.velocity.x, 0, player.velocity.z)
		if flat_velocity.length() < 1.0:
			return
		look_at_pos = neck.global_position + flat_velocity.normalized() * 5.0

	var from_pos := neck.global_position
	if Vector2(look_at_pos.x - from_pos.x, look_at_pos.z - from_pos.z).length() < 0.1:
		return
	
	# Smooth look_at
	var target_transform = neck.global_transform.looking_at(look_at_pos, Vector3.UP)
	# Runs every aim_frequency frames, so turn by that many frames' worth
	var weight := minf(delta * aim_frequency * AIM_TURN_SPEED, 1.0)
	neck.global_transform.basis = neck.global_transform.basis.slerp(target_transform.basis, weight)

func is_well_aimed() -> bool:
	if not target_player or not is_instance_valid(target_player):
		return false
	
	var target_pos = target_player.global_transform.origin + Vector3(0, CHEST_HEIGHT, 0)
	var from_pos = neck.global_transform.origin
	
	var neck_forward = -neck.global_transform.basis.z
	var target_direction = (target_pos - from_pos).normalized()
	
	var weapon = weapons_manager.current_weapon
	var hitscan: bool = weapon.is_gun and not weapon.is_projectile_launcher and not is_melee_weapon(weapon.weapon_name)
	return neck_forward.dot(target_direction) > (HITSCAN_AIM_DOT if hitscan else AIM_DOT)

# ============================================================================
# Utility Functions
# ============================================================================
func handle_spell_switching() -> void:
	if weapons_manager.current_weapon.weapon_name == "wand" and spell_timer >= spell_duration:
		spell_timer = 0.0
		var spells = weapons_manager.get_wand_spells()
		if spells.size() > 0:
			weapons_manager.set_wand_spell(spells[randi() % spells.size()])

func _in_team_game() -> bool:
	return player.world != null and player.world.gamemode != null and player.team != 0

# Vector2i.ZERO outside team games, so confidence treats the numbers as even
func _alive_counts() -> Vector2i:
	if not _in_team_game():
		return Vector2i.ZERO
	return player.world.gamemode.get_alive_counts(player.team)

func _flat_distance(point: Vector3) -> float:
	var my_pos := player.global_position
	return Vector2(point.x - my_pos.x, point.z - my_pos.z).length()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
