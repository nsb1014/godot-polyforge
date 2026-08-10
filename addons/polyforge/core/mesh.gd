extends RefCounted
## PolyMesh — vertex/face-level mesh under construction (PolyForge core).
## Faces are convex polygon index loops, fan-triangulated at emit. Emit is flat-shaded
## by DEFAULT (per-triangle normals) — the catalog's chunky-stylized law. Pass a
## smooth_angle_deg >= 0 to to_meshes() for opt-in ANGLE-THRESHOLDED smoothing (rounded
## masses shade smooth; creases sharper than the threshold stay crisp) — the claymorphic
## path; the default (-1.0) is unchanged and byte-identical.
## Deterministic: all randomness comes from caller-provided seeds.

var verts := PackedVector3Array()
var faces: Array[PackedInt32Array] = []
var face_colors := PackedColorArray()
var face_tags := PackedStringArray()

static func _new_self():
	return new()

func add_face(idx: PackedInt32Array, color: Color = Color.WHITE, tag: String = "") -> void:
	faces.append(idx)
	face_colors.append(color)
	face_tags.append(tag)

func transform(xf: Transform3D) -> void:
	for i in range(verts.size()):
		verts[i] = xf * verts[i]

func merge(other) -> void:
	var off := verts.size()
	verts.append_array(other.verts)
	for fi in range(other.faces.size()):
		var f: PackedInt32Array = other.faces[fi].duplicate()
		for i in range(f.size()):
			f[i] += off
		faces.append(f)
	face_colors.append_array(other.face_colors)
	face_tags.append_array(other.face_tags)

## fn(centroid: Vector3, normal: Vector3) -> Color, applied per face.
func paint(fn: Callable) -> void:
	for fi in range(faces.size()):
		var f := faces[fi]
		var c := Vector3.ZERO
		for vi in f:
			c += verts[vi]
		c /= f.size()
		var n := (verts[f[1]] - verts[f[0]]).cross(verts[f[2]] - verts[f[0]]).normalized()
		face_colors[fi] = fn.call(c, n)

func tag_all(tag: String) -> void:
	for i in range(face_tags.size()):
		face_tags[i] = tag

func aabb() -> AABB:
	if verts.is_empty():
		return AABB()
	var out := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		out = out.expand(v)
	return out

## Emit one indexed ArrayMesh per tag with face colors baked into COLOR. Flat-shaded by
## default; smooth_angle_deg >= 0 smooths corner normals across incident faces whose face
## normals are within that angle of the corner's own face (creases sharper stay hard).
## Indices are trivial (0..n-1) so builder.merged_mesh_flat_h's indexed loop works.
func to_meshes(smooth_angle_deg := -1.0) -> Dictionary:
	var smooth := smooth_angle_deg >= 0.0
	var fnorm := PackedVector3Array()   # per-face outward unit normal (smooth path only)
	var vfaces: Array = []              # per-vert incident face indices, ascending (smooth path only)
	var cos_thresh := 0.0
	if smooth:
		cos_thresh = cos(deg_to_rad(smooth_angle_deg))
		fnorm.resize(faces.size())
		for fi in range(faces.size()):
			var f: PackedInt32Array = faces[fi]
			fnorm[fi] = (verts[f[1]] - verts[f[0]]).cross(verts[f[2]] - verts[f[0]]).normalized()
		vfaces.resize(verts.size())
		for i in range(verts.size()):
			vfaces[i] = PackedInt32Array()
		for fi in range(faces.size()):
			for vi in faces[fi]:
				var lst: PackedInt32Array = vfaces[vi]   # read-modify-write (Packed elems are CoW)
				lst.append(fi)
				vfaces[vi] = lst
	var acc := {}  # tag -> [PackedVector3Array verts, PackedVector3Array normals, PackedColorArray cols]
	for fi in range(faces.size()):
		var tag := face_tags[fi]
		if not acc.has(tag):
			acc[tag] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
		var a: Array = acc[tag]
		var f := faces[fi]
		var col := face_colors[fi]
		for t in range(1, f.size() - 1):
			var i0: int = f[0]
			var i1: int = f[t]
			var i2: int = f[t + 1]
			var w0 := verts[i0]
			var w1 := verts[i1]
			var w2 := verts[i2]
			var n0: Vector3
			var n1: Vector3
			var n2: Vector3
			if smooth:
				n0 = _corner_normal(i0, fi, fnorm, vfaces, cos_thresh)
				n1 = _corner_normal(i1, fi, fnorm, vfaces, cos_thresh)
				n2 = _corner_normal(i2, fi, fnorm, vfaces, cos_thresh)
			else:
				var n := (w1 - w0).cross(w2 - w0).normalized()
				n0 = n; n1 = n; n2 = n
			# PolyMesh faces are stored CCW-viewed-from-outside (normals = outward). Godot
			# front faces are CLOCKWISE, so emit reversed (w0,w2,w1) or every mesh renders
			# inside-out. Each corner keeps its own (flat or smoothed) outward normal.
			a[0].append(w0); a[0].append(w2); a[0].append(w1)
			a[1].append(n0); a[1].append(n2); a[1].append(n1)
			a[2].append(col); a[2].append(col); a[2].append(col)
	var out := {}
	for tag in acc:
		var a: Array = acc[tag]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = a[0]
		arr[Mesh.ARRAY_NORMAL] = a[1]
		arr[Mesh.ARRAY_COLOR] = a[2]
		var idx := PackedInt32Array()
		idx.resize((a[0] as PackedVector3Array).size())
		for i in range(idx.size()):
			idx[i] = i
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out[tag] = m
	return out

