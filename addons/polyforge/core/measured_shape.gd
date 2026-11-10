extends RefCounted
## Shape definitions remain independent of tessellation. Distances use model units.
## Elliptical lofts interpolate measured stations linearly. Cubic curves use a
## second-derivative (Taylor remainder) bound for their chord approximation.

const PolyMesh := preload("mesh.gd")

static func bezier(control: Array, t: float) -> Vector3:
	var u := 1.0 - t
	return control[0] * u * u * u + control[1] * 3.0 * u * u * t + \
		control[2] * 3.0 * u * t * t + control[3] * t * t * t

static func sample_curve(control: Array, tolerance: float, max_depth := 12) -> Dictionary:
	if control.size() != 4 or not is_finite(tolerance) or tolerance <= 0.0 or \
			max_depth < 0 or max_depth > 16:
		return {"ok": false, "error": "Expected four controls, positive tolerance, depth 0..16"}
	for point in control:
		if not point is Vector3 or not point.is_finite():
			return {"ok": false, "error": "Curve controls must be finite Vector3 values"}
	var points: Array = [control[0]]
	var parameters: Array = [0.0]
	var pending: Array = [{"control": control, "start": 0.0, "end": 1.0, "depth": 0}]
	var maximum_bound := 0.0
	while not pending.is_empty():
		var interval: Dictionary = pending.pop_back()
		var c: Array = interval.control
		# For a C2 curve, deviation from its linear interpolant <= max|B''|/8.
		# B'' is linear on a cubic Bezier, so the maximum norm is at an endpoint.
		var bound := 0.75 * maxf((c[2] - 2.0 * c[1] + c[0]).length(),
			(c[3] - 2.0 * c[2] + c[1]).length())
		if bound <= tolerance:
			points.append(c[3])
			parameters.append(interval.end)
			maximum_bound = maxf(maximum_bound, bound)
			continue
		if interval.depth == max_depth:
			return {"ok": false, "error": "Curve subdivision limit cannot meet tolerance"}
		var a: Vector3 = (c[0] + c[1]) * 0.5
		var b: Vector3 = (c[1] + c[2]) * 0.5
		var d: Vector3 = (c[2] + c[3]) * 0.5
		var e := (a + b) * 0.5
		var f := (b + d) * 0.5
		var midpoint := (e + f) * 0.5
		var middle_t: float = (interval.start + interval.end) * 0.5
		pending.append({"control": [midpoint, f, d, c[3]], "start": middle_t,
			"end": interval.end, "depth": interval.depth + 1})
		pending.append({"control": [c[0], a, e, midpoint], "start": interval.start,
			"end": middle_t, "depth": interval.depth + 1})
	return {"ok": true, "points": points, "parameters": parameters,
		"maximum_chord_error_bound": maximum_bound, "tolerance": tolerance}

static func radial_segments(radius: float, tolerance: float) -> int:
	assert(is_finite(radius) and radius > 0.0 and is_finite(tolerance) and tolerance > 0.0)
	# A multiple of four preserves measured X/Z extrema on every elliptical station.
	var angle := acos(clampf(1.0 - tolerance / radius, -1.0, 1.0))
	assert(angle > 0.0, "Tolerance is below floating-point resolution")
	return maxi(8, ceili(PI / angle / 4.0) * 4)

static func section_at(stations: Array, height: float) -> Vector3:
	assert(stations.size() >= 2 and height >= stations.front().y and height <= stations.back().y)
	for index in range(1, stations.size()):
		var before: Vector3 = stations[index - 1]
		var after: Vector3 = stations[index]
		if height <= after.y:
			return before.lerp(after, (height - before.y) / (after.y - before.y))
	return stations.back()

static func arc_tube(center: Vector3, axis: Vector3, radial: Vector3,
		bend_radius: float, tube_radius: float, start_angle: float, end_angle: float,
		tolerance: float):
	assert(center.is_finite() and axis.is_finite() and radial.is_finite())
	assert(axis.length() > 0.0 and tube_radius > 0.0 and bend_radius > tube_radius)
	assert(is_finite(start_angle) and is_finite(end_angle) and
		absf(end_angle - start_angle) > 0.0 and absf(end_angle - start_angle) < TAU)
	var normal := axis.normalized()
	var first := (radial - normal * radial.dot(normal)).normalized()
	assert(not first.is_zero_approx(), "Arc radial direction must be perpendicular to its axis")
	var second := normal.cross(first)
	var steps := maxi(2, ceili(absf(end_angle - start_angle) / TAU *
		radial_segments(bend_radius, tolerance)))
	var path: Array = []
	var section: Array = []
	for index in range(steps + 1):
		var angle := lerpf(start_angle, end_angle, float(index) / steps)
		path.append(center + bend_radius * (first * cos(angle) + second * sin(angle)))
	var sides := radial_segments(tube_radius, tolerance)
	for side in range(sides):
		var angle := TAU * float(side) / sides
		section.append(Vector2(cos(angle), sin(angle)) * tube_radius)
	return PolyMesh.sweep(section, path)

