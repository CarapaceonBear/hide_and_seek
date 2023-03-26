class_name Player
extends CharacterBody3D

@onready var pivot = $Pivot
@onready var timer_jump_buffer = $Timers/JumpBuffer
@onready var timer_coyote_time = $Timers/CoyoteTime
@onready var timer_roll = $Timers/RollDuration
@onready var timer_roll_buffer = $Timers/RollBuffer
@onready var timer_slide = $Timers/SlideDuration
@onready var timer_slide_buffer = $Timers/SlideBuffer
@onready var timer_drop = $Timers/DropTimer
@onready var timer_high_jump = $Timers/HighJumpTimer
@onready var timer_long_jump = $Timers/LongJumpTimer
@onready var timer_spin = $Timers/SpinTimer
@onready var timer_grab = $Timers/GrabTimer
@onready var timer_grab_delay = $Timers/GrabDelayTimer
@onready var timer_wall_jump = $Timers/WallJumpTimer
@onready var anim_player = $AnimationPlayer
@onready var ray_forward = $Pivot/RayForward
@onready var ray_down = $Pivot/RayDown
@onready var ray_right = $Pivot/RayRight
@onready var ray_left = $Pivot/RayLeft

@export_group("Movement Basics")
@export var walk_speed = 3
@export var run_speed = 4
@export var max_speed = 14
@export var run_acceleration = 0.3
@export var fall_acceleration = 4
@export var walk_dead_zone = 0.2
@export var run_dead_zone = 0.6
@export_group("Jumping")
@export var jump_impulse = 20
@export var jump_buffer = 0.2
@export var coyote_time = 0.2
@export_group("Rolling")
@export var roll_duration = 1.2
@export var roll_impulse = 20
@export var roll_buffer = 0.2
@export var dive_speed = 30
@export var dive_rise = 18
@export var dive_limit = 3
@export_group("Crouching")
@export var crouch_speed = 3
@export var crouch_decelerate = 0.5
@export var slide_duration = 0.4
@export var slide_impulse = 16
@export var slide_decelerate = 0.3
@export var slide_buffer = 0.2
@export var drop_duration = 1
@export var drop_rise = 10
@export_group("Extended Jumps")
@export var high_jump_impulse = 32
@export var high_jump_duration = 1
@export var long_jump_impulse = 28
@export var long_jump_rise = 8
@export var long_jump_duration = 0.4
@export_group("Spinning")
@export var spin_duration = 0.2
@export var spin_rise = 8
@export var spin_limit = 1
@export var glide_speed = 8
@export_group("Wall Jumps")
@export var grab_delay = 0.4
@export var grab_duration = 1.4
@export var wall_jump_impulse = 14
@export var wall_jump_duration = 0.8
@export_group("Extras")
@export var camera_path : NodePath

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
	GLIDE, #movement ready
	ROLL_CLIMB,
	WALL_GRAB, #movement ready
	WALL_JUMP, #close
	LEDGE_GRAB,
	SIT
}
@onready var state = States.IDLE
@onready var accumulation_cap = max_speed - run_speed
var direction = Vector3.ZERO
var stick_direction = Vector2(0,1)
var target_velocity = Vector3.ZERO
var run_accumulation = 0
var terminal_velocity = 100
var fall_speed = 0
var dive_number = 0
var spin_number = 0
var grab_ready = true
var camera = null
var speedometer = Vector2.ZERO

@export var player_id := 1 :
	set(id):
		player_id = id
		$InputSynchronizer.set_multiplayer_authority(id)
@onready var input = $InputSynchronizer


func _ready():
	print("cam path = " + str(camera_path))
	if camera_path:
		camera = get_node(camera_path)
		print("player cam = " + str(camera))
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
	timer_grab.wait_time = grab_duration
	timer_grab_delay.wait_time = grab_delay
	timer_wall_jump.wait_time = wall_jump_duration


