extends Area3D

@export var health_amount: int = 25
@export var health_respawn_delay: float = 5.0
@onready var audio_stream_player_3d = $"../../AudioStreamPlayer3D"

@onready var health_root = $".."          # Parent or the node you want to hide/show
@onready var timer = $"../../Timer"

var has_been_picked_up = false

func _ready():
	# Ensure the Area can detect bodies
	monitoring = true
	monitorable = true

	# Make sure the Timer is a child, connect signal
	health_root.add_child(timer)
	timer.one_shot = true
	timer.connect("timeout", Callable(self, "_on_timer_timeout"))

func _physics_process(delta: float) -> void:
	# Only check if visible and not picked up yet
	if health_root.visible and not has_been_picked_up:
		for body in get_overlapping_bodies():
			# Is this a player who needs health?
			if body.is_in_group("players") and body.health < body.max_health:
				# Give health via RPC
				body.rpc("receive_health", health_amount)

				# Hide locally and sync with the network
				_hide_health()
				rpc("hide_health_global")

				has_been_picked_up = true
				break  # Stop checking more bodies this frame

func _hide_health():
	health_root.visible = false
	timer.start(health_respawn_delay)
	audio_stream_player_3d.play()
	# Do not reset has_been_picked_up here—wait until next show

func _show_health():
	health_root.visible = true
	has_been_picked_up = false

func _on_timer_timeout():
	# Timer is done—respawn locally and notify peers
	_show_health()
	rpc("show_health_global")

#
# RPC methods to sync hide/show across all peers
#
@rpc("any_peer")
func hide_health_global():
	_hide_health()

@rpc("any_peer")
func show_health_global():
	_show_health()
