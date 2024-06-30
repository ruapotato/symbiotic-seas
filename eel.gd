extends Node3D

@export var LEN = 1.5
@export var SPEED = 3.0
@export var TURN_SPEED = 1.5
@export var BODY_SEGMENTS = 10
@export var SEGMENT_LENGTH = LEN/BODY_SEGMENTS
@export var BODY_THICKNESS = 0.1
@export var FIN_HEIGHT = 0.3
@export var LUNGE_DISTANCE = 2.0
@export var LUNGE_FORCE = 15.0
@export var LUNGE_COOLDOWN = 3.0
@export var RETREAT_SPEED = 5.0
@export var RETREAT_DURATION = 1.5
@export var DAMAGE = 30
@export var TRIGGER_RANGE = 150.0
@export var CHASE_RANGE = 15.0  # New variable for the range at which the eel starts chasing
@export var JAW_OPEN_ANGLE = -70.0
@export var JAW_CLOSE_ANGLE = 0
@export var JAW_MOVE_SPEED = 200.0

var player
var target
var can_lunge = true
var retreat_timer = 0.0
var time_passed = 0.0
var body_segments = []
var jaw_piv
var current_jaw_angle = JAW_CLOSE_ANGLE
var states = ["CHASING", "LUNGING", "RETREATING", "WANDERING"]
var current_state = 0  # 0 for CHASING
var is_biting = false
var wander_direction = Vector3.ZERO
var wander_timer = 0.0
var WANDER_INTERVAL = 2.0

func _ready():
	player = get_player()
	generate_body()

func get_player():
	var root = get_tree().root
	return root.find_child("Clownfish", true, false)

func generate_body():
	# Create head
	var head = create_head()
	add_child(head)
	body_segments.append(head)

	# Create body segments
	for i in range(1, BODY_SEGMENTS):
		var segment = create_body_segment()
		segment.transform.origin.z = -i * SEGMENT_LENGTH
		add_child(segment)
		body_segments.append(segment)
	
	# Add collision shape to the body
	var collision_shape = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = BODY_THICKNESS
	shape.height = LEN
	collision_shape.shape = shape
	collision_shape.transform.origin.z = -LEN / 2
	collision_shape.rotate_x(PI/2)
	add_child(collision_shape)

func create_head():
	var head = Node3D.new()
	
	# Main head shape
	var main_shape = CSGSphere3D.new()
	main_shape.radius = BODY_THICKNESS * 1.2
	main_shape.material = create_material(Color(0.2, 0.6, 0.8))
	head.add_child(main_shape)
	
	# Eyes
	var left_eye = CSGSphere3D.new()
	left_eye.radius = BODY_THICKNESS * 0.2
	left_eye.transform.origin = Vector3(BODY_THICKNESS * 0.8, BODY_THICKNESS * 0.5, -BODY_THICKNESS * 0.5)
	left_eye.material = create_material(Color.WHITE)
	head.add_child(left_eye)
	
	var right_eye = CSGSphere3D.new()
	right_eye.radius = BODY_THICKNESS * 0.2
	right_eye.transform.origin = Vector3(-BODY_THICKNESS * 0.8, BODY_THICKNESS * 0.5, -BODY_THICKNESS * 0.5)
	right_eye.material = create_material(Color.WHITE)
	head.add_child(right_eye)
	
	# Jaw
	jaw_piv = Node3D.new()
	var jaw = CSGBox3D.new()
	jaw.size = Vector3(BODY_THICKNESS * 1.8, BODY_THICKNESS * 0.4, BODY_THICKNESS * 0.8)
	jaw.transform.origin.y = -BODY_THICKNESS * 0.2
	jaw.transform.origin.z = -BODY_THICKNESS * 0.4
	jaw.material = create_material(Color(0.15, 0.45, 0.6))
	jaw_piv.add_child(jaw)
	jaw_piv.transform.origin.z = -BODY_THICKNESS * 0.8
	jaw_piv.transform.origin.y = -.02
	head.add_child(jaw_piv)
	
	# Add bite zone
	var bite_zone = Area3D.new()
	var bite_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(BODY_THICKNESS * 2, BODY_THICKNESS * 0.6, BODY_THICKNESS * 1)
	bite_shape.shape = box_shape
	bite_shape.transform.origin.z = -BODY_THICKNESS * 0.4
	bite_zone.add_child(bite_shape)
	jaw_piv.add_child(bite_zone)
	
	# Connect the bite zone signal
	bite_zone.connect("body_entered", Callable(self, "_on_bite_zone_body_entered"))
	
	head.transform.origin.z = -LEN
	return head

