extends Node3D

@export var speed: float = 20.0
@export var life_time: float = 5.0
@export var explosion_radius: float = 6.0
@export var explosion_force: float = 10.0
@export var upward_force: float = 5.0
@export var max_damage: float = 35.0
@export var min_damage: float = 10.0
@export var rigid_body_force_multiplier: float = 100.0

var owner_player: Node
var _dir: Vector3 = Vector3.ZERO
var _age := 0.0

# optional VFX nodes if you use them:
@onready var smoke_big = $SmokeBig
@onready var explosion_big = $ExplosionBig
@onready var fire_small = $FireSmall

var valid : bool = true
@onready var timer = $Area3D/Timer

func init(owner: Node, dir: Vector3) -> void:
	owner_player = owner
	_dir = dir.normalized()
	look_at(global_position + _dir, Vector3.UP)

func _ready() -> void:
	# If launcher didn't call init(), infer direction from our transform
	if _dir == Vector3.ZERO:
		_dir = (-global_transform.basis.z).normalized()
		look_at(global_position + _dir, Vector3.UP)

func _physics_process(delta: float) -> void:

	if valid:
		global_position += _dir * speed * delta
		_age += delta
		if _age >= life_time:
			explode()
		

func _on_area_3d_body_entered(body):
	if !valid: return
	print("=-===-=--=-=-=-=-=")
	print(body)
	print("=-===-=--=-=-=-=-=")
	explode()
	if body == owner_player:
		return
	# players
	for player in get_tree().get_nodes_in_group("players"):
		var d = player.global_transform.origin.distance_to(global_transform.origin)
		if d <= explosion_radius:
			_apply_explosion_force_to_character(player)
			if player != owner_player:
				player.rpc("receive_damage", _calc_damage(d))
			elif Globals.self_harm:
				player.rpc("receive_damage", _calc_damage(d) / 4.0)
	# destructibles
	for obj in get_tree().get_nodes_in_group("destructable"):
		if obj.global_transform.origin.distance_to(global_transform.origin) <= explosion_radius:
			obj.rpc("destruct")
	# moveable rigidbodies
	for mv_body in get_tree().get_nodes_in_group("moveable"):
		if mv_body.global_transform.origin.distance_to(global_transform.origin) <= explosion_radius:
			_apply_explosion_force_to_rigidbody(mv_body) # <-- pass mv_body (bug fix)
	
func _calc_damage(dist: float) -> float:
	if dist > explosion_radius: return 0.0
	var t = dist / explosion_radius
	var dmg = max_damage - t * (max_damage - min_damage)
	return clamp(dmg, min_damage, max_damage)

func _apply_explosion_force_to_character(player):
	if player is CharacterBody3D:
		var dir = (player.global_transform.origin - global_transform.origin).normalized()
		var impulse = dir * explosion_force
		impulse.y += upward_force
		player.velocity += impulse

func _apply_explosion_force_to_rigidbody(body):
	if body is RigidBody3D:
		var dir = (body.global_transform.origin - global_transform.origin).normalized()
		var force = dir * explosion_force * rigid_body_force_multiplier
		body.apply_force(force, body.global_transform.origin)
		
func explode():
	hide_smoke()
	valid = false
	timer.start()
	

func hide_smoke():
	$Emitter.emitting = false
	$Flame.emitting = false
	$Smoke.emitting = false
	$FireSmall/Flame.emitting = false
	$FireSmall/Smoke.emitting = false
	$FireSmall/Sparks.emitting = false

func _on_timer_timeout():
	queue_free()
