
extends CharacterBody3D

signal health_changed(health_value)
signal mana_changed(mana_value)

@onready var world = get_tree().get_root().get_node("World")
@onready var player = $"."

# Player Nodes
# ============================================================================
# Bot Variables
# ============================================================================
var BOT_SPEED: float = 8.0
var shoot_cooldown_time: float = 2.0
var shoot_timer: float = 0.0
var is_bot: bool = false
var disable_respawn: bool = false
var bot_starter_weapon: String = "rocket_launcher"
var bot_weapon_range: String = "25"
var use_spawn_position: bool = false
var bot_origin: String = "0 0 0"
@onready var bot_logic: Node3D = $Bot_Logic

@onready var head: Node3D = $neck/head
@onready var neck: Node3D = $neck
@onready var standing_collision_shape: CollisionShape3D = $standing_collision_shape
@onready var crouching_collision_shape: CollisionShape3D = $crouching_collision_shape
@onready var main_camera: Camera3D = $neck/head/main_camera
@onready var viewmodel_camera: Camera3D = $neck/head/main_camera/SubViewportContainer/viewmodel_viewport/viewmodel_camera
@onready var viewmodel_viewport: SubViewport = $neck/head/main_camera/SubViewportContainer/viewmodel_viewport
@onready var weapons_manager: Node3D = $neck/head/main_camera/Weapons_Manager
@onready var player_hurt_noise: AudioStreamPlayer3D = $player_hurt_noise
@onready var raycast_crouching: RayCast3D = $raycast_crouching
@onready var interaction_ray: RayCast3D = $neck/head/main_camera/interaction_ray

@onready var raycast_wall: RayCast3D = $raycast_wall

@onready var _3p_model: Node3D = $"3p_model"
var last_tagged_by: String = "Unknown"


# Source
const MAX_VELOCITY_AIR: float = 0.6
const MAX_VELOCITY_GROUND: float = 7.5
const MAX_VELOCITY_GROUND_WALKING: float = 3.5
const MAX_ACCELERATION: float = 10 * MAX_VELOCITY_GROUND
const GRAVITY: int = 12
const KNIFE_EXTRA_SPEED: float = 1.5
# GRAVITY USED TO BE 15.34
const STOP_SPEED: int = 2 # Was 1.5
const JUMP_IMPULSE: float = sqrt(2 * GRAVITY * 3) #Orig was sqrt(2 * GRAVITY * 1.85)
const PLAYER_WALKING_MULTIPLIER: float = 0.666
var direction: Vector3 = Vector3.ZERO
var friction: int = 4
var wish_jump = false
var sensitivity: float = 0.05
var walking: bool = false

# Physcis interaction
var grabbed_object: RigidBody3D
var is_holding_object: bool = false

var health: int = 100 # Inital health
var max_health: int = 100 # Health set to max health on respawn

var mana: int = 50 # Inital mana
var max_mana: int = 100 # mana set to max health on respaw

# Speed Variables
const walking_speed: float = 5.0
const sprinting_speed: float = 10.0
const crouching_speed: float = 3.0
var current_speed: float = 10.0
const JUMP_VELOCITY: float = 10.0
var lerp_speed: float = 20.0
var crouching_depth: float = -1.0
var standing_depth: float = 0.0

var free_look_tilt_ammount: int = 8
const CROUCH_JUMP_BOOST: float = 1.0  # Adjust this value as needed for the boost amount
var has_crouch_boosted: bool = false


# Staris
const MAX_STEP_HEIGHT: float = 0.5
var _snapped_to_stairs_last_frame: bool = false
var _last_time_was_on_floor = -INF

# States
# Moved walking to Source Section
var sprinting: bool = false
var crouching: bool = false
var free_looking: bool = false
var sliding: bool = false
var is_walking: bool = false

# Jumping
const COYOTE_TIME: float = 0.1  # seconds you allow the jump after leaving the ground
var coyote_time_remaining: float = 0.0
var CUT_JUMP_HEIGHT: float = 0.5



