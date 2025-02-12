extends Node3D

# Define the weapons enum.
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

# Exported variable that shows a dropdown in the editor.
@export var weapon: Weapons

# An array that maps each enum value to its string name.
const WeaponNames = ["ak47", "knife", "rocket_launcher", "shotgun", "hegrenade", "flamespell", "salsa", "keyboard", "random"]

# How long before the weapon reappears.
@export var respawn_delay: float = 5.0

# Onready variables.
# (weapon_model is a child node that you rotate for a visual effect.)
@onready var weapon_model = $weapon_model
@onready var timer = $Timer

# Helper function to return the weapon’s string name.
func _get_weapon_name(weapon_value: int) -> String:
	return WeaponNames[weapon_value]

func _process(delta: float) -> void:
	# Rotate the weapon model for a nice effect.
	weapon_model.rotation.y += 1.0 * delta

func _ready() -> void:
	# Only the server (network authority) should handle collision events.
	if is_multiplayer_authority():
		# (Assuming you have an Area3D node named "Area3D" as a child.)
		$Area3D.connect("body_entered", Callable(self, "_on_area_3d_body_entered"))
		
	# Set up the timer.
	timer.one_shot = true
	timer.connect("timeout", Callable(self, "_on_timer_timeout"))

func _on_timer_timeout() -> void:
	# When the timer times out, show (respawn) the weapon.
	_show_weapon()
	# Only the server should tell all peers to show the weapon.
	if is_multiplayer_authority():
		rpc("show_weapon_global")

# Local function to hide the weapon.
func _hide_weapon() -> void:
	# Hide the entire node (the pickup).
	visible = false
	# Start the respawn timer.
	timer.start(respawn_delay)

# Local function to show the weapon.
func _show_weapon() -> void:
	visible = true

# RPC function that all peers will run to hide the weapon.
@rpc("any_peer")
func hide_weapon_global() -> void:
	_hide_weapon()

# RPC function that all peers will run to show the weapon.
@rpc("any_peer")
func show_weapon_global() -> void:
	_show_weapon()

# Called when a body enters the Area3D.
func _on_area_3d_body_entered(body: Node) -> void:
	# Only let the server (network authority) run the pickup logic.
	if not is_multiplayer_authority():
		return
	# If the weapon is already hidden, do nothing.
	if not visible:
		return
	
	# Get the weapon name from the enum.
	var weapon_name = _get_weapon_name(weapon)
	
	# Check if the body (player) already has the weapon.
	if body.has_method("receive_weapon") and body.does_have_weapon(weapon_name):
		print("Player ", body, " already has ", weapon_name)
		return

	print("Giving ", weapon_name, " to ", body)
	# Tell the player they received the weapon.
	# (This RPC is sent from the server to the specific client.)
	body.rpc("receive_weapon", weapon_name)
	
	# Hide the weapon on the server and then notify all peers.
	_hide_weapon()
	rpc("hide_weapon_global")
