extends RigidBody3D
const EXPLOSION_PRELOAD = preload("res://models/grenade/grenade_explosion.tscn")
@onready var world = get_tree().get_root().get_node("World")
@onready var area = $grenade/Node/body/Area3D


var owner_player
var grenade_timer = 0.0
var increasing = true

# Called when the node enters the scene tree for the first time.
func _ready():
	self.angular_velocity.z = 40

# Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if self.angular_velocity.z > 0:
		self.angular_velocity.z -= .5

	# Delete the grenade if it does not collide after a time
	grenade_timer += delta
	if grenade_timer > 4.0:
		explode()


func _on_body_entered(body):
	# Check if the body is the owner of the grenade
	if body == owner_player:
		return
	
	explode()


func explode():
	var explosion_scene = EXPLOSION_PRELOAD.instantiate()
	explosion_scene.owner_player = owner_player
	explosion_scene.global_position = global_position
	world.add_child(explosion_scene)
	queue_free()
