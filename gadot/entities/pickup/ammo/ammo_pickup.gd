extends Area3D

@export var ammo_amount: int = 30  # Ammo amount is now editable in the Godot Editor
@export var ammo_respawn_delay: float = 5.0  # Respawn delay is also editable

@onready var ammo_root = $".."
@onready var timer = $"../Timer"
@onready var csg_box_3d = $"../CSGBox3D"

func _process(delta):
	csg_box_3d.rotation.y += 1 * delta

func _ready():
	# Add the timer as a child of the node
	ammo_root.add_child(timer)
	timer.one_shot = true
	timer.connect("timeout", Callable(self, "_on_timer_timeout"))

func _on_body_entered(body):
	if not ammo_root.visible:
		return
	if body.has_method("is_ammo_full") and body.is_ammo_full():
		print("Ammo is already full for ", body.name)
		return

	print("Ammo Small Interacted with ", body)
	body.rpc("receive_ammo", ammo_amount)

	# Hide the ammo locally and notify all peers
	_hide_ammo()
	rpc("hide_ammo_global")

func _on_timer_timeout():
	# Respawn ammo locally and notify all peers
	_show_ammo()
	rpc("show_ammo_global")

# Local hide function
func _hide_ammo():
	ammo_root.visible = false
	timer.start(ammo_respawn_delay)

# Local show function
func _show_ammo():
	ammo_root.visible = true

# RPC to hide ammo globally
@rpc("any_peer")
func hide_ammo_global():
	_hide_ammo()

# RPC to show ammo globally
@rpc("any_peer")
func show_ammo_global():
	_show_ammo()