func _physics_process(delta):
	#print(States.keys()[state])
	#print(round(direction.x), round(direction.z))
	#print(target_velocity.length())
	#print(direction.length())
	#print(velocity)
	#print(velocity.length())
	#print(fall_speed)
	#print(target_velocity.y)
	print(stick_direction)
	
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
		grab_ready = true

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
			if Input.is_action_just_pressed("Spin"):
				spin()
			velocity = Vector3.ZERO
			move_and_slide()
			if not is_on_floor():
				state = States.FALL
		States.WALK:
			anim_player.play("walk")
			move(delta, cam_transform, 10, walk_speed)
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
		States.RUN:
			anim_player.play("run")
			run_accumulation += run_acceleration
			if run_accumulation > accumulation_cap:
				run_accumulation = accumulation_cap
			move(delta, cam_transform, (15 - (velocity.length() / 2)), (run_speed + run_accumulation))
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
			if run_accumulation > accumulation_cap:
				run_accumulation -= 1
			move(delta, cam_transform, 4, (run_speed + run_accumulation))
			if is_on_floor():
				landing()
			if Input.is_action_just_pressed("Jump"):
				if timer_coyote_time.time_left > 0:
					jump()
				else:
					timer_jump_buffer.start()
			if Input.is_action_just_pressed("Roll") and not ray_forward.is_colliding():
				dive()
			if Input.is_action_just_pressed("Crouch"):
				drop()
			if Input.is_action_just_pressed("Spin"):
				air_spin()
			if grab_ready and timer_grab_delay.time_left == 0 and not ray_down.is_colliding():
				if ray_forward.is_colliding():
					var col = ray_forward.get_collision_normal()
					var temp = false
					# TO BE TIDIED
					if col.x > -0.2 and col.x < 0.2:
						if col.z > 0.6 and direction.z < -0.6:
							temp = true
						elif col.z < -0.6 and direction.z > 0.6:
							temp = true
					elif col.z > -0.2 and col.z < 0.2:
						if col.x > 0.6 and direction.x < -0.6:
							temp = true
						elif col.x < -0.6 and direction.x > 0.6:
							temp = true
					elif col.x > 0 and direction.x < 0:
						if col.z > 0 and direction.z < 0:
							temp = true
						elif col.z < 0 and direction.z > 0:
							temp = true
					elif col.x < 0 and direction.x > 0:
						if col.z < 0 and direction.z > 0:
							temp = true
						elif col.z > 0 and direction.z < 0:
							temp = true
					if temp:
						wall_grab()
				if ray_left.is_colliding() and Input.is_action_just_pressed("Spin"):
					run_accumulation = 0
					fall_speed = 0
					wall_jump(cam_transform, ray_left.get_collision_normal())
				if ray_right.is_colliding() and Input.is_action_just_pressed("Spin"):
					run_accumulation = 0
					fall_speed = 0
					wall_jump(cam_transform, ray_right.get_collision_normal())
		States.ROLL:
			anim_player.play("roll")
			if run_accumulation > accumulation_cap - 2:
				run_accumulation -= 0.2
			move(delta, cam_transform, 2, (run_speed + run_accumulation))
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
			if ray_forward.is_colliding():
				state = States.ROLL_CLIMB
			# chaining rolls
			if is_on_floor() and Input.is_action_just_pressed("Roll") and timer_roll.time_left < 0.6:
				roll()
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
			run_accumulation -= 0.5
			move(delta, cam_transform, 0.8, (run_speed + run_accumulation))
			if Input.is_action_just_pressed("Jump"):
				timer_jump_buffer.start()
			if Input.is_action_just_pressed("Crouch"):
				drop()
			if ray_forward.is_colliding():
				state = States.WALL_GRAB
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
			if not is_on_floor():
				# CHANGE TO LEDGE HANG
				state = States.IDLE
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
			run_accumulation -= slide_decelerate
			move(delta, cam_transform, 1.8, (run_speed + run_accumulation))
			var stick_vector = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
			if Input.is_action_just_pressed("Jump") and stick_vector.length() > 0.6:
				long_jump()
			if ray_forward.is_colliding():
				state = States.IDLE
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
			move(delta, cam_transform, 15, 0)
			if Input.is_action_just_pressed("Roll"):
				timer_roll_buffer.start()
			if timer_drop.time_left > 0.6 and Input.is_action_just_pressed("Spin"):
				air_spin()
			if timer_drop.time_left < 0.5 and timer_roll_buffer.time_left > 0:
				dive()
			if timer_drop.time_left == 0:
				state = States.FALL
			if is_on_floor():
				landing()
		States.HIGH_JUMP:
			move(delta, cam_transform, 3, (run_speed + run_accumulation))
			if Input.is_action_just_pressed("Roll"):
				dive()
			if Input.is_action_just_pressed("Spin"):
				air_spin()
			if is_on_floor():
				landing()
			if timer_high_jump.time_left == 0:
				state = States.FALL
		States.LONG_JUMP:
			fall_speed = long_jump_rise * 2
			move(delta, cam_transform, 0.8, (run_speed + run_accumulation))
			dive_number = 1
			if ray_forward.is_colliding():
				state = States.WALL_GRAB
			if is_on_floor():
				landing()
			if timer_long_jump.time_left == 0:
				state = States.FALL
		States.SPIN:
			target_velocity.y = 0
			fall_speed = 0
			move(delta, cam_transform, 16, (run_speed + run_accumulation))
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
			target_velocity.y = 0
			fall_speed = 0
			move(delta, cam_transform, 16, (run_speed + run_accumulation))
			if timer_spin.time_left == 0:
				if Input.is_action_pressed("Spin"):
					state = States.GLIDE
				else: 
					run_accumulation = 0
					state = States.FALL
		States.GLIDE:
			fall_speed = glide_speed
			move(delta, cam_transform, 4, 10)
			if Input.is_action_just_pressed("Roll") and not ray_forward.is_colliding():
				dive()
			if not Input.is_action_pressed("Spin"):
				state = States.FALL
			if is_on_floor():
				state = States.IDLE
		States.ROLL_CLIMB:
			# temporary
			state = States.IDLE
		States.WALL_GRAB:
			fall_speed = 0
			anim_player.play("idle")
			if Input.is_action_just_pressed("Jump"):
				wall_jump(cam_transform, ray_forward.get_collision_normal())
			if Input.is_action_just_pressed("Crouch") or timer_grab.time_left == 0:
				state = States.FALL
		States.WALL_JUMP:
			# NEED TO SAVE NORMAL, SUBSEQUENT WALL GRABS MUST BE OPPOSITE
			move(delta, cam_transform, 0.8, (run_speed + run_accumulation))
			if is_on_floor():
				run_accumulation = 2
				state = States.RUN
			if grab_ready and timer_grab_delay.time_left == 0 and ray_forward.is_colliding() and not ray_down.is_colliding():
				state = States.WALL_GRAB
			if timer_wall_jump.time_left == 0:
				state = States.FALL