## Smoothed outward normal for vertex vi as seen from face fi: mean of the outward
## normals of vi's incident faces whose normal is within the angle threshold (cos_thresh)
## of face fi's own normal. Faces across a sharper crease are excluded, so a hard edge
## stays hard while a rounded region blends. Deterministic (incident faces are ascending).
func _corner_normal(vi: int, fi: int, fnorm: PackedVector3Array, vfaces: Array, cos_thresh: float) -> Vector3:
	var ref: Vector3 = fnorm[fi]
	var sum := Vector3.ZERO
	for fj in (vfaces[vi] as PackedInt32Array):
		if fnorm[fj].dot(ref) >= cos_thresh:
			sum += fnorm[fj]
	return sum.normalized() if sum.length() > 0.0001 else ref

# ---- generators ----

## Spin a 2D profile (Vector2(radius, y), bottom→top) around Y. ring_jitter (fraction)
## perturbs per-ring scale/phase and per-vertex radius for organic silhouettes.
## radius <= 0.0001 collapses that ring to a pole vertex. Non-pole ends get flat caps.
static func lathe(profile: Array, segments: int, ring_jitter := 0.0, seed_val := 0):
	var pm = _new_self()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var rings: Array = []  # per profile point: PackedInt32Array of vert indices (size 1 = pole)
	for pi in range(profile.size()):
		var p: Vector2 = profile[pi]
		var ring := PackedInt32Array()
		if p.x <= 0.0001:
			ring.append(pm.verts.size())
			pm.verts.append(Vector3(0, p.y, 0))
		else:
			var rj := 1.0 + rng.randf_range(-ring_jitter, ring_jitter)
			# Phase wobble stays a FRACTION of one segment: consecutive rings must keep
			# aligned vertices or the connecting quads twist into bowties (found the hard
			# way — a full random phase per ring crossed the top annulus over the axis).
			var phase := rng.randf_range(-0.35, 0.35) * TAU / segments if ring_jitter > 0.0 else 0.0
			for s in range(segments):
				var a := TAU * s / segments + phase
				var vr: float = p.x * rj * (1.0 + rng.randf_range(-ring_jitter, ring_jitter))
				ring.append(pm.verts.size())
				pm.verts.append(Vector3(cos(a) * vr, p.y, sin(a) * vr))
		rings.append(ring)
	for ri in range(rings.size() - 1):
		var a: PackedInt32Array = rings[ri]
		var b: PackedInt32Array = rings[ri + 1]
		if a.size() == 1 and b.size() == 1:
			continue
		for s in range(segments):
			var s2 := (s + 1) % segments
			if a.size() == 1:
				pm.add_face(PackedInt32Array([a[0], b[s], b[s2]]))
			elif b.size() == 1:
				pm.add_face(PackedInt32Array([a[s], b[0], a[s2]]))
			else:
				pm.add_face(PackedInt32Array([a[s], b[s], b[s2], a[s2]]))
	var bottom: PackedInt32Array = rings[0]
	if bottom.size() > 1:
		var cb: int = pm.verts.size()
		pm.verts.append(Vector3(0, (profile[0] as Vector2).y, 0))
		for s in range(segments):
			pm.add_face(PackedInt32Array([cb, bottom[s], bottom[(s + 1) % segments]]))
	var top: PackedInt32Array = rings[rings.size() - 1]
	if top.size() > 1:
		var ct: int = pm.verts.size()
		pm.verts.append(Vector3(0, (profile[profile.size() - 1] as Vector2).y, 0))
		for s in range(segments):
			pm.add_face(PackedInt32Array([ct, top[(s + 1) % segments], top[s]]))
	return pm

## Extrude a 2D outline (Vector2(x, z), angle-increasing order like (cos a, sin a))
## from y0 up by height. taper scales the top ring toward the outline centroid.
## Convex-ish outlines only (caps are fan-triangulated from the centroid).
static func extrude_poly(outline: Array, height: float, taper := 1.0, y0 := 0.0):
	var pm = _new_self()
	var n := outline.size()
	var cx := Vector2.ZERO
	for i in range(n):
		cx += outline[i] as Vector2
	cx /= n
	var bot := PackedInt32Array()
	var top := PackedInt32Array()
	for i in range(n):
		var o: Vector2 = outline[i]
		bot.append(pm.verts.size())
		pm.verts.append(Vector3(o.x, y0, o.y))
	for i in range(n):
		var o2: Vector2 = cx + ((outline[i] as Vector2) - cx) * taper
		top.append(pm.verts.size())
		pm.verts.append(Vector3(o2.x, y0 + height, o2.y))
	for i in range(n):
		var i2 := (i + 1) % n
		pm.add_face(PackedInt32Array([bot[i], top[i], top[i2], bot[i2]]))
	var cb: int = pm.verts.size()
	pm.verts.append(Vector3(cx.x, y0, cx.y))
	for i in range(n):
		pm.add_face(PackedInt32Array([cb, bot[i], bot[(i + 1) % n]]))
	var ct: int = pm.verts.size()
	pm.verts.append(Vector3(cx.x, y0 + height, cx.y))
	for i in range(n):
		pm.add_face(PackedInt32Array([ct, top[(i + 1) % n], top[i]]))
	return pm

