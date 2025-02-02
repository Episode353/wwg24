extends Area3D

@export var mana_amount: int = 25
@export var mana_respawn_delay: float = 5.0
@onready var audio_stream_player_3d = $"../../AudioStreamPlayer3D"

@onready var mana_root = $".."
@onready var timer = $"../../Timer"
@onready var omni_light_3d = $"../../OmniLight3D"

var has_been_picked_up = false

func _ready():
	monitoring = true
	monitorable = true

	# Timer setup
	mana_root.add_child(timer)
	timer.one_shot = true
	timer.connect("timeout", Callable(self, "_on_timer_timeout"))

func _physics_process(delta: float) -> void:
	# Only check if visible and not picked up yet
	if mana_root.visible and not has_been_picked_up:
		for body in get_overlapping_bodies():
			# Is this a player who needs mana?
			if body.is_in_group("players") and body.mana < body.max_mana:
				# Give mana via RPC
				body.rpc("receive_mana", mana_amount)

				# Hide locally and sync with the network
				_hide_mana()
				rpc("hide_mana_global")

				has_been_picked_up = true
				break

func _hide_mana():
	mana_root.visible = false
	omni_light_3d.visible = false
	timer.start(mana_respawn_delay)
	audio_stream_player_3d.play()

func _show_mana():
	mana_root.visible = true
	omni_light_3d.visible = true
	has_been_picked_up = false

func _on_timer_timeout():
	_show_mana()
	rpc("show_mana_global")

#
# RPC methods to sync hide/show across all peers
#
@rpc("any_peer")
func hide_mana_global():
	_hide_mana()

@rpc("any_peer")
func show_mana_global():
	_show_mana()
