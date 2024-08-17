extends Area3D



@onready var mana_drop_scene = $"../.."


var used = false

func _ready():
	# Connect the body_entered signal to the _on_body_entered function
	self.connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	# Check if the entered body is the desired object
	if body.is_in_group("players"):
		# Execute your code here
		if body.mana != body.max_mana:
			used = true
			body.rpc("receive_mana", 5)  # Ensure -25 is an integer
		# Add your custom code here
		if used == true:
			rpc("sync_queue_free")

@rpc("any_peer", "call_local")
func sync_queue_free():
	rpc_id(0, "queue_free_mana_drop")

@rpc("any_peer", "call_local")
func queue_free_mana_drop():
	mana_drop_scene.queue_free()
