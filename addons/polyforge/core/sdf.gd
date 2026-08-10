extends RefCounted
## PolyForge SDF module — Callable-based signed distance fields (negative inside)
## + a coarse surface-nets polygonizer that emits chunky low-poly PolyMesh shells.
## Use for forms that must melt together (clouds, rock undersides, slag).

const _MESH := preload("mesh.gd")   # relative: forge/ works at any project path

const _CELL_EDGES := [
	[Vector3i(0, 0, 0), Vector3i(1, 0, 0)], [Vector3i(0, 1, 0), Vector3i(1, 1, 0)],
	[Vector3i(0, 0, 1), Vector3i(1, 0, 1)], [Vector3i(0, 1, 1), Vector3i(1, 1, 1)],
	[Vector3i(0, 0, 0), Vector3i(0, 1, 0)], [Vector3i(1, 0, 0), Vector3i(1, 1, 0)],
	[Vector3i(0, 0, 1), Vector3i(0, 1, 1)], [Vector3i(1, 0, 1), Vector3i(1, 1, 1)],
	[Vector3i(0, 0, 0), Vector3i(0, 0, 1)], [Vector3i(1, 0, 0), Vector3i(1, 0, 1)],
	[Vector3i(0, 1, 0), Vector3i(0, 1, 1)], [Vector3i(1, 1, 0), Vector3i(1, 1, 1)],
]

static func sphere(r: float) -> Callable:
	return func(p: Vector3) -> float: return p.length() - r

static func box(half: Vector3) -> Callable:
	return func(p: Vector3) -> float:
		var q := p.abs() - half
		return Vector3(maxf(q.x, 0.0), maxf(q.y, 0.0), maxf(q.z, 0.0)).length() \
			+ minf(maxf(q.x, maxf(q.y, q.z)), 0.0)

## Box with radius-r rounded edges/corners. `half` is the OUTER half-extent; the base
## box is inset by r so the rounded solid keeps that outer size. Needs each half >= r.
static func round_box(half: Vector3, r: float) -> Callable:
	var inner: Vector3 = half - Vector3(r, r, r)
	return func(p: Vector3) -> float:
		var q := p.abs() - inner
		return Vector3(maxf(q.x, 0.0), maxf(q.y, 0.0), maxf(q.z, 0.0)).length() \
			+ minf(maxf(q.x, maxf(q.y, q.z)), 0.0) - r

## Flat-top hexagonal prism in XZ (vertices on +/-X),
## extruded +/-half_height along Y, with radius-r rounded edges. `circumradius` is the
## OUTER vertex radius; the 3 edge-normal pairs (30/90/150 deg) bound the hex, inset by r
## so the rounded solid keeps that outer size. round_r = 0.0 gives a crisp prism.
static func hex_prism(circumradius: float, half_height: float, round_r := 0.0) -> Callable:
	var apo: float = circumradius * cos(PI / 6.0) - round_r   # center->edge, inset by round
	var hh: float = half_height - round_r
	return func(p: Vector3) -> float:
		var d2: float = maxf(maxf(absf(0.8660254 * p.x + 0.5 * p.z), absf(p.z)),
			absf(-0.8660254 * p.x + 0.5 * p.z)) - apo
		var dy: float = absf(p.y) - hh
		return Vector2(maxf(d2, 0.0), maxf(dy, 0.0)).length() + minf(maxf(d2, dy), 0.0) - round_r

static func capsule(a: Vector3, b: Vector3, r: float) -> Callable:
	return func(p: Vector3) -> float:
		var pa := p - a
		var ba := b - a
		var h: float = clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
		return (pa - ba * h).length() - r

static func translate(sdf: Callable, off: Vector3) -> Callable:
	return func(p: Vector3) -> float: return sdf.call(p - off)

## Non-uniform stretch (breaks exact distances slightly; fine for polygonizing).
static func stretch(sdf: Callable, s: Vector3) -> Callable:
	var comp: float = minf(s.x, minf(s.y, s.z))
	return func(p: Vector3) -> float: return sdf.call(Vector3(p.x / s.x, p.y / s.y, p.z / s.z)) * comp

static func union_of(a: Callable, b: Callable) -> Callable:
	return func(p: Vector3) -> float: return minf(a.call(p), b.call(p))

static func smooth_union(a: Callable, b: Callable, k: float) -> Callable:
	return func(p: Vector3) -> float:
		var da: float = a.call(p)
		var db: float = b.call(p)
		var h: float = clampf(0.5 + 0.5 * (db - da) / k, 0.0, 1.0)
		return lerpf(db, da, h) - k * h * (1.0 - h)

