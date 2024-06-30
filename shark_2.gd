extends Node3D

@export var LENGTH = 4.0
@export var BODY_WIDTH = 0.8
@export var BODY_HEIGHT = 1.2
@export var DORSAL_FIN_HEIGHT = 0.8
@export var TAIL_FIN_HEIGHT = 1.0
@export var SPEED = 5.0
@export var TURN_SPEED = 1.0
@export var BITE_DISTANCE = 3.0
@export var BITE_FORCE = 20.0
@export var BITE_COOLDOWN = 2.0
@export var RETREAT_SPEED = 7.0
@export var RETREAT_DURATION = 1.0
@export var DAMAGE = 50
@export var TRIGGER_RANGE = 200.0
@export var CHASE_RANGE = 30.0
@export var JAW_OPEN_ANGLE = 30.0
@export var JAW_CLOSE_ANGLE = 0
@export var JAW_MOVE_SPEED = 150.0

var player
var target
var can_bite = true
var retreat_timer = 0.0
var time_passed = 0.0
var jaw
var current_jaw_angle = JAW_CLOSE_ANGLE
var states = ["CHASING", "BITING", "RETREATING", "PATROLLING"]
var current_state = 3  # Start with PATROLLING
var is_biting = false
var patrol_direction = Vector3.ZERO
var patrol_timer = 0.0
var PATROL_INTERVAL = 5.0

var body
var tail_fin

func _ready():
	player = get_player()
	generate_shark()

func get_player():
	var root = get_tree().root
	return root.find_child("Clownfish", true, false)

func generate_shark():
	body = create_body()
	add_child(body)
	
	jaw = create_jaw()
	body.add_child(jaw)
	
	tail_fin = create_tail_fin()
	body.add_child(tail_fin)
	
	var collision_shape = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = BODY_WIDTH / 2
	shape.height = LENGTH
	collision_shape.shape = shape
	collision_shape.rotate_x(PI/2)
	add_child(collision_shape)

func create_body():
	var mesh = CSGCombiner3D.new()
	
	# Main body
	var body_shape = CSGCylinder3D.new()
	body_shape.radius = BODY_WIDTH / 2
	body_shape.height = LENGTH
	body_shape.material = create_material(Color(0.5, 0.5, 0.6))  # Grey-blue color for shark
	body_shape.rotate_x(PI/2)
	mesh.add_child(body_shape)
	
	# Head shape (to make the front more pointed)
	var head_shape = CSGSphere3D.new()
	head_shape.radius = BODY_WIDTH / 2
	head_shape.material = create_material(Color(0.5, 0.5, 0.6))
	head_shape.transform.origin = Vector3(0, 0, -LENGTH/2 + BODY_WIDTH/4)
	mesh.add_child(head_shape)
	
	# Dorsal fin
	var dorsal_fin = CSGBox3D.new()
	dorsal_fin.size = Vector3(BODY_WIDTH * 0.1, DORSAL_FIN_HEIGHT, LENGTH * 0.2)
	dorsal_fin.transform.origin = Vector3(0, BODY_HEIGHT / 2 + DORSAL_FIN_HEIGHT / 2, -LENGTH * 0.1)
	dorsal_fin.material = create_material(Color(0.45, 0.45, 0.55))
	mesh.add_child(dorsal_fin)
	
	# Eyes
	var left_eye = CSGSphere3D.new()
	left_eye.radius = BODY_WIDTH * 0.05
	left_eye.transform.origin = Vector3(BODY_WIDTH * 0.35, BODY_HEIGHT * 0.3, -LENGTH / 2 + BODY_WIDTH * 0.3)
	left_eye.material = create_material(Color.BLACK)
	mesh.add_child(left_eye)
	
	var right_eye = CSGSphere3D.new()
	right_eye.radius = BODY_WIDTH * 0.05
	right_eye.transform.origin = Vector3(-BODY_WIDTH * 0.35, BODY_HEIGHT * 0.3, -LENGTH / 2 + BODY_WIDTH * 0.3)
	right_eye.material = create_material(Color.BLACK)
	mesh.add_child(right_eye)
	
	return mesh

func create_jaw():
	var jaw_node = Node3D.new()
	var lower_jaw = CSGBox3D.new()
	lower_jaw.size = Vector3(BODY_WIDTH * 0.8, BODY_HEIGHT * 0.1, BODY_WIDTH * 0.6)
	lower_jaw.transform.origin.y = BODY_HEIGHT * 0.05
	lower_jaw.transform.origin.z = -BODY_WIDTH * 0.3
	lower_jaw.material = create_material(Color(0.45, 0.45, 0.55))
	jaw_node.add_child(lower_jaw)
	jaw_node.transform.origin = Vector3(0, -BODY_HEIGHT * 0.2, -LENGTH / 2 + BODY_WIDTH * 0.3)
	
	var bite_zone = Area3D.new()
	var bite_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(BODY_WIDTH, BODY_HEIGHT * 0.3, BODY_WIDTH)
	bite_shape.shape = box_shape
	bite_shape.transform.origin.z = -BODY_WIDTH 
	bite_zone.add_child(bite_shape)
	jaw_node.add_child(bite_zone)
	
	bite_zone.connect("body_entered", Callable(self, "_on_bite_zone_body_entered"))
	
	return jaw_node

