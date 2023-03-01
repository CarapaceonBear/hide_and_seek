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
@export var slide_duration = 0.4
@onready var timer_slide = $SlideDuration
@export var slide_impulse = 16
@export var slide_decelerate = 0.3
@export var slide_buffer = 0.2
@onready var timer_slide_buffer = $SlideBuffer
@export var drop_duration = 1
@onready var timer_drop = $DropTimer
@export var drop_rise = 10

@export var high_jump_impulse = 32
@export var high_jump_duration = 1
@onready var timer_high_jump = $HighJumpTimer
@export var long_jump_impulse = 28
@export var long_jump_rise = 8
@export var long_jump_duration = 0.8
@onready var timer_long_jump = $LongJumpTimer

@export var spin_duration = 0.4
@onready var timer_spin = $SpinTimer
@export var spin_rise = 8
@export var spin_limit = 1
var spin_number = 0

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
	HIGH_JUMP, #movement ready
	LONG_JUMP, #movement ready
	SPIN, #movement ready
	AIR_SPIN, #movement ready
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
	timer_high_jump.wait_time = high_jump_duration
	timer_long_jump.wait_time = long_jump_duration
	timer_spin.wait_time = spin_duration

var speedometer = Vector2.ZERO

func _physics_process(delta):

	print(States.keys()[state])
	#print(round(direction.x), round(direction.z))
	#print(target_velocity.length())
	#print(direction.length())
	#print(velocity)
	#print(velocity.length())
	#print(fall_speed)
	#print(target_velocity.y)
	
	speedometer.x = velocity.x
	speedometer.y = velocity.z
	#print(speedometer.length())
	
	var cam_transform = camera.get_global_transform()
	
	# fall speed
	if is_on_floor():
		fall_speed = 0
	elif fall_speed < terminal_velocity:
		fall_speed = fall_speed + fall_acceleration
	
	if is_on_floor():
		dive_number = dive_limit
		spin_number = spin_limit

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
			velocity = Vector3.ZERO
			move_and_slide()
			
			if not is_on_floor():
				state = States.FALL
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
			velocity = target_velocity
			move_and_slide()
			
			if not (Input.is_action_pressed("Move_Left") or Input.is_action_pressed("Move_Right") or Input.is_action_pressed("Move_Forward") or Input.is_action_pressed("Move_Backward")):
				state = States.SKID

			if not is_on_floor():
				timer_coyote_time.start()
				state = States.FALL
			if is_on_floor() and Input.is_action_just_pressed("Jump"):
				jump()
			if is_on_floor() and Input.is_action_just_pressed("Roll"):
				roll()
			if is_on_floor() and Input.is_action_just_pressed("Crouch"):
				slide()
			if is_on_floor() and Input.is_action_just_pressed("Spin"):
				spin()
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
				landing()
			
			if Input.is_action_just_pressed("Jump"):
				if timer_coyote_time.time_left > 0:
					jump()
				else:
					timer_jump_buffer.start()
			if Input.is_action_pressed("Roll"):
				dive()
			if Input.is_action_pressed("Crouch"):
				drop()
			if Input.is_action_pressed("Spin"):
				air_spin()
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
				elif timer_coyote_time.time_left > 0:
					jump()
				else:
					timer_jump_buffer.start()
			if is_on_floor() and timer_jump_buffer.time_left > 0:
				run_accumulation = accumulation_cap - 4
				jump()
			if not is_on_floor():
				timer_coyote_time.start()
			
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
			
			var stick_vector = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
			if stick_vector.length() > 0:
				# medium turn while long-jumping
				stick_direction = stick_direction.lerp(stick_vector, 0.8 * delta)
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
			
			run_accumulation -= 0.5
			
			if Input.is_action_just_pressed("Jump"):
				timer_jump_buffer.start()
			if Input.is_action_just_pressed("Crouch"):
				drop()
			
