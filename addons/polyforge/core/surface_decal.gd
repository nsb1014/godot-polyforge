extends RefCounted
## Flush and softly embossed color geometry projected onto the front of an ellipsoid.
##
## Use zero-thickness decals for tattoos, paint, labels, and seams. Use feathered patches
## for eyes, lips, plates, and other shallow details that need a controlled central bulge
## while their rim meets the curved host without a ledge.

static func _front_point(center: Vector3, radii: Vector3, point: Vector2,
		lift: float) -> Dictionary:
	assert(radii.x > 0.0 and radii.y > 0.0 and radii.z > 0.0,
		"ellipsoid decal radii must be positive")
	var nx := (point.x - center.x) / radii.x
	var ny := (point.y - center.y) / radii.y
	var radial := nx * nx + ny * ny
	assert(radial < 1.0, "ellipsoid decal point lies outside the projected surface")
	var z := center.z + radii.z * sqrt(maxf(0.0, 1.0 - radial))
	var position := Vector3(point.x, point.y, z)
	var normal := Vector3(
		(position.x - center.x) / (radii.x * radii.x),
		(position.y - center.y) / (radii.y * radii.y),
		(position.z - center.z) / (radii.z * radii.z)).normalized()
	return {"position": position + normal * lift, "normal": normal}

static func _signed_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(points.size()):
		var next := (index + 1) % points.size()
		area += points[index].x * points[next].y - points[next].x * points[index].y
	return area * 0.5

static func _capsule_outline(length: float, width: float,
		cap_segments: int) -> PackedVector2Array:
	var radius := minf(width * 0.5, length * 0.5)
	var straight_half := maxf(0.0, (length - radius * 2.0) * 0.5)
	var points := PackedVector2Array()
	for index in range(cap_segments + 1):
		var angle := lerpf(0.0, PI, float(index) / float(cap_segments))
		points.append(Vector2(cos(angle) * radius,
			straight_half + sin(angle) * radius))
	for index in range(cap_segments + 1):
		var angle := lerpf(PI, TAU, float(index) / float(cap_segments))
		points.append(Vector2(cos(angle) * radius,
			-straight_half + sin(angle) * radius))
	return points

static func _ellipse_outline(size: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2(cos(angle) * size.x * 0.5,
			sin(angle) * size.y * 0.5))
	return points