# Slide Vars
var slide_timer: float = 0.0
var slide_timer_max: float = 1.0
var slide_vector: Vector2 = Vector2.ZERO
var slide_speed: float = 15.0

# Health States
var is_on_fire: bool = false
@onready var player_flames_fx: GPUParticles3D = $Area3D/PlayerFlamesFx
var fire_counter: int = 0

# View Bobbing Variables
var bob_amplitude: float = 0.0
const MAX_BOB_AMPLITUDE: float = 0.006  # Maximum bobbing amplitude
const BOB_FREQUENCY: float = 10.0       # Frequency of the bobbing (adjust as needed)
const BOB_ACCELERATION: float = 0.08   # Rate at which bob_amplitude increases
const BOB_DECELERATION: float = 0.014     # Rate at which bob_amplitude decreases
var bob_phase: float = 0.0
const VELOCITY_THRESHOLD: int = 6  # Adjust as needed


@onready var fps_rig: Node3D = $neck/head/main_camera/Weapons_Manager/FPS_RIG
var base_fps_rig_position: Vector3 = Vector3.ZERO  # To store the original position


# Moved Direction to Source

# Bhop Variables
var bhop_count: int = 0
var time_on_floor: float = 0.0
const bhop_reset_delay: float = 0.2  # How long the player can be on the floor before resetting bhop counter
const bhop_increase_speed_multiplier: int = 5 # How much speed is added per bhop

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = 20.0

# Create  a Three second cool down, to not allow spamming of the Kill key
var kill_timeout: int = 3
var kill_max_timeout: int = 3
var can_die: bool = true

# Footsteps
@onready var footstep_player: AudioStreamPlayer3D = $FootstepAudioPlayer
var distance_accumulated: float = 0.0
var step_distance_threshold: float = 4.0  # Adjust this to suit your game’s scale and speed
var last_position: Vector3
var left_step: bool = true  # Toggle to alternate footsteps

# Preload your footstep sounds
var footstep_left_sound = preload("res://sounds/footsteps/footstep_left.wav")
var footstep_right_sound = preload("res://sounds/footsteps/footstep_right.wav")

# Nocli
var cam_aligned_wish_dir := Vector3.ZERO
var noclip_speed_mult := 8.0
var noclip := false

#func _enter_tree():
	#set_multiplayer_authority(str(name).to_int())
	#
	#
# Peer id.
@export var peer_id : int : 
	set(value):
		peer_id = value
		

	
# Function to adjust the viewport size
func _adjust_viewport_size():
	if viewmodel_viewport:
		viewmodel_viewport.size = get_viewport().size


# Signal handler for size changes
func _on_size_changed():
	_adjust_viewport_size()

func _ready():
	if not is_multiplayer_authority():
		fps_rig.hide()
		return
	_3p_model.hide()
	Globals.paused = false
	fps_rig.show()  # Ensure FPS_RIG is visible

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	main_camera.current = !is_bot # If is bot is false (if is a bot) we dont need the camera (set it to false)
	
	# Connect the size_changed signal to the _on_size_changed function
	get_viewport().connect("size_changed", Callable(self, "_on_size_changed"))
	# Initial adjustment of the viewport size
	_adjust_viewport_size()
	# Store the original position of the FPS_RIG
	base_fps_rig_position = fps_rig.position
	# For Footsteps
	last_position = global_transform.origin
	# Add collision shapes to the Players Group
	$standing_collision_shape.add_to_group("players")
	$crouching_collision_shape.add_to_group("players")
	

const CS_SENSITIVITY_SCALE = 0.022  # Counter-Strike scale factor for sensitivity

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	if is_bot: return
	if Globals.paused:
		return
	if event is InputEventMouseMotion:
		var sensitivity = Globals.mouse_sensitivity * CS_SENSITIVITY_SCALE
		if free_looking:
			neck.rotate_y(deg_to_rad(-event.relative.x * sensitivity))
			neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-120), deg_to_rad(120))  # Freelook left/right
		else:
			rotate_y(deg_to_rad(-event.relative.x * sensitivity))
			head.rotate_x(deg_to_rad(-event.relative.y * sensitivity))
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-98), deg_to_rad(89))




