extends Area3D

enum ResourceType {PLANKTON, ALGAE, MINERAL}

var resource_type: ResourceType

func set_resource_type(type: ResourceType):
	resource_type = type
	var material = StandardMaterial3D.new()
	material.albedo_color = get_resource_color(type)
	$MeshInstance3D.material_override = material

func get_resource_color(type: ResourceType) -> Color:
	match type:
		ResourceType.PLANKTON:
			return Color.GREEN
		ResourceType.ALGAE:
			return Color.DARK_GREEN
		ResourceType.MINERAL:
			return Color.GOLD
	return Color.WHITE

func _on_body_entered(body):
	if body.has_method("collect_resource"):
		body.collect_resource(resource_type)
		queue_free()
