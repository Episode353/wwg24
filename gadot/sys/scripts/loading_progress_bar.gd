extends ProgressBar

@onready var progress_bar: ProgressBar = self
@onready var func_godot_map: FuncGodotMap = $"../../NavigationRegion3D/FuncGodotMap"

@onready var timer := Timer.new()
@onready var tween := create_tween()

const DELAY_BEFORE_FADE := 0.5  # Seconds to wait at 100% before fading
const FADE_DURATION := 0.5      # Seconds for fade animation

func _ready():
	await get_tree().process_frame
	self.show()
	if func_godot_map:
		func_godot_map.connect("build_progress", Callable(self, "_on_build_progress"))
	else:
		print("FuncGodotMap not found at expected path!")

	# Setup timer
	timer.one_shot = true
	timer.wait_time = DELAY_BEFORE_FADE
	timer.connect("timeout", Callable(self, "_on_timer_timeout"))
	add_child(timer)

func _on_build_progress(step: String, progress: float) -> void:
	progress_bar.value = clamp(progress * 100.0, progress_bar.min_value, progress_bar.max_value)

	if progress >= 1.0:
		timer.start()

func _on_timer_timeout() -> void:
	# Fade out modulate.a to 0
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.connect("finished", Callable(self, "_on_fade_finished"))

func _on_fade_finished():
	visible = false
	modulate.a = 1.0  # Reset alpha for future use