func _physics_process(delta):
	if not is_multiplayer_authority():
		return
	if is_bot: return
		
	 # Update coyote time: reset if on floor, otherwise count down
	if is_on_floor():
		coyote_time_remaining = COYOTE_TIME
	else:
		coyote_time_remaining = max(coyote_time_remaining - delta, 0)
	
	calculate_fire_damage()
	process_input()


	
	# Toggle collision shapes
	if crouching:
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
		
	else:
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true

	# Reset the boost flag when on the floor
	if is_on_floor():
		has_crouch_boosted = false
	else:
		# If in midair and the crouch action was just pressed, add a boost.
		if Input.is_action_just_pressed("crouch") and not has_crouch_boosted:
			self.position.y += CROUCH_JUMP_BOOST
			has_crouch_boosted = true
			
	# Optionally adjust head height for a visual crouch effect
	var target_head_height = crouching_depth if crouching else standing_depth
	head.position.y = lerp(head.position.y, target_head_height, delta * lerp_speed)

	process_movement(delta)
	kill_timeout -= delta
	if kill_timeout <= 0:
		can_die = true

	update_view_bobbing(delta)
	if not is_walking and not noclip:
		update_footsteps_vars()

	if not free_looking and neck != null:
		neck.rotation.x = lerp(neck.rotation.x, 0.0, delta * 5)
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta * 5)
		neck.rotation.z = lerp(neck.rotation.z, 0.0, delta * 5)



func update_view_bobbing(delta):
	if is_bot: return
	# Calculate the horizontal velocity (ignore Y component)
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z).length()
	
	# Determine if the player is moving based on horizontal velocity and being on the floor
	var is_moving = horizontal_velocity > VELOCITY_THRESHOLD and is_on_floor()
	
	if is_moving:
		# Increase the bob amplitude based on player's speed
		# You can adjust how the speed affects the amplitude
		# For example, scale amplitude with horizontal_velocity
		var speed_factor = clamp(horizontal_velocity / sprinting_speed, 0.0, 1.0)
		bob_amplitude += BOB_ACCELERATION * speed_factor * delta
		bob_amplitude = clamp(bob_amplitude, 0.0, MAX_BOB_AMPLITUDE)
	else:
		# Decrease the bob amplitude when not moving
		bob_amplitude -= BOB_DECELERATION * delta
		bob_amplitude = clamp(bob_amplitude, 0.0, MAX_BOB_AMPLITUDE)
	
	# Update the bob phase
	bob_phase += BOB_FREQUENCY * delta
	if bob_phase > 2 * PI:
		bob_phase -= 2 * PI  # Keep the phase within 0 to 2π
	
	# Calculate the sine wave offsets
	var bob_offset_y = sin(bob_phase) * bob_amplitude
	var bob_offset_x = sin(bob_phase ) * (bob_amplitude * 0.5)
	var bob_offset_z = cos(bob_phase * 2) * (bob_amplitude * 0.2)
	
	# Apply the offsets to the FPS_RIG's position relative to the base position
	fps_rig.position = base_fps_rig_position + Vector3(bob_offset_x, bob_offset_y, bob_offset_z)



func process_input():
	if is_bot: return
	direction = Vector3()
	if Globals.paused:
		return
	if Input.is_action_pressed("kill") and can_die:
		can_die = false
		kill_timeout = kill_max_timeout
		player_death()
	if Input.is_action_just_pressed("rebuild_map"):
		world.rpc("rebuild_map")

	# Free-looking
	if Input.is_action_just_pressed("free_look"):
		free_looking = true
	if Input.is_action_just_released("free_look"):
		free_looking = false

	if Input.is_action_just_pressed("walk"):
		is_walking = true
	if Input.is_action_just_released("walk"):
		is_walking = false

	# Movement directions
	if Input.is_action_pressed("forward"):
		direction -= transform.basis.z
	elif Input.is_action_pressed("backward"):
		direction += transform.basis.z
	if Input.is_action_pressed("left"):
		direction -= transform.basis.x
	elif Input.is_action_pressed("right"):
		direction += transform.basis.x

	# Jumping
	wish_jump = Input.is_action_pressed("jump")  # Change to is_action_pressed

	# Later in your physics process, if the player releases the jump button early:
	if Input.is_action_just_released("jump"):
		if velocity.y > 0.0:
			velocity.y *= CUT_JUMP_HEIGHT

	# Crouching: Set crouching true only when the player is on the floor.
	if Input.is_action_pressed("crouch"):
		crouching = true
	elif !raycast_crouching.is_colliding():
		crouching = false
		



