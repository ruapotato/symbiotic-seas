extends Node3D

class_name UnderwaterWorldGenerator

const HEX_SIZE = 5.0
const HEX_HEIGHT = 0.5
const CHUNK_SIZE = 16
const SLOPE_FACTOR = 0.05
const VIEW_DISTANCE = 2  # Reduced from 3 to 2

enum Zone {SHALLOW_REEF, MID_REEF, DEEP_REEF, OPEN_OCEAN, ABYSSAL}
enum ResourceType {PLANKTON, ALGAE, MINERAL}

var noise: FastNoiseLite
var terrain: Node3D
var loaded_chunks = {}
var current_chunk = Vector2.ZERO

var resource_scene = preload("res://Resource.tscn")
var obstacle_scene = preload("res://Obstacle.tscn")

func _ready():
	randomize()
	noise = FastNoiseLite.new()
	noise.seed = randi()
	
	terrain = Node3D.new()
	add_child(terrain)
	
	generate_world()

func _process(_delta):
	update_world()

func generate_world():
	for x in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
		for z in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
			generate_chunk(Vector2(x, z))

func update_world():
	var player_pos = get_viewport().get_camera_3d().global_transform.origin
	var new_chunk = Vector2(floor(player_pos.x / (CHUNK_SIZE * HEX_SIZE * 1.5)), 
							floor(player_pos.z / (CHUNK_SIZE * HEX_SIZE * sqrt(3))))
	
	if new_chunk != current_chunk:
		current_chunk = new_chunk
		for x in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
			for z in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
				var chunk_pos = current_chunk + Vector2(x, z)
				if not chunk_pos in loaded_chunks:
					generate_chunk(chunk_pos)
		
		var chunks_to_remove = []
		for chunk in loaded_chunks:
			if abs(chunk.x - current_chunk.x) > VIEW_DISTANCE or abs(chunk.y - current_chunk.y) > VIEW_DISTANCE:
				chunks_to_remove.append(chunk)
		
		for chunk in chunks_to_remove:
			remove_chunk(chunk)

func generate_chunk(chunk_pos: Vector2):
	var chunk = Node3D.new()
	chunk.name = "Chunk_%d_%d" % [chunk_pos.x, chunk_pos.y]
	terrain.add_child(chunk)
	
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			var hex_pos = calculate_hex_position(chunk_pos, x, z)
			generate_hex(hex_pos, chunk)
	
	loaded_chunks[chunk_pos] = chunk

func remove_chunk(chunk_pos: Vector2):
	if chunk_pos in loaded_chunks:
		loaded_chunks[chunk_pos].queue_free()
		loaded_chunks.erase(chunk_pos)

func calculate_hex_position(chunk_pos: Vector2, x: int, z: int) -> Vector3:
	var hex_x = (chunk_pos.x * CHUNK_SIZE + x) * HEX_SIZE * 1.75
	var hex_z = (chunk_pos.y * CHUNK_SIZE + z) * HEX_SIZE * sqrt(2.7)
	if z % 2 == 1:
		hex_x += HEX_SIZE * .85
	var hex_y = calculate_depth(hex_z)
	hex_x += hex_y * 0.1
	return Vector3(hex_x, hex_y, hex_z)

func calculate_depth(z: float) -> float:
	return -z * SLOPE_FACTOR

func generate_hex(position: Vector3, parent: Node3D):
	var zone = get_zone(position)
	generate_terrain_hex(position, zone, parent)
	generate_resources(position, zone, parent)
	generate_obstacles(position, zone, parent)

func get_zone(position: Vector3) -> int:
	var depth_ratio = abs(position.y) / 100.0
	if depth_ratio < 0.2:
		return Zone.SHALLOW_REEF
	elif depth_ratio < 0.4:
		return Zone.MID_REEF
	elif depth_ratio < 0.6:
		return Zone.DEEP_REEF
	elif depth_ratio < 0.8:
		return Zone.OPEN_OCEAN
	else:
		return Zone.ABYSSAL

func generate_terrain_hex(position: Vector3, zone: int, parent: Node3D):
	var hex_mesh = create_hex_mesh()
	var mesh_instance = MeshInstance3D.new()
	
	var material = StandardMaterial3D.new()
	material.albedo_color = get_zone_color(zone)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	mesh_instance.mesh = hex_mesh
	mesh_instance.material_override = material
	mesh_instance.position = position
	mesh_instance.rotation_degrees = Vector3(0, 90, 0)
	
	var static_body = StaticBody3D.new()
	mesh_instance.add_child(static_body)
	
	var collision_shape = CollisionShape3D.new()
	var shape = ConvexPolygonShape3D.new()
	shape.points = create_collision_points()
	collision_shape.shape = shape
	static_body.add_child(collision_shape)
	
	parent.add_child(mesh_instance)