static func subtract(a: Callable, b: Callable) -> Callable:
	return func(p: Vector3) -> float: return maxf(a.call(p), -b.call(p))

static func intersect(a: Callable, b: Callable) -> Callable:
	return func(p: Vector3) -> float: return maxf(a.call(p), b.call(p))

static func warp(sdf: Callable, seed_val: int, amp: float, freq: float) -> Callable:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.frequency = freq
	return func(p: Vector3) -> float: return sdf.call(p) + noise.get_noise_3dv(p) * amp

## Surface nets on a regular grid. Coarse `cell` is a feature: chunky low-poly shells.
## Pad `bounds` at least 2 cells past the surface or the shell is clipped open.
static func polygonize(sdf: Callable, bounds: AABB, cell: float):
	var pm = _MESH.new()
	var n := Vector3i(
		maxi(1, int(ceil(bounds.size.x / cell))),
		maxi(1, int(ceil(bounds.size.y / cell))),
		maxi(1, int(ceil(bounds.size.z / cell))))
	var cy: int = n.y + 1
	var cz: int = n.z + 1
	var field := PackedFloat32Array()
	field.resize((n.x + 1) * cy * cz)
	for i in range(n.x + 1):
		for j in range(cy):
			for k in range(cz):
				field[(i * cy + j) * cz + k] = sdf.call(bounds.position + Vector3(i, j, k) * cell)
	# one vertex per sign-change cell: mean of the cell's edge crossings
	var cell_vert := {}
	for i in range(n.x):
		for j in range(n.y):
			for k in range(n.z):
				var sum := Vector3.ZERO
				var cnt := 0
				for e in _CELL_EDGES:
					var ea: Vector3i = Vector3i(i, j, k) + (e[0] as Vector3i)
					var eb: Vector3i = Vector3i(i, j, k) + (e[1] as Vector3i)
					var da := field[(ea.x * cy + ea.y) * cz + ea.z]
					var db := field[(eb.x * cy + eb.y) * cz + eb.z]
					if (da < 0.0) == (db < 0.0):
						continue
					var t: float = 0.5 if absf(da - db) < 0.000001 else da / (da - db)
					sum += Vector3(ea) + (Vector3(eb) - Vector3(ea)) * t
					cnt += 1
				if cnt == 0:
					continue
				cell_vert[Vector3i(i, j, k)] = pm.verts.size()
				pm.verts.append(bounds.position + (sum / cnt) * cell)
	# quads: one per interior lattice edge with a sign change, joining the 4 cells around it.
	# Winding chosen so faces point from inside (negative field) toward outside.
	for i in range(n.x):
		for j in range(1, n.y):
			for k in range(1, n.z):
				var da := field[(i * cy + j) * cz + k]
				var db := field[((i + 1) * cy + j) * cz + k]
				if (da < 0.0) == (db < 0.0):
					continue
				_edge_quad(pm, cell_vert,
					[Vector3i(i, j - 1, k - 1), Vector3i(i, j, k - 1), Vector3i(i, j, k), Vector3i(i, j - 1, k)],
					da < 0.0)
	for j in range(n.y):
		for i in range(1, n.x):
			for k in range(1, n.z):
				var da := field[(i * cy + j) * cz + k]
				var db := field[(i * cy + j + 1) * cz + k]
				if (da < 0.0) == (db < 0.0):
					continue
				_edge_quad(pm, cell_vert,
					[Vector3i(i - 1, j, k - 1), Vector3i(i - 1, j, k), Vector3i(i, j, k), Vector3i(i, j, k - 1)],
					da < 0.0)
	for k in range(n.z):
		for i in range(1, n.x):
			for j in range(1, n.y):
				var da := field[(i * cy + j) * cz + k]
				var db := field[(i * cy + j) * cz + k + 1]
				if (da < 0.0) == (db < 0.0):
					continue
				_edge_quad(pm, cell_vert,
					[Vector3i(i - 1, j - 1, k), Vector3i(i, j - 1, k), Vector3i(i, j, k), Vector3i(i - 1, j, k)],
					da < 0.0)
	return pm

static func _edge_quad(pm, cell_vert: Dictionary, cells: Array, flip: bool) -> void:
	var f := PackedInt32Array()
	var order: Array = [0, 1, 2, 3] if flip else [3, 2, 1, 0]
	for oi in order:
		var key: Vector3i = cells[oi]
		if not cell_vert.has(key):
			return
		f.append(cell_vert[key])
	pm.add_face(f)