func _handle_noclip(delta) -> bool:
	if Input.is_action_just_pressed("noclip") and OS.has_feature("debug"):
		noclip = !noclip
	#standing_collision_shape.disabled = noclip

	if not noclip:
		return false

	var speed
	if !is_walking:
		speed = noclip_speed_mult * MAX_VELOCITY_GROUND
	else:
		speed = noclip_speed_mult * MAX_VELOCITY_GROUND_WALKING

	# Get horizontal movement based on camera direction.
	self.velocity = cam_aligned_wish_dir * speed

	# If the player presses spacebar (mapped to "jump"), add upward movement.
	if Input.is_action_pressed("jump"):
		self.velocity += Vector3.UP * speed
		
		# If the player presses Control (mapped to "ctrl"), add downward movement.
	if Input.is_action_pressed("crouch"):
		self.velocity += Vector3.DOWN * speed

	global_position += self.velocity * delta

	return true


func process_movement(delta):
	if is_bot: return
	if self.position.y < -100:
		player_death()
	if is_on_floor(): _last_time_was_on_floor = Engine.get_physics_frames()
	# Get the normalized input direction so that we don't move faster on diagonals
	var wish_dir = direction.normalized()
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	if is_walking and is_on_floor() and wish_dir != Vector3.ZERO and not can_move_in_direction(wish_dir):
		velocity = Vector3.ZERO
		return
	
	cam_aligned_wish_dir = main_camera.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)

	if not _handle_noclip(delta):
			# Instead of checking strictly for is_on_floor(), we also allow a jump if within coyote time.
			if wish_jump and (is_on_floor() or coyote_time_remaining > 0):
				velocity.y = JUMP_IMPULSE
				coyote_time_remaining = 0  # Consume the coyote jump so it only triggers once.
				velocity = update_velocity_air(wish_dir, delta)
				# Reset view bobbing when jumping
				bob_amplitude = 0.0
				bob_phase = 0.0
			elif is_on_floor():
				if walking:
					velocity.x *= PLAYER_WALKING_MULTIPLIER
					velocity.z *= PLAYER_WALKING_MULTIPLIER

				velocity = update_velocity_ground(wish_dir, delta)
			else:
				velocity.y -= GRAVITY * delta
				velocity = update_velocity_air(wish_dir, delta)

			if not _snap_up_stairs_check(delta):
				move_and_slide()
				_snap_down_to_stairs_check()

func _process(delta):
	if is_bot: return
	viewmodel_camera.global_transform = main_camera.global_transform
	



func accelerate(wish_dir: Vector3, max_speed: float, delta):
	# Get our current speed as a projection of velocity onto the wish_dir
	var current_accelerte_speed = velocity.dot(wish_dir)
	# How much we accelerate is the difference between the max speed and the current speed
	# clamped to be between 0 and MAX_ACCELERATION which is intended to stop you from going too fast
	var add_speed = clamp(max_speed - current_accelerte_speed, 0, MAX_ACCELERATION * delta)
	
	return velocity + add_speed * wish_dir

	