func create_hex_mesh() -> ArrayMesh:
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	for i in range(6):
		var angle = i * PI / 3
		vertices.append(Vector3(HEX_SIZE * cos(angle), 0, HEX_SIZE * sin(angle)))
		vertices.append(Vector3(HEX_SIZE * cos(angle), -HEX_HEIGHT, HEX_SIZE * sin(angle)))
	
	vertices.append(Vector3(0, 0, 0))  # Center top
	vertices.append(Vector3(0, -HEX_HEIGHT, 0))  # Center bottom
	
	# Top face
	for i in range(6):
		indices.append(12)  # Center top
		indices.append(i * 2)
		indices.append(((i + 1) % 6) * 2)
	
	# Bottom face
	for i in range(6):
		indices.append(13)  # Center bottom
		indices.append(((i + 1) % 6) * 2 + 1)
		indices.append(i * 2 + 1)
	
	# Side faces
	for i in range(6):
		var next = (i + 1) % 6
		indices.append(i * 2)
		indices.append(next * 2)
		indices.append(i * 2 + 1)
		
		indices.append(next * 2)
		indices.append(next * 2 + 1)
		indices.append(i * 2 + 1)
	
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = vertices
	arrays[ArrayMesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh

func create_collision_points() -> PackedVector3Array:
	var points = PackedVector3Array()
	
	# Top face points
	for i in range(6):
		var angle = i * PI / 3
		points.append(Vector3(HEX_SIZE * cos(angle), 0, HEX_SIZE * sin(angle)))
	
	# Bottom face points
	for i in range(6):
		var angle = i * PI / 3
		points.append(Vector3(HEX_SIZE * cos(angle), -HEX_HEIGHT, HEX_SIZE * sin(angle)))
	
	# Center top and bottom
	points.append(Vector3(0, 0, 0))
	points.append(Vector3(0, -HEX_HEIGHT, 0))
	
	return points

func get_zone_color(zone: int) -> Color:
	match zone:
		Zone.SHALLOW_REEF:
			return Color(0.3, 0.7, 1.0, 0.2)
		Zone.MID_REEF:
			return Color(0.2, 0.5, 0.8, 0.3)
		Zone.DEEP_REEF:
			return Color(0.1, 0.3, 0.6, 0.4)
		Zone.OPEN_OCEAN:
			return Color(0.05, 0.1, 0.4, 0.5)
		Zone.ABYSSAL:
			return Color(0.01, 0.05, 0.2, 0.6)
	return Color.WHITE

func generate_resources(position: Vector3, zone: int, parent: Node3D):
	var spawn_chance = 0.1 + abs(position.y) / 100.0 * 0.2
	if randf() < spawn_chance:
		var resource_type = get_random_resource(zone)
		var resource_instance = resource_scene.instantiate()
		resource_instance.position = position + Vector3(randf() * HEX_SIZE, randf() * HEX_HEIGHT, randf() * HEX_SIZE)
		resource_instance.set_resource_type(resource_type)
		parent.add_child(resource_instance)

func get_random_resource(zone: int) -> int:
	var available_resources = []
	match zone:
		Zone.SHALLOW_REEF, Zone.MID_REEF:
			available_resources = [ResourceType.PLANKTON, ResourceType.ALGAE, ResourceType.MINERAL]
		Zone.DEEP_REEF, Zone.OPEN_OCEAN:
			available_resources = [ResourceType.PLANKTON, ResourceType.MINERAL]
		Zone.ABYSSAL:
			available_resources = [ResourceType.MINERAL]
	return available_resources[randi() % available_resources.size()]

func generate_obstacles(position: Vector3, zone: int, parent: Node3D):
	var spawn_chance = 0.05 + abs(position.y) / 100.0 * 0.1
	if randf() < spawn_chance:
		var obstacle_instance = obstacle_scene.instantiate()
		obstacle_instance.position = position + Vector3(randf() * HEX_SIZE, randf() * HEX_HEIGHT, randf() * HEX_SIZE)
		obstacle_instance.rotation = Vector3(randf() * PI, randf() * PI, randf() * PI)
		parent.add_child(obstacle_instance)
