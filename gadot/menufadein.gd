extends ColorRect

@onready var menufadein = $"."
@onready var func_godot_map: FuncGodotMap = $"../../NavigationRegion3D/FuncGodotMap"

var inital_delay := 3  # Frame delay after map loads
var fadeSpeed: float = 2.0  # Fade-out speed
var start_fade := false

func _ready() -> void:
	self.show()
	
	# Connect to the build_complete signal
	if func_godot_map:
		func_godot_map.connect("build_complete", Callable(self, "_on_map_built"), CONNECT_ONE_SHOT)
	else:
		push_error("FuncGodotMap not found!")

func _on_map_built():
	# Start counting frames before fade
	start_fade = true
	$"../HUD/Crosshair Shader".show()

func _process(delta: float) -> void:
	if start_fade:
		if inital_delay > 0:
			inital_delay -= 1
			return  # wait for delay

		# Start fading once delay is over
		if menufadein.color.a > 0:
			var new_color = menufadein.color
			new_color.a = max(new_color.a - fadeSpeed * delta, 0)
			menufadein.color = new_color
			
