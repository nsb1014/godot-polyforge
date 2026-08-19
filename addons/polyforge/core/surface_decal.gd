extends RefCounted
## Flush and softly embossed color geometry projected onto the front of an ellipsoid.
##
## Use zero-thickness decals for tattoos, paint, labels, and seams. Use feathered patches
## for eyes, lips, plates, and other shallow details that need a controlled central bulge
## while their rim meets the curved host without a ledge.

const MAX_CONFORMANCE_SUBDIVISIONS := 8
const CONFORMANCE_EPSILON_FACTOR := 0.000001

static func _inverse_radii(radii: Vector3) -> Vector3:
	assert(radii.x > 0.0 and radii.y > 0.0 and radii.z > 0.0,
		"ellipsoid decal radii must be positive")
	return Vector3(1.0 / radii.x, 1.0 / radii.y, 1.0 / radii.z)

static func _front_position(center: Vector3, radii: Vector3, inverse_radii: Vector3,
		inverse_squared_radii: Vector3, point: Vector2, lift: float) -> Vector3:
	var nx := (point.x - center.x) * inverse_radii.x
	var ny := (point.y - center.y) * inverse_radii.y
	var radial := nx * nx + ny * ny
	assert(radial < 1.0, "ellipsoid decal point lies outside the projected surface")
	var position := Vector3(point.x, point.y,
		center.z + radii.z * sqrt(maxf(0.0, 1.0 - radial)))
	var offset := position - center
	var normal := Vector3(
		offset.x * inverse_squared_radii.x,
		offset.y * inverse_squared_radii.y,
		offset.z * inverse_squared_radii.z).normalized()
	return position + normal * lift

static func _point_penetrates_front(center: Vector3, radii: Vector3,
		inverse_radii: Vector3, point: Vector3, epsilon: float) -> bool:
	var nx := (point.x - center.x) * inverse_radii.x
	var ny := (point.y - center.y) * inverse_radii.y
	var radial := nx * nx + ny * ny
	if radial >= 1.0:
		return false
	var surface_z := center.z + radii.z * sqrt(maxf(0.0, 1.0 - radial))
	return point.z + epsilon < surface_z

static func _triangle_penetrates_front(center: Vector3, radii: Vector3,
		inverse_radii: Vector3, a: Vector3, b: Vector3, c: Vector3,
		epsilon: float) -> bool:
	return _point_penetrates_front(center, radii, inverse_radii, (a + b) * 0.5, epsilon) or \
		_point_penetrates_front(center, radii, inverse_radii, (b + c) * 0.5, epsilon) or \
		_point_penetrates_front(center, radii, inverse_radii, (c + a) * 0.5, epsilon) or \
		_point_penetrates_front(center, radii, inverse_radii, (a + b + c) / 3.0, epsilon)

static func _cached_front_position(center: Vector3, radii: Vector3,
		inverse_radii: Vector3, inverse_squared_radii: Vector3, point: Vector2,
		lift: float, positions: Dictionary) -> Vector3:
	if positions.has(point):
		return positions[point]
	var position := _front_position(center, radii, inverse_radii,
		inverse_squared_radii, point, lift)
	positions[point] = position
	return position

static func _projected_vertex_index(center: Vector3, radii: Vector3,
		inverse_radii: Vector3, inverse_squared_radii: Vector3, point: Vector2,
		lift: float, positions: Dictionary, vertex_indices: Dictionary,
		vertices: PackedVector3Array) -> int:
	if vertex_indices.has(point):
		return int(vertex_indices[point])
	var index := vertices.size()
	vertices.append(_cached_front_position(center, radii, inverse_radii,
		inverse_squared_radii, point, lift, positions))
	vertex_indices[point] = index
	return index

