extends RayCast3D

@onready var camera_3d: Camera3D = $".."
@onready var interaction_ray: RayCast3D = $"."
@onready var holding_body: StaticBody3D = $"../holding_body"
@onready var player = $"../../../.."

var grab_joint: JoltGeneric6DOFJoint3D

# A constant to control how strong the shot is
const SHOOT_FORCE: float = 10.0

func _process(delta):
	if !is_multiplayer_authority(): 
		return

	# Handle pickup/release with "interact"
	if Input.is_action_just_pressed("interact"):
		if player.is_holding_object and player.grabbed_object:
			# If we are already holding something, request its release
			rpc_id(1, "request_release_object")
		else:
			# Request pickup – you could pass additional info (like the raycast hit)
			rpc_id(1, "request_pickup_object", global_transform.origin)
	
	# Handle shooting the held object.
	if Input.is_action_just_pressed("shoot") and player.is_holding_object and player.grabbed_object:
		# Determine the forward direction.
		# (Godot’s camera forward is typically the -Z direction.)
		var shoot_dir: Vector3 = -camera_3d.global_transform.basis.z.normalized()
		# Tell the server to shoot the object in that direction.
		rpc_id(1, "request_shoot_object", shoot_dir)
	
	# Safety check: if the object is too far away, request release
	if player.grabbed_object and (player.grabbed_object.global_transform.origin - global_transform.origin).length() > 3:
		rpc_id(player.peer_id, "request_release_object")


@rpc("any_peer", "call_local")
func request_pickup_object(requester_global_pos: Vector3):
	# Do a raycast to see if an object was hit
	var hit_object: PhysicsBody3D = interaction_ray.get_collider() as PhysicsBody3D
	if !hit_object:
		return

	# Check the distance between the requester and the object
	var distance = (hit_object.global_transform.origin - requester_global_pos).length()
	if distance > 5:
		return  # object is too far away

	# *** Check if the object is already grabbed. ***
	if hit_object.is_in_group("is_grabbed"):
		return

	# Verify that the object is grabbable and is a RigidBody3D
	if hit_object.is_in_group("grabbable") and hit_object is RigidBody3D:
		# Create the joint (on the server)
		create_6dof_joint(hit_object)
		# Notify clients that the object has been picked up
		rpc("on_object_picked_up", hit_object.get_path())


@rpc("any_peer", "call_local")
func on_object_picked_up(object_path: NodePath):
	var body = get_node_or_null(object_path) as RigidBody3D
	if body:
		body.can_sleep = false
		# *** Add the object to the "is_grabbed" group when it is picked up. ***
		body.add_to_group("is_grabbed")
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
	release_grabbed_object()


func release_grabbed_object():
	player.is_holding_object = false
	if grab_joint:
		grab_joint.queue_free()
		grab_joint = null

	if player.grabbed_object:
		# Optionally allow the object to sleep again
		player.grabbed_object.can_sleep = true
		# *** Remove the object from the "is_grabbed" group when it is released. ***
		player.grabbed_object.remove_from_group("is_grabbed")
		player.grabbed_object = null


@rpc("any_peer", "call_local")
func request_shoot_object(shoot_direction: Vector3):
	# This function is executed on the server.
	# Make sure the player is indeed holding an object.
	if not player.is_holding_object or not player.grabbed_object:
		return

	# Store the object reference before releasing it
	var shot_object: RigidBody3D = player.grabbed_object

	# Release the held object (this will remove the joint and clear the player’s reference)
	release_grabbed_object()

	# Apply an impulse to launch the object.
	shot_object.apply_central_impulse(shoot_direction * SHOOT_FORCE)
