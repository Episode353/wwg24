extends RayCast3D

@onready var camera_3d: Camera3D = $".."
@onready var interaction_ray: RayCast3D = $"."
@onready var holding_body: StaticBody3D = $"../holding_body"

var grabbed_object: RigidBody3D
var grab_joint: Generic6DOFJoint3D
var is_holding_object = false

func _process(delta):
	if Input.is_action_just_pressed("interact"):
		if is_holding_object and grabbed_object:
			# If we are already holding something, release it
			release_grabbed_object()
		else:
			# Try to pick something up
			attempt_pickup()
			
	if grabbed_object and (grabbed_object.global_transform.origin - global_transform.origin).length() > 3:
			release_grabbed_object()

func attempt_pickup():
	var hit_object: PhysicsBody3D = interaction_ray.get_collider() as PhysicsBody3D
	if !hit_object:
		return
	
	# Optional distance check
	var distance = (hit_object.global_transform.origin - global_transform.origin).length()
	if distance > 5:
		return  # too far
	
	# Check if it's a RigidBody3D in "grabbable" group
	if hit_object.is_in_group("grabbable") and hit_object is RigidBody3D:
		grabbed_object = hit_object
		is_holding_object = true
		create_6dof_joint(grabbed_object)

func create_6dof_joint(body: RigidBody3D):
	grab_joint = Generic6DOFJoint3D.new()
	grab_joint.node_a = holding_body.get_path()
	grab_joint.node_b = body.get_path()

	# 1) Lock linear movement: The object cannot move away from the holding_body
	#grab_joint.linear_limit_lower = Vector3.ZERO
	#grab_joint.linear_limit_upper = Vector3.ZERO
#
	## 2) Lock angular movement: The object must rotate with the holding_body
	#grab_joint.angular_limit_lower = Vector3.ZERO
	#grab_joint.angular_limit_upper = Vector3.ZERO

	# Add the joint to the scene so the physics engine can process it
	add_child(grab_joint)

	# Wake the body so it doesn't remain sleeping
	body.sleeping = false

func release_grabbed_object():
	is_holding_object = false
	
	if grab_joint:
		grab_joint.queue_free()
		grab_joint = null

	grabbed_object = null
