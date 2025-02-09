extends Node3D

@onready var timer: Timer = $Fireball/Timer
@onready var fireball: Node3D = $Fireball
var objects_removed = false
var owner_player
var queue_timer = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _physics_process(delta):
	if objects_removed:
		queue_timer += 1
	if queue_timer >= 80:
		print("qeue_free")
		queue_free()
	if not is_instance_valid(fireball):
		return  # Exit if fireball has been freed
	# Move the rocket forward
	fireball.translate(Vector3(0, 0, -0.5))
	


func remove_objects():
	objects_removed = true
	fireball.queue_free()

func _on_timer_timeout() -> void:
	remove_objects()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body == owner_player:
		return
	body.rpc("receive_damage", 20)
	remove_objects()
