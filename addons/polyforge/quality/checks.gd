extends RefCounted
## Semantic checks for named PolyForge assemblies.
##
## This module ports the model-regression philosophy and selected geometry algorithms from
## WAM's wam/checks.py and wam/lint.py (Elliott Dehn, used with permission). See NOTICE.md.

const MAX_PROXIMITY_POINTS := 600

static func _indices(arr: Array) -> PackedInt32Array:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var raw = arr[Mesh.ARRAY_INDEX]
	if raw != null and not (raw as PackedInt32Array).is_empty():
		return raw
	var idx := PackedInt32Array()
	idx.resize(verts.size())
	for i in range(idx.size()):
		idx[i] = i
	return idx

static func geometry(part: Dictionary) -> Dictionary:
	var vertices := PackedVector3Array()
	var triangles: Array[PackedInt32Array] = []
	var mesh: Mesh = part.mesh
	var xf: Transform3D = part.get("transform", Transform3D.IDENTITY)
	for si in range(mesh.get_surface_count()):
		if mesh is ArrayMesh and \
				(mesh as ArrayMesh).surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arr := mesh.surface_get_arrays(si)
		var src: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx := _indices(arr)
		var offset := vertices.size()
		for v in src:
			vertices.append(xf * v)
		for ti in range(0, idx.size() - 2, 3):
			triangles.append(PackedInt32Array([
				idx[ti] + offset, idx[ti + 1] + offset, idx[ti + 2] + offset]))
	var bounds := AABB()
	if not vertices.is_empty():
		bounds = AABB(vertices[0], Vector3.ZERO)
		for v in vertices:
			bounds = bounds.expand(v)
	return {"vertices": vertices, "triangles": triangles, "aabb": bounds}

static func build_cache(parts: Array) -> Dictionary:
	var cache := {}
	for part in parts:
		assert(not cache.has(part.name), "duplicate semantic part name: " + part.name)
		cache[part.name] = geometry(part)
	return cache

static func _sample(points: PackedVector3Array, limit := MAX_PROXIMITY_POINTS) -> PackedVector3Array:
	if points.size() <= limit:
		return points
	var out := PackedVector3Array()
	var step := maxi(1, points.size() / limit)
	for i in range(0, points.size(), step):
		out.append(points[i])
	return out

static func gap(a: Dictionary, b: Dictionary) -> float:
	var av := _sample(a.vertices)
	var bv := _sample(b.vertices)
	if av.is_empty() or bv.is_empty():
		return INF
	var best := INF
	for pa in av:
		for pb in bv:
			best = minf(best, pa.distance_to(pb))
	return best

static func _edges(g: Dictionary) -> Array:
	var seen := {}
	var out := []
	for tri in g.triangles:
		for pair in [[tri[0], tri[1]], [tri[1], tri[2]], [tri[2], tri[0]]]:
			var lo: int = mini(pair[0], pair[1])
			var hi: int = maxi(pair[0], pair[1])
			var key := "%d:%d" % [lo, hi]
			if not seen.has(key):
				seen[key] = true
				out.append([g.vertices[lo], g.vertices[hi]])
	return out

static func intersects(a: Dictionary, b: Dictionary) -> bool:
	if a.vertices.is_empty() or b.vertices.is_empty() or not a.aabb.intersects(b.aabb):
		return false
	for edge in _edges(a):
		for tri in b.triangles:
			var hit = Geometry3D.segment_intersects_triangle(
				edge[0], edge[1], b.vertices[tri[0]], b.vertices[tri[1]], b.vertices[tri[2]])
			if hit != null:
				return true
	for edge in _edges(b):
		for tri in a.triangles:
			var hit = Geometry3D.segment_intersects_triangle(
				edge[0], edge[1], a.vertices[tri[0]], a.vertices[tri[1]], a.vertices[tri[2]])
			if hit != null:
				return true
	return false

static func _inside(point: Vector3, solid: Dictionary) -> bool:
	if not solid.aabb.has_point(point):
		return false
	var ray_end := point + Vector3(maxf(solid.aabb.size.x * 2.0, 1.0), 0.000137, 0.000271)
	var crossings := 0
	for tri in solid.triangles:
		var hit = Geometry3D.segment_intersects_triangle(
			point, ray_end, solid.vertices[tri[0]], solid.vertices[tri[1]], solid.vertices[tri[2]])
		if hit != null:
			crossings += 1
	return crossings % 2 == 1

static func buried(inner: Dictionary, outer: Dictionary, sample_limit := 24) -> bool:
	if inner.vertices.is_empty() or outer.vertices.is_empty():
		return false
	if not outer.aabb.encloses(inner.aabb):
		return false
	var samples := _sample(inner.vertices, sample_limit)
	var inside_count := 0
	for point in samples:
		if _inside(point, outer):
			inside_count += 1
	return samples.size() > 0 and float(inside_count) / samples.size() > 0.95

static func asymmetry(g: Dictionary, plane_x := 0.0) -> float:
	var points := _sample(g.vertices)
	if points.is_empty():
		return 0.0
	var worst := 0.0
	for point in points:
		var mirror := Vector3(plane_x * 2.0 - point.x, point.y, point.z)
		var nearest := INF
		for other in points:
			nearest = minf(nearest, mirror.distance_to(other))
		worst = maxf(worst, nearest)
	return worst