static func _emit_conformed_triangle(center: Vector3, radii: Vector3,
		inverse_radii: Vector3, inverse_squared_radii: Vector3,
		a: Vector2, b: Vector2, c: Vector2, lift: float, epsilon: float,
		depth: int, positions: Dictionary, vertex_indices: Dictionary,
		vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	var projected_a := _cached_front_position(center, radii, inverse_radii,
		inverse_squared_radii, a, lift, positions)
	var projected_b := _cached_front_position(center, radii, inverse_radii,
		inverse_squared_radii, b, lift, positions)
	var projected_c := _cached_front_position(center, radii, inverse_radii,
		inverse_squared_radii, c, lift, positions)
	var penetrates := _triangle_penetrates_front(center, radii, inverse_radii,
		projected_a, projected_b, projected_c, epsilon)
	if penetrates and depth < MAX_CONFORMANCE_SUBDIVISIONS:
		var ab := (a + b) * 0.5
		var bc := (b + c) * 0.5
		var ca := (c + a) * 0.5
		_emit_conformed_triangle(center, radii, inverse_radii, inverse_squared_radii,
			a, ab, ca, lift, epsilon, depth + 1, positions, vertex_indices,
			vertices, indices)
		_emit_conformed_triangle(center, radii, inverse_radii, inverse_squared_radii,
			ab, b, bc, lift, epsilon, depth + 1, positions, vertex_indices,
			vertices, indices)
		_emit_conformed_triangle(center, radii, inverse_radii, inverse_squared_radii,
			ca, bc, c, lift, epsilon, depth + 1, positions, vertex_indices,
			vertices, indices)
		_emit_conformed_triangle(center, radii, inverse_radii, inverse_squared_radii,
			ab, bc, ca, lift, epsilon, depth + 1, positions, vertex_indices,
			vertices, indices)
		return
	assert(not penetrates,
		"surface decal could not conform within the subdivision limit; increase lift")
	var a_index := _projected_vertex_index(center, radii, inverse_radii,
		inverse_squared_radii, a, lift, positions, vertex_indices, vertices)
	var b_index := _projected_vertex_index(center, radii, inverse_radii,
		inverse_squared_radii, b, lift, positions, vertex_indices, vertices)
	var c_index := _projected_vertex_index(center, radii, inverse_radii,
		inverse_squared_radii, c, lift, positions, vertex_indices, vertices)
	# Parameter-space triangles are counter-clockwise. Godot front faces are clockwise.
	indices.append(a_index)
	indices.append(c_index)
	indices.append(b_index)

static func _geometric_normals(vertices: PackedVector3Array,
		indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for index in range(0, indices.size(), 3):
		var a := indices[index]
		var b := indices[index + 1]
		var c := indices[index + 2]
		# The mesh uses clockwise front faces, so reverse the usual cross-product order.
		var face_normal := (vertices[c] - vertices[a]).cross(
			vertices[b] - vertices[a])
		if face_normal.length_squared() <= 0.000000000001:
			continue
		normals[a] = normals[a] + face_normal
		normals[b] = normals[b] + face_normal
		normals[c] = normals[c] + face_normal
	for index in range(normals.size()):
		if normals[index].length_squared() > 0.000000000001:
			normals[index] = normals[index].normalized()
		else:
			normals[index] = Vector3.BACK
	return normals

static func _mesh_from_arrays(vertices: PackedVector3Array,
		indices: PackedInt32Array, material: Material) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = _geometric_normals(vertices, indices)
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh

static func _signed_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(points.size()):
		var next := (index + 1) % points.size()
		area += points[index].x * points[next].y - points[next].x * points[index].y
	return area * 0.5

static func _ellipse_outline(size: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2(cos(angle) * size.x * 0.5,
			sin(angle) * size.y * 0.5))
	return points

static func _capsule_outline(length: float, width: float,
		cap_segments: int) -> PackedVector2Array:
	if is_equal_approx(length, width):
		return _ellipse_outline(Vector2(width, width), cap_segments * 2)
	var radius := width * 0.5
	var straight_half := (length - width) * 0.5
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

## `points` are world-space XY coordinates in the ellipsoid's front projection.
## The polygon may be convex or concave but may not self-intersect. Triangles are
## adaptively subdivided until their midpoints and centroids clear the host surface.
static func ellipsoid_polygon(center: Vector3, radii: Vector3,
		points: PackedVector2Array, material: Material, lift := 0.001) -> ArrayMesh:
	assert(points.size() >= 3, "surface decal polygon needs at least three points")
	assert(material != null, "surface decal requires a material")
	assert(lift > 0.0, "surface decal lift must be positive")
	var inverse_radii := _inverse_radii(radii)
	var inverse_squared_radii := Vector3(
		inverse_radii.x * inverse_radii.x,
		inverse_radii.y * inverse_radii.y,
		inverse_radii.z * inverse_radii.z)
	var contour := points.duplicate()
	if _signed_area(contour) < 0.0:
		contour.reverse()
	var triangulated := Geometry2D.triangulate_polygon(contour)
	assert(not triangulated.is_empty(), "surface decal polygon could not be triangulated")

	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var positions := {}
	var vertex_indices := {}
	var max_radius := maxf(radii.x, maxf(radii.y, radii.z))
	var epsilon := maxf(max_radius * CONFORMANCE_EPSILON_FACTOR, 0.0000001)
	for index in range(0, triangulated.size(), 3):
		_emit_conformed_triangle(center, radii, inverse_radii, inverse_squared_radii,
			contour[triangulated[index]], contour[triangulated[index + 1]],
			contour[triangulated[index + 2]], lift, epsilon, 0, positions,
			vertex_indices, vertices, indices)
	return _mesh_from_arrays(vertices, indices, material)

## Creates a rounded stroke aligned to local +Y before rotation. `local_center` is an XY
## offset from the ellipsoid center; length includes the rounded caps.
static func ellipsoid_capsule(center: Vector3, radii: Vector3,
		local_center: Vector2, length: float, width: float, rotation_degrees: float,
		material: Material, lift := 0.001, cap_segments := 5) -> ArrayMesh:
	assert(length > 0.0 and width > 0.0, "surface decal capsule dimensions must be positive")
	assert(length >= width, "surface decal capsule length must be at least its width")
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
	var inverse_radii := _inverse_radii(radii)
	var inverse_squared_radii := Vector3(
		inverse_radii.x * inverse_radii.x,
		inverse_radii.y * inverse_radii.y,
		inverse_radii.z * inverse_radii.z)
	var radians := deg_to_rad(rotation_degrees)
	var count := local_outline.size()
	var vertices := PackedVector3Array()
	var center_xy := Vector2(center.x, center.y) + local_center
	vertices.append(_front_position(center, radii, inverse_radii,
		inverse_squared_radii, center_xy, lift + height))

	for ring in range(1, radial_rings + 1):
		var ratio := float(ring) / float(radial_rings)
		var ring_height := height * (1.0 - smoothstep(0.0, 1.0, ratio))
		for point in local_outline:
			var xy := Vector2(center.x, center.y) + local_center + \
				(point * ratio).rotated(radians)
			vertices.append(_front_position(center, radii, inverse_radii,
				inverse_squared_radii, xy, lift + ring_height))

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

	return _mesh_from_arrays(vertices, indices, material)

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
	assert(length >= width, "capsule patch length must be at least its width")
	assert(cap_segments >= 3, "capsule patch needs at least three cap segments")
	return ellipsoid_feathered_patch(center, radii, local_center,
		_capsule_outline(length, width, cap_segments), rotation_degrees, material,
		height, lift, radial_rings)
