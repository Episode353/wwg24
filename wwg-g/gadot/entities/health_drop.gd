extends Node3D

@export var health_drop: int
var used: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func _on_body_entered(body: Node3D) -> void:
	if used:
		return
	if body.is_in_group("players"):
		body.health += health_drop
		used = true
		sync_queue_free()

func sync_queue_free() -> void:
	# This can contain any synchronization logic needed
	queue_free_health_drop()

func queue_free_health_drop() -> void:
	queue_free()
