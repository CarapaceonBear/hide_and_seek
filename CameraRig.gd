extends Marker3D

@export var lerp_speed = 3.0
@export var target_path : NodePath

@onready var cam_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
@export var cam_lerp = 7.0
@export var rotation_speed = 2
@export var tilt_speed = 1

var target = null

func _ready():
	if target_path:
		target = get_node(target_path)

func _process(delta):
	if !target:
		return
	
	position = position.lerp(target.position, cam_lerp * delta)
	
	#global_transform = global_transform.interpolate_with(temp, cam_lerp * delta)
	
	var rotation_y = Vector3.ZERO
	var rotation_x = Vector3.ZERO
	
	if Input.is_action_pressed("Look_Left"):
		rotation_y.y += 1
	if Input.is_action_pressed("Look_Right"):
		rotation_y.y -= 1
	
	if Input.is_action_pressed("Look_Up"):
		rotation_x.x += 1
	if Input.is_action_pressed("Look_Down"):
		rotation_x.x -= 1
	
	if rotation_y != Vector3.ZERO:
		rotation_y = rotation_y.normalized()
	if rotation_x != Vector3.ZERO:
		rotation_x = rotation_x.normalized()
	
	transform.basis = transform.basis.rotated(rotation_y, rotation_speed * delta) 

#	HOW THE ACTUAL FUCK DO I CLAMP THIS
#	if rotation_x.x < -20:
#		rotation_x.x = -20
#	if rotation_x.x > 30:
#		rotation_x.x = 30
	cam_pivot.rotate(rotation_x, tilt_speed * delta)
	
	transform = transform.orthonormalized()
	cam_pivot.transform = cam_pivot.transform.orthonormalized()
	
	#rotate(rotation_direction, rotation_speed * delta)
	




