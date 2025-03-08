extends Node3D

var owner_player
@onready var collision_shape_3d_2 = $CollisionShape3D2
@onready var world = get_tree().get_root().get_node("World")
@onready var visual_root = $"Visual Root"
@onready var omni_light_3d = $"Visual Root/OmniLight3D"
@onready var collision_shape_3d = $Area3D/CollisionShape3D

var lifetime := 5.0 # lifetime in seconds, easily adjustable
var elapsed := 0.0
var initial_scale := Vector3.ONE
var initial_light_energy := 1.0 # set to your actual starting energy

func _ready():
	initial_scale = visual_root.scale
	initial_light_energy = omni_light_3d.light_energy

func _physics_process(delta):
	elapsed += delta
	
	# Calculate normalized time between 0 (just spawned) and 1 (ready to explode)
	var t = elapsed / lifetime

	# Smoothly interpolate scale and energy based on time t
	var scale_factor = lerp(1.0, 0.0, t)
	visual_root.scale = initial_scale * scale_factor
	collision_shape_3d_2.scale = initial_scale * scale_factor
	collision_shape_3d.scale = initial_scale * scale_factor
	omni_light_3d.light_energy = lerp(initial_light_energy, 0.0, t)

	if t >= 1.0:
		explode()

func _on_area_3d_body_entered(body):
	if !is_multiplayer_authority(): 
		return
	
	if body == owner_player:
		return
	
	if body.is_in_group("players"):
		body.rpc("receive_damage", 32)
		explode()

func explode():
	print("bye bye!")
	queue_free()
