extends RefCounted
## Project-neutral environment generation: authored landforms, surface rules, spline cuts,
## and deterministic constrained prop scattering.
##
## The layer model is derived from WAM's wam/zone.py by Elliott Dehn and is used with
## permission. This is a native GDScript implementation built on PolyForge PolyMesh.

const PolyMesh := preload("../core/mesh.gd")

class Spec extends RefCounted:
	var size := Vector2(100.0, 100.0)
	var resolution := Vector2i(64, 64)
	var seed := 1
	var water_level = -INF
	var landforms: Array[Dictionary] = []
	var surfaces: Array[Dictionary] = []
	var scatters: Array[Dictionary] = []

	func _init(zone_size := Vector2(100.0, 100.0), zone_resolution := Vector2i(64, 64),
			zone_seed := 1) -> void:
		size = zone_size
		resolution = zone_resolution
		seed = zone_seed

	func add_landform(operation: Dictionary) -> Spec:
		landforms.append(operation)
		return self

	func add_surface(rule: Dictionary) -> Spec:
		surfaces.append(rule)
		return self

	func add_scatter(rule: Dictionary) -> Spec:
		scatters.append(rule)
		return self

static func base(height := 0.0) -> Dictionary:
	return {"type": "base", "height": height}

static func hill(center: Vector2, radius: float, height: float, exponent := 2.0) -> Dictionary:
	return {"type": "hill", "center": center, "radius": radius, "height": height,
		"exponent": exponent}

static func plateau(center: Vector2, radius: float, height: float,
		edge_width := 10.0) -> Dictionary:
	return {"type": "plateau", "center": center, "radius": radius, "height": height,
		"edge_width": edge_width}

static func basin(center: Vector2, radius: float, depth: float, exponent := 2.0) -> Dictionary:
	return {"type": "basin", "center": center, "radius": radius, "depth": depth,
		"exponent": exponent}

static func rim(height: float, width: float) -> Dictionary:
	return {"type": "rim", "height": height, "width": width}

static func noise(scale: float, amount: float, seed_offset := 0) -> Dictionary:
	return {"type": "noise", "scale": scale, "amount": amount, "seed": seed_offset}

## A spline modifies terrain inside `width`: negative delta carves a river/trench; a small
## positive delta raises a wall or berm. Points are Vector2(x,z).
static func spline(points: Array[Vector2], width: float, delta: float,
		falloff := 1.0) -> Dictionary:
	return {"type": "spline", "points": points, "width": width, "delta": delta,
		"falloff": falloff}

static func surface_default(tag: String, color := Color.WHITE) -> Dictionary:
	return {"type": "default", "tag": tag, "color": color}

static func surface_slope_above(degrees: float, tag: String, color := Color.WHITE) -> Dictionary:
	return {"type": "slope_above", "degrees": degrees, "tag": tag, "color": color}

static func surface_height(minimum: float, maximum: float, tag: String,
		color := Color.WHITE) -> Dictionary:
	return {"type": "height", "minimum": minimum, "maximum": maximum,
		"tag": tag, "color": color}

static func surface_near_water(distance: float, tag: String, color := Color.WHITE) -> Dictionary:
	return {"type": "near_water", "distance": distance, "tag": tag, "color": color}

static func scatter(asset: String, count: int, options := {}) -> Dictionary:
	return {
		"asset": asset,
		"count": count,
		"minimum_height": options.get("minimum_height", -INF),
		"maximum_height": options.get("maximum_height", INF),
		"maximum_slope": options.get("maximum_slope", 90.0),
		"minimum_spacing": options.get("minimum_spacing", 0.0),
		"scale": options.get("scale", Vector2.ONE),
		"seed": options.get("seed", 0),
	}

static func _smoothstep(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	if denom < 0.000000001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / denom, 0.0, 1.0)
	return point.distance_to(a + ab * t)

static func _distance_to_polyline(point: Vector2, points: Array) -> float:
	var best := INF
	for i in range(points.size() - 1):
		best = minf(best, _distance_to_segment(point, points[i], points[i + 1]))
	return best

static func _noise_fields(spec: Spec) -> Dictionary:
	var fields := {}
	for op in spec.landforms:
		if op.type == "noise":
			var key := str(op.get("seed", 0))
			if not fields.has(key):
				var field := FastNoiseLite.new()
				field.seed = spec.seed + int(op.get("seed", 0))
				field.frequency = 1.0 / maxf(float(op.scale), 0.0001)
				fields[key] = field
	return fields

