extends Node3D

@onready var rocket_proj = $rocket_proj
const EXPLOSION_PRELOAD = preload("res://models/rocket_launcher/explosion.tscn")
@onready var world = get_tree().get_root().get_node("World")

var owner_player
var rocket_timer = 0

func _process(_delta):
	# Move the rocket forward
	rocket_proj.position.z -= 0.4
	# Delete the rocket if it does not collide after a time
	rocket_timer += 1
	if rocket_timer >= 1000:
		queue_free()

func _on_area_3d_body_entered(body):
	# Check if the body is the owner of the rocket
	if body == owner_player:
		return
	
	var explosion_scene = EXPLOSION_PRELOAD.instantiate()
	explosion_scene.owner_player = owner_player
	explosion_scene.global_transform = rocket_proj.global_transform
	explosion_scene.scale = Vector3.ONE  # Ensure the explosion scale is 1
	world.add_child.call_deferred(explosion_scene)
	
	queue_free()

func explode():
	# Create and configure the explosion
	var explosion_scene = EXPLOSION_PRELOAD.instantiate()
	explosion_scene.owner_player = null
	explosion_scene.global_transform = rocket_proj.global_transform
	explosion_scene.scale = Vector3.ONE  # Ensure the explosion scale is 1
	world.add_child.call_deferred(explosion_scene)

	# Free the rocket
	queue_free()
