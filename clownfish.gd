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
@export var ROTATIONAL_DRAG_COEFFICIENT = 0.2
@export var START_LIFE = 100
@export var RESOURCE_COLLECTION_RANGE = 2.0
@export var AUTO_SWIM_RANGE = 5.0
@export var AUTO_SWIM_SPEED = 5.0

@onready var spring_arm = $piv/SpringArm3D
@onready var tail_piv = $tail_piv
@onready var piv = $piv
@onready var mesh = $mesh

var life = START_LIFE
var tail_swing_time = 0.0
var current_tail_angle = 0.0
var target_velocity = Vector3.ZERO
var input_dir = Vector3.ZERO
var is_protected = false
var collected_resources = {"plankton": 0, "algae": 0, "minerals": 0}
var anemone = null

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.add_excluded_object(self)
	add_to_group("clownfish")
	#print("Clownfish initialized")

func _physics_process(delta):
	var force = get_movement_force(delta)
	apply_central_force(force)
	
	keep_camera()
	handle_rotation(delta)
	apply_water_drag(delta)
	animate_tail(delta)
	collect_resources()

	#print("Velocity: ", linear_velocity, " Force: ", force)

func _integrate_forces(state):
	state.apply_central_force(Vector3.UP * gravity_scale * state.total_gravity.length())

func get_movement_force(delta):
	input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (piv.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	#print(anemone)
	#if anemone:
	#	print(global_position.distance_to(anemone.global_position))

	if input_dir.length() > 0:
		#print("Player input detected")
		return direction * SPEED
	elif anemone and global_position.distance_to(anemone.global_position) <= AUTO_SWIM_RANGE:
		#print("Auto-swimming to anemone")
		return auto_swim_to_anemone() * AUTO_SWIM_SPEED
	else:
		#print("No movement")
		return Vector3.ZERO

func auto_swim_to_anemone():
	if anemone:
		var direction_to_anemone = ((anemone.global_position + Vector3(0,.9,0)) - global_position).normalized()
		#print("Direction to anemone: ", direction_to_anemone)
		return direction_to_anemone
	else:
		#print("No anemone set for auto-swim")
		return Vector3.ZERO

func handle_rotation(delta):
	if linear_velocity.length() > MOVEMENT_THRESHOLD:
		var look_direction = linear_velocity.normalized()
		var new_transform = global_transform.looking_at(global_position + look_direction, Vector3.UP)
		global_transform = global_transform.interpolate_with(new_transform, delta * ROTATION_SPEED)

func keep_camera():
	piv.global_position = global_position

func apply_water_drag(delta):
	var velocity = linear_velocity
	var speed = velocity.length()
	
	if speed > 0:
		var drag_force = -velocity.normalized() * speed * speed * WATER_DRAG_COEFFICIENT
		apply_central_force(drag_force)
		#print("Applied drag force: ", drag_force)
	
	if angular_velocity.length() > 0.01:
		angular_velocity = angular_velocity.lerp(Vector3.ZERO, delta * 10)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_camera(event.relative)
	
	if event.is_action_pressed("zoom_in"):
		zoom_camera(-ZOOM_SPEED)
	elif event.is_action_pressed("zoom_out"):
		zoom_camera(ZOOM_SPEED)
	
	if event.is_action_pressed("open_menu") and is_protected:
		open_menu()

func rotate_camera(mouse_motion):
	piv.rotate_y(-mouse_motion.x * MOUSE_SENSITIVITY)
	piv.rotate_object_local(Vector3.RIGHT, -mouse_motion.y * MOUSE_SENSITIVITY)

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
	$piv/SpringArm3D/Camera3D.rotation = Vector3.ZERO
	
	tail_swing_time = fmod(tail_swing_time, TAU)

func set_stagger(stagger_vector):
	apply_central_impulse(stagger_vector)
	#print("Stagger applied: ", stagger_vector)

func set_protected(value):
	is_protected = value
	if value:
		deposit_resources() 
	#print("Protected status: ", is_protected)

func take_damage(amount):
	if not is_protected:
		life -= amount
		#print("Damage taken: ", amount, " Current life: ", life)
		if life <= 0:
			pass
			#print("Clownfish died!")
			# Implement death or respawn logic

func collect_resources():
	var resources_in_range = get_tree().get_nodes_in_group("resources")
	for resource in resources_in_range:
		if global_position.distance_to(resource.global_position) <= RESOURCE_COLLECTION_RANGE:
			var collected = resource.collect()
			collected_resources[collected.type] += collected.amount
			#print("Collected resource: ", collected.type, " Amount: ", collected.amount)

func deposit_resources():
	if anemone:
		for resource_type in collected_resources:
			anemone.add_resources(resource_type, collected_resources[resource_type])
			#print("Deposited ", collected_resources[resource_type], " ", resource_type, " to anemone")
			collected_resources[resource_type] = 0

func open_menu():
	if anemone:
		pass
		#print("Opening Anemone menu")
		# Implement your UI logic here
func heal(this_much):
	life += this_much
	if life > START_LIFE:
		life = START_LIFE
	#print("HEAL Set life to: " + str(life))

func set_anemone(new_anemone):
	anemone = new_anemone
	#print("New anemone set: ", anemone)

func upgrade_anemone(upgrade_type):
	if anemone:
		var success = anemone.upgrade(upgrade_type)
		if success:
			pass
			#print("Anemone upgraded: ", upgrade_type)
		else:
			pass
			#print("Upgrade failed: ", upgrade_type)