func update_velocity_ground(wish_dir: Vector3, delta):
	# Apply friction when on the ground and then accelerate
	var speed = velocity.length()
	if speed != 0:
		var control = max(STOP_SPEED, speed)
		var drop = control * friction * delta
		# Scale the velocity based on friction
		velocity *= max(speed - drop, 0) / speed

	var max_velocity_ground_current = MAX_VELOCITY_GROUND
	if is_walking:
		max_velocity_ground_current = MAX_VELOCITY_GROUND_WALKING
	if crouching:
		max_velocity_ground_current = crouching_speed
		
	if weapons_manager.current_weapon.weapon_name == "knife" or weapons_manager.current_weapon.weapon_name == "hands":
		max_velocity_ground_current += KNIFE_EXTRA_SPEED

	return accelerate(wish_dir, max_velocity_ground_current, delta)

	
func update_velocity_air(wish_dir: Vector3, delta):
	# Do not apply any friction
	return accelerate(wish_dir, MAX_VELOCITY_AIR, delta)
	

func player_death():
	if disable_respawn:
		queue_free()
	interaction_ray.release_grabbed_object()
	var world_pos = global_transform.origin
	# Reset momentum
	velocity = Vector3.ZERO
	# Reset ammo for all weapons

	weapons_manager.reset_all_ammo()
	weapons_manager.drop_all_weapons()
	# Spawn mana drop only for the local player who died
	if is_multiplayer_authority():
		rpc("spawn_mana_for_all", world_pos)
		world.rpc("display_to_killfeed", last_tagged_by, self.name)

	# Call the world's respawn player function
	var world_to_respawn = get_parent()
	world_to_respawn.respawn_player(self)
	health = max_health
	mana = 50
	self.set_on_fire(false)
	mana_changed.emit(mana)
	health_changed.emit(health)
	if is_bot:
		bot_logic.initialize_bot()
		


@rpc("call_local")
func launch_rocket():
	const ROCKET = preload("res://models/rocket_launcher/rocket.tscn")
	var proj_instance = ROCKET.instantiate()

	proj_instance.global_transform = main_camera.global_transform
	
	# Set the owner of the projectile
	proj_instance.owner_player = self
	var launch_rocket_to_world = get_parent()
	launch_rocket_to_world.add_child.call_deferred(proj_instance)
	
@rpc("call_local")
func launch_he_grenade():
	const GRENADE_PROJ = preload("res://models/grenade/grenade_proj.tscn")
	var proj_instance = GRENADE_PROJ.instantiate()
	proj_instance.global_transform = main_camera.global_transform
	proj_instance.owner_player = self
	var launch_speed = 20.0 # Adjust the speed as necessary
	var forward_direction = main_camera.global_transform.basis.z.normalized()
	proj_instance.linear_velocity = -forward_direction * launch_speed

	var launch_grenade_to_world = get_parent()
	launch_grenade_to_world.add_child.call_deferred(proj_instance)
	
	
@rpc("call_local")
func launch_salsa():
	const SALSA_PROJ = preload("res://models/salsa/salsa_proj.tscn")
	var proj_instance = SALSA_PROJ.instantiate()
	proj_instance.global_transform = main_camera.global_transform
	proj_instance.owner_player = self
	var launch_speed = 20.0 # Adjust the speed as necessary
	var forward_direction = main_camera.global_transform.basis.z.normalized()
	proj_instance.linear_velocity = -forward_direction * launch_speed
	var launch_salsa_to_world = get_parent()
	launch_salsa_to_world.add_child.call_deferred(proj_instance)


@rpc("call_local")
func launch_fireball():
	const FIREBALL = preload("res://models/the_power/fireball/fireball.tscn")
	var proj_instance = FIREBALL.instantiate()

	proj_instance.global_transform = main_camera.global_transform
	
	# Set the owner of the projectile
	proj_instance.owner_player = self
	var launch_rocket_to_world = get_parent()
	launch_rocket_to_world.add_child.call_deferred(proj_instance)


# Define an RPC to spawn mana drop for all clients
@rpc("call_local")
func spawn_mana_for_all(world_pos):
	const MANADROP = preload("res://manadrop.tscn")
	# Instantiate MANADROP
	var instance = MANADROP.instantiate()
	# Set the position slightly above the world_pos
	var spawn_height = 1  # Adjust this value as needed
	instance.transform.origin = Vector3(world_pos.x, world_pos.y + spawn_height, world_pos.z)
	instance.mana_drop_ammount = mana
	instance.mana_drop_owner = self
	get_tree().current_scene.add_child(instance)
	
	
	

