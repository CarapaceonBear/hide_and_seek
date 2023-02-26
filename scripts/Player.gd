class_name Player
extends CharacterBody3D

@onready var pivot = $Pivot

@export var walk_speed = 3
@export var run_speed = 4
@export var max_speed = 14
@export var run_acceleration = 0.3
var run_accumulation = 0
@onready var accumulation_cap = max_speed - run_speed
@export var fall_acceleration = 4
var terminal_velocity = 100
var fall_speed = 0
@export var walk_dead_zone = 0.2
@export var run_dead_zone = 0.6

var direction = Vector3.ZERO
var stick_direction = Vector2(0,1)
var target_velocity = Vector3.ZERO

@export var jump_impulse = 20
@export var jump_buffer = 0.2
@onready var timer_jump_buffer = $JumpBuffer
@export var coyote_time = 0.2
@onready var timer_coyote_time = $CoyoteTime

@export var roll_duration = 1.2
@onready var timer_roll = $RollDuration
@export var roll_impulse = 20
@export var roll_buffer = 0.2
@onready var timer_roll_buffer = $RollBuffer
@export var dive_speed = 30
@export var dive_rise = 18
@export var dive_limit = 3
var dive_number = 0

@export var crouch_speed = 3
@export var crouch_decelerate = 0.5
@export var slide_duration = 0.8
@onready var timer_slide = $SlideDuration
@export var slide_impulse = 16
@export var slide_decelerate = 0.3
@export var slide_buffer = 0.2
@onready var timer_slide_buffer = $SlideBuffer
@export var drop_duration = 1
@onready var timer_drop = $DropTimer
@export var drop_rise = 10

@onready var anim_player = $AnimationPlayer

@export var camera_path : NodePath
var camera = null

enum States {
	IDLE, #movement ready
	WALK, #movement ready
	RUN, #movement ready
	SKID, #movement ready
	FALL, #movement ready
	ROLL, #movement ready
	DIVE, #movement ready
	CROUCH, #movement ready
	SLIDE, #movement ready
	DROP, #movement ready
	HIGH_JUMP,
	LONG_JUMP,
	SPIN,
	GLIDE,
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
	timer_jump_buffer.wait_time = jump_buffer
	timer_coyote_time.wait_time = coyote_time
	timer_roll.wait_time = roll_duration
	timer_roll_buffer.wait_time = roll_buffer
	timer_slide.wait_time = slide_duration
	timer_slide_buffer.wait_time = slide_buffer
	timer_drop.wait_time = drop_duration


func _physics_process(delta):

	#print(States.keys()[state])
	#print(direction.x, direction.z)
	#print(velocity)
	print(velocity.length())
	
	var cam_transform = camera.get_global_transform()
	
	# fall speed
	if is_on_floor():
		fall_speed = 0
	elif fall_speed < terminal_velocity:
		fall_speed = fall_speed + fall_acceleration
	
	if is_on_floor():
		dive_number = dive_limit

	match state:
		States.IDLE:
			anim_player.play("idle")
			direction = Vector3.ZERO
			if (Input.is_action_pressed("Move_Left") or Input.is_action_pressed("Move_Right") or Input.is_action_pressed("Move_Forward") or Input.is_action_pressed("Move_Backward")):
				stick_direction = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
				if stick_direction.length() > walk_dead_zone:
					state = States.WALK
				elif stick_direction.length() > run_dead_zone:
					state = States.RUN
			if Input.is_action_just_pressed("Jump"):
				jump()
			if Input.is_action_just_pressed("Crouch"):
				crouch()
			velocity = target_velocity
			move_and_slide()
		States.WALK:
			anim_player.play("walk")
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
			
			if Input.is_action_just_pressed("Jump"):
				jump()
			# TEMPORARY - SHOULD WALK INTO LEDGE GRAB
			elif not is_on_floor():
				state = States.FALL
				timer_coyote_time.start()
			if Input.is_action_just_pressed("Crouch"):
				crouch()
			
			velocity = target_velocity
			move_and_slide()
		States.RUN:
			anim_player.play("run")
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

			if is_on_floor() and Input.is_action_just_pressed("Jump"):
				jump()
			elif not is_on_floor():
				state = States.FALL
				timer_coyote_time.start()
			if is_on_floor() and Input.is_action_just_pressed("Roll"):
				roll()
			if is_on_floor() and Input.is_action_just_pressed("Crouch"):
				slide()

			velocity = target_velocity
			move_and_slide()
		States.SKID:
			anim_player.play("skid")
			run_accumulation = 0
			if velocity.length() < 1:
				target_velocity = Vector3.ZERO
				state = States.IDLE
			else:
				target_velocity.x = target_velocity.x - target_velocity.x * 0.1
				target_velocity.z = target_velocity.z - target_velocity.z * 0.1
			
			if is_on_floor() and Input.is_action_just_pressed("Jump"):
				jump()
			# TEMPORARY - SHOULD SKID INTO LEDGE GRAB
			elif not is_on_floor():
				state = States.FALL
				timer_coyote_time.start()
			if Input.is_action_just_pressed("Crouch"):
				crouch()
			
			velocity = target_velocity
			move_and_slide()
		States.FALL:
			var stick_vector = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
			if stick_vector.length() > 0:
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
				
			target_velocity.y = target_velocity.y - (fall_speed * delta)
			velocity = target_velocity
			move_and_slide()
			
			if is_on_floor():
				if timer_jump_buffer.time_left > 0:
					anim_player.stop()
					jump()
				elif timer_roll_buffer.time_left > 0:
					roll()
				elif (Input.is_action_pressed("Move_Left") or Input.is_action_pressed("Move_Right") or Input.is_action_pressed("Move_Forward") or Input.is_action_pressed("Move_Backward")):
					state = States.RUN
				else:
					state = States.SKID
			
