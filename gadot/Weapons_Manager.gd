extends Node3D

signal weapon_changed
signal update_ammo
signal update_weapon_stack

@onready var animation_player = $FPS_RIG/AnimationPlayer
@onready var main_camera = $".."

@onready var world = get_tree().get_root().get_node("World")
@onready var player = $"../../../.."

var current_weapon = null
var weapon_raise = false
var weapon_stack = [] # An array of all weapons the player has
@onready var raycast_shoot = $"../raycast_shoot"
var weapon_indicator = 0
var next_weapon: String
@onready var ac_timer = $"../area_collision/Timer"

@onready var bullet_decal = preload("res://tscn/bullet_decal.tscn")

var weapon_list = {}
@export var _weapon_resources: Array[Weapon_Resource]
@onready var raycast_wall = $"../../../../raycast_wall"
@onready var area_collision = $"../area_collision"

@export var start_weapons: Array[String]

func _ready():
	Initalize(start_weapons) # Enter the state machine
	
func _input(event):
	if not is_multiplayer_authority(): return
	if event.is_action_pressed("w_up"):
		weapon_indicator = (weapon_indicator + 1) % weapon_stack.size()
		exit(weapon_stack[weapon_indicator])

	if event.is_action_pressed("w_down"):
		weapon_indicator = (weapon_indicator - 1 + weapon_stack.size()) % weapon_stack.size()
		exit(weapon_stack[weapon_indicator])

	if event.is_action_pressed("shoot") && weapon_raise == false:
		shoot()
	
	if event.is_action_pressed("reload"):
		reload()
	

func reset_all_ammo():
	print("weapons_manager reset all ammo")
	for weapon_name in weapon_stack:
		var weapon = weapon_list[weapon_name]
		weapon.current_ammo = weapon.current_ammo_default
		weapon.reserve_ammo = weapon.reserve_ammo_default
		weapon.mag_ammo = weapon.mag_ammo_default
		print(weapon_name)
		emit_signal("update_ammo", [current_weapon.current_ammo, current_weapon.reserve_ammo])
		




func Initalize(_start_weapons: Array):
	if not is_multiplayer_authority(): return
	# Create a Dictionary to refer to our weapons
	for weapon in _weapon_resources:
		weapon_list[weapon.weapon_name] = weapon

	for i in _start_weapons:
		weapon_stack.push_back(i) # Add our start weapons

	current_weapon = weapon_list[weapon_stack[0]]
	emit_signal("update_weapon_stack", weapon_stack)
	enter()

func enter():
	
	animation_player.queue(current_weapon.activate_anim)
	emit_signal("weapon_changed", current_weapon.weapon_name)
	emit_signal("update_ammo", [current_weapon.current_ammo, current_weapon.reserve_ammo])

func exit(_next_weapon: String):
	#In order to change weapons first call exit
	if next_weapon != current_weapon.weapon_name:
		if animation_player.get_current_animation() != current_weapon.deactivate_anim:
			animation_player.play(current_weapon.deactivate_anim)
			next_weapon = _next_weapon
	
func change_weapon(weapon_name: String):
	
	current_weapon = weapon_list[weapon_name]
	var weapon_range = current_weapon.weapon_range
	raycast_shoot.target_position.z = weapon_range
	print("Switched to Weapon: ", current_weapon.weapon_name)
	ac_timer.wait_time = current_weapon.fire_rate
	next_weapon = ""
	enter()



func _on_animation_player_animation_finished(anim_name):
	if current_weapon == null:
		return
	
	if anim_name == current_weapon.deactivate_anim:
		change_weapon(next_weapon)
		animation_player.play(current_weapon.activate_anim)
	
	if anim_name == current_weapon.shoot_anim and current_weapon.auto_fire and not current_weapon.skip_animation_on_fire:
		if Input.is_action_pressed("shoot"):
			shoot()
	
	idle()

		
		
func raycast_shoot_procc():
	var hit_object = raycast_shoot.get_collider()
	# Place the Bullet Decal
	var col_nor = raycast_shoot.get_collision_normal()
	var col_point = raycast_shoot.get_collision_point()
	var b = bullet_decal.instantiate()
	raycast_shoot.get_collider().add_child(b)
	b.global_transform.origin = col_point
	if col_nor == Vector3.DOWN or col_nor == Vector3.UP:
		# For floors and ceilings, set rotation to face upwards
		b.rotation_degrees.x = 90
	else:
		# For walls, use look_at to orient the decal
		b.look_at(col_point - col_nor, Vector3(0, 1, 0))
	# Check if the hit object is a player
	if hit_object.is_in_group("players"):
		# Assuming the player has a "receive_w" method marked as an rpxc
		hit_object.rpc("receive_damage", current_weapon.damage)
		hit_object.rpc("update_last_tagged_by", player.name)
	else:
		print("Hit object is not a player.")

	
