extends RefCounted
## Surface-aware placement for generated details.
##
## Inspired by WAM's `on=` / `snap_on` workflow in wam/mesh.py at
## https://github.com/elliottdehn/wam/tree/0ac32d599fd8d7c954812136292a19bb0be1a965.
## The closest-point implementation below is adapted to Godot Mesh arrays.

static func closest_point_on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		var bc := c - b
		return b + bc * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom := 1.0 / maxf(va + vb + vc, 0.000000000001)
	var v := vb * denom
	var w := vc * denom
	return a + ab * v + ac * w

static func _indices(arr: Array) -> PackedInt32Array:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var raw = arr[Mesh.ARRAY_INDEX]
	if raw != null and not (raw as PackedInt32Array).is_empty():
		return raw
	var out := PackedInt32Array()
	out.resize(verts.size())
	for i in range(out.size()):
		out[i] = i
	return out

## Returns {valid, position, normal, distance, surface, triangle}. Position and normal are
## in world space. `approximate_position` is an authoring hint, not a precise landing point.
static func closest_point(mesh: Mesh, approximate_position: Vector3,
		host_transform := Transform3D.IDENTITY) -> Dictionary:
	var best := {
		"valid": false,
		"position": approximate_position,
		"normal": Vector3.UP,
		"distance": INF,
		"surface": -1,
		"triangle": -1,
	}
	if mesh == null:
		return best
	for si in range(mesh.get_surface_count()):
		if mesh.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arr := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx := _indices(arr)
		for ti in range(0, idx.size() - 2, 3):
			if idx[ti] < 0 or idx[ti + 1] < 0 or idx[ti + 2] < 0 \
					or idx[ti] >= verts.size() or idx[ti + 1] >= verts.size() or idx[ti + 2] >= verts.size():
				continue
			var a: Vector3 = host_transform * verts[idx[ti]]
			var b: Vector3 = host_transform * verts[idx[ti + 1]]
			var c: Vector3 = host_transform * verts[idx[ti + 2]]
			var normal := (b - a).cross(c - a)
			if normal.length_squared() < 0.000000000001:
				continue
			var point := closest_point_on_triangle(approximate_position, a, b, c)
			var distance := point.distance_to(approximate_position)
			if distance < float(best.distance):
				best = {
					"valid": true,
					"position": point,
					"normal": normal.normalized(),
					"distance": distance,
					"surface": si,
					"triangle": ti / 3,
				}
	return best

## Construct a transform whose local +Y follows the hit normal. `heading_hint` controls
## rotation around the normal. The origin is sunk into the host by `inset`.
static func frame_from_hit(hit: Dictionary, inset := 0.0,
		heading_hint := Vector3.FORWARD) -> Transform3D:
	assert(hit.get("valid", false), "surface attachment needs a valid hit")
	var y: Vector3 = hit.normal.normalized()
	var z := heading_hint - y * heading_hint.dot(y)
	if z.length_squared() < 0.000001:
		var fallback := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
		z = fallback - y * fallback.dot(y)
	z = z.normalized()
	var x := y.cross(z).normalized()
	z = x.cross(y).normalized()
	return Transform3D(Basis(x, y, z), hit.position - y * inset)

static func snap(mesh: Mesh, approximate_position: Vector3, inset := 0.0,
		host_transform := Transform3D.IDENTITY, heading_hint := Vector3.FORWARD) -> Transform3D:
	var hit := closest_point(mesh, approximate_position, host_transform)
	assert(hit.valid, "cannot snap to an empty or non-triangle mesh")
	return frame_from_hit(hit, inset, heading_hint)
