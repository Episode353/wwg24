extends RigidBody3D

const EXPLOSION_PRELOAD = preload("res://models/salsa/salsa_explosion.tscn")
@onready var world = get_tree().get_root().get_node("World")

@onready var area = $salsa/Node/Layer_1/Area3D

var owner_player
var num_explosions = 25  # Number of explosion effects to spawn
var explosion_radius = 5.0  # Radius around the point where explosions are spawned

# Called when the node enters the scene tree for the first time.
func _ready():
	self.angular_velocity.z = 40

# Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if self.angular_velocity.z > 0:
		self.angular_velocity.z -= .05

func check_area_and_explode():
	# Get all bodies in the Area3D
	var bodies = area.get_overlapping_bodies()
	if bodies.size() > 0:
		explode()

func explode():
	for i in range(num_explosions):
		# Calculate angle and radius for even distribution
		var angle = (i / float(num_explosions)) * 2.0 * PI
		var distance = randf_range(0, explosion_radius)
		var x = cos(angle) * distance
		var z = sin(angle) * distance
		var explosion_position = global_position + Vector3(x, 0, z)
		
		# Instantiate and position the explosion scene
		var explosion_scene = EXPLOSION_PRELOAD.instantiate()
		explosion_scene.owner_player = owner_player
		explosion_scene.global_position = explosion_position
		world.add_child(explosion_scene)

	queue_free()


func _on_area_3d_body_entered(body):
	# Check if the body is the owner of the grenade
	if body == owner_player:
		return
	
	explode()
