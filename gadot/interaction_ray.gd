extends RayCast3D

@onready var camera_3d: Camera3D = $".."
@onready var interaction_ray: RayCast3D = $"."
@onready var holding_body: StaticBody3D = $"../holding_body"
@onready var player = $"../../../.."


var grab_joint: JoltGeneric6DOFJoint3D



func _process(delta):
	if is_multiplayer_authority():
		if Input.is_action_just_pressed("interact"):
			if player.is_holding_object and player.grabbed_object:
				# If we are already holding something, release it
				rpc_id(player.peer_id, "request_release_object")
			else:
				# Ask server to attempt a pickup
				# We can pass the raycast’s hit info or simply do the raycast on the server side again.
				rpc_id(1, "request_pickup_object", global_transform.origin)
		
		# Safety check: if the object is too far, request release
		if player.grabbed_object and (player.grabbed_object.global_transform.origin - global_transform.origin).length() > 3:
			rpc_id(player.peer_id, "request_release_object")


@rpc("any_peer", "call_local")
func request_pickup_object(requester_global_pos: Vector3):
	# This function runs on the server (assuming ID=1 is the server).
	# Perform the same logic you used to pick up the object, but do it on the server side.
	
	var hit_object: PhysicsBody3D = interaction_ray.get_collider() as PhysicsBody3D
	if !hit_object:
		return
	
	# Distance check
	var distance = (hit_object.global_transform.origin - requester_global_pos).length()
	if distance > 5:
		return  # too far

	# Check if it's a RigidBody3D in "grabbable" group
	if hit_object.is_in_group("grabbable") and hit_object is RigidBody3D:
		# Actually create the joint on the server
		create_6dof_joint(hit_object)
		
		# Inform all clients (or just the requesting client) that we succeeded
		# So they can set local flags. You can also rely on the replicated node
		# tree if your joint is in a synchronized scene.
		rpc("on_object_picked_up", hit_object.get_path())


@rpc("any_peer", "call_local")
func on_object_picked_up(object_path: NodePath):
	var body = get_node_or_null(object_path) as RigidBody3D
		#body.can_sleep = false
	if body:
		player.grabbed_object = body
		player.is_holding_object = true

func create_6dof_joint(body: RigidBody3D):
	grab_joint = JoltGeneric6DOFJoint3D.new()
	grab_joint.node_a = holding_body.get_path()
	grab_joint.node_b = body.get_path()
	grab_joint.solver_velocity_iterations = 120
	grab_joint.solver_position_iterations = 120
	add_child(grab_joint)
	
@rpc("any_peer", "call_local")
func request_release_object():
	# Let the server do the actual release
	release_grabbed_object()

func release_grabbed_object():
	player.is_holding_object = false
	if grab_joint:
		grab_joint.queue_free()
		grab_joint = null

	if player.grabbed_object:
		# Allow the object to go back to sleep
		player.grabbed_object.can_sleep = true
		player.grabbed_object = null
