extends RefCounted
## PolyForge builder base — PORTABLE, project-agnostic Godot scaffolding.
##
## This holds the vocabulary that has nothing to do with any one game: stock-primitive
## helpers, the transform/material factories, PolyMesh emit glue, the greeble kit,
## and the two ArrayMesh merge strategies. It carries NO palette, NO theme, NO catalog or
## folder contract — a project supplies those by subclassing this class.
##
## Ships with addons/polyforge/ for reuse in any Godot 4 project; subclass it
## with your own palette + output contract, and you have the whole authoring harness.
##
## Merge/output contract (consumer-side, e.g. a part catalog) lives in the CONSUMER, not here;
## `merged_mesh`/`merged_mesh_flat_h` are pure emit strategies with no project constants.

var _parts: Array = []  # [mesh, material, Transform3D]

# ---- material factories ----

## Plain diffuse/metallic StandardMaterial3D; bakes the colour into albedo directly.
static func _mat(mat_name: String, albedo: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = mat_name
	m.albedo_color = albedo
	m.metallic = metal
	m.roughness = rough
	return m

## Emissive StandardMaterial3D (glowing accent).
static func _glow(mat_name: String, albedo: Color, emit: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = mat_name
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = emit
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m

## White-albedo material that renders forge per-face colors (vertex_color_use_as_albedo).
## Only shows non-white colour if the MESH carries painted per-face vertex colour, i.e. a
## PolyMesh shape that had .paint() called — stock primitives render plain white through this.
static func _mat_vc(mat_name: String, metal: float, rough: float) -> StandardMaterial3D:
	var m := _mat(mat_name, Color.WHITE, metal, rough)
	m.vertex_color_use_as_albedo = true
	return m

# ---- transform + stock primitives ----

func _xf(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	b = b.scaled(scl)
	return Transform3D(b, pos)

func _box(size: Vector3, mat: StandardMaterial3D, pos: Vector3, rot := Vector3.ZERO) -> void:
	var m := BoxMesh.new(); m.size = size
	_parts.append([m, mat, _xf(pos, rot)])

func _cyl(bottom_r: float, top_r: float, h: float, seg: int, mat: StandardMaterial3D,
		pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> void:
	var m := CylinderMesh.new()
	m.bottom_radius = bottom_r; m.top_radius = top_r; m.height = h; m.radial_segments = seg
	_parts.append([m, mat, _xf(pos, rot, scl)])

func _sphere(r: float, mat: StandardMaterial3D, pos: Vector3, scl := Vector3.ONE) -> void:
	var m := SphereMesh.new(); m.radius = r; m.height = r * 2.0
	m.radial_segments = 18; m.rings = 9
	_parts.append([m, mat, _xf(pos, Vector3.ZERO, scl)])

func _torus(inner: float, outer: float, mat: StandardMaterial3D, pos: Vector3,
		rot := Vector3.ZERO, scl := Vector3.ONE) -> void:
	var m := TorusMesh.new(); m.inner_radius = inner; m.outer_radius = outer
	m.rings = 32; m.ring_segments = 8
	_parts.append([m, mat, _xf(pos, rot, scl)])

func _capsule(r: float, h: float, mat: StandardMaterial3D, pos: Vector3, rot := Vector3.ZERO) -> void:
	var m := CapsuleMesh.new(); m.radius = r; m.height = h
	_parts.append([m, mat, _xf(pos, rot)])

## Append a PolyMesh (core/mesh.gd): one _parts entry per face tag, material from
## tag_mats[tag] (fallback tag_mats[""]). Face colors ride ARRAY_COLOR — pair with
## _mat_vc or a shader that reads COLOR directly.
func _poly(pm, tag_mats: Dictionary, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> void:
	var meshes: Dictionary = pm.to_meshes()
	for tag in meshes:
		var mat: StandardMaterial3D = tag_mats.get(tag, tag_mats.get("", null))
		_parts.append([meshes[tag], mat, _xf(pos, rot, scl)])

# ---- greeble kit (project-agnostic: every helper takes its material(s) as arguments) ----

## Evenly spaced rivet/bolt studs along a seam or edge.
func rivet_line(from: Vector3, to: Vector3, count: int, mat: StandardMaterial3D, r: float = 0.035) -> void:
	for i in range(count):
		var t := float(i) / float(max(count - 1, 1))
		_sphere(r, mat, from.lerp(to, t))

## A single straight conduit/pipe between two points. Axis-aligned only: orients along
## whichever of X/Z has the larger delta (matches the single-axis capsule/cylinder rotation
## convention — do not call this for a genuinely diagonal run, the capsule will not visually
## reach both endpoints).
func pipe_run(from: Vector3, to: Vector3, radius: float, mat: StandardMaterial3D) -> void:
	var diff := to - from
	var length := diff.length()
	var mid := (from + to) * 0.5
	var rot := Vector3.ZERO
	if absf(diff.x) >= absf(diff.z) and absf(diff.x) >= absf(diff.y):
		rot = Vector3(0, 0, 90)
	elif absf(diff.z) > absf(diff.x) and absf(diff.z) >= absf(diff.y):
		rot = Vector3(90, 0, 0)
	_capsule(radius, length, mat, mid, rot)

## A ring trim accent (wraps the ad-hoc torus-trim pattern into a reusable helper).
func trim_band(pos: Vector3, radius: float, thickness: float, mat: StandardMaterial3D, scl := Vector3.ONE) -> void:
	_torus(radius - thickness * 0.5, radius + thickness * 0.5, mat, pos, Vector3.ZERO, scl)

## Seeded small-shape scatter for filling a bounded surface area with fine greeble detail
## (rivets/bolts/vent caps). Uses its own RandomNumberGenerator instance seeded by seed_val,
## so it never perturbs a caller's own RNG stream. Use sparingly, for surface texture only —
## never for silhouette-defining shapes (those must be hand-placed).
func greeble_scatter(aabb: AABB, budget: int, seed_val: int, mats: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for i in range(budget):
		var p := aabb.position + Vector3(
			rng.randf() * aabb.size.x,
			rng.randf() * aabb.size.y,
			rng.randf() * aabb.size.z)
		var mat: StandardMaterial3D = mats[rng.randi() % mats.size()]
		var r := 0.02 + rng.randf() * 0.025
		if rng.randi() % 2 == 0:
			_sphere(r, mat, p)
		else:
			_cyl(r, r * 0.85, r * 1.6, 6, mat, p)

# ---- merge / emit strategies (no project constants) ----

## Merge all parts into ONE ArrayMesh with one surface per material. The common
## single-merged-mesh output contract (a consumer that extracts one Mesh per GLB) is satisfied
## by this — but that contract lives in the consumer, not here.
func merged_mesh() -> ArrayMesh:
	var by_mat := {}  # material -> Array[[mesh, xf]]
	for p in _parts:
		var key = p[1]
		if not by_mat.has(key):
			by_mat[key] = []
		by_mat[key].append([p[0], p[2]])
	var out: ArrayMesh = null
	for mat in by_mat.keys():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for entry in by_mat[mat]:
			st.append_from(entry[0], 0, entry[1])
		st.set_material(mat)
		out = st.commit(out)
	return out

## Flat-shaded, vertex-colour-baked merge for surfaces consumed by a COLOR-reading shader.
## Bakes each primitive's colour into vertex COLOR.rgb and a per-slice height factor
## (0 at that primitive's own world-Y base, 1 at its top) into COLOR.a, with per-triangle
## FLAT normals for crisp facets. Splits into TWO surfaces by `mat.emission_enabled`:
##   surface 0 = OPAQUE (COLOR.rgb = albedo, COLOR.a = height)
##   surface 1 = EMISSIVE glow (COLOR.rgb = emission colour)   [omitted if no emissive parts]
## A consumer sets one shader material PER-SURFACE. If the consumer folds an instance tint in
## as COLOR = vertexColor x instanceColor, that tint MUST keep alpha = 1.0 or the height
## factor collapses.
func merged_mesh_flat_h() -> ArrayMesh:
	var opaque := SurfaceTool.new(); opaque.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glow := SurfaceTool.new(); glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_opaque := false
	var has_glow := false
	for p in _parts:
		var mesh: Mesh = p[0]
		var mat: StandardMaterial3D = p[1]
		var xf: Transform3D = p[2]
		var is_glow: bool = mat != null and mat.emission_enabled
		var col: Color = Color.WHITE
		if mat != null:
			col = mat.emission if is_glow else mat.albedo_color
		var st: SurfaceTool = glow if is_glow else opaque
		if is_glow:
			has_glow = true
		else:
			has_opaque = true
		var arr := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		# Forge meshes (PolyMesh.to_meshes) arrive with per-face colors pre-baked in
		# ARRAY_COLOR — pass their RGB through; stock primitives keep the material colour.
		var src_cols := PackedColorArray()
		if arr[Mesh.ARRAY_COLOR] != null:
			src_cols = arr[Mesh.ARRAY_COLOR]
		# Per-primitive world-space Y span → the slice's local height axis.
		var ymin := INF
		var ymax := -INF
		for v in verts:
			var wy: float = (xf * v).y
			ymin = min(ymin, wy)
			ymax = max(ymax, wy)
		var span: float = max(ymax - ymin, 0.0001)
		for ti in range(0, idx.size(), 3):
			var w0: Vector3 = xf * verts[idx[ti]]
			var w1: Vector3 = xf * verts[idx[ti + 1]]
			var w2: Vector3 = xf * verts[idx[ti + 2]]
			var fn := (w1 - w0).cross(w2 - w0).normalized()
			for c in range(3):
				var vi := idx[ti + c]
				var w: Vector3 = xf * verts[vi]
				var base: Color = col if src_cols.is_empty() else src_cols[vi]
				var hf: float = clamp((w.y - ymin) / span, 0.0, 1.0)
				st.set_color(Color(base.r, base.g, base.b, hf))
				st.set_normal(fn)
				st.add_vertex(w)
	# Commit opaque as surface 0, glow as surface 1 (stable order for the consumer).
	var out: ArrayMesh = null
	if has_opaque:
		out = opaque.commit(out)
	if has_glow:
		out = glow.commit(out)
	return out

## Clear accumulated primitives so one provider instance can build many parts.
func reset() -> void:
	_parts.clear()
