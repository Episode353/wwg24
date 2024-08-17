extends Area3D

@onready var health_drop = $"../.."
var used = false

func _ready():
	# Connect the body_entered signal to the _on_body_entered function
	self.connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	print(body)
	# Check if the entered body is the desired object
	if body.is_in_group("players"):
		# Execute your code here
		print("Object entered the area")
		if body.health != body.max_health:
			used = true
		body.rpc("receive_health", 25)  # Ensure -25 is an integer
		# Add your custom code here
		if used == true:
			rpc("sync_queue_free")

@rpc("any_peer")
func sync_queue_free():
	rpc_id(0, "queue_free_health_drop")

@rpc("any_peer", "call_local")
func queue_free_health_drop():
	health_drop.queue_free()
