extends Node3D
# Exported variable uses the enum (this will show a dropdown)
@export var weapon: Weapons

# Create an array that maps the enum values to the corresponding string names.
const WeaponNames = ["ak47", "knife", "rocket_launcher", "shotgun", "hegrenade", "flamespell", "salsa", "keyboard", "random"]

func _get_weapon_name(weapon_value: int) -> String:
	return WeaponNames[weapon_value]


@export var ammo: int = 30
@export var respawn_delay: float = 5.0
@onready var weapon_root = $"."
@onready var weapon_model = $weapon_model
@onready var timer = $Timer




func _process(delta):
	weapon_model.rotation.y += 1 * delta

func _ready():
	# Add the timer as a child of the node
	weapon_model.add_child(timer)
	timer.one_shot = true
	timer.connect("timeout", Callable(self, "_on_timer_timeout"))

func _on_timer_timeout():
	# Respawn ammo locally and notify all peers
	_show_weapon()
	rpc("show_ammo_global")

# Local hide function
func _hide_weapon():
	weapon_root.visible = false
	timer.start(respawn_delay)

# Local show function
func _show_weapon():
	weapon_root.visible = true

# RPC to hide ammo globally
@rpc("any_peer")
func hide_weapon_global():
	_hide_weapon()

# RPC to show ammo globally
@rpc("any_peer")
func show_weapon_global():
	_show_weapon()


# Define your enum as before
enum Weapons {
	ak47,
	knife,
	rocket_launcher,
	shotgun,
	hegrenade,
	flamespell,
	salsa,
	keyboard,
	random
}



func _on_area_3d_body_entered(body):
	if !is_multiplayer_authority(): return
	if not weapon_root.visible:
		return
	
	# Convert the enum (int) to its string representation.
	var weapon_name = _get_weapon_name(weapon)
	
	# Now pass the string to does_have_weapon
	if body.has_method("receive_weapon") and body.does_have_weapon(weapon_name):
		print("Player ", body, " already has ", weapon_name)
		return

	print("Giving ", weapon_name, " To ", body)
	body.rpc("receive_weapon", weapon_name)
	
	# Hide the weapon locally and notify all peers
	_hide_weapon()
	rpc("hide_ammo_global")
