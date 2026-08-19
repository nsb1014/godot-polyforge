extends RefCounted
## Detailed big-head Sukuna-inspired chibi character.
##
## The model is authored as a named PolyForge assembly so the face, hair, markings,
## clothing, hands, and boots remain addressable in the preserved GLB.  The target is a
## hero-quality ~60k triangle character with a +Z-facing portrait pose.  The budget is
## spent on smooth primary surfaces instead of micro-details such as fingernails.

const Assembly := preload("res://addons/polyforge/core/assembly.gd")
const Attachments := preload("res://addons/polyforge/core/attachments.gd")
const Parameters := preload("res://addons/polyforge/core/parameters.gd")
const PolyMesh := preload("res://addons/polyforge/core/mesh.gd")
const Stock := preload("res://addons/polyforge/core/stock.gd")
const Checks := preload("res://addons/polyforge/quality/checks.gd")

func _xf(position: Vector3, rotation_degrees := Vector3.ZERO,
		scale := Vector3.ONE) -> Transform3D:
	var radians := Vector3(
		deg_to_rad(rotation_degrees.x),
		deg_to_rad(rotation_degrees.y),
		deg_to_rad(rotation_degrees.z))
	return Transform3D(Basis.from_euler(radians).scaled(scale), position)

func _orient_y(position: Vector3, direction: Vector3) -> Transform3D:
	var unit := direction.normalized()
	return Transform3D(Basis(Quaternion(Vector3.UP, unit)), position)

func _primitive(mesh: PrimitiveMesh, material: Material) -> PrimitiveMesh:
	mesh.material = material
	return mesh

func _circle(radius: float, segments: int) -> Array:
	var points := []
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return points

func _poly_mesh(poly, material: Material, smooth_angle := 42.0) -> ArrayMesh:
	var emitted: Dictionary = poly.to_meshes(smooth_angle)
	var mesh: ArrayMesh = emitted.get("")
	assert(mesh != null, "PolyForge detail mesh did not emit its default surface")
	mesh.surface_set_material(0, material)
	return mesh

func _tube(points: Array, radius: float, material: Material, segments := 12) -> ArrayMesh:
	var poly = PolyMesh.sweep(_circle(radius, segments), points, Callable(), true)
	return _poly_mesh(poly, material, 34.0)

func _spike_mesh(length: float, radius: float, material: Material, segments := 20) -> ArrayMesh:
	var profile := [
		Vector2(0.0, 0.0),
		Vector2(radius, length * 0.08),
		Vector2(radius * 1.05, length * 0.25),
		Vector2(radius * 0.72, length * 0.58),
		Vector2(radius * 0.28, length * 0.84),
		Vector2(0.0, length),
	]
	return _poly_mesh(PolyMesh.lathe(profile, segments, 0.0, 0), material, 48.0)

func _add_capsule(asset: Assembly, name: String, start: Vector3, finish: Vector3,
		radius: float, material: Material, tags := ["limb"]) -> void:
	var direction := finish - start
	asset.add(name, _primitive(Stock.capsule(radius, direction.length(), 19, 10), material),
		_orient_y((start + finish) * 0.5, direction), {"tags": tags})

func _add_cylinder(asset: Assembly, name: String, start: Vector3, finish: Vector3,
		radius: float, material: Material, segments := 32, tags := ["detail"]) -> void:
	var direction := finish - start
	asset.add(name, _primitive(Stock.cylinder(radius, radius, direction.length(), segments), material),
		_orient_y((start + finish) * 0.5, direction), {"tags": tags})

func _add_tube(asset: Assembly, name: String, points: Array, radius: float,
		material: Material, tags := ["detail"], segments := 12) -> void:
	asset.add(name, _tube(points, radius, material, segments), Transform3D.IDENTITY,
		{"tags": tags})

func _add_spike(asset: Assembly, name: String, head_center: Vector3, head_radius: float,
		direction: Vector3, length: float, radius: float, material: Material) -> void:
	var unit := direction.normalized()
	var base := head_center + Vector3(
		unit.x * head_radius * 1.01,
		unit.y * head_radius * 1.06,
		unit.z * head_radius * 0.94)
	asset.add(name, _spike_mesh(length, radius, material, 18),
		_orient_y(base, unit), {"tags": ["hair", "silhouette"]})

func _add_button(asset: Assembly, name: String, position: Vector3, radius: float,
		material: Material) -> void:
	asset.add(name, _primitive(Stock.cylinder(radius, radius, radius * 0.42, 28), material),
		_xf(position, Vector3(90.0, 0.0, 0.0)), {"tags": ["outfit", "hardware"]})