#			var stick_vector = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
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
			
			if Input.is_action_just_pressed("Jump"):
				high_jump()
			
			if not Input.is_action_pressed("Crouch"):
				# drop accel, otherwise tapping crouch can transition roll>run and keep all momentum
				run_accumulation = 0
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
			
			if Input.is_action_just_pressed("Jump") and stick_vector.length() > 0.6:
				long_jump()
			
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
			run_accumulation = 0
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
				landing()
		States.HIGH_JUMP:
			var stick_vector = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
			if stick_vector.length() > 0:
				# medium turn while jumping
				stick_direction = stick_direction.lerp(stick_vector, 3 * delta)
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
			
			if Input.is_action_just_pressed("Roll"):
				dive()
			if Input.is_action_just_pressed("Spin"):
				air_spin()
			
			if is_on_floor():
				landing()
			
			if timer_high_jump.time_left == 0:
				state = States.FALL
		States.LONG_JUMP:
			var stick_vector = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
			if stick_vector.length() > 0:
				# medium turn while long-jumping
				stick_direction = stick_direction.lerp(stick_vector, 0.8 * delta)
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
				
			target_velocity.y = target_velocity.y - (fall_speed * delta * 0.5)
			velocity = target_velocity
			move_and_slide()
			
			dive_number = 0
			if is_on_floor():
				landing()
			
			if timer_long_jump.time_left == 0:
				state = States.FALL
		States.SPIN:
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
			target_velocity.x = direction.x * (run_speed + run_accumulation)
			target_velocity.z = direction.z * (run_speed + run_accumulation)
			
			target_velocity.y = 0
#			target_velocity.y = target_velocity.y - (fall_speed * delta)
			velocity = target_velocity
			move_and_slide()
			
			if timer_spin.time_left == 0:
				if not is_on_floor():
					spin_number -= 1
					state = States.FALL
				elif Input.is_action_pressed("Crouch"):
					state = States.CROUCH
				elif (Input.is_action_pressed("Move_Left") or Input.is_action_pressed("Move_Right") or Input.is_action_pressed("Move_Forward") or Input.is_action_pressed("Move_Backward")):
					
					state = States.RUN
				else:
					state = States.SKID
		States.AIR_SPIN:
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
			target_velocity.x = direction.x * (run_speed + run_accumulation)
			target_velocity.z = direction.z * (run_speed + run_accumulation)
				
			target_velocity.y = target_velocity.y - (fall_speed * delta * 0.2)
			velocity = target_velocity
			move_and_slide()
			
			if timer_spin.time_left == 0:
				if Input.is_action_pressed("Spin"):
					state = States.GLIDE
				else: 
					state = States.FALL

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
	if direction.length() < 0.1:
		state = States.FALL
		return
	if dive_number > 0:
		dive_number -= 1
		run_accumulation = dive_speed
		target_velocity.y = dive_rise
		state = States.DIVE


func crouch():
	anim_player.play("crouch")
	target_velocity.y = 0
	state = States.CROUCH


func slide():
	run_accumulation = slide_impulse
	target_velocity.y = 0
	timer_slide.start()
	state = States.SLIDE


func drop():
	anim_player.play("drop")
	fall_speed = 0
	target_velocity.y = drop_rise
	timer_drop.start()
	state = States.DROP


func high_jump():
	anim_player.play("flip")
	timer_high_jump.start()
	run_accumulation = 0
	target_velocity.x = 0
	target_velocity.z = 0
	target_velocity.y = high_jump_impulse
	state = States.HIGH_JUMP


func long_jump():
	anim_player.play("flip")
	timer_long_jump.start()
	run_accumulation = long_jump_impulse
	target_velocity.y = long_jump_rise
	state = States.LONG_JUMP


func landing():
	target_velocity.y = 0
	if timer_jump_buffer.time_left > 0:
		anim_player.stop()
		jump()
	elif timer_roll_buffer.time_left > 0:
		roll()
	elif Input.is_action_pressed("Crouch"):
		crouch()
	elif (Input.is_action_pressed("Move_Left") or Input.is_action_pressed("Move_Right") or Input.is_action_pressed("Move_Forward") or Input.is_action_pressed("Move_Backward")):
		state = States.RUN
	else:
		state = States.SKID


func spin():
	anim_player.play("spin")
	timer_spin.start()
	state = States.SPIN


func air_spin():
	if spin_number > 0:
		spin_number -= 1
		anim_player.play("spin")
		timer_spin.start()
		run_accumulation = 2
		target_velocity.y = spin_rise
		state = States.AIR_SPIN