func create_body_segment():
	var segment = Node3D.new()
	
	# Main body
	var body = CSGCylinder3D.new()
	body.radius = BODY_THICKNESS
	body.height = SEGMENT_LENGTH
	body.material = create_material(Color(0.2, 0.6, 0.8))
	segment.add_child(body)
	
	# Central fin
	var fin = CSGBox3D.new()
	fin.size = Vector3(BODY_THICKNESS * 0.1, SEGMENT_LENGTH * 1.2, FIN_HEIGHT)
	fin.material = create_material(Color(0.15, 0.45, 0.6))
	segment.add_child(fin)
	
	segment.rotate_x(PI/2)  # Rotate the segment to face forward
	return segment

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
		"LUNGING":
			pass  # Handled in lunge_at_target()
		"RETREATING":
			retreat(delta)
		"WANDERING":
			wander(delta)
	
	animate_body(delta)
	animate_jaw(delta)


func chase_target(delta):
	var distance_to_target = global_position.distance_to(target.global_position)
	
	if distance_to_target <= LUNGE_DISTANCE and can_lunge:
		lunge_at_target()
	else:
		var direction_to_target = (target.global_position - global_position).normalized()
		var current_forward = -global_transform.basis.z
		var new_forward = current_forward.lerp(direction_to_target, TURN_SPEED * delta).normalized()
		
		look_at(global_position + new_forward, Vector3.UP)
		global_position += new_forward * SPEED * delta

func lunge_at_target():
	look_at(target.global_position)
	var lunge_direction = (target.global_position - global_position).normalized()
	global_position += lunge_direction * LUNGE_FORCE * get_physics_process_delta_time()
	current_state = 1  # LUNGING
	can_lunge = false
	is_biting = true
	
	get_tree().create_timer(LUNGE_COOLDOWN).connect("timeout", Callable(self, "_on_lunge_cooldown_timeout"))
	get_tree().create_timer(0.5).connect("timeout", Callable(self, "_on_lunge_end"))

func _on_lunge_cooldown_timeout():
	can_lunge = true

func _on_lunge_end():
	current_state = 2  # RETREATING
	retreat_timer = 0.0
	is_biting = false

func retreat(delta):
	retreat_timer += delta
	
	var retreat_direction = -global_transform.basis.z
	global_position += retreat_direction * RETREAT_SPEED * delta
	
	if retreat_timer >= RETREAT_DURATION:
		print("Back to case")
		current_state = 4  # Back to WANDERING

func animate_body(delta):
	var wave_amplitude = 0.2
	var wave_frequency = 2.0
	
	for i in range(1, body_segments.size()):
		var segment = body_segments[i]
		var wave_factor = 1.0 - (float(i) / body_segments.size())  # Factor to increase wave near the head
		var wave = sin(time_passed * wave_frequency + i * 0.5) * wave_amplitude * wave_factor
		segment.transform.origin.x = wave
		
		# Calculate the direction to the previous segment
		var direction = (body_segments[i-1].global_position - segment.global_position).normalized()
		
		# Create a basis with the y-axis aligned with the direction to the previous segment
		var y_axis = direction
		var x_axis = y_axis.cross(Vector3.UP).normalized()
		var z_axis = x_axis.cross(y_axis).normalized()
		var new_basis = Basis(x_axis, y_axis, z_axis)
		
		# Apply the new orientation
		segment.global_transform.basis = new_basis

func animate_jaw(delta):
	var target_angle = JAW_OPEN_ANGLE if is_biting else JAW_CLOSE_ANGLE
	current_jaw_angle = move_toward(current_jaw_angle, target_angle, JAW_MOVE_SPEED * delta)
	jaw_piv.rotation_degrees.x = current_jaw_angle

func find_target():
	var distance_to_player = global_position.distance_to(player.global_position)
	if player.is_protected:
		target = null
		current_state = 3  # WANDERING
	elif distance_to_player < CHASE_RANGE and can_lunge:
		target = player
		current_state = 0  # CHASING
	elif distance_to_player < TRIGGER_RANGE:
		target = player
		current_state = 3  # WANDERING
	else:
		target = null
		current_state = 3  # WANDERING

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

		#print("Eel bit the player!")

func wander(delta):
	wander_timer += delta
	if wander_timer >= WANDER_INTERVAL:
		wander_timer = 0.0
		wander_direction = Vector3(randf() * 2 - 1, 0, randf() * 2 - 1).normalized()
	
	var current_forward = -global_transform.basis.z
	var new_forward = current_forward.lerp(wander_direction, TURN_SPEED * delta).normalized()
	
	look_at(global_position + new_forward, Vector3.UP)
	global_position += new_forward * SPEED * delta