static func loft_band(stations: Array, start: Vector2, end: Vector2,
		width: float, offset: float, thickness: float):
	assert(width > 0.0 and thickness > 0.0 and start.distance_to(end) > 0.0)
	var across := (end - start).normalized().orthogonal() * width * 0.5
	var steps := maxi(2, ceili(start.distance_to(end) / (width * 0.5)))
	var mesh = PolyMesh.new()
	for index in range(steps + 1):
		var center := start.lerp(end, float(index) / steps)
		for depth in [offset, offset + thickness]:
			for point in [center - across, center + across]:
				var radii := section_at(stations, point.y)
				assert(absf(point.x) < radii.x, "Band must stay on the front of its loft")
				var z := radii.z * sqrt(1.0 - pow(point.x / radii.x, 2))
				mesh.verts.append(Vector3(point.x, point.y, z + depth))
	for index in range(steps):
		var a := index * 4
		var b := a + 4
		mesh.add_face(PackedInt32Array([a, b, b + 1, a + 1]))
		mesh.add_face(PackedInt32Array([a + 2, a + 3, b + 3, b + 2]))
		mesh.add_face(PackedInt32Array([a, a + 2, b + 2, b]))
		mesh.add_face(PackedInt32Array([a + 1, b + 1, b + 3, a + 3]))
	mesh.add_face(PackedInt32Array([0, 1, 3, 2]))
	var last := steps * 4
	mesh.add_face(PackedInt32Array([last, last + 2, last + 3, last + 1]))
	return mesh

static func loft(stations: Array, tolerance: float):
	assert(stations.size() >= 2, "Loft requires at least two measured stations")
	var radius := 0.0
	for i in range(stations.size()):
		var station: Vector3 = stations[i] # radius X, height Y, radius Z
		assert(station.is_finite() and station.x > 0.0 and station.z > 0.0)
		assert(i == 0 or station.y > (stations[i - 1] as Vector3).y)
		radius = maxf(radius, maxf(station.x, station.z))
	var sides := radial_segments(radius, tolerance)
	var mesh = PolyMesh.new()
	for station in stations:
		for side in range(sides):
			var angle := TAU * float(side) / sides
			mesh.verts.append(Vector3(station.x * cos(angle), station.y,
				station.z * sin(angle)))
	for ring in range(stations.size() - 1):
		for side in range(sides):
			var next := (side + 1) % sides
			mesh.add_face(PackedInt32Array([ring * sides + side,
				(ring + 1) * sides + side, (ring + 1) * sides + next, ring * sides + next]))
	var bottom := PackedInt32Array()
	var top := PackedInt32Array()
	for side in range(sides):
		bottom.append(side)
		top.append(stations.size() * sides - 1 - side)
	mesh.add_face(bottom)
	mesh.add_face(top)
	return mesh

static func curved_tube(control: Array, start_radius: float, end_radius: float,
		tolerance: float) -> Dictionary:
	if not is_finite(start_radius) or not is_finite(end_radius) or \
			start_radius <= 0.0 or end_radius <= 0.0:
		return {"ok": false, "error": "Tube radii must be finite and positive"}
	var sampled := sample_curve(control, tolerance)
	if not sampled.ok:
		return sampled
	for i in range(1, sampled.points.size()):
		if sampled.points[i].distance_to(sampled.points[i - 1]) < 0.0000001:
			return {"ok": false, "error": "Tube contains a zero-length sampled segment"}
	for i in range(1, sampled.points.size() - 1):
		var incoming: Vector3 = (sampled.points[i] - sampled.points[i - 1]).normalized()
		var outgoing: Vector3 = (sampled.points[i + 1] - sampled.points[i]).normalized()
		if incoming.dot(outgoing) < -0.999999:
			return {"ok": false, "error": "Tube contains a reversing cusp"}
	var sides := radial_segments(maxf(start_radius, end_radius), tolerance)
	var section: Array = []
	for side in range(sides):
		var angle := TAU * float(side) / sides
		section.append(Vector2(cos(angle), sin(angle)))
	var radii: Array = []
	for t in sampled.parameters:
		radii.append(lerpf(start_radius, end_radius, t))
	var scale_at := func(t: float) -> float:
		return radii[roundi(t * (radii.size() - 1))]
	sampled.mesh = PolyMesh.sweep(section, sampled.points, scale_at, false)
	# Center fans avoid thin sliver triangles at small tapered end caps.
	for endpoint in [0, sampled.points.size() - 1]:
		var center_index: int = sampled.mesh.verts.size()
		sampled.mesh.verts.append(sampled.points[endpoint])
		for side in range(sides):
			var a: int = endpoint * sides + side
			var b: int = endpoint * sides + (side + 1) % sides
			var face := [center_index, b, a] if endpoint == 0 else [center_index, a, b]
			sampled.mesh.add_face(PackedInt32Array(face))
	sampled.radial_segments = sides
	sampled.radial_error_bound = maxf(start_radius, end_radius) * (1.0 - cos(PI / sides))
	# Bounds describe the centerline and individual rings, not a full tube Hausdorff bound.
	return sampled

static func extruded_profile(outline: PackedVector2Array, depth: float):
	assert(outline.size() >= 3 and is_finite(depth) and depth > 0.0)
	var polygon := outline.duplicate()
	if Geometry2D.is_polygon_clockwise(polygon):
		polygon.reverse()
	var triangles := Geometry2D.triangulate_polygon(polygon)
	assert(not triangles.is_empty(), "Profile must be a simple triangulable polygon")
	var mesh = PolyMesh.new()
	var count := polygon.size()
	for z in [-depth * 0.5, depth * 0.5]:
		for point in polygon:
			mesh.verts.append(Vector3(point.x, point.y, z))
	for i in range(0, triangles.size(), 3):
		var a := triangles[i]
		var b := triangles[i + 1]
		var c := triangles[i + 2]
		mesh.add_face(PackedInt32Array([a, c, b]))
		mesh.add_face(PackedInt32Array([a + count, b + count, c + count]))
	for i in range(count):
		var next := (i + 1) % count
		mesh.add_face(PackedInt32Array([i, next, next + count, i + count]))
	return mesh
