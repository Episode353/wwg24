extends CharacterBody3D

signal health_changed(health_value)
signal mana_changed(mana_value)

@onready var world = get_tree().get_root().get_node("World")
@onready var player = $"."

# Player Nodes

@onready var head = $neck/head
@onready var neck = $neck
@onready var muzzle_flash = $neck/head/Camera3D/Pistol/MuzzleFlash
@onready var crouching_collision_shape = $crouching_collision_shape
@onready var standing_collision_shape = $standing_collision_shape
@onready var raycast_crouching = $raycast_crouching

@onready var main_camera = $neck/head/main_camera
@onready var viewmodel_camera = $neck/head/main_camera/SubViewportContainer/viewmodel_viewport/viewmodel_camera
@onready var viewmodel_viewport = $neck/head/main_camera/SubViewportContainer/viewmodel_viewport

@onready var raycast_wall = $raycast_wall
@onready var sub_viewport = $CanvasLayer/SubViewportContainer/SubViewport

const MANADROP = preload("res://manadrop.tscn")
@onready var _3p_model = $"3p_model"
var last_tagged_by = "Unknown"


# Source
const MAX_VELOCITY_AIR = 0.6
const MAX_VELOCITY_GROUND = 8.0
const MAX_ACCELERATION = 10 * MAX_VELOCITY_GROUND
const GRAVITY = 12
# GRAVITY USED TO BE 15.34
const STOP_SPEED = 1.5
const JUMP_IMPULSE = sqrt(2 * GRAVITY * 1.85)
const PLAYER_WALKING_MULTIPLIER = 0.666
var direction = Vector3.ZERO
var friction = 4
var wish_jump = false
var sensitivity = 0.05
var walking = false


var health = 100 # Inital health
var max_health = 100 # Health set to max health on respawn

var mana = 50 # Inital mana
var max_mana = 100 # mana set to max health on respaw

# Speed Variables
const walking_speed = 5.0
const sprinting_speed = 10.0
const crouching_speed = 3.0
var current_speed = 10.0
const JUMP_VELOCITY = 10.0
var lerp_speed = 20.0
var crouching_depth = -0.5
var standing_depth = 1.8
var free_look_tilt_ammount = 8


# Staris
const MAX_STEP_HEIGHT = 0.5
var _snapped_to_stairs_last_frame := false
var _last_time_was_on_floor = -INF

# States
# Moved walking to Source Section
var sprinting = false
var crouching = false
var free_looking = false
var sliding = false

# Slide Vars
var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_vector = Vector2.ZERO
var slide_speed = 15.0

# Health States
var is_on_fire = false
@onready var player_flames_fx = $Area3D/PlayerFlamesFx
var fire_counter = 0


# Input Variables
const mouse_sens = 0.1
# Moved Direction to Source

# Bhop Variables
var bhop_count = 0
var time_on_floor = 0.0
const bhop_reset_delay = 0.2  # How long the player can be on the floor before resetting bhop counter
const bhop_increase_speed_multiplier = 5 # How much speed is added per bhop

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 20.0

# Create  a Three second cool down, to not allow spamming of the Kill key
var kill_timeout = 3
var kill_max_timeout = 3
var can_die = true


var username : String = "init"

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	
	
# Peer id.
@export var peer_id : int : 
	set(value):
		peer_id = value
		name = str(peer_id)
		$username_label.text = str(peer_id)
	
# Function to adjust the viewport size
func _adjust_viewport_size():
	if viewmodel_viewport:
		viewmodel_viewport.size = get_viewport().size


# Signal handler for size changes
func _on_size_changed():
	_adjust_viewport_size()

func _ready():
	if not is_multiplayer_authority(): return
	_3p_model.hide()
	
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	main_camera.current = true
	
	# Connect the size_changed signal to the _on_size_changed function
	get_viewport().connect("size_changed", Callable(self, "_on_size_changed"))
	# Initial adjustment of the viewport size
	_adjust_viewport_size()
	
	

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		if free_looking:
			neck.rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
			neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-120), deg_to_rad(120)) #How far left and right you can look like freelooking
		else:
			rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
			head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-98), deg_to_rad(89))
	



