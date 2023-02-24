class_name Player
extends CharacterBody3D

@onready var pivot = $Pivot

@export var walk_speed = 3
@export var run_speed = 4
@export var max_speed = 20
@export var run_acceleration = 0.2
var run_accumulation = 0
@onready var accumulation_cap = max_speed - run_speed
@export var fall_acceleration = 75
@export var walk_dead_zone = 0.2
@export var run_dead_zone = 0.6

var direction = Vector3.ZERO
var stick_direction = Vector2(0,-1)
var target_velocity = Vector3.ZERO
@export var jump_impulse = 20

@export var camera_path : NodePath
var camera = null

enum States {
	IDLE, #movement ready
	RUN, #movement ready
	WALK, #movement ready
	FALL, #movement ready
	SKID, #movement ready
	SLIDE,
	SPIN,
	GLIDE,
	CROUCH,
	DROP,
	ROLL,
	DIVE,
	HIGH_JUMP,
	LONG_JUMP,
	ROLL_CLIMB,
	WALL_GRAB,
	WALL_JUMP,
	LEDGE_GRAB,
	SIT
}
@onready var state = States.IDLE


func _ready():
	if camera_path:
		camera = get_node(camera_path)


func _physics_process(delta):

	print(States.keys()[state])
	#print(direction.x, direction.z)
	#print(velocity)
	#print(velocity.length())
	
	var cam_transform = camera.get_global_transform()

	match state:
		States.IDLE:
			direction = Vector3.ZERO
			if (Input.is_action_pressed("Move_Left") or Input.is_action_pressed("Move_Right") or Input.is_action_pressed("Move_Forward") or Input.is_action_pressed("Move_Backward")):
				stick_direction = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
				if stick_direction.length() < walk_dead_zone:
					state = States.WALK
				else:
					state = States.RUN
			if Input.is_action_just_pressed("Jump"):
				target_velocity.y = jump_impulse
			if not is_on_floor():
				state = States.FALL
			velocity = target_velocity
			move_and_slide()
		States.WALK:
			stick_direction = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
			if stick_direction.x < -0.1:
				#print("left")
				direction += -cam_transform.basis[0] * -stick_direction.x
			if stick_direction.x > 0.1:
				#print("right")
				direction += cam_transform.basis[0] * stick_direction.x
			if stick_direction.y < -0.1:
				#print("forward")
				direction += -cam_transform.basis[2] * -stick_direction.y
			if stick_direction.y > 0.1:
				#print("backward")
				direction += cam_transform.basis[2] * stick_direction.y
			if direction != Vector3.ZERO:
				direction = direction.normalized()
				pivot.look_at(position + direction, Vector3.UP)
			target_velocity.x = direction.x * walk_speed
			target_velocity.z = direction.z * walk_speed
			
			if stick_direction.length() < walk_dead_zone:
				state = States.IDLE
			elif stick_direction.length() > run_dead_zone:
				state = States.RUN
			
			velocity = target_velocity
			move_and_slide()
		States.RUN:
			run_accumulation += run_acceleration
			var stick_vector = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
			# turning wider at higher velocity
			stick_direction = stick_direction.lerp(stick_vector, (15 - (velocity.length() / 2)) * delta)
			if stick_direction.x < -0.1:
				#print("left")
				direction += -cam_transform.basis[0] * -stick_direction.x
			if stick_direction.x > 0.1:
				#print("right")
				direction += cam_transform.basis[0] * stick_direction.x
			if stick_direction.y < -0.1:
				#print("forward")
				direction += -cam_transform.basis[2] * -stick_direction.y
			if stick_direction.y > 0.1:
				#print("backward")
				direction += cam_transform.basis[2] * stick_direction.y

			if run_accumulation > accumulation_cap:
				run_accumulation = accumulation_cap

			if direction != Vector3.ZERO:
				direction = direction.normalized()
				pivot.look_at(position + direction, Vector3.UP)

			target_velocity.x = direction.x * (run_speed + run_accumulation)
			target_velocity.z = direction.z * (run_speed + run_accumulation)
			if not (Input.is_action_pressed("Move_Left") or Input.is_action_pressed("Move_Right") or Input.is_action_pressed("Move_Forward") or Input.is_action_pressed("Move_Backward")):
				state = States.SKID

			if not is_on_floor():
				state = States.FALL
			if is_on_floor() and Input.is_action_just_pressed("Jump"):
				target_velocity.y = jump_impulse

			velocity = target_velocity
			move_and_slide()
		States.SKID:
			run_accumulation = 0
			if velocity.length() < 1:
				target_velocity = Vector3.ZERO
				state = States.IDLE
			else:
				target_velocity.x = target_velocity.x - target_velocity.x * 0.1
				target_velocity.z = target_velocity.z - target_velocity.z * 0.1
			
			if not is_on_floor():
				state = States.FALL
			if is_on_floor() and Input.is_action_just_pressed("Jump"):
				target_velocity.y = jump_impulse
			
			velocity = target_velocity
			move_and_slide()
		States.FALL:
			var stick_vector = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
			# slow turn while falling
			stick_direction = stick_direction.lerp(stick_vector, 2 * delta)
			if stick_direction.x < -0.1:
				#print("left")
				direction += -cam_transform.basis[0] * -stick_direction.x
			if stick_direction.x > 0.1:
				#print("right")
				direction += cam_transform.basis[0] * stick_direction.x
			if stick_direction.y < -0.1:
				#print("forward")
				direction += -cam_transform.basis[2] * -stick_direction.y
			if stick_direction.y > 0.1:
				#print("backward")
				direction += cam_transform.basis[2] * stick_direction.y
			if direction != Vector3.ZERO:
				direction = direction.normalized()
				pivot.look_at(position + direction, Vector3.UP)
			target_velocity.x = direction.x * (run_speed + run_accumulation)
			target_velocity.z = direction.z * (run_speed + run_accumulation)
				
			target_velocity.y = target_velocity.y - (fall_acceleration * delta)
			velocity = target_velocity
			move_and_slide()
			
			if is_on_floor():
				if (Input.is_action_pressed("Move_Left") or Input.is_action_pressed("Move_Right") or Input.is_action_pressed("Move_Forward") or Input.is_action_pressed("Move_Backward")):
					state = States.RUN
				else:
					state = States.SKID