			if Input.is_action_just_pressed("Jump"):
				if timer_coyote_time.time_left > 0:
					jump()
				else:
					timer_jump_buffer.start()
			if Input.is_action_pressed("Roll"):
				dive()
			if Input.is_action_pressed("Crouch"):
				drop()
		States.ROLL:
			anim_player.play("roll")
			
			var stick_vector = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
			if stick_vector.length() > 0:
				# slow turn while rolling
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
			
			target_velocity.y = target_velocity.y - (fall_speed * delta)
			velocity = target_velocity
			move_and_slide()
			
			if run_accumulation > accumulation_cap - 2:
				run_accumulation -= 0.2
			
			if Input.is_action_just_pressed("Jump"):
				if is_on_floor():
					run_accumulation = accumulation_cap - 4
					jump()
				else:
					timer_jump_buffer.start()
			if is_on_floor() and timer_jump_buffer.time_left > 0:
				run_accumulation = accumulation_cap - 4
				jump()
			
			# chaining rolls
			if Input.is_action_just_pressed("Roll") and timer_roll.time_left < 0.6:
				roll()
			
			# MIGHT WORK BETTER TRIGGERING A SLIDE
			if is_on_floor() and Input.is_action_just_pressed("Crouch"):
				crouch()
			
			if timer_roll.time_left == 0:
				if not is_on_floor():
					state = States.FALL
				elif (Input.is_action_pressed("Move_Left") or Input.is_action_pressed("Move_Right") or Input.is_action_pressed("Move_Forward") or Input.is_action_pressed("Move_Backward")):
					state = States.RUN
				else:
					state = States.SKID
		States.DIVE:
			anim_player.play("dive")
			target_velocity.x = direction.x * (run_speed + run_accumulation)
			target_velocity.z = direction.z * (run_speed + run_accumulation)
				
			target_velocity.y = target_velocity.y - (fall_speed * delta)
			velocity = target_velocity
			move_and_slide()
			
			run_accumulation -= 0.5
			
			if Input.is_action_just_pressed("Jump"):
				timer_jump_buffer.start()
			if Input.is_action_just_pressed("Crouch"):
				drop()
			
			var stick_vector = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
			if is_on_floor():
				if stick_vector.length() > 0:
					roll()
				else:
					state = States.SKID
		States.CROUCH:
			anim_player.queue("crouching")
			var stick_direction = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
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
			
			# skid a little if moving into a crouch (ie from rolling)
			if target_velocity.length() > 3.5:
				if target_velocity.x > 0 and target_velocity.x > direction.x * crouch_speed:
					target_velocity.x -= crouch_decelerate
				elif target_velocity.x < 0 and target_velocity.x < direction.x * crouch_speed:
					target_velocity.x += crouch_decelerate 
				if target_velocity.z > 0 and target_velocity.z > direction.z * crouch_speed:
					target_velocity.z -= crouch_decelerate
				elif target_velocity.z < 0 and target_velocity.z < direction.z * crouch_speed:
					target_velocity.z += crouch_decelerate
			else:
				target_velocity.x = direction.x * crouch_speed
				target_velocity.z = direction.z * crouch_speed
			
			velocity = target_velocity
			move_and_slide()
			
			if not (Input.is_action_pressed("Move_Left") or Input.is_action_pressed("Move_Right") or Input.is_action_pressed("Move_Forward") or Input.is_action_pressed("Move_Backward")):
				direction = Vector3.ZERO
			
			if not Input.is_action_pressed("Crouch"):
				state = States.IDLE
		States.SLIDE:
			anim_player.play("slide")
			
			var stick_vector = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
			if stick_vector.length() > 0:
				# slow turn while sliding
				stick_direction = stick_direction.lerp(stick_vector, 1.8 * delta )
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
			
			target_velocity.y = target_velocity.y - (fall_speed * delta)
			velocity = target_velocity
			move_and_slide()
			
			run_accumulation -= slide_decelerate
			
			if timer_slide.time_left == 0:
				if not is_on_floor():
					state = States.FALL
				elif Input.is_action_pressed("Crouch"):
					state = States.CROUCH
				elif (Input.is_action_pressed("Move_Left") or Input.is_action_pressed("Move_Right") or Input.is_action_pressed("Move_Forward") or Input.is_action_pressed("Move_Backward")):
					state = States.RUN
				else:
					state = States.SKID
		States.DROP:
			target_velocity.x = 0
			target_velocity.z = 0
			target_velocity.y = target_velocity.y - (fall_speed * delta)
			velocity = target_velocity
			move_and_slide()
			
			var stick_vector = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
			if stick_vector.length() > 0:
				# slow turn while dropping
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
			
			if Input.is_action_just_pressed("Roll"):
				timer_roll_buffer.start()
			
			if timer_drop.time_left < 0.5 and timer_roll_buffer.time_left > 0:
				dive()
			
			if timer_drop.time_left == 0:
				state = States.FALL
			if is_on_floor():
				state = States.IDLE

func jump():
	anim_player.play("jump")
	target_velocity.y = jump_impulse
	timer_coyote_time.stop()
	state = States.FALL


func roll():
	run_accumulation = roll_impulse
	timer_roll.start()
	state = States.ROLL


func dive():
	if dive_number > 0:
		dive_number -= 1
		run_accumulation = dive_speed
		target_velocity.y = dive_rise
		state = States.DIVE


func crouch():
	anim_player.play("crouch")
	state = States.CROUCH


func slide():
	run_accumulation = slide_impulse
	timer_slide.start()
	state = States.SLIDE


func drop():
	anim_player.play("drop")
	fall_speed = 0
	target_velocity.y = drop_rise
	timer_drop.start()
	state = States.DROP