func _physics_process(delta):
	if not is_multiplayer_authority():
		return
		
	
		
	calculate_fire_damage()
	
	
	
	process_input()
	process_movement(delta)
	kill_timeout -= delta
	if kill_timeout <= 0:
		can_die = true
	
	# Check and lerp neck rotation if not free looking
	if not free_looking and neck != null:  # Ensure neck node is valid
		# Lerp neck rotation back to default (Vector3.ZERO)
		neck.rotation.x = lerp(neck.rotation.x, 0.0, delta * 5)
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta * 5)
		neck.rotation.z = lerp(neck.rotation.z, 0.0, delta * 5)
	
		
	


	
func process_input():
	direction = Vector3()
	
	if Input.is_action_pressed("kill") && can_die:
		can_die = false
		kill_timeout = kill_max_timeout
		player_death()
	
	# Free-looking
	if Input.is_action_just_pressed("free_look"):
		free_looking = true
	if Input.is_action_just_released("free_look"):
		free_looking = false
	
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
	
	# Walking
	#walking = Input.is_action_pressed("walk")

func process_movement(delta):
	if self.position.y < -100:
		print("Player has fallen off of map, Respawning...")
		player_death()
	if is_on_floor(): _last_time_was_on_floor = Engine.get_physics_frames()
	# Get the normalized input direction so that we don't move faster on diagonals
	var wish_dir = direction.normalized()

	if is_on_floor():
		# If wish_jump is true then we won't apply any friction and allow the 
		# player to jump instantly, this gives us a single frame where we can 
		# perfectly bunny hop"mesh"
		if wish_jump:
			velocity.y = JUMP_IMPULSE
			# Update velocity as if we are in the air
			velocity = update_velocity_air(wish_dir, delta)
		else:
			if walking:
				velocity.x *= PLAYER_WALKING_MULTIPLIER
				velocity.z *= PLAYER_WALKING_MULTIPLIER
			
			velocity = update_velocity_ground(wish_dir, delta)
	else:
		# Only apply gravity while in the air
		velocity.y -= GRAVITY * delta
		velocity = update_velocity_air(wish_dir, delta)

	if not _snap_up_stairs_check(delta):
		# Because _snap_up_stairs_check moves the body manually, don't call move_and_slide
		# This should be fine since we ensure with the body_test_motion that it doesn't 
		# collide with anything except the stairs it's moving up to.
		move_and_slide()
		_snap_down_to_stairs_check()
	viewmodel_camera.global_transform = main_camera.global_transform

func accelerate(wish_dir: Vector3, max_speed: float, delta):
	# Get our current speed as a projection of velocity onto the wish_dir
	var current_speed = velocity.dot(wish_dir)
	# How much we accelerate is the difference between the max speed and the current speed
	# clamped to be between 0 and MAX_ACCELERATION which is intended to stop you from going too fast
	var add_speed = clamp(max_speed - current_speed, 0, MAX_ACCELERATION * delta)
	
	return velocity + add_speed * wish_dir
	
func update_velocity_ground(wish_dir: Vector3, delta):
	# Apply friction when on the ground and then accelerate
	var speed = velocity.length()
	
	if speed != 0:
		var control = max(STOP_SPEED, speed)
		var drop = control * friction * delta
		
		# Scale the velocity based on friction
		velocity *= max(speed - drop, 0) / speed
	
	return accelerate(wish_dir, MAX_VELOCITY_GROUND, delta)
	
func update_velocity_air(wish_dir: Vector3, delta):
	# Do not apply any friction
	return accelerate(wish_dir, MAX_VELOCITY_AIR, delta)
	

