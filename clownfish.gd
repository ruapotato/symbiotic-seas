extends RigidBody3D

@export var SPEED = 10.0
@export var ROTATION_SPEED = 10.0
@export var ZOOM_SPEED = 0.5
@export var MIN_ZOOM = 0.1
@export var MAX_ZOOM = 10.0
@export var TAIL_SWING_SPEED = 2.5
@export var TAIL_SWING_AMPLITUDE = 0.5
@export var TAIL_CENTER_SPEED = 20.0
@export var MOVEMENT_THRESHOLD = 0.1
@export var MOUSE_SENSITIVITY = 0.005
@export var WATER_DRAG_COEFFICIENT = 0.5
@export var ROTATIONAL_DRAG_COEFFICIENT = 0.2  # New export variable for rotational drag
@export var START_LIFE = 100

@onready var spring_arm = $piv/SpringArm3D
@onready var tail_piv = $tail_piv
@onready var piv = $piv
@onready var mesh = $mesh

var life = START_LIFE
var tail_swing_time = 0.0
var current_tail_angle = 0.0
var target_velocity = Vector3.ZERO
var input_dir = Vector3.ZERO

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.add_excluded_object(self)

func _physics_process(delta):
	apply_movement_force(delta)
	keep_camera()
	handle_rotation(delta)
	apply_water_drag(delta)
	animate_tail(delta)

func _integrate_forces(state):
	# Apply buoyancy force
	state.apply_central_force(Vector3.UP * gravity_scale * state.total_gravity.length())

func apply_movement_force(delta):
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (piv.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if input_dir.length() > 0:
		apply_central_force(direction * SPEED)

func handle_rotation(delta):
	if linear_velocity.length() > MOVEMENT_THRESHOLD:
		var look_direction = linear_velocity.normalized()
		var new_transform = global_transform.looking_at(global_position + look_direction, Vector3.UP)
		global_transform = global_transform.interpolate_with(new_transform, delta * ROTATION_SPEED)

func keep_camera():
	piv.global_position = global_position

func apply_water_drag(delta):
	# Linear drag
	var velocity = linear_velocity
	var speed = velocity.length()
	
	if speed > 0:
		var drag_force = -velocity.normalized() * speed * speed * WATER_DRAG_COEFFICIENT * delta
		apply_central_force(drag_force)
	
	if angular_velocity.length() > .01:
		angular_velocity = lerp(angular_velocity, Vector3(0,0,0), delta * 10)
	# Rotational drag
	#var angular_velocity_magnitude = angular_velocity.length()
	#if angular_velocity_magnitude > 0:
	#	var rotational_drag_torque = -angular_velocity.normalized() * angular_velocity_magnitude * angular_velocity_magnitude * ROTATIONAL_DRAG_COEFFICIENT
	#	apply_torque(rotational_drag_torque)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_camera(event.relative)
	
	if event.is_action_pressed("zoom_in"):
		zoom_camera(-ZOOM_SPEED)
	elif event.is_action_pressed("zoom_out"):
		zoom_camera(ZOOM_SPEED)

func rotate_camera(mouse_motion):
	piv.rotate_y(-mouse_motion.x * MOUSE_SENSITIVITY)
	#piv.rotate_x(-mouse_motion.y * MOUSE_SENSITIVITY)
	piv.rotate_object_local(Vector3.RIGHT, -mouse_motion.y * MOUSE_SENSITIVITY)
	#piv.rotation.x = clamp(piv.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func zoom_camera(zoom_direction):
	spring_arm.spring_length = clamp(spring_arm.spring_length + zoom_direction, MIN_ZOOM, MAX_ZOOM)

func animate_tail(delta):
	var speed = linear_velocity.length()
	var is_moving = speed > MOVEMENT_THRESHOLD
	
	if is_moving:
		tail_swing_time += delta * TAIL_SWING_SPEED * speed
		var target_angle = sin(tail_swing_time) * TAIL_SWING_AMPLITUDE
		current_tail_angle = lerp(current_tail_angle, target_angle, delta * TAIL_CENTER_SPEED)
	else:
		tail_swing_time = 0.0
		current_tail_angle = lerp(current_tail_angle, 0.0, delta * TAIL_CENTER_SPEED)
	
	tail_piv.rotation.y = current_tail_angle
	tail_piv.rotation.z = 0
	tail_piv.rotation.x = 0
	$piv/SpringArm3D/Camera3D.rotation = Vector3(0,0,0)
	
	tail_swing_time = fmod(tail_swing_time, TAU)

func set_stagger(stagger_vector):
	apply_central_impulse(stagger_vector)