func area_collision_procc(self_id):
	var ac_enim = area_collision.get_overlapping_bodies()
	print("Self ID: ", self_id) # Print self ID for debugging
	for e in ac_enim:
		var e_id = e.get_instance_id() # Get the unique ID of each entity
		print("Checking entity ID: ", e_id) # Print each entity ID being checked
		if e.is_in_group("players"):
			print("In players group: Entity ID: ", e_id)
			if e.name != str(self_id): # Compare with the player ID passed to the function
				print("Damaging player: Entity ID: ", e_id) # Debug print
				e.rpc("receive_damage", current_weapon.damage)
				e.rpc("update_last_tagged_by", player.name)
			else:
				print("Ignoring self: Entity ID: ", e_id) # Debug print



func shoot():
	if current_weapon.current_ammo != 0:
		if !animation_player.is_playing() or animation_player.current_animation == current_weapon.idle_anim:
			animation_player.play(current_weapon.shoot_anim)
		else:
			return
		if current_weapon.disable_ammo == false:
			current_weapon.current_ammo -= 1
			emit_signal("update_ammo", [current_weapon.current_ammo, current_weapon.reserve_ammo])
		
		if raycast_shoot.is_colliding():
			raycast_shoot_procc()
			
		if current_weapon.is_projectile_launcher:
			
			if current_weapon.weapon_name == "rocket_launcher":
				player.rpc("launch_rocket")
			if current_weapon.weapon_name == "he_grenade":
				await get_tree().create_timer(0.5).timeout
				player.rpc("launch_he_grenade")
				animation_player.play(current_weapon.activate_anim)
				
			if current_weapon.weapon_name == "salsa":
				await get_tree().create_timer(0.5).timeout
				player.rpc("launch_salsa")
				animation_player.play(current_weapon.activate_anim)
			
		if current_weapon.use_area_damage_collision == true:
			area_collision_procc(multiplayer.get_unique_id())
	else:
		reload()


func reload():
	print("reload")
	if current_weapon.disable_ammo == false:
		if current_weapon.current_ammo == current_weapon.mag_ammo:
			print("Current Ammo is equal to Mag Ammo")
			return
		elif !animation_player.is_playing() or animation_player.current_animation == current_weapon.idle_anim:
			if current_weapon.reserve_ammo != 0:
				print("current_weapon.reserve_ammo != 0")
				animation_player.play(current_weapon.reload_anim)
				var reload_ammount = min(current_weapon.mag_ammo - current_weapon.current_ammo,current_weapon.mag_ammo,current_weapon.reserve_ammo)
				
				current_weapon.current_ammo = current_weapon.current_ammo + reload_ammount
				current_weapon.reserve_ammo = current_weapon.reserve_ammo - reload_ammount
				emit_signal("update_ammo", [current_weapon.current_ammo, current_weapon.reserve_ammo])
				
			else:
				animation_player.play(current_weapon.out_of_ammo_anim)
				print("Triggered Reload()")


func idle():
	await get_tree().create_timer(.1).timeout
	if !Input.is_action_pressed("shoot") and current_weapon.has_idle_anim:
		if !animation_player.current_animation == "weapon_raise":
			return
		animation_player.play(current_weapon.idle_anim)
		print("Plaing Idle Animation")

func _physics_process(delta):
	
	if not is_multiplayer_authority():
		return
	
	# in the future i don't want to update this every frame :(
	rpc_update_weapon_info()


	if not current_weapon.disable_wall_prox:
		if raycast_wall.is_colliding() and animation_player.current_animation != current_weapon.wall_raise_anim and not weapon_raise:
			animation_player.play(current_weapon.wall_raise_anim)
			weapon_raise = true
		elif not raycast_wall.is_colliding() and weapon_raise:
			animation_player.play(current_weapon.wall_lower_anim)
			weapon_raise = false

	if current_weapon.use_area_damage_collision:
		if Input.is_action_just_pressed("shoot"):
			ac_timer.start()
		elif Input.is_action_just_released("shoot"):
			ac_timer.stop()

@rpc("reliable")
func rpc_update_weapon_info():
	# RPC to send weapon info to the world script for the local player
	world.rpc_id(multiplayer.get_unique_id(), "update_weapon_info", current_weapon.weapon_name, current_weapon.current_ammo, current_weapon.reserve_ammo, weapon_stack)



func _on_timer_timeout():
	shoot()