func create_tail_fin():
	var fin = CSGBox3D.new()
	fin.size = Vector3(TAIL_FIN_HEIGHT, TAIL_FIN_HEIGHT, BODY_WIDTH * 0.1)
	fin.transform.origin = Vector3(0, 0, LENGTH / 2 + BODY_WIDTH * 0.05)
	fin.rotate_x(PI/2)  # Rotate 90 degrees around x-axis to make it vertical
	fin.material = create_material(Color(0.45, 0.45, 0.55))
	return fin

func create_material(color):
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	return material


func _physics_process(delta):
	time_passed += delta
	find_target()

	match states[current_state]:
		"CHASING":
			chase_target(delta)
		"BITING":
			pass  # Handled in bite_target()
		"RETREATING":
			retreat(delta)
		"PATROLLING":
			patrol(delta)

	animate_shark(delta)
	animate_jaw(delta)

func chase_target(delta):
	var distance_to_target = global_position.distance_to(target.global_position)
	
	if distance_to_target <= BITE_DISTANCE and can_bite:
		bite_target()
	else:
		var direction_to_target = (target.global_position - global_position).normalized()
		var current_forward = -global_transform.basis.z
		var new_forward = current_forward.lerp(direction_to_target, TURN_SPEED * delta).normalized()
		
		look_at(global_position + new_forward, Vector3.UP)
		global_position += new_forward * SPEED * delta

func bite_target():
	look_at(target.global_position)
	var bite_direction = (target.global_position - global_position).normalized()
	global_position += bite_direction * BITE_FORCE * get_physics_process_delta_time()
	current_state = 1  # BITING
	can_bite = false
	is_biting = true
	
	get_tree().create_timer(BITE_COOLDOWN).connect("timeout", Callable(self, "_on_bite_cooldown_timeout"))
	get_tree().create_timer(0.5).connect("timeout", Callable(self, "_on_bite_end"))

func _on_bite_cooldown_timeout():
	can_bite = true

func _on_bite_end():
	current_state = 2  # RETREATING
	retreat_timer = 0.0
	is_biting = false

func retreat(delta):
	retreat_timer += delta
	
	var retreat_direction = -global_transform.basis.z
	global_position += retreat_direction * RETREAT_SPEED * delta
	
	if retreat_timer >= RETREAT_DURATION:
		current_state = 3  # Back to PATROLLING

func animate_shark(delta):
	var tail_amplitude = 0.2
	var tail_frequency = 2.0
	
	var tail_rotation = sin(time_passed * tail_frequency) * tail_amplitude
	tail_fin.rotation.y = tail_rotation

func animate_jaw(delta):
	var target_angle = -JAW_OPEN_ANGLE if is_biting else JAW_CLOSE_ANGLE
	current_jaw_angle = move_toward(current_jaw_angle, target_angle, JAW_MOVE_SPEED * delta)
	jaw.rotation_degrees.x = current_jaw_angle

func find_target():
	var distance_to_player = global_position.distance_to(player.global_position)
	if player.is_protected:
		target = null
		current_state = 3  # PATROLLING
	elif distance_to_player < CHASE_RANGE and can_bite:
		target = player
		current_state = 0  # CHASING
	elif distance_to_player < TRIGGER_RANGE:
		target = player
		current_state = 3  # PATROLLING
	else:
		target = null
		current_state = 3  # PATROLLING

func _on_bite_zone_body_entered(body):
	if body == player:
		var bite_direction = (body.global_position - global_position).normalized()
		var bite_force = 100.0  # Adjust this value to control the strength         
		var stagger_vector = bite_direction * bite_force

		if body.has_method("set_stagger"):
			body.set_stagger(stagger_vector)
		elif "stagger" in body:
			body.stagger = stagger_vector
		
		body.life -= DAMAGE

func patrol(delta):
	patrol_timer += delta
	if patrol_timer >= PATROL_INTERVAL:
		patrol_timer = 0.0
		patrol_direction = Vector3(randf() * 2 - 1, 0, randf() * 2 - 1).normalized()
	
	var current_forward = -global_transform.basis.z
	var new_forward = current_forward.lerp(patrol_direction, TURN_SPEED * 0.5 * delta).normalized()
	
	look_at(global_position + new_forward, Vector3.UP)
	global_position += new_forward * SPEED * 0.7 * delta