@rpc("any_peer", "call_local")
func update_last_tagged_by(tagged_name):
	last_tagged_by = tagged_name

#func player_respawn():
	#health = max_health
	#mana = 0
	## Randomize spawn to prevent spawn collision
	#position.x = randi_range(-10, 10)
	#position.z = randi_range(-10, 10)
	#position.y = 10
	#mana_changed.emit(mana)
	#health_changed.emit(health)

		
func play_hurt_sound():
	player_hurt_noise.play()

@rpc("any_peer", "call_local")
func receive_damage(dmg):
	health -= int(dmg)
	health_changed.emit(health)
	if health <= 0:
		player_death()
	play_hurt_sound()
	
	
@rpc("any_peer", "call_local")
func receive_health(rcv_hp):
	health += int(rcv_hp)
	health_changed.emit(health)
	if health >= max_health:
		health = max_health

	
	
@rpc("any_peer", "call_local")
func receive_mana(received_mana):
	mana += int(received_mana)
	if mana >= max_mana:# Dont let Mana exceed the maximum
		mana = max_mana
	if mana < 0:# Prevent mama from going negative
		mana = 0
	mana_changed.emit(mana)
	
@rpc("any_peer", "call_local")
func receive_ammo(received_ammo):
	weapons_manager.add_ammo_to_all(received_ammo)

func is_ammo_full() -> bool:
	return weapons_manager.is_all_ammo_full()
	
	
@rpc("any_peer", "call_local")
func receive_weapon(received_weapon):
	weapons_manager.add_weapon(received_weapon)
	
@rpc("any_peer", "call_local")
func add_all_weapons():
	weapons_manager.add_all_weapons()

func does_have_weapon(weapon):
	return weapons_manager.does_have_weapon(weapon)

	

# Method to set the on_fire state
func set_on_fire(state: bool) -> void:
	is_on_fire = state
	player_flames_fx.emitting = state
	# Add additional logic here, such as applying damage or visual effects
	
	
func calculate_fire_damage():
	
	if is_on_fire:
		fire_counter += 1
	else:
		fire_counter -= 1
	
	
	fire_counter = clamp(fire_counter, 0, 20) # Set a maximum and minumum value for the variable
	
	if fire_counter >= 20:
		receive_damage(1)
		fire_counter = 0
		
