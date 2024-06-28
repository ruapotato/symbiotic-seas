extends RigidBody3D

@onready var tail_piv = $tail_piv
@onready var jaw_piv = $jaw_piv

const SPEED = 5.0
const TURN_SPEED = 1.0
const TAIL_SWING_SPEED = 5.0
const TAIL_SWING_AMPLITUDE = 30.0
const LUNGE_DISTANCE = 5.0
const LUNGE_FORCE = 20
const LUNGE_COOLDOWN = 2.0
const RETREAT_SPEED = 7.0
const MAX_ROTATION_SPEED = 2.0
const UPWARD_ANGLE = 30.0  # Angle in degrees for upward retreat
const RETREAT_DURATION = 2.0  # Duration of retreat in seconds
const JAW_OPEN_ANGLE = -45.0  # Maximum jaw opening angle in degrees
const JAW_OPEN_SPEED = 3.0  # Speed at which the jaw opens
const DAMAGE = 50

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var player
var target
var trigger_range = 20
var time_passed = 0.0
var can_lunge = true
var retreat_direction = Vector3.ZERO
var retreat_timer = 0.0
var jaw_target_angle = 0.0

var states = ["CHASING", "LUNGING", "RETREATING"]
var current_state = 0  # 0 for CHASING
var previous_state = 0

func _ready():
	player = get_player()
	axis_lock_angular_x = true
	axis_lock_angular_z = true

func get_player():
	var root_i_hope = get_parent()
	while root_i_hope.name != "world":
		root_i_hope = root_i_hope.get_parent()
	return(root_i_hope.find_child("Clownfish"))

func _physics_process(delta):
	time_passed += delta
	
	if target != null:
		match states[current_state]:
			"CHASING":
				chase_target(delta)
			"LUNGING":
				# Lunge behavior is handled by apply_central_impulse in lunge_at_target()
				pass
			"RETREATING":
				retreat(delta)
		
		animate_tail(delta)
		animate_jaw(delta)
	else:
		linear_velocity = linear_velocity.lerp(Vector3.ZERO, delta)
	
	angular_velocity.y = clamp(angular_velocity.y, -MAX_ROTATION_SPEED, MAX_ROTATION_SPEED)
	
	if current_state != previous_state:
		print("Shark State: ", states[current_state])
		previous_state = current_state

func chase_target(delta):
	var distance_to_target = global_position.distance_to(target.global_position)
	
	if distance_to_target <= LUNGE_DISTANCE and can_lunge:
		lunge_at_target()
	else:
		var direction_to_target = (target.global_position - global_position).normalized()
		
		# Smooth turning
		var current_forward = -global_transform.basis.z
		var new_forward = current_forward.lerp(direction_to_target, TURN_SPEED * delta).normalized()
		
		# Use look_at() to orient the shark towards the target
		look_at(global_position + new_forward, Vector3.UP)
		
		# Set velocity directly towards the target
		linear_velocity = direction_to_target * SPEED

func lunge_at_target():
	look_at(target.global_position)
	var lunge_direction = (target.global_position - global_position).normalized()
	apply_central_impulse(lunge_direction * LUNGE_FORCE)
	current_state = 1  # LUNGING
	can_lunge = false
	
	# Open the jaw
	jaw_target_angle = JAW_OPEN_ANGLE
	
	get_tree().create_timer(LUNGE_COOLDOWN).connect("timeout", Callable(self, "_on_lunge_cooldown_timeout"))
	get_tree().create_timer(0.5).connect("timeout", Callable(self, "_on_lunge_end"))

func _on_lunge_cooldown_timeout():
	can_lunge = true

func _on_lunge_end():
	current_state = 2  # RETREATING
	start_retreat()
	# Close the jaw
	jaw_target_angle = 0.0

func start_retreat():
	# Generate a random horizontal direction
	var random_horizontal = Vector3(randf() - 0.5, 0, randf() - 0.5).normalized()
	
	# Rotate the direction upward
	retreat_direction = random_horizontal.rotated(random_horizontal.cross(Vector3.UP).normalized(), deg_to_rad(UPWARD_ANGLE))
	retreat_timer = 0.0

func retreat(delta):
	retreat_timer += delta
	
	# Move in the retreat direction
	linear_velocity = retreat_direction * RETREAT_SPEED
	
	# Rotate towards the retreat direction
	var current_forward = -global_transform.basis.z
	var new_forward = current_forward.lerp(retreat_direction, TURN_SPEED * delta).normalized()
	look_at(global_position + new_forward, Vector3.UP)
	
	# Check if retreat time is over
	if retreat_timer >= RETREAT_DURATION:
		current_state = 0  # Back to CHASING

func animate_tail(delta):
	var swing = sin(time_passed * TAIL_SWING_SPEED) * TAIL_SWING_AMPLITUDE
	tail_piv.rotation_degrees.y = swing

func animate_jaw(delta):
	# Smoothly interpolate the jaw rotation towards the target angle
	var current_angle = jaw_piv.rotation_degrees.x
	var new_angle = lerp(current_angle, jaw_target_angle, JAW_OPEN_SPEED * delta)
	jaw_piv.rotation_degrees.x = new_angle

func find_target():
	if global_position.distance_to(player.global_position) < trigger_range:
		target = player
	else:
		target = null
		current_state = 0  # CHASING

func _process(delta):
	find_target()


func _on_bite_zone_body_entered(body):
	if body == player:
		var bite_direction = (body.global_position - global_position).normalized()
		var bite_force = 150.0  # Adjust this value to control the strength         
		# Calculate the stagger vector
		var stagger_vector = bite_direction * bite_force

		# Set the player's stagger
		if body.has_method("set_stagger"):
			body.set_stagger(stagger_vector)
		elif "stagger" in body:
			body.stagger = stagger_vector
		
		body.life -= DAMAGE

		# Optionally, you can add some visual or audio feedback here
		print("Shark bit the player!")
