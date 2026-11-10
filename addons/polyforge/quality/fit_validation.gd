extends RefCounted
## Independent measurements of emitted geometry for nested armor and handle grips.

static func cylinder_clearance(geometry: Dictionary, center: Vector3,
		axis: Vector3, radius: float) -> float:
	if axis.is_zero_approx() or radius <= 0.0 or geometry.triangles.is_empty():
		return -INF
	var normal := axis.normalized()
	var reference := Vector3.UP if absf(normal.y) < .9 else Vector3.RIGHT
	var x_axis := normal.cross(reference).normalized()
	var y_axis := normal.cross(x_axis)
	var minimum := INF
	# Project each filled triangle onto the plane perpendicular to the handle.
	# Distance to that projected triangle is the exact distance to the infinite axis.
	for triangle in geometry.triangles:
		var polygon := PackedVector2Array()
		for index in triangle:
			var offset: Vector3 = geometry.vertices[index] - center
			polygon.append(Vector2(offset.dot(x_axis), offset.dot(y_axis)))
		if Geometry2D.is_point_in_polygon(Vector2.ZERO, polygon):
			return -radius
		for edge in range(3):
			var nearest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO,
				polygon[edge], polygon[(edge + 1) % 3])
			minimum = minf(minimum, nearest.length())
	return minimum - radius

static func _local_vertices(geometry: Dictionary, inverse: Transform3D) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	for vertex in geometry.vertices:
		vertices.append(inverse * vertex)
	return vertices

static func _radius(vertices: PackedVector3Array, triangles: Array,
		origin: Vector3, direction: Vector3) -> float:
	var nearest := INF
	for triangle in triangles:
		var a := vertices[triangle[0]]
		var edge1 := vertices[triangle[1]] - a
		var edge2 := vertices[triangle[2]] - a
		var cross := direction.cross(edge2)
		var determinant := edge1.dot(cross)
		if absf(determinant) < 0.0000000001:
			continue
		var offset := origin - a
		var u := offset.dot(cross) / determinant
		var q := offset.cross(edge1)
		var v := direction.dot(q) / determinant
		var distance := edge2.dot(q) / determinant
		# Include shared triangle edges despite transform roundoff.
		if u >= -.00001 and v >= -.00001 and u + v <= 1.00001 and distance >= 0.0:
			nearest = minf(nearest, distance)
	return nearest

static func shell_clearance(inner: Dictionary, outer: Dictionary,
		frame: Transform3D, start: float, end: float) -> float:
	if end <= start or inner.triangles.is_empty() or outer.triangles.is_empty():
		return -INF
	var inverse := frame.affine_inverse()
	var inner_vertices := _local_vertices(inner, inverse)
	var outer_vertices := _local_vertices(outer, inverse)
	var heights: Array = []
	for index in range(9):
		heights.append(lerpf(start, end, .0001 + .9998 * float(index) / 8))
	# Include emitted stations as well as uniform samples, so taper changes are tested.
	var seen_stations := {}
	for vertex in inner_vertices:
		var station_key := roundi((vertex.y - start) / (end - start) * 100000)
		if station_key > 0 and station_key < 100000 and not seen_stations.has(station_key):
			seen_stations[station_key] = true
			heights.append(lerpf(start, end, float(station_key) / 100000))
	var minimum := INF
	for height in heights:
		for index in range(32):
			var angle := TAU * float(index) / 32
			var origin := Vector3(0, height, 0)
			var direction := Vector3(cos(angle), 0, sin(angle))
			var inner_radius := _radius(inner_vertices, inner.triangles, origin, direction)
			var outer_radius := _radius(outer_vertices, outer.triangles, origin, direction)
			if not is_finite(inner_radius) or not is_finite(outer_radius):
				return -INF
			minimum = minf(minimum, outer_radius - inner_radius)
	return minimum
