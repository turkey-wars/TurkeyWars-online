extends Node3D

@export var extents: Vector2 = Vector2(60, 25)
@export var grass_count: int = 40000

func _ready():
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.15, 0.6)
	mesh.center_offset = Vector3(0, 0.3, 0) # Base at origin
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = grass_count
	mm.mesh = mesh
	
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat = null
	if ResourceLoader.exists("res://grass_material.tres"):
		mat = load("res://grass_material.tres")
	if mat:
		mmi.material_override = mat
	else:
		var fallback_mat := StandardMaterial3D.new()
		fallback_mat.albedo_color = Color(0.23, 0.45, 0.15, 1)
		mmi.material_override = fallback_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

	for i in range(grass_count):
		var t = Transform3D()
		t = t.scaled_local(Vector3(1, randf_range(0.5, 1.5), 1))
		t = t.rotated_local(Vector3.UP, randf_range(0, TAU))
		t.origin = Vector3(randf_range(-extents.x, extents.x), 0, randf_range(-extents.y, extents.y))
		mm.set_instance_transform(i, t)