func is_surface_too_steep(normal: Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > self.floor_max_angle

func _run_body_test_motion(from: Transform3D, motion : Vector3, result = null) -> bool:
	if not result: result = PhysicsTestMotionResult3D.new()
	var params = PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	return PhysicsServer3D.body_test_motion(self.get_rid(), params, result)


func _snap_down_to_stairs_check() -> void:
	var did_snap := false
	var floor_below : bool = %StairsBelowRayCast3D.is_colliding() and not is_surface_too_steep(%StairsBelowRayCast3D.get_collision_normal())
	var was_on_floor_last_frame = Engine.get_physics_frames() - _last_time_was_on_floor == 1
	if not is_on_floor() and velocity.y <= 0 and (was_on_floor_last_frame or _snapped_to_stairs_last_frame) and floor_below:
		var body_test_result = PhysicsTestMotionResult3D.new()
		if _run_body_test_motion(self.global_transform, Vector3(0, -MAX_STEP_HEIGHT,0), body_test_result):
			var translate_y = body_test_result.get_travel().y
			self.position.y += translate_y
			apply_floor_snap()
			did_snap = true
	_snapped_to_stairs_last_frame = did_snap

func _snap_up_stairs_check(delta) -> bool:
	if not is_on_floor() and not _snapped_to_stairs_last_frame: return false
	# Don't snap stairs if trying to jump, also no need to check for stairs ahead if not moving
	if self.velocity.y > 0 or (self.velocity * Vector3(1,0,1)).length() == 0: return false
	var expected_move_motion = self.velocity * Vector3(1,0,1) * delta
	var step_pos_with_clearance = self.global_transform.translated(expected_move_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0))
	# Run a body_test_motion slightly above the pos we expect to move to, towards the floor.
	#  We give some clearance above to ensure there's ample room for the player.
	#  If it hits a step <= MAX_STEP_HEIGHT, we can teleport the player on top of the step
	#  along with their intended motion forward.
	var down_check_result = KinematicCollision3D.new()
	if (self.test_move(step_pos_with_clearance, Vector3(0,-MAX_STEP_HEIGHT*2,0), down_check_result)
	and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D"))):
		var step_height = ((step_pos_with_clearance.origin + down_check_result.get_travel()) - self.global_position).y
		# Note I put the step_height <= 0.01 in just because I noticed it prevented some physics glitchiness
		# 0.02 was found with trial and error. Too much and sometimes get stuck on a stair. Too little and can jitter if running into a ceiling.
		# The normal character controller (both jolt & default) seems to be able to handled steps up of 0.1 anyway
		if step_height > MAX_STEP_HEIGHT or step_height <= 0.01 or (down_check_result.get_position() - self.global_position).y > MAX_STEP_HEIGHT: return false
		%StairsAheadRayCast3D.global_position = down_check_result.get_position() + Vector3(0,MAX_STEP_HEIGHT,0) + expected_move_motion.normalized() * 0.1
		%StairsAheadRayCast3D.force_raycast_update()
		if %StairsAheadRayCast3D.is_colliding() and not is_surface_too_steep(%StairsAheadRayCast3D.get_collision_normal()):

			self.global_position = step_pos_with_clearance.origin + down_check_result.get_travel()
			apply_floor_snap()
			_snapped_to_stairs_last_frame = true
			return true
	return false
	
func update_footsteps_vars():
	# Update footsteps only if the player is on the floor and moving sufficiently.
	if is_on_floor() and velocity.length() > 1.0:
		# Calculate how far the player moved since last frame.
		var current_position = global_transform.origin
		distance_accumulated += last_position.distance_to(current_position)
		
		# If the accumulated distance exceeds the threshold, play a footstep.
		if distance_accumulated >= step_distance_threshold:
			play_footstep_sound()
			distance_accumulated = 0.0  # Reset the accumulator
		
		# Update last_position for the next frame.
		last_position = current_position
		

func play_footstep_sound():
	# Call the RPC so that all peers (including the local client) play the footstep sound.
	rpc("rpc_play_footstep", left_step)
	# Toggle the foot for the next step.
	left_step = !left_step


@rpc("any_peer", "call_local")
func rpc_play_footstep(is_left: bool) -> void:
	# Choose the appropriate sound based on which foot was pressed.
	if is_left:
		footstep_player.stream = footstep_left_sound
	else:
		footstep_player.stream = footstep_right_sound
	footstep_player.play()








func can_move_in_direction(move_dir: Vector3) -> bool:
	# Only do this check when on the floor and when moving.
	if not is_on_floor() or move_dir == Vector3.ZERO:
		return true

	# Calculate an offset from the player's origin toward the direction of movement.
	# Adjust 'edge_offset' to roughly the distance from your center to the edge of your collision shape.
	var edge_offset = 0.2  # Example value; tweak as needed.
	var ray_origin = global_transform.origin + move_dir.normalized() * edge_offset + Vector3(0, 0.1, 0)
	# Cast the ray downward far enough to detect the floor.
	var ray_length = 0.5  # Adjust depending on your scale.
	var ray_end = ray_origin + Vector3.DOWN * ray_length

	var params = PhysicsRayQueryParameters3D.new()
	params.from = ray_origin
	params.to = ray_end
	# Optionally set collision_mask to only detect floor layers.
	# params.collision_mask = FLOOR_LAYER_MASK

	var result = get_world_3d().direct_space_state.intersect_ray(params)
	return (result.size() > 0)  # Returns true if floor detected.
