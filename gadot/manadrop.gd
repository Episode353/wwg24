extends Node3D

var target_body_position: Vector3
var speed: float = 50.0
@onready var despawn = $RigidBody3D/despawn
#@onready var despawn = $RigidBody3D/despawnasd
var mana_drop_owner
var mana_drop_ammount
# This Controls the Height of the Target position the 
# Mana ball will travel towards
# If it is set to 6, the ball will launch towards 6 units above the
# Players head when the trigger is entered
# This is supposed to make collecting them more satisfying and interactable
var offset_above_target: float = 6.0 

func _process(delta: float):
	if target_body_position:
		var target_position = target_body_position + Vector3(0, offset_above_target, 0)
		var direction = (target_position - global_transform.origin).normalized()
		translate(direction * speed * delta)

func _on_area_3d_body_entered(body: Node):
	if body == mana_drop_owner: return
	if body.is_in_group("players"):
		var animation_player = $RigidBody3D/CSGSphere3D/AnimationPlayer
		animation_player.play("dissapear")
		body.rpc("receive_mana", mana_drop_ammount)
		target_body_position = body.global_transform.origin

func _on_despawn_timeout():
	queue_free()

func _on_spawn_timeout():
	var area_3d = $RigidBody3D/CSGSphere3D/Area3D
	area_3d.monitoring = true