static func axis_size(g: Dictionary, axis: int) -> float:
	if g.vertices.is_empty():
		return 0.0
	return [g.aabb.size.x, g.aabb.size.y, g.aabb.size.z][axis]

static func require_gap(a: String, b: String, minimum: float) -> Dictionary:
	return {"type": "gap", "a": a, "b": b, "minimum": minimum}

static func require_no_intersection(a: String, b: String) -> Dictionary:
	return {"type": "no_intersection", "a": a, "b": b}

static func require_not_buried(inner: String, outer: String) -> Dictionary:
	return {"type": "not_buried", "a": inner, "b": outer}

static func require_symmetric(part: String, tolerance: float, plane_x := 0.0) -> Dictionary:
	return {"type": "symmetric", "a": part, "tolerance": tolerance, "plane_x": plane_x}

static func require_axis_ratio(a: String, a_axis: int, b: String, b_axis: int,
		minimum: float, maximum: float) -> Dictionary:
	return {"type": "axis_ratio", "a": a, "a_axis": a_axis, "b": b,
		"b_axis": b_axis, "minimum": minimum, "maximum": maximum}

static func require_axis_size(part: String, axis: int, target: float,
		tolerance: float) -> Dictionary:
	return {"type": "axis_size", "a": part, "axis": axis,
		"target": target, "tolerance": tolerance}

static func require_axis_range(part: String, axis: int, minimum: float,
		maximum := INF) -> Dictionary:
	return {"type": "axis_range", "a": part, "axis": axis,
		"minimum": minimum, "maximum": maximum}

static func measure(cache: Dictionary, rule: Dictionary) -> Dictionary:
	var kind: String = rule.type
	if kind == "gap":
		return {"value": gap(cache[rule.a], cache[rule.b]), "unit": "distance"}
	if kind == "no_intersection":
		return {"value": intersects(cache[rule.a], cache[rule.b]), "unit": "bool"}
	if kind == "not_buried":
		return {"value": buried(cache[rule.a], cache[rule.b]), "unit": "bool"}
	if kind == "symmetric":
		return {"value": asymmetry(cache[rule.a], rule.get("plane_x", 0.0)), "unit": "distance"}
	if kind == "axis_ratio":
		var denom := axis_size(cache[rule.b], rule.b_axis)
		return {"value": axis_size(cache[rule.a], rule.a_axis) / maxf(denom, 0.000000001), "unit": "ratio"}
	if kind == "axis_size" or kind == "axis_range":
		return {"value": axis_size(cache[rule.a], rule.axis), "unit": "distance"}
	return {"value": null, "unit": "unknown"}

static func evaluate(parts: Array, rules: Array) -> Dictionary:
	var cache := build_cache(parts)
	var failures := PackedStringArray()
	var measurements := []
	for rule in rules:
		if not cache.has(rule.a) or (rule.has("b") and not cache.has(rule.b)):
			failures.append("check references an unknown named part: " + str(rule))
			continue
		var result := measure(cache, rule)
		measurements.append({"rule": rule, "value": result.value, "unit": result.unit})
		match rule.type:
			"gap":
				if result.value < rule.minimum:
					failures.append("gap(%s, %s) %.6f < %.6f" % [rule.a, rule.b, result.value, rule.minimum])
			"no_intersection":
				if result.value:
					failures.append("%s intersects %s" % [rule.a, rule.b])
			"not_buried":
				if result.value:
					failures.append("%s is entirely buried in %s" % [rule.a, rule.b])
			"symmetric":
				if result.value > rule.tolerance:
					failures.append("%s asymmetry %.6f > %.6f" % [rule.a, result.value, rule.tolerance])
			"axis_ratio":
				if result.value < rule.minimum or result.value > rule.maximum:
					failures.append("%s/%s axis ratio %.6f outside %.6f..%.6f" % [
						rule.a, rule.b, result.value, rule.minimum, rule.maximum])
			"axis_size":
				if absf(result.value - rule.target) > rule.tolerance:
					failures.append("%s axis %d size %.6f differs from %.6f by more than %.6f" % [
						rule.a, rule.axis, result.value, rule.target, rule.tolerance])
			"axis_range":
				if result.value < rule.minimum or result.value > rule.maximum:
					failures.append("%s axis %d size %.6f outside %.6f..%.6f" % [
						rule.a, rule.axis, result.value, rule.minimum, rule.maximum])
			_:
				failures.append("unknown semantic check type: " + str(rule.type))
	return {"failures": failures, "measurements": measurements, "cache": cache}

## Check every unapproved pair. Attachments and intentionally interpenetrating construction
## can be exempted through Assembly.allow_overlap().
static func noclip(parts: Array) -> PackedStringArray:
	var cache := build_cache(parts)
	var failures := PackedStringArray()
	for ai in range(parts.size()):
		for bi in range(ai + 1, parts.size()):
			var a: Dictionary = parts[ai]
			var b: Dictionary = parts[bi]
			if a.intentional_overlaps.has(b.name) or b.intentional_overlaps.has(a.name):
				continue
			if intersects(cache[a.name], cache[b.name]):
				failures.append("unapproved intersection: %s vs %s" % [a.name, b.name])
	return failures
