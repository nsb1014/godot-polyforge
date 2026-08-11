extends RefCounted
## Project-neutral structural lint for PolyForge meshes.
##
## The semantic checks in this module were expanded after studying WAM's lint pipeline
## (https://github.com/elliottdehn/wam, commit 0ac32d599fd8d7c954812136292a19bb0be1a965).
## Reused concepts are credited in NOTICE.md; this implementation targets Godot Mesh data.

const AREA_EPSILON := 0.0000000001

static func triangle_count(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var total := 0
	for si in range(mesh.get_surface_count()):
		var arr: Array = mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var raw_idx = arr[Mesh.ARRAY_INDEX]
		if raw_idx == null or (raw_idx as PackedInt32Array).is_empty():
			total += verts.size() / 3
		else:
			total += (raw_idx as PackedInt32Array).size() / 3
	return total

static func polymesh_triangle_count(poly) -> int:
	var total := 0
	for face in poly.faces:
		total += maxi(0, (face as PackedInt32Array).size() - 2)
	return total

static func _finite(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)

static func _edge_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]

## Validate PolyMesh before emission, while polygon topology and material ownership still
## exist. This catches failures that are hidden after fan triangulation/unwelding.
static func check_polymesh(poly, tri_budget: int = -1, require_closed := false) -> PackedStringArray:
	var fails := PackedStringArray()
	if poly == null or poly.verts.is_empty() or poly.faces.is_empty():
		fails.append("empty PolyMesh")
		return fails
	for vi in range(poly.verts.size()):
		if not _finite(poly.verts[vi]):
			fails.append("vertex %d is non-finite" % vi)
	var edges := {} # undirected edge -> [uses, signed direction sum]
	for fi in range(poly.faces.size()):
		var face: PackedInt32Array = poly.faces[fi]
		if face.size() < 3:
			fails.append("face %d has fewer than 3 vertices" % fi)
			continue
		var seen := {}
		var valid := true
		for vi in face:
			if vi < 0 or vi >= poly.verts.size():
				fails.append("face %d references out-of-range vertex %d" % [fi, vi])
				valid = false
			elif seen.has(vi):
				fails.append("face %d repeats vertex %d" % [fi, vi])
			seen[vi] = true
		if not valid:
			continue
		var p0: Vector3 = poly.verts[face[0]]
		for ti in range(1, face.size() - 1):
			var p1: Vector3 = poly.verts[face[ti]]
			var p2: Vector3 = poly.verts[face[ti + 1]]
			if (p1 - p0).cross(p2 - p0).length_squared() * 0.25 < AREA_EPSILON:
				fails.append("face %d emits a degenerate triangle" % fi)
				break
		for ei in range(face.size()):
			var a: int = face[ei]
			var b: int = face[(ei + 1) % face.size()]
			if a == b:
				continue
			var key := _edge_key(a, b)
			var stat: Array = edges.get(key, [0, 0])
			stat[0] += 1
			stat[1] += 1 if a < b else -1
			edges[key] = stat
	var open_edges := 0
	var inconsistent := 0
	var nonmanifold := 0
	for key in edges:
		var stat: Array = edges[key]
		if stat[0] == 1:
			open_edges += 1
		elif stat[0] == 2 and stat[1] != 0:
			inconsistent += 1
		elif stat[0] > 2:
			nonmanifold += 1
	if inconsistent > 0:
		fails.append("%d shared edges have inconsistent winding" % inconsistent)
	if nonmanifold > 0:
		fails.append("%d non-manifold edges are used by more than two faces" % nonmanifold)
	if require_closed and open_edges > 0:
		fails.append("mesh is open at %d boundary edges" % open_edges)
	if poly.face_colors.size() != poly.faces.size():
		fails.append("face color count does not match face count")
	if poly.face_tags.size() != poly.faces.size():
		fails.append("face tag count does not match face count")
	var triangles := polymesh_triangle_count(poly)
	if tri_budget > 0 and triangles > tri_budget:
		fails.append("triangle budget: %d triangles > %d" % [triangles, tri_budget])
	return fails

## Structural checks on emitted ArrayMesh data. Indexed and unindexed triangle surfaces
## are supported. Open surfaces are valid; use check_polymesh(..., true) for closed solids.
static func check_mesh(mesh: Mesh, tri_budget: int = -1) -> PackedStringArray:
	var fails := PackedStringArray()
	if mesh == null or mesh.get_surface_count() == 0:
		fails.append("empty mesh")
		return fails
	for si in range(mesh.get_surface_count()):
		if mesh.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
			fails.append("surface %d is not a triangle list" % si)
			continue
		var arr: Array = mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var raw_idx = arr[Mesh.ARRAY_INDEX]
		var idx := PackedInt32Array()
		if raw_idx == null or (raw_idx as PackedInt32Array).is_empty():
			if verts.size() % 3 != 0:
				fails.append("surface %d unindexed triangle list has %d vertices" % [si, verts.size()])
			idx.resize(verts.size())
			for i in range(idx.size()):
				idx[i] = i
		else:
			idx = raw_idx
			if idx.size() % 3 != 0:
				fails.append("surface %d index count %d is not divisible by 3" % [si, idx.size()])
		for vi in range(verts.size()):
			if not _finite(verts[vi]):
				fails.append("surface %d vertex %d is non-finite" % [si, vi])
				break
		for ii in idx:
			if ii < 0 or ii >= verts.size():
				fails.append("surface %d has out-of-range index %d" % [si, ii])
				break
		for ti in range(0, idx.size() - 2, 3):
			if idx[ti] < 0 or idx[ti + 1] < 0 or idx[ti + 2] < 0 \
					or idx[ti] >= verts.size() or idx[ti + 1] >= verts.size() or idx[ti + 2] >= verts.size():
				continue
			var a := verts[idx[ti]]
			var b := verts[idx[ti + 1]]
			var c := verts[idx[ti + 2]]
			if (b - a).cross(c - a).length_squared() * 0.25 < AREA_EPSILON:
				fails.append("surface %d has a degenerate triangle at index %d" % [si, ti / 3])
				break
		if arr[Mesh.ARRAY_COLOR] != null:
			var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
			if cols.size() != verts.size():
				fails.append("surface %d color count does not match vertex count" % si)
			for c in cols:
				if c.a < -0.001 or c.a > 1.001:
					fails.append("surface %d COLOR.a out of [0,1]" % si)
					break
	var triangles := triangle_count(mesh)
	if tri_budget > 0 and triangles > tri_budget:
		fails.append("triangle budget: %d triangles > %d" % [triangles, tri_budget])
	return fails

## Two independent builds must emit identical geometry and attributes.
static func check_determinism(a: ArrayMesh, b: ArrayMesh) -> PackedStringArray:
	var fails := PackedStringArray()
	if a == null or b == null:
		fails.append("determinism check got a null build")
		return fails
	if a.get_surface_count() != b.get_surface_count():
		fails.append("non-deterministic surface count on rebuild")
		return fails
	for si in range(a.get_surface_count()):
		var aa: Array = a.surface_get_arrays(si)
		var ba: Array = b.surface_get_arrays(si)
		for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
			if aa[slot] != ba[slot]:
				fails.append("non-deterministic array slot %d on surface %d" % [slot, si])
				return fails
	return fails
