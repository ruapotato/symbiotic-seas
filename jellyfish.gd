extends Node3D

@export var BODY_RADIUS = 1.0
@export var BODY_HEIGHT = 1.5
@export var TENTACLE_LENGTH = 2.0
@export var TENTACLE_COUNT = 8
@export var SPEED = 1.0
@export var BOUNCE_FORCE = 10.0
@export var STING_SLOW_FACTOR = 0.5
@export var STING_DURATION = 3.0
@export var STING_DAMAGE = 10
@export var TRIGGER_RANGE = 15.0
@export var PULSE_SPEED = 1.0
@export var PULSE_AMPLITUDE = 0.2
@export var REORIENT_SPEED = 2.0

var player
var target
var time_passed = 0.0
var current_state = "FLOATING"
var body
var tentacles = []
var rigid_body: RigidBody3D

func _ready():
	player = get_player()
	generate_jellyfish()

func get_player():
	var root_i_hope = get_parent()
	while root_i_hope.name != "world":
		root_i_hope = root_i_hope.get_parent()
	return(root_i_hope.find_child("Clownfish"))

func generate_jellyfish():
	rigid_body = RigidBody3D.new()
	rigid_body.gravity_scale = 0.0  # Jellyfish doesn't fall due to gravity
	add_child(rigid_body)

	create_jellyfish_body()
	create_tentacles()
	
	var collision_shape = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = BODY_RADIUS
	shape.height = BODY_HEIGHT
	collision_shape.shape = shape
	rigid_body.add_child(collision_shape)

	var bounce_area = Area3D.new()
	var bounce_shape = CollisionShape3D.new()
	bounce_shape.shape = SphereShape3D.new()
	bounce_shape.shape.radius = BODY_RADIUS
	bounce_area.add_child(bounce_shape)
	bounce_area.connect("body_entered", Callable(self, "_on_bounce_zone_body_entered"))
	rigid_body.add_child(bounce_area)

func create_jellyfish_body():
	body = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = BODY_RADIUS
	sphere_mesh.height = BODY_HEIGHT
	sphere_mesh.is_hemisphere = true
	body.mesh = sphere_mesh
	body.material_override = create_material(Color(0.8, 0.8, 1.0, 0.6))
	body.rotate_x(0)  # No rotation needed, as the hemisphere now faces upward by default
	body.position.y = -BODY_HEIGHT/5.5  # Adjust position to align with tentacles
	rigid_body.add_child(body)

func create_tentacles():
	var tentacle_parent = Node3D.new()
	rigid_body.add_child(tentacle_parent)
	
	for i in range(TENTACLE_COUNT):
		var tentacle = MeshInstance3D.new()
		var cylinder_mesh = CylinderMesh.new()
		cylinder_mesh.top_radius = 0.05
		cylinder_mesh.bottom_radius = 0.02
		cylinder_mesh.height = TENTACLE_LENGTH
		tentacle.mesh = cylinder_mesh
		tentacle.material_override = create_material(Color(0.8, 0.8, 1.0, 0.4))
		
		var angle = (2 * PI * i) / TENTACLE_COUNT
		
		# Position tentacle at the bottom edge of the body
		tentacle.position = Vector3(BODY_RADIUS * 0.8 * cos(angle), -BODY_HEIGHT / 4, BODY_RADIUS * 0.8 * sin(angle))
		
		# Rotate to point downwards (along negative Y axis)
		tentacle.rotation = Vector3(0, 0, 0)
		
		# Move the mesh origin to the top of the tentacle
		tentacle.position.y -= TENTACLE_LENGTH / 2
		
		tentacle_parent.add_child(tentacle)
		tentacles.append(tentacle)
		
		var sting_area = Area3D.new()
		var sting_shape = CollisionShape3D.new()
		var capsule_shape = CapsuleShape3D.new()
		capsule_shape.radius = 0.1
		capsule_shape.height = TENTACLE_LENGTH
		sting_shape.shape = capsule_shape
		sting_area.add_child(sting_shape)
		sting_area.connect("body_entered", Callable(self, "_on_sting_zone_body_entered"))
		tentacle.add_child(sting_area)

func create_material(color):
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.flags_transparent = true
	return material

func _physics_process(delta):
	time_passed += delta
	find_target()

	if current_state == "FLOATING":
		float_around(delta)
	else:  # PULSING
		pulse(delta)

	animate_tentacles(delta)
	reorient_upright(delta)

func float_around(delta):
	var float_direction = Vector3(sin(time_passed * 0.5), cos(time_passed * 0.3), sin(time_passed * 0.7))
	rigid_body.linear_velocity = float_direction * SPEED

func pulse(delta):
	var pulse = sin(time_passed * PULSE_SPEED) * PULSE_AMPLITUDE
	rigid_body.scale = Vector3(1 + pulse, 1 - pulse, 1 + pulse)

func animate_tentacles(_delta):
	for i in range(TENTACLE_COUNT):
		var tentacle = tentacles[i]
		var swing = sin(time_passed * 2 + i) * 0.2
		tentacle.rotation.x = swing

func reorient_upright(delta):
	var up_direction = Vector3.UP
	var current_up = rigid_body.global_transform.basis.y.normalized()
	var rotation_axis = current_up.cross(up_direction).normalized()
	
	if rotation_axis.length() > 0.001:
		var rotation_angle = current_up.angle_to(up_direction)
		rigid_body.rotate(rotation_axis, rotation_angle * REORIENT_SPEED * delta)

func find_target():
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player < TRIGGER_RANGE:
		target = player
		current_state = "PULSING"
	else:
		target = null
		current_state = "FLOATING"

func _on_bounce_zone_body_entered(body):
	if body == player:
		var bounce_direction = (body.global_position - global_position).normalized()
		bounce_direction.y = abs(bounce_direction.y)  # Ensure upward bounce
		var bounce_vector = bounce_direction * BOUNCE_FORCE
		if body is RigidBody3D:
			body.apply_central_impulse(bounce_vector)
		elif "velocity" in body:
			body.velocity += bounce_vector

func _on_sting_zone_body_entered(body):
	if body == player:
		if body.has_method("apply_slow"):
			body.apply_slow(STING_SLOW_FACTOR, STING_DURATION)
		if body.has_method("take_damage"):
			body.take_damage(STING_DAMAGE)
