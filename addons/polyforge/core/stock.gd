extends RefCounted
## Stock Godot mesh factories for asset recipes.
##
## Unlike BuilderBase's accumulating helpers, these return meshes directly so recipes can
## add them to a named Assembly. They remain ordinary Godot resources and need no runtime
## PolyForge dependency after export.

static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

static func cylinder(bottom_radius: float, top_radius: float, height: float,
		radial_segments := 12) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = maxi(radial_segments, 3)
	return mesh

static func sphere(radius: float, radial_segments := 16, rings := 8) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = maxi(radial_segments, 4)
	mesh.rings = maxi(rings, 2)
	return mesh

static func torus(inner_radius: float, outer_radius: float,
		rings := 24, ring_segments := 8) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = maxi(rings, 3)
	mesh.ring_segments = maxi(ring_segments, 3)
	return mesh

static func capsule(radius: float, height: float,
		radial_segments := 16, rings := 8) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = maxi(radial_segments, 4)
	mesh.rings = maxi(rings, 2)
	return mesh

static func material(name: String, color: Color, metallic := 0.0,
		roughness := 0.8) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.resource_name = name
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	return result

static func glow_material(name: String, color: Color, energy := 1.5) -> StandardMaterial3D:
	var result := material(name, color, 0.0, 0.4)
	result.emission_enabled = true
	result.emission = color
	result.emission_energy_multiplier = energy
	return result

static func with_material(mesh: PrimitiveMesh, value: Material) -> PrimitiveMesh:
	mesh.material = value
	return mesh
