extends Area3D

@onready var rocket = $"../.."


@rpc("any_peer", "call_local")
func destruct():
	rocket.explode()
