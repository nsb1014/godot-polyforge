extends RefCounted
## Deterministic procedural paint operators baked into PolyMesh face colors.
##
## Operator vocabulary and stacking behavior are derived from WAM's procedural texture
## system (wam/texture.py, Elliott Dehn; used with permission). PolyForge deliberately
## starts with vertex-color-compatible face paint so Godot projects need no atlas pipeline.

static func height_gradient(bottom: Color, top: Color, minimum: float, maximum: float) -> Dictionary:
	return {"type": "height_gradient", "bottom": bottom, "top": top,
		"minimum": minimum, "maximum": maximum}

static func normal_gradient(down: Color, up: Color) -> Dictionary:
	return {"type": "normal_gradient", "down": down, "up": up}

static func noise(scale: float, amount: float, seed_offset := 0) -> Dictionary:
	return {"type": "noise", "scale": scale, "amount": amount, "seed": seed_offset}

static func band(axis: Vector3, at: float, width: float, color: Color,
		softness := 0.0) -> Dictionary:
	return {"type": "band", "axis": axis.normalized(), "at": at, "width": width,
		"color": color, "softness": softness}

static func streaks(axis: Vector3, scale: float, amount: float, seed_offset := 0) -> Dictionary:
	return {"type": "streaks", "axis": axis.normalized(), "scale": scale,
		"amount": amount, "seed": seed_offset}

static func planks(axis: Vector3, count: float, seam_width: float, seam: Color) -> Dictionary:
	return {"type": "planks", "axis": axis.normalized(), "count": count,
		"seam_width": seam_width, "seam": seam}

static func bricks(horizontal: Vector3, vertical: Vector3, courses: float,
		ratio: float, seam_width: float, seam: Color) -> Dictionary:
	return {"type": "bricks", "horizontal": horizontal.normalized(),
		"vertical": vertical.normalized(), "courses": courses, "ratio": ratio,
		"seam_width": seam_width, "seam": seam}

static func _centroid(poly, face: PackedInt32Array) -> Vector3:
	var result := Vector3.ZERO
	for vi in face:
		result += poly.verts[vi]
	return result / maxf(face.size(), 1.0)

static func _normal(poly, face: PackedInt32Array) -> Vector3:
	if face.size() < 3:
		return Vector3.UP
	return (poly.verts[face[1]] - poly.verts[face[0]]).cross(
		poly.verts[face[2]] - poly.verts[face[0]]).normalized()

static func _multiply_value(color: Color, value: float) -> Color:
	return Color(clampf(color.r * value, 0.0, 1.0), clampf(color.g * value, 0.0, 1.0),
		clampf(color.b * value, 0.0, 1.0), color.a)

static func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)

## Apply an operator stack in order. Source alpha is always preserved because consumers may
## use COLOR.a for unrelated shader data such as height, masks, or faction blending.
static func apply(poly, operators: Array, seed_value := 0) -> void:
	var noises := {}
	for op in operators:
		if op.type in ["noise", "streaks"]:
			var key := "%s:%s" % [op.type, str(op.get("seed", 0))]
			if not noises.has(key):
				var field := FastNoiseLite.new()
				field.seed = seed_value + int(op.get("seed", 0))
				field.frequency = 1.0 / maxf(float(op.get("scale", 1.0)), 0.0001)
				noises[key] = field
	for fi in range(poly.faces.size()):
		var face: PackedInt32Array = poly.faces[fi]
		var point := _centroid(poly, face)
		var normal := _normal(poly, face)
		var color: Color = poly.face_colors[fi]
		var alpha := color.a
		for op in operators:
			match op.type:
				"height_gradient":
					var t := inverse_lerp(float(op.minimum), float(op.maximum), point.y)
					color = (op.bottom as Color).lerp(op.top, clampf(t, 0.0, 1.0))
				"normal_gradient":
					var t := clampf(normal.y * 0.5 + 0.5, 0.0, 1.0)
					color = (op.down as Color).lerp(op.up, t)
				"noise":
					var key := "noise:%s" % str(op.get("seed", 0))
					var value: float = (noises[key] as FastNoiseLite).get_noise_3dv(point)
					color = _multiply_value(color, 1.0 + value * float(op.amount))
				"streaks":
					var key := "streaks:%s" % str(op.get("seed", 0))
					var axis: Vector3 = op.axis
					var along := point.dot(axis)
					var cross_point := point - axis * along
					var sample := cross_point * 8.0 + axis * along * 0.35
					var value: float = (noises[key] as FastNoiseLite).get_noise_3dv(sample)
					color = _multiply_value(color, 1.0 + value * float(op.amount))
				"band":
					var distance := absf(point.dot(op.axis) - float(op.at))
					var half_width := maxf(float(op.width) * 0.5, 0.000001)
					if distance <= half_width:
						var blend := 1.0
						if float(op.softness) > 0.0:
							blend = clampf((half_width - distance) / float(op.softness), 0.0, 1.0)
						color = color.lerp(op.color, blend)
				"planks":
					var k := point.dot(op.axis) * float(op.count)
					var fraction := fposmod(k, 1.0)
					if fraction < float(op.seam_width) or fraction > 1.0 - float(op.seam_width):
						color = op.seam
				"bricks":
					var row := point.dot(op.vertical) * float(op.courses)
					var row_index := floori(row)
					var row_fraction := fposmod(row, 1.0)
					var column := point.dot(op.horizontal) * float(op.courses) * float(op.ratio)
					column += 0.5 if row_index % 2 != 0 else 0.0
					var column_fraction := fposmod(column, 1.0)
					var width: float = op.seam_width
					if row_fraction < width or row_fraction > 1.0 - width \
							or column_fraction < width or column_fraction > 1.0 - width:
						color = op.seam
		color = _with_alpha(color, alpha)
		poly.face_colors[fi] = color

## Cheap object-space ambient occlusion. Faces become darker when nearby face centroids lie
## in front of their normal. Intended for offline authoring, not per-frame use.
static func ambient_occlusion(poly, radius: float, amount: float) -> void:
	var centers := PackedVector3Array()
	var normals := PackedVector3Array()
	for face in poly.faces:
		centers.append(_centroid(poly, face))
		normals.append(_normal(poly, face))
	for i in range(poly.faces.size()):
		var occlusion := 0.0
		var contributors := 0
		for j in range(poly.faces.size()):
			if i == j:
				continue
			var delta := centers[j] - centers[i]
			var distance := delta.length()
			if distance > 0.000001 and distance < radius:
				occlusion += maxf(0.0, normals[i].dot(delta / distance)) * (1.0 - distance / radius)
				contributors += 1
		var factor := 1.0 - clampf(occlusion / maxf(contributors, 1.0), 0.0, 1.0) * amount
		poly.face_colors[i] = _multiply_value(poly.face_colors[i], factor)
