extends StaticBody3D

func _ready():
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.4, 0.4, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	$MeshInstance3D.material_override = material