## Grid surface centered at origin in XZ; y from height_fn(x, z). +Y quads, open underside.
static func heightfield(size: Vector2, res: Vector2i, height_fn: Callable):
	var pm = _new_self()
	for j in range(res.y + 1):
		for i in range(res.x + 1):
			var x := -size.x * 0.5 + size.x * i / res.x
			var z := -size.y * 0.5 + size.y * j / res.y
			pm.verts.append(Vector3(x, height_fn.call(x, z), z))
	var w := res.x + 1
	for j in range(res.y):
		for i in range(res.x):
			var v00 := j * w + i
			pm.add_face(PackedInt32Array([v00, v00 + w, v00 + w + 1, v00 + 1]))
	return pm

## Sweep a 2D cross-section along a 3D polyline. Parallel-transport frames (no twist).
## scale_fn.call(t in [0,1]) -> float scales each ring; empty Callable = 1.0.
static func sweep(cross_section: Array, path: Array, scale_fn := Callable(), close_caps := true):
	var pm = _new_self()
	var t_prev: Vector3 = ((path[1] as Vector3) - (path[0] as Vector3)).normalized()
	var up := Vector3.UP if absf(t_prev.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x_axis := up.cross(t_prev).normalized()
	var y_axis := t_prev.cross(x_axis).normalized()
	var rings: Array = []
	var last := path.size() - 1
	for pi in range(path.size()):
		var t_cur: Vector3
		if pi == 0:
			t_cur = ((path[1] as Vector3) - (path[0] as Vector3)).normalized()
		elif pi == last:
			t_cur = ((path[last] as Vector3) - (path[last - 1] as Vector3)).normalized()
		else:
			t_cur = ((path[pi + 1] as Vector3) - (path[pi - 1] as Vector3)).normalized()
		if t_prev.cross(t_cur).length() > 0.0001:
			var q := Quaternion(t_prev, t_cur)
			x_axis = (q * x_axis).normalized()
			y_axis = (q * y_axis).normalized()
		t_prev = t_cur
		var s: float = scale_fn.call(float(pi) / last) if scale_fn.is_valid() else 1.0
		var ring := PackedInt32Array()
		for ci in range(cross_section.size()):
			var c: Vector2 = cross_section[ci]
			ring.append(pm.verts.size())
			pm.verts.append((path[pi] as Vector3) + (x_axis * c.x + y_axis * c.y) * s)
		rings.append(ring)
	var m := cross_section.size()
	for ri in range(rings.size() - 1):
		var a: PackedInt32Array = rings[ri]
		var b: PackedInt32Array = rings[ri + 1]
		for s2 in range(m):
			var s3 := (s2 + 1) % m
			pm.add_face(PackedInt32Array([a[s2], a[s3], b[s3], b[s2]]))
	if close_caps and m >= 3:
		var first: PackedInt32Array = rings[0]
		var f0 := PackedInt32Array()
		for s2 in range(m):
			f0.append(first[m - 1 - s2])
		pm.add_face(f0)
		var lastr: PackedInt32Array = rings[rings.size() - 1]
		var f1 := PackedInt32Array()
		for s2 in range(m):
			f1.append(lastr[s2])
		pm.add_face(f1)
	return pm

# ---- modifiers ----

func _vertex_normals() -> PackedVector3Array:
	var acc := PackedVector3Array()
	acc.resize(verts.size())
	for fi in range(faces.size()):
		var f := faces[fi]
		var n := (verts[f[1]] - verts[f[0]]).cross(verts[f[2]] - verts[f[0]])
		for vi in f:
			acc[vi] = acc[vi] + n
	for i in range(acc.size()):
		acc[i] = acc[i].normalized() if acc[i].length() > 0.0001 else Vector3.UP
	return acc

## Push verts along smoothed vertex normals by seeded noise. |offset| <= amplitude.
func displace(seed_val: int, amplitude: float, frequency: float) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.frequency = frequency
	var vn := _vertex_normals()
	for i in range(verts.size()):
		verts[i] += vn[i] * (noise.get_noise_3dv(verts[i]) * amplitude)

## Unweld: every face gets unique verts. displace() after facet() moves faces
## independently (shattered); before facet() keeps the skin connected (organic).
func facet() -> void:
	var nv := PackedVector3Array()
	var nf: Array[PackedInt32Array] = []
	for fi in range(faces.size()):
		var f := faces[fi]
		var nfi := PackedInt32Array()
		for vi in f:
			nfi.append(nv.size())
			nv.append(verts[vi])
		nf.append(nfi)
	verts = nv
	faces = nf

