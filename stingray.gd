extends Node3D

@export var BODY_WIDTH = 2.0
@export var BODY_LENGTH = 1.5
@export var BODY_HEIGHT = 0.2
@export var TAIL_LENGTH = 1.0
@export var SPEED = 2.0
@export var TURN_SPEED = 1.0
@export var FLAP_SPEED = 2.0
@export var FLAP_AMPLITUDE = 0.2
@export var STING_DISTANCE = 1.5
@export var STING_FORCE = 10.0
@export var STING_COOLDOWN = 4.0
@export var RETREAT_SPEED = 3.0
@export var RETREAT_DURATION = 2.0
@export var DAMAGE = 20
@export var TRIGGER_RANGE = 10.0
@export var ROTATION_SMOOTHNESS = 0.1
@export var MOVEMENT_DAMPING = 0.9

var player
var target
var can_sting = true
var retreat_timer = 0.0
var time_passed = 0.0
var states = ["GLIDING", "STINGING", "RETREATING"]
var current_state = 0  # 0 for GLIDING
var is_stinging = false
var velocity = Vector3.ZERO
var target_direction = Vector3.ZERO

# Global variables for body parts
var body
var left_wing
var right_wing
var tail
var stinger
var sting_zone

func _ready():
	player = get_player()
	generate_body()

func get_player():
	var root = get_tree().root
	return root.find_child("Clownfish", true, false)

func generate_body():
	# Main body
	body = CSGBox3D.new()
	body.size = Vector3(BODY_WIDTH, BODY_HEIGHT, BODY_LENGTH)
	body.material = create_material(Color(0.5, 0.5, 0.5))
	add_child(body)

	# Left wing
	left_wing = CSGBox3D.new()
	left_wing.size = Vector3(BODY_WIDTH / 2, BODY_HEIGHT / 2, BODY_LENGTH)
	left_wing.transform.origin = Vector3(-BODY_WIDTH / 2, 0, 0)
	left_wing.material = create_material(Color(0.6, 0.6, 0.6))
	add_child(left_wing)

	# Right wing
	right_wing = CSGBox3D.new()
	right_wing.size = Vector3(BODY_WIDTH / 2, BODY_HEIGHT / 2, BODY_LENGTH)
	right_wing.transform.origin = Vector3(BODY_WIDTH / 2, 0, 0)
	right_wing.material = create_material(Color(0.6, 0.6, 0.6))
	add_child(right_wing)

	# Tail
	tail = CSGCylinder3D.new()
	tail.radius = BODY_HEIGHT / 4
	tail.height = TAIL_LENGTH
	tail.transform.origin = Vector3(0, 0, BODY_LENGTH / 2 + TAIL_LENGTH / 2)
	tail.rotate_x(PI / 2)
	tail.material = create_material(Color(0.4, 0.4, 0.4))
	add_child(tail)

	# Stinger
	stinger = CSGCylinder3D.new()
	stinger.radius = BODY_HEIGHT / 8
	stinger.height = BODY_HEIGHT
	stinger.transform.origin = Vector3(0, 0, BODY_LENGTH / 2 + TAIL_LENGTH)
	stinger.material = create_material(Color(0.3, 0.3, 0.3))
	add_child(stinger)

	# Add collision shape
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(BODY_WIDTH, BODY_HEIGHT, BODY_LENGTH)
	collision_shape.shape = shape
	add_child(collision_shape)

	# Add sting zone
	sting_zone = Area3D.new()
	var sting_shape = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = BODY_HEIGHT / 4
	capsule_shape.height = BODY_HEIGHT
	sting_shape.shape = capsule_shape
	sting_shape.transform.origin = Vector3(0, 0, BODY_LENGTH / 2 + TAIL_LENGTH)
	sting_shape.rotate_x(PI / 2)
	sting_zone.add_child(sting_shape)
	add_child(sting_zone)

	# Connect the sting zone signal
	sting_zone.connect("body_entered", Callable(self, "_on_sting_zone_body_entered"))

func create_material(color):
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	return material

func _physics_process(delta):
	time_passed += delta
	
	if target:
		match states[current_state]:
			"GLIDING":
				glide_towards_target(delta)
			"STINGING":
				pass  # Handled in sting_target()
			"RETREATING":
				retreat(delta)
		
		animate_body(delta)
	else:
		find_target()
	
	# Apply velocity
	global_position += velocity * delta
	
	# Apply damping
	velocity *= MOVEMENT_DAMPING

func glide_towards_target(delta):
	var distance_to_target = global_position.distance_to(target.global_position)
	
	if distance_to_target <= STING_DISTANCE and can_sting:
		sting_target()
	else:
		var direction_to_target = (target.global_position - global_position).normalized()
		
		# Smoothly update the target direction
		target_direction = target_direction.lerp(direction_to_target, TURN_SPEED * delta)
		
		var current_forward = -global_transform.basis.z
		var new_forward = current_forward.lerp(target_direction, TURN_SPEED * delta).normalized()
		
		look_at(global_position + new_forward, Vector3.UP)
		velocity = velocity.lerp(new_forward * SPEED, ROTATION_SMOOTHNESS)

func sting_target():
	var direction_to_target = (target.global_position - global_position).normalized()
	target_direction = direction_to_target  # Update target direction immediately for stinging
	var new_transform = global_transform.looking_at(target.global_position, Vector3.UP)
	global_transform = global_transform.interpolate_with(new_transform, ROTATION_SMOOTHNESS)
	
	velocity = direction_to_target * STING_FORCE
	current_state = 1  # STINGING
	can_sting = false
	is_stinging = true
	
	get_tree().create_timer(STING_COOLDOWN).connect("timeout", Callable(self, "_on_sting_cooldown_timeout"))
	get_tree().create_timer(0.5).connect("timeout", Callable(self, "_on_sting_end"))

func _on_sting_cooldown_timeout():
	can_sting = true

func _on_sting_end():
	current_state = 2  # RETREATING
	retreat_timer = 0.0
	is_stinging = false

func retreat(delta):
	retreat_timer += delta
	
	var retreat_direction = -global_transform.basis.z
	target_direction = target_direction.lerp(retreat_direction, TURN_SPEED * delta)
	velocity = velocity.lerp(target_direction * RETREAT_SPEED, ROTATION_SMOOTHNESS)
	
	if retreat_timer >= RETREAT_DURATION:
		current_state = 0  # Back to GLIDING

func animate_body(delta):
	var flap = sin(time_passed * FLAP_SPEED) * FLAP_AMPLITUDE
	left_wing.rotation.z = flap
	right_wing.rotation.z = -flap

func find_target():
	if global_position.distance_to(player.global_position) < TRIGGER_RANGE:
		target = player
	else:
		target = null
		current_state = 0  # GLIDING

func _on_sting_zone_body_entered(body):
	if body == player and is_stinging:
		var sting_direction = (body.global_position - global_position).normalized()
		var sting_force = 100.0  # Adjust this value to control the strength         
		var stagger_vector = sting_direction * sting_force

		if body.has_method("set_stagger"):
			body.set_stagger(stagger_vector)
		elif "stagger" in body:
			body.stagger = stagger_vector
		
		body.life -= DAMAGE

		print("Stingray stung the player!")
