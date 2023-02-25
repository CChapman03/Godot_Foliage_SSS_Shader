extends ColorRect

func _ready():
	pass # Replace with function body.


func _process(delta):
	$HFlowContainer/HBoxContainer/FPS_Counter.text = "FPS: " + str(Engine.get_frames_per_second())
