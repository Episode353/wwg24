extends CollisionShape3D

var flame_timer = 0.0
const FLAME_TIMER_MAX = 5.0
var has_set_on_fire_method = false
var was_on_fire = false  # Track the previous on-fire state
@onready var player = $"../.."

# Called when the node enters the scene tree for the first time.
func _ready():
	# Check if player has the set_on_fire method and store the result
	has_set_on_fire_method = player.has_method("set_on_fire")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if flame_timer > 0:
		flame_timer -= delta
		if flame_timer < 0:
			flame_timer = 0
		
		# Update player script's is_on_fire variable only if method exists
		if has_set_on_fire_method and not was_on_fire:
			player.set_on_fire(true)
			was_on_fire = true
		print(flame_timer)
	else:
		# Set is_on_fire to false if timer is zero and only if it was previously true
		if has_set_on_fire_method and was_on_fire:
			player.set_on_fire(false)
			was_on_fire = false

func _on_area_3d_body_entered(body):
	print("Body Entered Collision Script", body)
	if body.is_in_group("flammable"):
		print("Is In Group Flammable", body)
		flame_timer = FLAME_TIMER_MAX
		print(flame_timer)
