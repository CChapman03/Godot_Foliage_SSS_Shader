extends Node3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	set_process(true)
	
func _process(delta):
	
	# Update Player Position in shaders
	$Grass.material_override.set_shader_parameter("playerpos", $Player.transform.origin)
	#print($Grass.material_override.get_shader_parameter("playerpos"))
	
	if Input.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().quit()
