extends CharacterBody3D

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
@export var STAGGER_RECOVERY_SPEED = 5.0  # New export variable for stagger recovery
@export var START_LIFE = 100

@onready var spring_arm = $piv/SpringArm3D
@onready var tail_piv = $mesh/tail_piv
@onready var piv = $piv

var life = START_LIFE
var tail_swing_time = 0.0
var current_tail_angle = 0.0
var target_velocity = Vector3(0,0,0)
var stagger = Vector3(0,0,0)

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	$piv/SpringArm3D.add_excluded_object(self)

func _physics_process(delta):
	handle_stagger(delta)
	
	if stagger.length() > 0:
		# If staggered, don't process normal movement
		return
	
	target_velocity = Vector3(0,0,0)
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (piv.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed = SPEED

	if direction:
		target_velocity.x = direction.x * speed
		target_velocity.z = direction.z * speed
		target_velocity.y = direction.y * speed
	else:
		target_velocity.x = lerp(target_velocity.x, 0.0, delta * 5)
		target_velocity.z = lerp(target_velocity.z, 0.0, delta * 5)
		target_velocity.y = lerp(target_velocity.y, 0.0, delta * 5)
	
	velocity = velocity.lerp(target_velocity, delta * 5.0)
	
	move_and_slide()
	
	if velocity.length() > MOVEMENT_THRESHOLD:
		var look_direction = velocity.normalized()
		var new_transform = transform.looking_at(transform.origin + look_direction, Vector3.UP)
		$mesh.transform = $mesh.transform.interpolate_with(new_transform, delta * ROTATION_SPEED)
		$mesh.global_position = global_position
	
	animate_tail(delta)

func handle_stagger(delta):
	if stagger.length() > 0:
		# Apply the stagger push
		velocity = stagger
		move_and_slide()
		
		# Gradually reduce the stagger effect
		stagger = stagger.lerp(Vector3.ZERO, delta * STAGGER_RECOVERY_SPEED)
		#print(stagger)
		
		# If stagger is very small, reset it to zero
		if stagger.length() < 0.1:
			stagger = Vector3.ZERO

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_camera(event.relative)
	
	if event.is_action_pressed("zoom_in"):
		zoom_camera(-ZOOM_SPEED)
	elif event.is_action_pressed("zoom_out"):
		zoom_camera(ZOOM_SPEED)

func rotate_camera(mouse_motion):
	piv.rotate_y(-mouse_motion.x * MOUSE_SENSITIVITY)
	piv.rotate_object_local(Vector3.RIGHT, -mouse_motion.y * MOUSE_SENSITIVITY)
	piv.rotation.x = clamp(piv.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func zoom_camera(zoom_direction):
	spring_arm.spring_length = clamp(spring_arm.spring_length + zoom_direction, MIN_ZOOM, MAX_ZOOM)

func animate_tail(delta):
	var speed = velocity.length()
	var is_moving = speed > MOVEMENT_THRESHOLD
	
	if is_moving:
		tail_swing_time += delta * TAIL_SWING_SPEED * speed
		var target_angle = sin(tail_swing_time) * TAIL_SWING_AMPLITUDE
		current_tail_angle = lerp(current_tail_angle, target_angle, delta * TAIL_CENTER_SPEED)
	else:
		tail_swing_time = 0.0
		current_tail_angle = lerp(current_tail_angle, 0.0, delta * TAIL_CENTER_SPEED)
	
	tail_piv.rotation.y = current_tail_angle
	
	tail_swing_time = fmod(tail_swing_time, TAU)