func parameters() -> Dictionary:
	return {
		"height": Parameters.scale(3.6, 3.2, 4.0, "m",
			"Canonical overall height from boot sole to hair tip."),
		"bulk": Parameters.number(1.0, 0.92, 1.12, "ratio",
			"Horizontal chibi mass multiplier for the head, torso, and limbs."),
	}

func build(p) -> Dictionary:
	var height: float = p.value("height")
	var bulk: float = p.value("bulk")
	var unit: float = p.derive("canonical_unit", "height", 1.0 / 3.6)
	var head_center := Vector3(0.0, unit * 2.55, 0.0)
	var head_radius := unit * 0.78
	var body_center := Vector3(0.0, unit * 1.34, 0.0)
	var skin := Stock.material("skin_warm", Color("f1c493"), 0.0, 0.64)
	var skin_shadow := Stock.material("skin_shadow", Color("d99a6b"), 0.0, 0.72)
	var lip := Stock.material("lip_coral", Color("c9575c"), 0.0, 0.52)
	var hair := Stock.material("hair_rose", Color("a95355"), 0.0, 0.56)
	var hair_light := Stock.material("hair_highlight", Color("d37b6d"), 0.0, 0.48)
	var hair_shadow := Stock.material("hair_shadow", Color("5b2b39"), 0.0, 0.70)
	var tattoo := Stock.material("cursed_markings", Color("17151c"), 0.0, 0.44)
	var tattoo_red := Stock.material("marking_red", Color("7f2632"), 0.0, 0.56)
	var sclera := Stock.material("eye_sclera", Color("fff3dc"), 0.0, 0.32)
	var iris := Stock.material("iris_crimson", Color("d6423b"), 0.0, 0.28)
	var iris_dark := Stock.material("iris_ring", Color("771923"), 0.0, 0.38)
	var pupil := Stock.material("pupil", Color("090a12"), 0.0, 0.22)
	var eye_glint := Stock.glow_material("eye_glint", Color("ffb08d"), 1.4)
	var outfit := Stock.material("uniform_navy", Color("151c36"), 0.08, 0.62)
	var outfit_mid := Stock.material("uniform_blue", Color("253052"), 0.10, 0.58)
	var outfit_light := Stock.material("uniform_seam", Color("46557a"), 0.12, 0.48)
	var red := Stock.material("collar_red", Color("a73439"), 0.0, 0.54)
	var red_light := Stock.material("collar_highlight", Color("d0524b"), 0.0, 0.46)
	var sole := Stock.material("boot_sole", Color("18131b"), 0.0, 0.82)
	var gold := Stock.material("button_gold", Color("d9a24e"), 0.58, 0.38)
	var metal_dark := Stock.material("hardware_dark", Color("30263a"), 0.52, 0.40)
	var white := Stock.material("teeth_highlight", Color("fff8e8"), 0.0, 0.28)

	var asset := Assembly.new()
	var attachments := Attachments.new(asset)

	# Body and oversized clothing masses.
	asset.add("torso", _primitive(Stock.sphere(unit * 0.53, 40, 20), outfit),
		_xf(body_center, Vector3.ZERO, Vector3(1.04 * bulk, 1.20, 0.72 * bulk)),
		{"tags": ["body", "outfit", "mass"]})
	asset.add("torso_front_panel", _primitive(Stock.sphere(unit * 0.37, 32, 16), outfit_mid),
		_xf(Vector3(0.0, unit * 1.42, unit * 0.27), Vector3.ZERO,
			Vector3(1.18 * bulk, 1.35, 0.32)), {"tags": ["outfit", "front"]})
	asset.add("waist_band", _primitive(Stock.torus(unit * 0.33, unit * 0.385, 40, 10), tattoo),
		_xf(Vector3(0.0, unit * 0.98, 0.0), Vector3.ZERO,
			Vector3(1.22 * bulk, 1.0, 0.88 * bulk)), {"tags": ["outfit", "hardware"]})
	asset.add("belt_red_inlay", _primitive(Stock.torus(unit * 0.345, unit * 0.365, 40, 8), red),
		_xf(Vector3(0.0, unit * 1.00, 0.0), Vector3.ZERO,
			Vector3(1.20 * bulk, 1.0, 0.86 * bulk)), {"tags": ["outfit", "accent"]})
	asset.add("belt_buckle", _primitive(Stock.box(Vector3(unit * 0.18, unit * 0.16, unit * 0.07)), gold),
		_xf(Vector3(0.0, unit * 1.00, unit * 0.42)), {"tags": ["outfit", "hardware", "front"]})
	asset.add("lower_hem", _primitive(Stock.torus(unit * 0.40, unit * 0.445, 40, 8), outfit_light),
		_xf(Vector3(0.0, unit * 1.02, 0.0), Vector3.ZERO,
			Vector3(1.13 * bulk, 1.0, 0.78 * bulk)), {"tags": ["outfit", "trim"]})

	# Neck, collar, scarf knot, and front fastening.
	asset.add("neck", _primitive(Stock.cylinder(unit * 0.22, unit * 0.24, unit * 0.30, 28), skin_shadow),
		_xf(Vector3(0.0, unit * 1.95, 0.0)), {"tags": ["body", "joint"]})
	asset.add("collar_outer", _primitive(Stock.torus(unit * 0.24, unit * 0.355, 42, 9), red),
		_xf(Vector3(0.0, unit * 1.91, 0.0), Vector3.ZERO,
			Vector3(1.10 * bulk, 1.0, 0.86 * bulk)), {"tags": ["outfit", "collar"]})
	asset.add("collar_highlight", _primitive(Stock.torus(unit * 0.29, unit * 0.325, 42, 6), red_light),
		_xf(Vector3(0.0, unit * 1.945, unit * 0.006), Vector3.ZERO,
			Vector3(1.08 * bulk, 1.0, 0.84 * bulk)), {"tags": ["outfit", "trim"]})
	asset.add("scarf_knot", _primitive(Stock.sphere(unit * 0.18, 34, 17), red_light),
		_xf(Vector3(0.0, unit * 1.76, unit * 0.34), Vector3.ZERO,
			Vector3(1.22, 0.82, 0.58)), {"tags": ["outfit", "front", "accent"]})
	asset.add("scarf_knot_shadow", _primitive(Stock.torus(unit * 0.10, unit * 0.14, 28, 8), tattoo),
		_xf(Vector3(0.0, unit * 1.77, unit * 0.37), Vector3(90.0, 0.0, 0.0)),
		{"tags": ["outfit", "front"]})

	# Head, ears, jaw blush, and the dark hair cap.
	asset.add("head", _primitive(Stock.sphere(head_radius, 56, 28), skin),
		_xf(head_center, Vector3.ZERO, Vector3(1.0 * bulk, 1.06, 0.92)),
		{"tags": ["head", "face", "mass"]})
	asset.add("jaw_warmth", _primitive(Stock.sphere(unit * 0.48, 40, 20), skin_shadow),
		_xf(head_center + Vector3(0.0, -unit * 0.18, unit * 0.12), Vector3.ZERO,
			Vector3(1.14 * bulk, 0.68, 0.72)), {"tags": ["head", "face", "accent"]})
	for side in [-1.0, 1.0]:
		var ear_suffix := "L" if side < 0.0 else "R"
		asset.add("ear_" + ear_suffix, _primitive(Stock.sphere(unit * 0.16, 32, 16), skin),
			_xf(head_center + Vector3(side * unit * 0.75 * bulk, -unit * 0.01, -unit * 0.01),
				Vector3.ZERO, Vector3(0.78, 1.15, 0.62)), {"tags": ["head", "face"]})
		asset.add("ear_inner_" + ear_suffix, _primitive(Stock.sphere(unit * 0.075, 24, 12), lip),
			_xf(head_center + Vector3(side * unit * 0.79 * bulk, -unit * 0.015, unit * 0.075),
				Vector3.ZERO, Vector3(0.55, 1.0, 0.40)), {"tags": ["head", "accent"]})
	asset.add("hair_cap", _primitive(Stock.sphere(unit * 0.82, 40, 20), hair_shadow),
		_xf(head_center + Vector3(0.0, unit * 0.04, -unit * 0.09), Vector3.ZERO,
			Vector3(1.04 * bulk, 1.02, 0.99)), {"tags": ["hair", "mass"]})
	asset.add("hair_cap_front", _primitive(Stock.sphere(unit * 0.76, 36, 18), hair),
		_xf(head_center + Vector3(0.0, unit * 0.10, unit * 0.04), Vector3.ZERO,
			Vector3(1.01 * bulk, 0.86, 0.82)), {"tags": ["hair", "front"]})

	# Layered sculptural spikes make the silhouette read from all eight octants.
	var spike_specs := [
		[Vector3(-0.88, 0.22, 0.12), 0.40, 0.15], [Vector3(-0.78, 0.48, 0.20), 0.46, 0.145],
		[Vector3(-0.60, 0.72, 0.20), 0.52, 0.14], [Vector3(-0.34, 0.88, 0.18), 0.48, 0.135],
		[Vector3(-0.06, 1.00, 0.08), 0.44, 0.13], [Vector3(0.24, 0.94, 0.10), 0.50, 0.135],
		[Vector3(0.52, 0.80, 0.12), 0.47, 0.14], [Vector3(0.76, 0.55, 0.16), 0.42, 0.145],
		[Vector3(0.90, 0.25, 0.08), 0.36, 0.14], [Vector3(-0.96, -0.02, 0.08), 0.31, 0.13],
		[Vector3(0.96, -0.04, 0.08), 0.31, 0.13], [Vector3(-0.75, 0.20, -0.58), 0.42, 0.14],
		[Vector3(-0.42, 0.57, -0.67), 0.49, 0.14], [Vector3(-0.08, 0.82, -0.72), 0.53, 0.145],
		[Vector3(0.28, 0.72, -0.68), 0.50, 0.14], [Vector3(0.62, 0.48, -0.60), 0.43, 0.145],
		[Vector3(0.78, 0.18, -0.48), 0.34, 0.13], [Vector3(0.0, 1.0, -0.12), 0.56, 0.14],
	]
	for index in range(spike_specs.size()):
		var spec: Array = spike_specs[index]
		var material: Material = hair_light if index % 3 == 0 else hair
		_add_spike(asset, "hair_spike_%02d" % index, head_center, head_radius,
			spec[0], unit * float(spec[1]), unit * float(spec[2]), material)
	# Two long temple locks frame the face.
	_add_spike(asset, "hair_temple_L", head_center, head_radius,
		Vector3(-0.95, -0.18, 0.18), unit * 0.48, unit * 0.16, hair_light)
	_add_spike(asset, "hair_temple_R", head_center, head_radius,
		Vector3(0.95, -0.18, 0.18), unit * 0.48, unit * 0.16, hair_light)

	# High-detail eyes: white volume, dark rim, concentric iris, pupil, and glint.
	var eye_y := head_center.y + unit * 0.07
	var eye_z := head_center.z + unit * 0.60
	for side in [-1.0, 1.0]:
		var eye_suffix := "L" if side < 0.0 else "R"
		var eye_x: float = float(side) * unit * 0.255 * bulk
		var eye_pos := Vector3(eye_x, eye_y, eye_z)
		asset.add("eye_white_" + eye_suffix, _primitive(Stock.sphere(unit * 0.19, 44, 22), sclera),
			_xf(eye_pos, Vector3.ZERO, Vector3(1.0, 0.88, 0.54)), {"tags": ["eyes", "face"]})
		asset.add("eye_rim_" + eye_suffix, _primitive(Stock.torus(unit * 0.135, unit * 0.17, 40, 9), tattoo),
			_xf(eye_pos + Vector3(0.0, 0.0, unit * 0.075), Vector3(90.0, 0.0, 0.0),
				Vector3(1.0, 1.0, 0.83)), {"tags": ["eyes", "face", "marking"]})
		asset.add("iris_ring_" + eye_suffix, _primitive(Stock.torus(unit * 0.066, unit * 0.090, 32, 7), iris_dark),
			_xf(eye_pos + Vector3(0.0, 0.0, unit * 0.088), Vector3(90.0, 0.0, 0.0)),
			{"tags": ["eyes", "face"]})
		asset.add("iris_" + eye_suffix, _primitive(Stock.sphere(unit * 0.082, 28, 14), iris),
			_xf(eye_pos + Vector3(0.0, 0.0, unit * 0.095), Vector3.ZERO,
				Vector3(1.0, 1.0, 0.48)), {"tags": ["eyes", "face", "accent"]})
		asset.add("pupil_" + eye_suffix, _primitive(Stock.sphere(unit * 0.040, 22, 11), pupil),
			_xf(eye_pos + Vector3(0.0, 0.0, unit * 0.132), Vector3.ZERO,
				Vector3(0.82, 1.0, 0.38)), {"tags": ["eyes", "face"]})
		asset.add("eye_glint_" + eye_suffix, _primitive(Stock.sphere(unit * 0.018, 14, 7), eye_glint),
			_xf(eye_pos + Vector3(-side * unit * 0.026, unit * 0.028, unit * 0.15)),
			{"tags": ["eyes", "accent"]})

	# Nose, open smiling mouth, teeth, and tongue.
	asset.add("nose", _primitive(Stock.sphere(unit * 0.105, 28, 14), skin_shadow),
		_xf(head_center + Vector3(0.0, -unit * 0.045, unit * 0.635), Vector3.ZERO,
			Vector3(0.72, 0.80, 0.56)), {"tags": ["face", "nose"]})
	asset.add("mouth_open", _primitive(Stock.sphere(unit * 0.205, 36, 18), tattoo),
		_xf(head_center + Vector3(0.0, -unit * 0.285, unit * 0.565), Vector3.ZERO,
			Vector3(1.34, 0.56, 0.52)), {"tags": ["face", "mouth"]})
	_add_tube(asset, "upper_lip", [
		head_center + Vector3(-unit * 0.24, -unit * 0.245, unit * 0.735),
		head_center + Vector3(-unit * 0.07, -unit * 0.205, unit * 0.758),
		head_center + Vector3(0.0, -unit * 0.235, unit * 0.745),
		head_center + Vector3(unit * 0.08, -unit * 0.205, unit * 0.758),
		head_center + Vector3(unit * 0.24, -unit * 0.245, unit * 0.735),
	], unit * 0.040, lip, ["face", "mouth", "accent"], 12)
	_add_tube(asset, "lower_lip", [
		head_center + Vector3(-unit * 0.22, -unit * 0.335, unit * 0.718),
		head_center + Vector3(0.0, -unit * 0.365, unit * 0.735),
		head_center + Vector3(unit * 0.22, -unit * 0.335, unit * 0.718),
	], unit * 0.035, lip, ["face", "mouth", "accent"], 12)
	asset.add("tongue", _primitive(Stock.sphere(unit * 0.11, 28, 14), red_light),
		_xf(head_center + Vector3(0.0, -unit * 0.34, unit * 0.655), Vector3.ZERO,
			Vector3(1.45, 0.50, 0.42)), {"tags": ["face", "mouth", "accent"]})
	for side in [-1.0, 1.0]:
		var tooth_suffix := "L" if side < 0.0 else "R"
		asset.add("tooth_top_" + tooth_suffix, _primitive(Stock.box(Vector3(
			unit * 0.10, unit * 0.12, unit * 0.035)), white),
			_xf(head_center + Vector3(side * unit * 0.13, -unit * 0.235, unit * 0.695)),
			{"tags": ["face", "mouth"]})

	# Cursed markings and brows are deliberately modeled as raised, readable geometry.
	_add_tube(asset, "brow_L", [
		head_center + Vector3(-unit * 0.43 * bulk, unit * 0.24, unit * 0.675),
		head_center + Vector3(-unit * 0.28 * bulk, unit * 0.30, unit * 0.704),
		head_center + Vector3(-unit * 0.13 * bulk, unit * 0.24, unit * 0.685),
	], unit * 0.034, tattoo, ["face", "marking", "front"], 14)
	_add_tube(asset, "brow_R", [
		head_center + Vector3(unit * 0.13 * bulk, unit * 0.24, unit * 0.685),
		head_center + Vector3(unit * 0.28 * bulk, unit * 0.30, unit * 0.704),
		head_center + Vector3(unit * 0.43 * bulk, unit * 0.24, unit * 0.675),
	], unit * 0.034, tattoo, ["face", "marking", "front"], 14)
	_add_tube(asset, "forehead_mark_L", [
		head_center + Vector3(-unit * 0.17 * bulk, unit * 0.48, unit * 0.60),
		head_center + Vector3(-unit * 0.22 * bulk, unit * 0.38, unit * 0.67),
		head_center + Vector3(-unit * 0.17 * bulk, unit * 0.31, unit * 0.70),
	], unit * 0.030, tattoo, ["face", "marking", "front"], 12)
	_add_tube(asset, "forehead_mark_R", [
		head_center + Vector3(unit * 0.17 * bulk, unit * 0.48, unit * 0.60),
		head_center + Vector3(unit * 0.22 * bulk, unit * 0.38, unit * 0.67),
		head_center + Vector3(unit * 0.17 * bulk, unit * 0.31, unit * 0.70),
	], unit * 0.030, tattoo, ["face", "marking", "front"], 12)
	_add_tube(asset, "forehead_center", [
		head_center + Vector3(-unit * 0.055, unit * 0.53, unit * 0.53),
		head_center + Vector3(0.0, unit * 0.45, unit * 0.65),
		head_center + Vector3(unit * 0.055, unit * 0.53, unit * 0.53),
	], unit * 0.025, tattoo_red, ["face", "marking", "front"], 12)
	for side in [-1.0, 1.0]:
		var mark_suffix := "L" if side < 0.0 else "R"
		_add_tube(asset, "cheek_mark_a_" + mark_suffix, [
			head_center + Vector3(side * unit * 0.41 * bulk, -unit * 0.03, unit * 0.54),
			head_center + Vector3(side * unit * 0.49 * bulk, -unit * 0.09, unit * 0.50),
			head_center + Vector3(side * unit * 0.43 * bulk, -unit * 0.16, unit * 0.55),
		], unit * 0.027, tattoo, ["face", "marking"], 12)
		_add_tube(asset, "cheek_mark_b_" + mark_suffix, [
			head_center + Vector3(side * unit * 0.36 * bulk, -unit * 0.10, unit * 0.59),
			head_center + Vector3(side * unit * 0.44 * bulk, -unit * 0.17, unit * 0.55),
		], unit * 0.022, tattoo_red, ["face", "marking"], 12)
		_add_tube(asset, "under_eye_mark_" + mark_suffix, [
			Vector3(side * unit * 0.31 * bulk, eye_y - unit * 0.12, eye_z + unit * 0.07),
			Vector3(side * unit * 0.37 * bulk, eye_y - unit * 0.19, eye_z + unit * 0.04),
			Vector3(side * unit * 0.29 * bulk, eye_y - unit * 0.25, eye_z + unit * 0.03),
		], unit * 0.020, tattoo, ["face", "marking"], 10)
	# Vertical mouth-corner cuts and chin glyphs.
	_add_tube(asset, "mouth_mark_L", [
		head_center + Vector3(-unit * 0.29 * bulk, -unit * 0.22, unit * 0.62),
		head_center + Vector3(-unit * 0.35 * bulk, -unit * 0.30, unit * 0.59),
		head_center + Vector3(-unit * 0.30 * bulk, -unit * 0.38, unit * 0.56),
	], unit * 0.023, tattoo, ["face", "marking"], 11)
	_add_tube(asset, "mouth_mark_R", [
		head_center + Vector3(unit * 0.29 * bulk, -unit * 0.22, unit * 0.62),
		head_center + Vector3(unit * 0.35 * bulk, -unit * 0.30, unit * 0.59),
		head_center + Vector3(unit * 0.30 * bulk, -unit * 0.38, unit * 0.56),
	], unit * 0.023, tattoo, ["face", "marking"], 11)
	_add_tube(asset, "chin_glyph", [
		head_center + Vector3(-unit * 0.16 * bulk, -unit * 0.48, unit * 0.49),
		head_center + Vector3(-unit * 0.06 * bulk, -unit * 0.42, unit * 0.56),
		head_center + Vector3(unit * 0.04 * bulk, -unit * 0.49, unit * 0.50),
		head_center + Vector3(unit * 0.14 * bulk, -unit * 0.43, unit * 0.54),
	], unit * 0.025, tattoo, ["face", "marking"], 12)

	# Arms, sleeves, cuffs, and smooth mitten-like hands.
	var shoulder_y := unit * 1.62
	var elbow_y := unit * 1.28
	var wrist_y := unit * 1.05
	var shoulder_x := unit * 0.52 * bulk
	for side in [-1.0, 1.0]:
		var arm_suffix := "L" if side < 0.0 else "R"
		var shoulder := Vector3(side * shoulder_x, shoulder_y, 0.0)
		var elbow := Vector3(side * unit * 0.63 * bulk, elbow_y, unit * 0.03)
		var wrist := Vector3(side * unit * 0.64 * bulk, wrist_y, unit * 0.10)
		_add_capsule(asset, "upper_sleeve_" + arm_suffix, shoulder, elbow, unit * 0.145, outfit,
			["limb", "outfit", "side"])
		_add_capsule(asset, "fore_sleeve_" + arm_suffix, elbow, wrist, unit * 0.135, outfit_mid,
			["limb", "outfit", "side"])
		_add_cylinder(asset, "cuff_" + arm_suffix,
			wrist - Vector3(0.0, unit * 0.07, 0.0), wrist + Vector3(0.0, unit * 0.07, 0.0),
			unit * 0.15, tattoo, 28, ["limb", "outfit", "trim"])
		var hand := wrist + Vector3(0.0, -unit * 0.18, unit * 0.045)
		asset.add("hand_" + arm_suffix, _primitive(Stock.sphere(unit * 0.17, 32, 16), skin),
			_xf(hand, Vector3.ZERO, Vector3(0.86, 1.04, 0.78)), {"tags": ["limb", "hand"]})
		# Keep the hands as clean, rounded mitten volumes: the reference reads as a
		# smooth collectible toy, so triangles go into the silhouette rather than nails.

	# Pants, knees, boots, soles, cuffs, and boot lace bands.
	asset.add("pelvis", _primitive(Stock.sphere(unit * 0.37, 36, 18), outfit),
		_xf(Vector3(0.0, unit * 0.88, 0.0), Vector3.ZERO,
			Vector3(1.22 * bulk, 0.76, 0.92 * bulk)), {"tags": ["body", "outfit"]})
	for side in [-1.0, 1.0]:
		var leg_suffix := "L" if side < 0.0 else "R"
		var hip := Vector3(side * unit * 0.20 * bulk, unit * 0.79, 0.0)
		var knee := Vector3(side * unit * 0.22 * bulk, unit * 0.48, unit * 0.01)
		var ankle := Vector3(side * unit * 0.22 * bulk, unit * 0.23, unit * 0.04)
		_add_capsule(asset, "thigh_" + leg_suffix, hip, knee, unit * 0.17, outfit,
			["limb", "outfit", "leg"])
		_add_capsule(asset, "shin_" + leg_suffix, knee, ankle, unit * 0.145, outfit_mid,
			["limb", "outfit", "leg"])
		asset.add("knee_panel_" + leg_suffix, _primitive(Stock.sphere(unit * 0.12, 28, 14), outfit_light),
			_xf(knee + Vector3(0.0, 0.0, unit * 0.10)), {"tags": ["limb", "outfit", "detail"]})
		asset.add("boot_" + leg_suffix, _primitive(Stock.sphere(unit * 0.24, 36, 18), red),
			_xf(Vector3(side * unit * 0.22 * bulk, unit * 0.15, unit * 0.12), Vector3.ZERO,
				Vector3(0.96 * bulk, 0.68, 1.38)), {"tags": ["foot", "outfit"]})
		asset.add("boot_sole_" + leg_suffix, _primitive(Stock.sphere(unit * 0.22, 28, 14), sole),
			_xf(Vector3(side * unit * 0.22 * bulk, unit * 0.07, unit * 0.14), Vector3.ZERO,
				Vector3(1.02 * bulk, 0.23, 1.42)), {"tags": ["foot", "hardware"]})
		_add_cylinder(asset, "boot_cuff_" + leg_suffix,
			Vector3(side * unit * 0.22 * bulk, unit * 0.25, unit * 0.03),
			Vector3(side * unit * 0.22 * bulk, unit * 0.40, unit * 0.03),
			unit * 0.18, tattoo, 28, ["foot", "outfit", "trim"])
		for lace in range(3):
			var lace_y := unit * (0.17 + float(lace) * 0.065)
			_add_tube(asset, "boot_lace_%s_%d" % [leg_suffix, lace], [
				Vector3(side * unit * 0.12 * bulk, lace_y, unit * 0.295),
				Vector3(side * unit * 0.32 * bulk, lace_y, unit * 0.295),
			], unit * 0.018, gold, ["foot", "hardware", "detail"], 10)

	# Outfit seams and hardware, all derived from the torso rather than floating pixels.
	_add_tube(asset, "front_zipper", [
		Vector3(0.0, unit * 1.13, unit * 0.49),
		Vector3(0.0, unit * 1.40, unit * 0.51),
		Vector3(0.0, unit * 1.68, unit * 0.42),
	], unit * 0.018, metal_dark, ["outfit", "front", "hardware"], 10)
	_add_tube(asset, "lapel_L", [
		Vector3(-unit * 0.26 * bulk, unit * 1.75, unit * 0.38),
		Vector3(-unit * 0.16 * bulk, unit * 1.57, unit * 0.49),
		Vector3(-unit * 0.28 * bulk, unit * 1.40, unit * 0.48),
	], unit * 0.024, outfit_light, ["outfit", "front", "trim"], 12)
	_add_tube(asset, "lapel_R", [
		Vector3(unit * 0.26 * bulk, unit * 1.75, unit * 0.38),
		Vector3(unit * 0.16 * bulk, unit * 1.57, unit * 0.49),
		Vector3(unit * 0.28 * bulk, unit * 1.40, unit * 0.48),
	], unit * 0.024, outfit_light, ["outfit", "front", "trim"], 12)
	for row in range(3):
		_add_button(asset, "button_L_%d" % row,
			Vector3(-unit * 0.17 * bulk, unit * (1.53 - float(row) * 0.17), unit * 0.51),
			unit * 0.038, gold)
		_add_button(asset, "button_R_%d" % row,
			Vector3(unit * 0.17 * bulk, unit * (1.53 - float(row) * 0.17), unit * 0.51),
			unit * 0.038, gold)
	# Small shoulder stitching keeps the side views intentional.
	for side in [-1.0, 1.0]:
		var stitch_suffix := "L" if side < 0.0 else "R"
		for row in range(4):
			var y := unit * (1.65 - float(row) * 0.10)
			_add_tube(asset, "shoulder_stitch_%s_%d" % [stitch_suffix, row], [
				Vector3(side * unit * 0.50 * bulk, y, unit * 0.12),
				Vector3(side * unit * 0.58 * bulk, y - unit * 0.015, unit * 0.16),
			], unit * 0.012, gold, ["outfit", "detail"], 8)

	# Geometry-derived attachment points for tools and downstream rigs.
	var eye_mount := Vector3(0.0, eye_y, eye_z + unit * 0.17)
	var chest_mount := Vector3(0.0, unit * 1.48, unit * 0.52)
	attachments.surface("eye_line_mount", "head", eye_mount, {
		"heading": Vector3.FORWARD,
		"inset": unit * 0.005, "max_hint_distance": unit * 0.28,
		"position_tolerance": unit * 0.02,
	})
	attachments.surface("chest_zipper_mount", "torso", chest_mount, {
		"heading": Vector3.FORWARD,
		"inset": unit * 0.006, "max_hint_distance": unit * 0.24,
		"position_tolerance": unit * 0.04,
	})

	return {
		"name": "bighead_sukuna",
		"category": "character",
		"assembly": asset,
		"triangle_budget": 60000,
		"topology_budget": {
			"rendered_triangles": 60000,
			"unique_triangles": 60000,
		},
		"quality_profile": "hero",
		"checks": [
			Checks.require_axis_ratio("head", 1, "torso", 1, 1.20, 2.40),
			Checks.require_axis_size("head", 0, unit * 1.56 * bulk, unit * 0.04),
			Checks.require_axis_range("torso", 1, unit * 0.90, unit * 1.55),
		],
		"anchors": {
			"ground": Vector3(0.0, unit * 0.01, 0.0),
			"head": head_center,
			"crown": head_center + Vector3(0.0, unit * 1.38, -unit * 0.05),
			"eye_line": eye_mount,
			"chest": chest_mount,
			"left_hand": Vector3(-unit * 0.64 * bulk, wrist_y - unit * 0.18, unit * 0.145),
			"right_hand": Vector3(unit * 0.64 * bulk, wrist_y - unit * 0.18, unit * 0.145),
		},
		"attachments": attachments.snapshot(),
		"readability": {
			"target_pixels": 96,
			"supersample": 2,
			"minimum_regions": 5,
			"minimum_contrast": 0.08,
			"minimum_stroke_px": 1.5,
			"view_set": "octants",
			"critical_parts": {
				"head": {"selector": {"tags": ["head"]}, "minimum_visible_fraction": 0.16},
				"hair": {"selector": {"tags": ["hair"]}, "minimum_visible_fraction": 0.08},
			},
		},
		"reference_profile": {
			"image": {
				"source": "user-provided 1000011624.jpg",
				"description": "Handheld toy reference: oversized warm head, rose spikes, dark blue uniform, red collar and boots.",
			},
			"semantic_groups": {
				"oversized_head": {"selector": {"tags": ["head"]}, "minimum": 1, "policy": "required"},
				"rose_hair": {"selector": {"tags": ["hair"]}, "minimum": 8, "policy": "required"},
				"cursed_face": {"selector": {"tags": ["marking"]}, "minimum": 10, "policy": "required"},
				"red_eyes": {"selector": {"tags": ["eyes"]}, "minimum": 6, "policy": "required"},
				"uniform_body": {"selector": {"tags": ["outfit"]}, "minimum": 8, "policy": "required"},
			},
			"proportions": [
				{"name": "head_to_full_width", "numerator_axis": 1, "denominator_axis": 0,
					"minimum": 1.20, "maximum": 2.40, "policy": "preferred"},
			],
		},
		"front": "+Z",
		"metadata": {
			"description": "Hero-quality big-head Sukuna-inspired chibi character with modeled tattoos, layered spikes, expressive red eyes, uniform hardware, hands, and boot laces.",
			"style": "collectible vinyl figure with sculptural detail",
			"triangle_target": 60000,
			"reference_asset": "1000011624.jpg",
		},
	}
