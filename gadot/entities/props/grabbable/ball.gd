extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	print(global_position)
	print(global_transform)
	var world = get_tree().get_root().get_node("World")
	if world:
		world.rpc("spawn_ball", global_transform)
	queue_free()
