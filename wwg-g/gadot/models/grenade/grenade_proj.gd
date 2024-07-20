extends RigidBody3D

const EXPLOSION_PRELOAD = preload("res://models/rocket_launcher/explosion.tscn")
@onready var world: Node = get_tree().get_root().get_node("World")
@onready var area: Area3D = $grenade/Node/body/Area3D

var owner_player: Node
var grenade_timer: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.angular_velocity.z = 40

# Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if self.angular_velocity.z > 0:
		self.angular_velocity.z -= 0.5
	# Delete the grenade if it does not collide after a time
	grenade_timer += delta
	if grenade_timer >= 4.0:
		check_area_and_explode()

func _on_body_entered(body: Node) -> void:
	# Check if the body is the owner of the grenade
	if body == owner_player:
		return
	
	explode()

func check_area_and_explode() -> void:
	# Get all bodies in the Area3D
	var bodies: Array = area.get_overlapping_bodies()
	if bodies.size() > 0:
		explode()

func explode() -> void:
	var explosion_scene: Node = EXPLOSION_PRELOAD.instantiate()
	explosion_scene.owner_player = owner_player
	explosion_scene.global_position = global_position
	world.add_child(explosion_scene)
	queue_free()
