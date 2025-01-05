extends RigidBody3D
const EXPLOSION_PRELOAD = preload("res://models/grenade/grenade_explosion.tscn")
@onready var world = get_tree().get_root().get_node("World")
@onready var area = $grenade/Node/body/Area3D
@onready var omni_light_3d = $OmniLight3D

var owner_player
var grenade_timer = 0.0
var light_blink_timer = 0.0

# Total time before the grenade explodes
const EXPLOSION_TIME = 4.0

func _ready():
	self.angular_velocity.z = 40

func _physics_process(delta):
	# Gradually reduce angular velocity
	if self.angular_velocity.z > 0:
		self.angular_velocity.z -= 0.5

	# Increment grenade timer
	grenade_timer += delta

	# Calculate remaining time percentage
	var time_remaining = max(EXPLOSION_TIME - grenade_timer, 0)
	var f_complete = time_remaining / EXPLOSION_TIME

	# Increase blinking frequency by adjusting the formula
	var freq = max(0.05 + 0.8 * pow(f_complete, 2), 0.05)  # Exponential decrease for faster blinking

	# Update light blinking
	light_blink_timer += delta
	if light_blink_timer >= freq:
		omni_light_3d.light_energy = 2.0 if omni_light_3d.light_energy == 0.0 else 0.0
		light_blink_timer = 0.0

	# Check for explosion
	if grenade_timer > EXPLOSION_TIME:
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
