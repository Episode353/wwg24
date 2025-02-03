extends CSGBox3D

@rpc("any_peer", "call_local")
func destruct():
	queue_free()
