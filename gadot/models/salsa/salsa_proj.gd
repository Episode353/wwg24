extends RigidBody3D

const EXPLOSION_PRELOAD = preload("res://models/salsa/salsa_explosion.tscn")
@onready var world = get_tree().get_root().get_node("World")

@onready var area = $salsa/Node/Layer_1/Area3D

var owner_player

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
	var explosion_scene = EXPLOSION_PRELOAD.instantiate()
	explosion_scene.owner_player = owner_player
	explosion_scene.global_position = global_position
	world.add_child(explosion_scene)
	queue_free()


func _on_area_3d_body_entered(body):
	# Check if the body is the owner of the grenade
	if body == owner_player:
		return
	
	explode()
