extends Node3D

@export var BASE_SIZE = 2.0
@export var BASE_HEIGHT = 1.5
@export var OUTER_TENTACLE_COUNT = 20
@export var INNER_TENTACLE_COUNT = 30
@export var TENTACLE_LENGTH = 1.0
@export var TENTACLE_THICKNESS = 0.1
@export var SWAY_SPEED = 1.0
@export var SWAY_AMPLITUDE = 0.2
@export var PROTECTION_RADIUS = 3.0
@export var MAX_HEALTH = 100.0
@export var HEALING_RATE = 1.0  # Health restored per second
@export var PLAYER_HEALING_RATE = 2.0  # Health restored to player per second

var current_size
var current_health
var current_sting_power
var stored_resources = {"plankton": 0, "algae": 0, "minerals": 0}
var upgrades = {
	"size": 1,
	"sting_power": 1,
	"healing_rate": 1,
	"protection_radius": 1
}

var base
var tentacles = []
var protection_zone
var player
var player_in_zone = false

func _ready():
	current_size = BASE_SIZE
	current_health = MAX_HEALTH
	current_sting_power = 10  # Base sting power
	player = get_player()
	generate_anemone()
	create_protection_zone()
	#print("Anemone initialized")

func get_player():
	var root = get_tree().root
	return root.find_child("Clownfish", true, false)

func generate_anemone():
	# Create base
	base = CSGCylinder3D.new()
	base.radius = current_size / 2
	base.height = BASE_HEIGHT
	base.material = create_material(Color(0.8, 0.2, 0.2))  # Reddish color
	add_child(base)

	# Create outer tentacles
	for i in range(OUTER_TENTACLE_COUNT):
		create_tentacle(i, OUTER_TENTACLE_COUNT, current_size / 2)

	# Create inner tentacles spiraling inward
	var spiral_spacing = (current_size / 2) / INNER_TENTACLE_COUNT
	for i in range(INNER_TENTACLE_COUNT):
		var radius = (current_size / 2) - (i * spiral_spacing)
		create_tentacle(i, INNER_TENTACLE_COUNT, radius, true)

	#print("Anemone generated with ", tentacles.size(), " tentacles")

func create_tentacle(index, total_count, radius, is_inner = false):
	var tentacle = CSGCylinder3D.new()
	tentacle.radius = TENTACLE_THICKNESS
	tentacle.height = TENTACLE_LENGTH * (0.5 if is_inner else 1.0)
	var angle = (2 * PI * index) / total_count
	var offset = Vector3(cos(angle) * radius, BASE_HEIGHT / 2, sin(angle) * radius)
	tentacle.transform.origin = offset
	tentacle.look_at(tentacle.transform.origin + Vector3.UP, Vector3.FORWARD)
	tentacle.material = create_material(Color(1.0, 0.7, 0.7))  # Light pink color
	add_child(tentacle)
	tentacles.append(tentacle)

func create_protection_zone():
	protection_zone = Area3D.new()
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = PROTECTION_RADIUS
	collision_shape.shape = sphere_shape
	protection_zone.add_child(collision_shape)
	add_child(protection_zone)

	# Connect signals
	protection_zone.connect("body_entered", Callable(self, "_on_body_entered_protection_zone"))
	protection_zone.connect("body_exited", Callable(self, "_on_body_exited_protection_zone"))
	#print("Protection zone created with radius ", PROTECTION_RADIUS)

func create_material(color):
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	return material

func _physics_process(delta):
	animate_tentacles(delta)
	heal(delta)
	if player_in_zone and player:
		heal_player(delta)

func animate_tentacles(delta):
	for i in range(tentacles.size()):
		var tentacle = tentacles[i]
		var sway = sin(Time.get_ticks_msec() * 0.001 * SWAY_SPEED + i) * SWAY_AMPLITUDE
		tentacle.rotation.x = sway
		tentacle.rotation.z = sway

func heal(delta):
	var heal_amount = HEALING_RATE * upgrades["healing_rate"] * delta
	current_health = min(current_health + heal_amount, MAX_HEALTH)
	#print("Anemone healed for ", heal_amount, ". Current health: ", current_health)

func heal_player(delta):

	var heal_amount = PLAYER_HEALING_RATE * upgrades["healing_rate"] * delta
	player.heal(heal_amount)


func upgrade(type):
	if upgrades[type] < 5:  # Assuming 5 is the max upgrade level
		var cost = calculate_upgrade_cost(type)
		if can_afford(cost):
			deduct_resources(cost)
			upgrades[type] += 1
			apply_upgrade(type)
			#print("Upgraded ", type, " to level ", upgrades[type])
			return true
	#print("Upgrade failed for ", type)
	return false

func calculate_upgrade_cost(type):
	# Implement your cost calculation logic here
	# This is a placeholder implementation
	return {
		"plankton": 10 * upgrades[type],
		"algae": 5 * upgrades[type],
		"minerals": 3 * upgrades[type]
	}

func can_afford(cost):
	for resource in cost:
		if stored_resources[resource] < cost[resource]:
			return false
	return true

func deduct_resources(cost):
	for resource in cost:
		stored_resources[resource] -= cost[resource]
	#print("Resources deducted: ", cost)

func apply_upgrade(type):
	match type:
		"size":
			current_size *= 1.2
			update_size()
		"sting_power":
			current_sting_power *= 1.5
		"healing_rate":
			# Healing rate is directly used in the heal function
			pass
		"protection_radius":
			PROTECTION_RADIUS *= 1.2
			update_protection_zone()

func update_size():
	base.radius = current_size / 2
	for i in range(tentacles.size()):
		var tentacle = tentacles[i]
		var angle = (2 * PI * i) / tentacles.size()
		var offset = Vector3(cos(angle) * current_size / 2, BASE_HEIGHT / 2, sin(angle) * current_size / 2)
		tentacle.transform.origin = offset
	#print("Anemone size updated to ", current_size)

func update_protection_zone():
	var collision_shape = protection_zone.get_node("CollisionShape3D")
	var sphere_shape = collision_shape.shape
	sphere_shape.radius = PROTECTION_RADIUS
	#print("Protection zone radius updated to ", PROTECTION_RADIUS)

func _on_body_entered_protection_zone(body):
	if body == player:
		body.set_protected(true)
		body.set_anemone(self)
		player_in_zone = true
		#print("Player entered protection zone")
	elif body.has_method("take_damage"):
		body.take_damage(current_sting_power)
		#print("Enemy took ", current_sting_power, " damage from protection zone")

func _on_body_exited_protection_zone(body):
	if body == player:
		body.set_protected(false)
		player_in_zone = false
		#print("Player exited protection zone")

func add_resources(type, amount):
	stored_resources[type] += amount
	#print("Added ", amount, " of ", type, " to stored resources")

func get_stored_resources():
	return stored_resources

func take_damage(amount):
	current_health -= amount
	#print("Anemone took ", amount, " damage. Current health: ", current_health)
	if current_health <= 0:
		pass
		#print("Anemone health depleted!")
		# Implement game over or respawn logic