func player_death():
	var world_pos = global_transform.origin
	# Reset momentum
	velocity = Vector3.ZERO
	# Reset ammo for all weapons

	$neck/head/main_camera/Weapons_Manager.reset_all_ammo()
	# Spawn mana drop only for the local player who died
	if is_multiplayer_authority():
		rpc("spawn_mana_for_all", world_pos)
		world.rpc("display_to_killfeed", last_tagged_by, self.name)

	# Call the world's respawn player function
	var world = get_parent()
	world.respawn_player(self)
	health = max_health
	mana = 50
	self.set_on_fire(false)
	mana_changed.emit(mana)
	health_changed.emit(health)


@rpc("call_local")
func launch_rocket():
	const ROCKET = preload("res://models/rocket_launcher/rocket.tscn")
	var proj_instance = ROCKET.instantiate()

	proj_instance.global_transform = main_camera.global_transform
	
	# Set the owner of the projectile
	proj_instance.owner_player = self
	var world = get_parent()
	world.add_child.call_deferred(proj_instance)
	
@rpc("call_local")
func launch_he_grenade():
	const GRENADE_PROJ = preload("res://models/grenade/grenade_proj.tscn")
	var proj_instance = GRENADE_PROJ.instantiate()
	proj_instance.global_transform = main_camera.global_transform
	proj_instance.owner_player = self
	var launch_speed = 20.0 # Adjust the speed as necessary
	var forward_direction = main_camera.global_transform.basis.z.normalized()
	proj_instance.linear_velocity = -forward_direction * launch_speed

	var world = get_parent()
	world.add_child.call_deferred(proj_instance)
	
	
@rpc("call_local")
func launch_salsa():
	const SALSA_PROJ = preload("res://models/salsa/salsa_proj.tscn")
	var proj_instance = SALSA_PROJ.instantiate()
	proj_instance.global_transform = main_camera.global_transform
	proj_instance.owner_player = self
	var launch_speed = 20.0 # Adjust the speed as necessary
	var forward_direction = main_camera.global_transform.basis.z.normalized()
	proj_instance.linear_velocity = -forward_direction * launch_speed
	var world = get_parent()
	world.add_child.call_deferred(proj_instance)




# Define an RPC to spawn mana drop for all clients
@rpc("call_local")
func spawn_mana_for_all(world_pos):
	# Wait for 1 second
	get_tree().create_timer(1.0)
	# Instantiate MANADROP
	var instance = MANADROP.instantiate()
	# Set the position slightly above the world_pos
	var spawn_height = 1  # Adjust this value as needed
	instance.transform.origin = Vector3(world_pos.x, world_pos.y + spawn_height, world_pos.z)
	# Add the instance to the current scene
	get_tree().current_scene.add_child(instance)
	
	

@rpc("any_peer", "call_local")
func update_last_tagged_by(name):
	last_tagged_by = name

#func player_respawn():
	#health = max_health
	#mana = 0
	## Randomize spawn to prevent spawn collision
	#position.x = randi_range(-10, 10)
	#position.z = randi_range(-10, 10)
	#position.y = 10
	#mana_changed.emit(mana)
	#health_changed.emit(health)
		
@rpc("any_peer", "call_local")
func receive_damage(dmg):
	health -= dmg
	health_changed.emit(health)
	if health <= 0:
		player_death()
	print(health)
	
@rpc("any_peer", "call_local")
func receive_health(rcv_hp):
	health += rcv_hp
	health_changed.emit(health)
	if health >= max_health:
		health = max_health
	print(health)

	
	
@rpc("any_peer", "call_local")
func receive_mana(received_mana):
	print("receive_mana:", received_mana)
	mana += received_mana
	if mana >= max_mana:# Dont let Mana exceed the maximum
		mana = max_mana
	if mana < 0:# Prevent mama from going negative
		mana = 0
	mana_changed.emit(mana)
	
	

# Method to set the on_fire state
func set_on_fire(state: bool) -> void:
	is_on_fire = state
	player_flames_fx.emitting = state
	# Add additional logic here, such as applying damage or visual effects
	print("Player is_on_fire set to: ", is_on_fire)
	
	
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
	

