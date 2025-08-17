extends Node3D

@onready var flame = $Flame
@onready var smoke = $Smoke
@onready var sparks = $Sparks


func enable():
	flame.emitting = true
	smoke.emitting = true
	sparks.emitting = true
	
func disable():
	flame.emitting = false
	smoke.emitting = false
	sparks.emitting = false