## `points` are world-space XY coordinates in the ellipsoid's front projection.
## The polygon may be convex or concave but may not self-intersect.
static func ellipsoid_polygon(center: Vector3, radii: Vector3,
		points: PackedVector2Array, material: Material, lift := 0.001) -> ArrayMesh:
	assert(points.size() >= 3, "surface decal polygon needs at least three points")
	assert(material != null, "surface decal requires a material")
	var contour := points.duplicate()
	if _signed_area(contour) < 0.0:
		contour.reverse()
	var triangulated := Geometry2D.triangulate_polygon(contour)
	assert(not triangulated.is_empty(), "surface decal polygon could not be triangulated")

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	vertices.resize(contour.size())
	normals.resize(contour.size())
	for index in range(contour.size()):
		var projected := _front_point(center, radii, contour[index], lift)
		vertices[index] = projected.position
		normals[index] = projected.normal

	# Geometry2D returns counter-clockwise triangles. Godot treats clockwise triangles as
	# front faces, so reverse each triangle while retaining the outward ellipsoid normals.
	var indices := PackedInt32Array()
	for index in range(0, triangulated.size(), 3):
		indices.append(triangulated[index])
		indices.append(triangulated[index + 2])
		indices.append(triangulated[index + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh

## Creates a rounded stroke aligned to local +Y before rotation. `local_center` is an XY
## offset from the ellipsoid center; length includes the rounded caps.
static func ellipsoid_capsule(center: Vector3, radii: Vector3,
		local_center: Vector2, length: float, width: float, rotation_degrees: float,
		material: Material, lift := 0.001, cap_segments := 5) -> ArrayMesh:
	assert(length > 0.0 and width > 0.0, "surface decal capsule dimensions must be positive")
	assert(cap_segments >= 2, "surface decal capsule needs at least two cap segments")
	var local := _capsule_outline(length, width, cap_segments)
	var radians := deg_to_rad(rotation_degrees)
	var points := PackedVector2Array()
	for point in local:
		points.append(Vector2(center.x, center.y) + local_center + point.rotated(radians))
	return ellipsoid_polygon(center, radii, points, material, lift)

## Builds a star-shaped detail whose complete front follows the host ellipsoid. The patch
## reaches `height` at its center and smoothly feathers to `lift` at the outer ring. It has
## no vertical side wall, so shallow facial parts read as embedded rather than glued on.
static func ellipsoid_feathered_patch(center: Vector3, radii: Vector3,
		local_center: Vector2, local_outline: PackedVector2Array,
		rotation_degrees: float, material: Material, height := 0.01,
		lift := 0.001, radial_rings := 3) -> ArrayMesh:
	assert(local_outline.size() >= 3, "feathered patch outline needs at least three points")
	assert(_signed_area(local_outline) > 0.0,
		"feathered patch outline must be counter-clockwise")
	assert(material != null, "feathered patch requires a material")
	assert(height >= 0.0 and lift >= 0.0,
		"feathered patch height and lift must be non-negative")
	assert(radial_rings >= 2, "feathered patch needs at least two radial rings")
	var radians := deg_to_rad(rotation_degrees)
	var count := local_outline.size()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var center_xy := Vector2(center.x, center.y) + local_center
	var center_hit := _front_point(center, radii, center_xy, lift + height)
	vertices.append(center_hit.position)
	normals.append(center_hit.normal)

	for ring in range(1, radial_rings + 1):
		var ratio := float(ring) / float(radial_rings)
		var ring_height := height * (1.0 - smoothstep(0.0, 1.0, ratio))
		for point in local_outline:
			var xy := Vector2(center.x, center.y) + local_center + \
				(point * ratio).rotated(radians)
			var hit := _front_point(center, radii, xy, lift + ring_height)
			vertices.append(hit.position)
			normals.append(hit.normal)

	var indices := PackedInt32Array()
	# Reverse counter-clockwise parameter-space triangles for Godot's clockwise front faces.
	for column in range(count):
		var next := (column + 1) % count
		indices.append(0)
		indices.append(1 + next)
		indices.append(1 + column)
	for ring in range(1, radial_rings):
		var inner_start := 1 + (ring - 1) * count
		var outer_start := 1 + ring * count
		for column in range(count):
			var next := (column + 1) % count
			indices.append(inner_start + column)
			indices.append(outer_start + next)
			indices.append(outer_start + column)
			indices.append(inner_start + column)
			indices.append(inner_start + next)
			indices.append(outer_start + next)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh

static func ellipsoid_ellipse_patch(center: Vector3, radii: Vector3,
		local_center: Vector2, size: Vector2, rotation_degrees: float,
		material: Material, height := 0.01, lift := 0.001,
		radial_rings := 3, segments := 18) -> ArrayMesh:
	assert(size.x > 0.0 and size.y > 0.0, "ellipse patch size must be positive")
	assert(segments >= 8, "ellipse patch needs at least eight segments")
	return ellipsoid_feathered_patch(center, radii, local_center,
		_ellipse_outline(size, segments), rotation_degrees, material,
		height, lift, radial_rings)

static func ellipsoid_capsule_patch(center: Vector3, radii: Vector3,
		local_center: Vector2, length: float, width: float, rotation_degrees: float,
		material: Material, height := 0.01, lift := 0.001,
		radial_rings := 3, cap_segments := 6) -> ArrayMesh:
	assert(length > 0.0 and width > 0.0, "capsule patch dimensions must be positive")
	assert(cap_segments >= 3, "capsule patch needs at least three cap segments")
	return ellipsoid_feathered_patch(center, radii, local_center,
		_capsule_outline(length, width, cap_segments), rotation_degrees, material,
		height, lift, radial_rings)
