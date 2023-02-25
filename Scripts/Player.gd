extends CharacterBody3D

var camera_angle = 0
var mouse_sensitivity = 0.3

var v = Vector3()
var direction = Vector3()

# fly vars
const FLY_SPEED = 40
const FLY_ACCEL = 4

# walk vars
var gravity = -9.8 * 3
const MAX_SPEED = 20
const MAX_RUNNING_SPEED = 30
const ACCEL = 2
const DECCEL = 6

# jump vars
var jump_height = 10

var pos

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _physics_process(delta):
	walk(delta)

func _input(event):
	if event is InputEventMouseMotion:
		$Head.rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		
		var change = -event.relative.y * mouse_sensitivity
		if change + camera_angle < 90 and change + camera_angle > -90:
			$Head/Camera.rotate_x(deg_to_rad(change))
			camera_angle += change
			
func walk(delta):
	
	# reset the direction of the player
	direction = Vector3()
	
	# get the rotation of the camera
	var aim = $Head/Camera.get_camera_transform().basis
	
	# check input and change direction
	if (Input.is_action_pressed("move_forward")):
		direction -= aim.z
	if (Input.is_action_pressed("move_backward")):
		direction += aim.z
	if (Input.is_action_pressed("move_left")):
		direction -= aim.x
	if (Input.is_action_pressed("move_right")):
		direction += aim.x
		
	direction = direction.normalized()
	
	# apply gravity
	velocity.y += gravity * delta
	
	var temp_vel = velocity
	temp_vel.y = 0
	
	var speed
	if (Input.is_action_pressed("move_run")):
		speed = MAX_RUNNING_SPEED
	else:
		speed = MAX_SPEED
	
	# set max player speed
	var target = direction * speed
	
	var accelaration
	if direction.dot(temp_vel) > 0:
		accelaration = ACCEL
	else:
		accelaration = DECCEL
	
	# gradually increase velocity
	temp_vel = temp_vel.lerp(target, accelaration * delta)
	
	velocity.x = temp_vel.x
	velocity.z = temp_vel.z
	
	# move
	v = move_and_slide()
	
	if(Input.is_action_just_pressed("jump")):
		if velocity.y < jump_height:
			velocity.y = jump_height
		else:
			velocity.y = 0

func fly(delta):
	# reset the direction of the player
	direction = Vector3()
	
	# get the rotation of the camera
	var aim = $Head/Camera.get_camera_transform().basis
	
	# check input and change direction
	if (Input.is_action_pressed("move_forward")):
		direction -= aim.z
	if (Input.is_action_pressed("move_backward")):
		direction += aim.z
	if (Input.is_action_pressed("move_left")):
		direction -= aim.x
	if (Input.is_action_pressed("move_right")):
		direction += aim.x
		
	direction = direction.normalized()
	
	# set max player speed
	var target = direction * FLY_SPEED
	
	# gradually increase velocity
	velocity = v.lerp(target, FLY_ACCEL * delta)
	
	# move
	move_and_slide()
