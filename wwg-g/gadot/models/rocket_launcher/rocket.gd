extends Node3D

@onready var rocket_proj: Node3D = $rocket_proj
const EXPLOSION_PRELOAD: PackedScene = preload("res://models/rocket_launcher/explosion.tscn")
@onready var world: Node = get_tree().get_root().get_node("World")

var owner_player: Node
var rocket_timer: int = 0

func _process(delta: float) -> void:
	# Move the rocket forward
	rocket_proj.position.z -= 0.4
	# Delete the rocket if it does not collide after a time
	rocket_timer += 1
	if rocket_timer >= 1000:
		queue_free()

func _on_area_3d_body_entered(body: Node) -> void:
	# Check if the body is the owner of the rocket
	if body == owner_player:
		return
	
	var explosion_scene: Node = EXPLOSION_PRELOAD.instantiate()
	explosion_scene.set("owner_player", owner_player)
	explosion_scene.global_position = rocket_proj.global_position
	world.add_child(explosion_scene)
	
	queue_free()