func move(delta, cam_transform, turn_lerp, move_speed):
	var stick_vector = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
	if stick_vector.length() > 0:
		stick_direction = stick_direction.lerp(stick_vector, turn_lerp * delta)
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
	target_velocity.x = direction.x * move_speed
	target_velocity.z = direction.z * move_speed
	if not is_on_floor():
		target_velocity.y = target_velocity.y - (fall_speed * delta)
	velocity = target_velocity
	move_and_slide()


func jump():
	anim_player.play("jump")
	target_velocity.y = jump_impulse
	timer_coyote_time.stop()
	timer_grab_delay.start()
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


func wall_grab():
	run_accumulation = 0
	target_velocity.y = 0
	grab_ready = false
	timer_grab.start()
	state = States.WALL_GRAB


func wall_jump(cam_transform, normal):
	anim_player.play("jump")
	direction = normal
	run_accumulation = wall_jump_impulse
	
	# VERY JANKY - NEEDS FIXING
	if direction.x < -0.1:
		stick_direction.x = -cam_transform.basis[0].x * -direction.x
	if direction.x > 0.1:
		stick_direction.x = cam_transform.basis[0].x * direction.x
	if direction.z < -0.1:
		stick_direction.y = -cam_transform.basis[2].z * -direction.z
	if direction.z > 0.1:
		stick_direction.y = cam_transform.basis[2].z * direction.z
	
	target_velocity.y = jump_impulse
	grab_ready = true
	timer_grab_delay.start()
	timer_wall_jump.start()
	state = States.WALL_JUMP
