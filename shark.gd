extends RigidBody3D

@export var SPEED = 5.0
@export var TURN_SPEED = 1.5
@export var TAIL_SWING_SPEED = 5.0
@export var TAIL_SWING_AMPLITUDE = 30.0
@export var LUNGE_DISTANCE = 5.0
@export var LUNGE_FORCE = 20.0
@export var LUNGE_COOLDOWN = 3.0
@export var RETREAT_SPEED = 7.0
@export var RETREAT_DURATION = 2.0
@export var JAW_OPEN_ANGLE = -45.0
@export var JAW_CLOSE_ANGLE = 0.0
@export var JAW_MOVE_SPEED = 200.0
@export var DAMAGE = 50
@export var TRIGGER_RANGE = 20.0

@onready var tail_piv = $tail_piv
@onready var jaw_piv = $jaw_piv

var player
var target
var can_lunge = true
var retreat_timer = 0.0
var time_passed = 0.0
var current_jaw_angle = 0.0
var states = ["CHASING", "LUNGING", "RETREATING"]
var current_state = 0  # 0 for CHASING
var is_biting = false

func _ready():
	player = get_player()
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	#print("Shark initialized")

func get_player():
	var root = get_tree().root
	return root.find_child("Clownfish", true, false)

func _physics_process(delta):
	time_passed += delta
	
	if find_target():
		match states[current_state]:
			"CHASING":
				chase_target(delta)
			"LUNGING":
				pass  # Handled in lunge_at_target()
			"RETREATING":
				retreat(delta)
		
		animate_tail(delta)
		animate_jaw(delta)
	else:
		linear_velocity = linear_velocity.lerp(Vector3.ZERO, delta)
	
	angular_velocity.y = clamp(angular_velocity.y, -TURN_SPEED, TURN_SPEED)

func chase_target(delta):
	var distance_to_target = global_position.distance_to(find_target().global_position)
	
	if distance_to_target <= LUNGE_DISTANCE and can_lunge:
		lunge_at_target()
	else:
		var direction_to_target = (find_target().global_position - global_position).normalized()
		var current_forward = -global_transform.basis.z
		var new_forward = current_forward.lerp(direction_to_target, TURN_SPEED * delta).normalized()
		
		look_at(global_position + new_forward, Vector3.UP)
		linear_velocity = direction_to_target * SPEED

func lunge_at_target():
	look_at(find_target().global_position)
	var lunge_direction = (find_target().global_position - global_position).normalized()
	apply_central_impulse(lunge_direction * LUNGE_FORCE)
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
	linear_velocity = retreat_direction * RETREAT_SPEED
	
	if retreat_timer >= RETREAT_DURATION:
		current_state = 0  # Back to CHASING

func animate_tail(delta):
	var swing = sin(time_passed * TAIL_SWING_SPEED) * TAIL_SWING_AMPLITUDE
	tail_piv.rotation_degrees.y = swing

func animate_jaw(delta):
	var target_angle = JAW_OPEN_ANGLE if is_biting else JAW_CLOSE_ANGLE
	current_jaw_angle = move_toward(current_jaw_angle, target_angle, JAW_MOVE_SPEED * delta)
	jaw_piv.rotation_degrees.x = current_jaw_angle

func find_target():
	if player and global_position.distance_to(player.global_position) < TRIGGER_RANGE:
		if not player.is_protected:
			target = player
			#print("Shark found target")
		else:
			target = null
			#print("Shark's target is protected")
	else:
		target = null
		current_state = 0  # CHASING
	return(target)

func _on_bite_zone_body_entered(body):
	if body == player and is_biting and not player.is_protected:
		var bite_direction = (body.global_position - global_position).normalized()
		var bite_force = 150.0  # Adjust this value to control the strength         
		var stagger_vector = bite_direction * bite_force

		if body.has_method("set_stagger"):
			body.set_stagger(stagger_vector)
		
		body.take_damage(DAMAGE)
		#print("Shark bit the player!")

func take_damage(amount):
	pass
	# Implement damage logic here
	#print("Shark took ", amount, " damage")
	# You might want to add health tracking and destruction logic