static func height_at(spec: Spec, x: float, z: float, fields := {}) -> float:
	if fields.is_empty():
		fields = _noise_fields(spec)
	var point := Vector2(x, z)
	var value := 0.0
	for op in spec.landforms:
		match op.type:
			"base":
				value = float(op.height)
			"hill":
				var t := clampf(1.0 - point.distance_to(op.center) / maxf(op.radius, 0.0001), 0.0, 1.0)
				value += float(op.height) * pow(_smoothstep(t), float(op.exponent))
			"plateau":
				var distance := point.distance_to(op.center)
				var edge := maxf(float(op.edge_width), 0.0001)
				var t := clampf((float(op.radius) - distance) / edge + 1.0, 0.0, 1.0)
				value += float(op.height) * _smoothstep(t)
			"basin":
				var t := clampf(1.0 - point.distance_to(op.center) / maxf(op.radius, 0.0001), 0.0, 1.0)
				value -= float(op.depth) * pow(_smoothstep(t), float(op.exponent))
			"rim":
				var half := spec.size * 0.5
				var edge_distance := minf(half.x - absf(x), half.y - absf(z))
				var t := 1.0 - clampf(edge_distance / maxf(float(op.width), 0.0001), 0.0, 1.0)
				value += float(op.height) * _smoothstep(t)
			"noise":
				var field: FastNoiseLite = fields[str(op.get("seed", 0))]
				value += field.get_noise_2d(x, z) * float(op.amount)
			"spline":
				var distance := _distance_to_polyline(point, op.points)
				var t := clampf(1.0 - distance / maxf(float(op.width), 0.0001), 0.0, 1.0)
				value += float(op.delta) * pow(_smoothstep(t), float(op.falloff))
	return value

static func _face_center(poly, face: PackedInt32Array) -> Vector3:
	var center := Vector3.ZERO
	for vi in face:
		center += poly.verts[vi]
	return center / maxf(face.size(), 1.0)

static func _face_normal(poly, face: PackedInt32Array) -> Vector3:
	return (poly.verts[face[1]] - poly.verts[face[0]]).cross(
		poly.verts[face[2]] - poly.verts[face[0]]).normalized()

static func _surface_for(spec: Spec, center: Vector3, normal: Vector3) -> Dictionary:
	var selected := {"tag": "", "color": Color.WHITE}
	var slope := rad_to_deg(acos(clampf(normal.dot(Vector3.UP), -1.0, 1.0)))
	for rule in spec.surfaces:
		var matches := false
		match rule.type:
			"default":
				matches = true
			"slope_above":
				matches = slope > float(rule.degrees)
			"height":
				matches = center.y >= float(rule.minimum) and center.y <= float(rule.maximum)
			"near_water":
				matches = spec.water_level > -INF and absf(center.y - spec.water_level) <= float(rule.distance)
		if matches:
			selected = {"tag": rule.tag, "color": rule.color}
	return selected

static func build_terrain(spec: Spec):
	var fields := _noise_fields(spec)
	var poly = PolyMesh.heightfield(spec.size, spec.resolution,
		func(x: float, z: float): return height_at(spec, x, z, fields))
	for fi in range(poly.faces.size()):
		var center := _face_center(poly, poly.faces[fi])
		var normal := _face_normal(poly, poly.faces[fi])
		var surface := _surface_for(spec, center, normal)
		poly.face_tags[fi] = surface.tag
		poly.face_colors[fi] = surface.color
	return poly

static func normal_at(spec: Spec, x: float, z: float, fields := {}) -> Vector3:
	var step := minf(spec.size.x / maxf(spec.resolution.x, 1.0),
		spec.size.y / maxf(spec.resolution.y, 1.0)) * 0.5
	var left := height_at(spec, x - step, z, fields)
	var right := height_at(spec, x + step, z, fields)
	var back := height_at(spec, x, z - step, fields)
	var forward := height_at(spec, x, z + step, fields)
	return Vector3(left - right, step * 2.0, back - forward).normalized()

## Returns deterministic placement records {asset, transform, scale}. A caller can turn
## these into MeshInstance3D, MultiMeshInstance3D, PackedScene children, or another format.
static func scatter_placements(spec: Spec) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	var fields := _noise_fields(spec)
	for rule in spec.scatters:
		var rng := RandomNumberGenerator.new()
		rng.seed = spec.seed + int(rule.seed)
		var accepted: Array[Vector2] = []
		var attempts := 0
		while accepted.size() < int(rule.count) and attempts < int(rule.count) * 40:
			attempts += 1
			var x := rng.randf_range(-spec.size.x * 0.5, spec.size.x * 0.5)
			var z := rng.randf_range(-spec.size.y * 0.5, spec.size.y * 0.5)
			var y := height_at(spec, x, z, fields)
			if y < float(rule.minimum_height) or y > float(rule.maximum_height):
				continue
			var normal := normal_at(spec, x, z, fields)
			var slope := rad_to_deg(acos(clampf(normal.dot(Vector3.UP), -1.0, 1.0)))
			if slope > float(rule.maximum_slope):
				continue
			var point := Vector2(x, z)
			var spaced := true
			for prior in accepted:
				if point.distance_to(prior) < float(rule.minimum_spacing):
					spaced = false
					break
			if not spaced:
				continue
			accepted.append(point)
			var scale_range: Vector2 = rule.scale
			var uniform_scale := rng.randf_range(scale_range.x, scale_range.y)
			placements.append({
				"asset": rule.asset,
				"transform": Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), Vector3(x, y, z)),
				"scale": uniform_scale,
				"normal": normal,
			})
	return placements
