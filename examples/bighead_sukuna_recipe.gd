extends RefCounted
## Stylized big-head Sukuna character derived from the supplied vinyl-figure reference.
## The reference supplies identity, palette, and proportions; occluded geometry is completed
## symmetrically so the asset reads from all eight PolyForge review angles.

const Assembly := preload("res://addons/polyforge/core/assembly.gd")
const Checks := preload("res://addons/polyforge/quality/checks.gd")
const Parameters := preload("res://addons/polyforge/core/parameters.gd")
const ReferenceProfile := preload("res://addons/polyforge/core/reference_profile.gd")
const Stock := preload("res://addons/polyforge/core/stock.gd")
const SurfaceDecal := preload("res://addons/polyforge/core/surface_decal.gd")

const REFERENCE_SHA256 := "0f6a5494e336b05da880a8fb7ea7de57871659ab817efedd5b87539b6a0ced62"

func _xf(position: Vector3, rotation_degrees := Vector3.ZERO,
		scale := Vector3.ONE) -> Transform3D:
	var radians := Vector3(
		deg_to_rad(rotation_degrees.x),
		deg_to_rad(rotation_degrees.y),
		deg_to_rad(rotation_degrees.z))
	return Transform3D(Basis.from_euler(radians).scaled(scale), position)

func _part(mesh: PrimitiveMesh, material: Material) -> PrimitiveMesh:
	return Stock.with_material(mesh, material)

func _between(start: Vector3, finish: Vector3) -> Transform3D:
	var y_axis := (finish - start).normalized()
	var seed := Vector3.RIGHT
	if absf(y_axis.dot(seed)) > 0.92:
		seed = Vector3.FORWARD
	var z_axis := seed.cross(y_axis).normalized()
	var x_axis := y_axis.cross(z_axis).normalized()
	return Transform3D(Basis(x_axis, y_axis, z_axis), (start + finish) * 0.5)

func _add_spike(asset, name: String, start: Vector3, finish: Vector3,
		base_radius: float, material: Material, tags: Array) -> void:
	asset.add(name, _part(Stock.cylinder(base_radius, 0.015,
		start.distance_to(finish), 7), material), _between(start, finish), {"tags": tags})

func _add_face_ellipse(asset, name: String, head_center: Vector3, head_radii: Vector3,
		local_center: Vector2, size: Vector2, rotation_degrees: float,
		material: Material, height: float, lift: float, tags: Array,
		rings := 3, segments := 18) -> void:
	var mesh := SurfaceDecal.ellipsoid_ellipse_patch(head_center, head_radii,
		local_center, size, rotation_degrees, material, height, lift, rings, segments)
	asset.add(name, mesh, Transform3D.IDENTITY, {"tags": tags})

func _add_face_capsule(asset, name: String, head_center: Vector3, head_radii: Vector3,
		local_center: Vector2, length: float, width: float, rotation_degrees: float,
		material: Material, height: float, lift: float, tags: Array,
		rings := 3, cap_segments := 6) -> void:
	var mesh := SurfaceDecal.ellipsoid_capsule_patch(head_center, head_radii,
		local_center, length, width, rotation_degrees, material, height, lift,
		rings, cap_segments)
	asset.add(name, mesh, Transform3D.IDENTITY, {"tags": tags})

func parameters() -> Dictionary:
	return {
		"height": Parameters.scale(3.9, 3.3, 4.5, "m",
			"Overall character height including the tallest hair spike."),
		"head_scale": Parameters.number(1.0, 0.90, 1.12, "ratio",
			"Independent big-head exaggeration while preserving body scale."),
	}

func build(p) -> Dictionary:
	var height: float = p.value("height")
	var head_scale: float = p.value("head_scale")
	var unit: float = p.derive("character.unit", "height", 1.0 / 3.9)
	var head_radius: float = p.computed("head.radius", 0.72 * unit * head_scale,
		["height", "head_scale"], "0.72 * height / 3.9 * head_scale")
	var head_center := Vector3(0.0, 2.70 * unit, 0.0)
	var head_radii := Vector3(head_radius * 1.06, head_radius, head_radius * 0.94)
	var torso_center := Vector3(0.0, 1.57 * unit, -0.015 * unit)
	var boot_y: float = 0.24 * unit
	var ground_y: float = boot_y - 0.20 * unit
	var hair_top: float = 3.90 * unit

	var skin := Stock.material("skin_warm", Color("f1c6a3"), 0.0, 0.78)
	var skin_shadow := Stock.material("skin_shadow", Color("d99f7f"), 0.0, 0.82)
	var hair := Stock.material("hair_salmon", Color("d88473"), 0.0, 0.74)
	var navy := Stock.material("uniform_navy", Color("172642"), 0.08, 0.72)
	var navy_light := Stock.material("uniform_edge", Color("263c61"), 0.05, 0.68)
	var scarf := Stock.material("scarf_crimson", Color("a82925"), 0.0, 0.62)
	var boot_red := Stock.material("boot_red", Color("9f2824"), 0.02, 0.60)
	var sole := Stock.material("boot_soles", Color("221d20"), 0.0, 0.88)
	var eye_white := Stock.material("eye_white", Color("f7f3e9"), 0.0, 0.66)
	var iris := Stock.material("iris_red", Color("c32f2f"), 0.0, 0.52)
	var feature_black := Stock.material("feature_black", Color("15151b"), 0.0, 0.70)
	var mouth := Stock.material("mouth_coral", Color("e85f61"), 0.0, 0.60)
	var gold := Stock.material("button_gold", Color("d3a84e"), 0.45, 0.40)

	var asset := Assembly.new()

	# Compact body and uniform.
	asset.add("torso", _part(Stock.capsule(0.39 * unit, 0.94 * unit, 14, 7), navy),
		_xf(torso_center, Vector3.ZERO, Vector3(1.08, 1.0, 0.67)),
		{"tags": ["body", "uniform"]})
	asset.add("hips", _part(Stock.sphere(0.36 * unit, 12, 6), navy_light),
		_xf(Vector3(0.0, 1.12 * unit, -0.01 * unit), Vector3.ZERO,
			Vector3(1.06, 0.62, 0.68)), {"tags": ["body", "uniform"]})
	asset.add("collar", _part(Stock.torus(0.22 * unit, 0.38 * unit, 18, 7), scarf),
		_xf(Vector3(0.0, 2.03 * unit, 0.0), Vector3.ZERO, Vector3(1.06, 0.72, 0.92)),
		{"tags": ["uniform", "scarf"]})
	asset.add("collar_front", _part(Stock.box(Vector3(
		0.42 * unit, 0.18 * unit, 0.12 * unit)), scarf),
		_xf(Vector3(0.0, 1.98 * unit, 0.285 * unit), Vector3(-8.0, 0.0, 0.0)),
		{"tags": ["uniform", "scarf"]})
	for index in range(2):
		asset.add("button_%d" % index, _part(Stock.sphere(0.035 * unit, 10, 5), gold),
			_xf(Vector3(0.18 * unit, (1.83 - index * 0.22) * unit, 0.275 * unit),
				Vector3.ZERO, Vector3(1.0, 1.0, 0.45)), {"tags": ["uniform", "trim"]})

	for side in [-1.0, 1.0]:
		var suffix := "L" if side > 0.0 else "R"
		asset.add("arm_" + suffix, _part(Stock.capsule(0.14 * unit, 0.76 * unit, 12, 6), navy),
			_xf(Vector3(side * 0.53 * unit, 1.50 * unit, -0.005 * unit),
				Vector3(0.0, 0.0, side * 7.0), Vector3(1.0, 1.0, 0.84)),
			{"tags": ["body", "uniform", "limb"]})
		asset.add("cuff_" + suffix, _part(Stock.cylinder(
			0.15 * unit, 0.14 * unit, 0.12 * unit, 10), navy_light),
			_xf(Vector3(side * 0.58 * unit, 1.14 * unit, 0.01 * unit),
				Vector3(0.0, 0.0, side * 7.0)), {"tags": ["uniform", "limb"]})
		asset.add("hand_" + suffix, _part(Stock.sphere(0.14 * unit, 12, 6), skin),
			_xf(Vector3(side * 0.59 * unit, 1.01 * unit, 0.035 * unit), Vector3.ZERO,
				Vector3(0.82, 1.0, 0.76)), {"tags": ["body", "hand"]})
		asset.add("leg_" + suffix, _part(Stock.capsule(0.17 * unit, 0.78 * unit, 12, 6), navy),
			_xf(Vector3(side * 0.22 * unit, 0.72 * unit, -0.01 * unit), Vector3.ZERO,
				Vector3(0.90, 1.0, 0.78)), {"tags": ["body", "uniform", "limb"]})
		asset.add("boot_" + suffix, _part(Stock.box(Vector3(
			0.35 * unit, 0.40 * unit, 0.48 * unit)), boot_red),
			_xf(Vector3(side * 0.23 * unit, boot_y, 0.075 * unit),
				Vector3(side * 2.0, 0.0, 0.0)), {"tags": ["footwear", "boot"]})
		asset.add("sole_" + suffix, _part(Stock.box(Vector3(
			0.36 * unit, 0.075 * unit, 0.50 * unit)), sole),
			_xf(Vector3(side * 0.23 * unit, 0.075 * unit, 0.083 * unit)),
			{"tags": ["footwear", "sole"]})
		asset.add("boot_cuff_" + suffix, _part(Stock.cylinder(
			0.19 * unit, 0.17 * unit, 0.13 * unit, 10), boot_red),
			_xf(Vector3(side * 0.23 * unit, 0.46 * unit, 0.015 * unit)),
			{"tags": ["footwear", "boot"]})

	# Oversized head, ears, and nose.
	asset.add("head", _part(Stock.sphere(head_radius, 20, 12), skin),
		_xf(head_center, Vector3.ZERO, Vector3(1.06, 1.0, 0.94)),
		{"tags": ["head", "face", "skin"]})
	for side in [-1.0, 1.0]:
		var suffix := "L" if side > 0.0 else "R"
		asset.add("ear_" + suffix, _part(Stock.sphere(0.15 * unit * head_scale, 12, 6), skin_shadow),
			_xf(head_center + Vector3(side * 0.73 * unit * head_scale, -0.01 * unit, 0.0),
				Vector3.ZERO, Vector3(0.72, 1.0, 0.62)), {"tags": ["head", "face"]})
	asset.add("nose", _part(Stock.sphere(0.105 * unit * head_scale, 12, 6), skin_shadow),
		_xf(head_center + Vector3(0.0, -0.12 * unit, 0.615 * unit * head_scale),
			Vector3.ZERO, Vector3(0.52, 0.72, 0.60)), {"tags": ["face", "nose"]})

	# Eye whites, red irises, pupils, and strongly angled brows.
	for side in [-1.0, 1.0]:
		var suffix := "L" if side > 0.0 else "R"
		var eye_x: float = side * 0.29 * unit * head_scale
		var eye_center := Vector2(eye_x, 0.08 * unit * head_scale)
		var iris_center := Vector2(eye_x - side * 0.015 * unit * head_scale,
			0.075 * unit * head_scale)
		_add_face_ellipse(asset, "eye_white_" + suffix, head_center, head_radii,
			eye_center, Vector2(0.44, 0.26) * unit * head_scale, -side * 8.0,
			eye_white, 0.018 * unit * head_scale, 0.001 * unit,
			["face", "eye", "conformal_patch"], 4, 20)
		_add_face_ellipse(asset, "iris_" + suffix, head_center, head_radii,
			iris_center, Vector2(0.12, 0.15) * unit * head_scale, 0.0,
			iris, 0.005 * unit * head_scale, 0.020 * unit * head_scale,
			["face", "eye", "conformal_patch"], 3, 16)
		_add_face_ellipse(asset, "pupil_" + suffix, head_center, head_radii,
			iris_center, Vector2(0.050, 0.062) * unit * head_scale, 0.0,
			feature_black, 0.003 * unit * head_scale, 0.026 * unit * head_scale,
			["face", "eye", "conformal_patch"], 3, 14)
		_add_face_capsule(asset, "eyebrow_" + suffix, head_center, head_radii,
			Vector2(eye_x, 0.29 * unit * head_scale), 0.34 * unit * head_scale,
			0.070 * unit * head_scale, -side * 71.0, feature_black,
			0.004 * unit * head_scale, 0.001 * unit,
			["face", "brow", "conformal_patch"], 3, 6)

	# Open smirk and tooth strip use the same host ellipsoid and taper flush at their rims.
	_add_face_capsule(asset, "mouth", head_center, head_radii,
		Vector2(0.04 * unit * head_scale, -0.34 * unit * head_scale),
		0.31 * unit * head_scale, 0.18 * unit * head_scale, 84.0, mouth,
		0.012 * unit * head_scale, 0.001 * unit,
		["face", "mouth", "conformal_patch"], 4, 7)
	_add_face_capsule(asset, "teeth", head_center, head_radii,
		Vector2(0.02 * unit * head_scale, -0.285 * unit * head_scale),
		0.19 * unit * head_scale, 0.050 * unit * head_scale, 85.0, eye_white,
		0.002 * unit * head_scale, 0.014 * unit * head_scale,
		["face", "mouth", "conformal_patch"], 3, 6)

	# Salmon hair cap and low-poly spikes. Back spikes make the unseen side cohesive.
	asset.add("hair_cap", _part(Stock.sphere(0.73 * unit * head_scale, 18, 9), hair),
		_xf(head_center + Vector3(0.0, 0.30 * unit, -0.09 * unit), Vector3.ZERO,
			Vector3(1.07, 0.70, 0.94)), {"tags": ["head", "hair"]})
	var spikes := [
		[Vector3(-0.04, 3.28, -0.02), Vector3(-0.05, 3.90, 0.00), 0.19],
		[Vector3(-0.31, 3.26, -0.02), Vector3(-0.58, 3.78, 0.00), 0.18],
		[Vector3(0.27, 3.27, -0.02), Vector3(0.55, 3.78, 0.00), 0.18],
		[Vector3(-0.56, 3.13, -0.04), Vector3(-0.97, 3.51, -0.02), 0.17],
		[Vector3(0.55, 3.13, -0.04), Vector3(0.97, 3.51, -0.02), 0.17],
		[Vector3(-0.48, 3.19, -0.30), Vector3(-0.72, 3.57, -0.60), 0.16],
		[Vector3(0.48, 3.19, -0.30), Vector3(0.72, 3.57, -0.60), 0.16],
		[Vector3(0.00, 3.25, -0.42), Vector3(0.00, 3.67, -0.77), 0.17],
		[Vector3(-0.25, 3.18, 0.29), Vector3(-0.39, 3.51, 0.50), 0.13],
		[Vector3(0.25, 3.18, 0.29), Vector3(0.39, 3.51, 0.50), 0.13],
	]
	for index in range(spikes.size()):
		var spike: Array = spikes[index]
		var start: Vector3 = spike[0] * unit
		var finish: Vector3 = spike[1] * unit
		start.x *= head_scale
		finish.x *= head_scale
		start.z *= head_scale
		finish.z *= head_scale
		if index == 0:
			finish.y = hair_top
		_add_spike(asset, "hair_spike_%02d" % index, start, finish,
			float(spike[2]) * unit * head_scale, hair, ["head", "hair"])

	var reference := ReferenceProfile.new({
		"id": "bighead_sukuna_figure_photo_v1",
		"sha256": REFERENCE_SHA256,
		"width": 1152,
		"height": 1536,
		"description": "user-supplied photo of a stylized big-head Sukuna figure",
	}, {
		"oversized_head": {"selector": {"tags": ["head"]}, "minimum": 2},
		"pink_spiked_hair": {"selector": {"tags": ["hair"]}, "minimum": 10},
		"face_identity": {"selector": {"tags": ["face"]}, "minimum": 12},
		"navy_uniform": {"selector": {"tags": ["uniform"]}, "minimum": 8},
		"red_boots": {"selector": {"tags": ["boot"]}, "minimum": 4},
	}, {
		"head_center": {"minimum": Vector3(0.42, 0.58, 0.25),
			"maximum": Vector3(0.58, 0.82, 0.75)},
		"ground": {"minimum": Vector3(0.35, 0.0, 0.20),
			"maximum": Vector3(0.65, 0.08, 0.80)},
	}, [], [{
		"name": "compact big-head silhouette",
		"numerator_axis": 1,
		"denominator_axis": 0,
		"minimum": 1.55,
		"maximum": 2.35,
	}], "bighead_sukuna.reference_profile.v1", {
		"semantic_groups": "required",
		"anchors": "preferred",
		"appearance_slots": "informational",
		"proportions": "preferred",
	})
	assert(reference.validate().is_empty(), "reference profile must validate")

	return {
		"name": "bighead_sukuna",
		"category": "character",
		"assembly": asset,
		"triangle_budget": 12000,
		"topology_budget": {"rendered_triangles": 12000, "unique_triangles": 12000},
		"quality_profile": "hero",
		"checks": [
			Checks.require_axis_ratio("head", 0, "torso", 0, 1.45, 2.20),
			Checks.require_axis_size("head", 0, head_radius * 2.0 * 1.06,
				height * 0.005),
			Checks.require_axis_range("sole_L", 1, 0.06 * unit, 0.09 * unit),
		],
		"anchors": {
			"head_center": head_center,
			"face_center": head_center + Vector3(0.0, -0.05 * unit, 0.60 * unit),
			"chest": torso_center + Vector3(0.0, 0.14 * unit, 0.30 * unit),
			"ground": Vector3(0.0, ground_y, 0.0),
		},
		"reference_profile": reference.to_canonical_dict(),
		"readability": {
			"target_pixels": 96,
			"supersample": 2,
			"view_set": "octants",
			"minimum_regions": 6,
			"minimum_contrast": 0.055,
			"minimum_stroke_px": 1.0,
			"required": true,
			"critical_parts": {
				"face": {"minimum_visible_fraction": 0.03,
					"members": PackedStringArray(["eye_white_L", "eye_white_R", "mouth"]),
					"views": [0.0, 45.0, 315.0]},
				"hair": {"minimum_visible_fraction": 0.04,
					"members": PackedStringArray(["hair_cap", "hair_spike_00"])},
			},
		},
		"front": "+Z",
		"metadata": {
			"description": "Procedural low-poly big-head Sukuna with conformal eyes and mouth",
			"surface_details": "polyforge.ellipsoid_feathered_patch.v1",
			"reference_image_sha256": REFERENCE_SHA256,
			"reference_claims": {
				"required": ["oversized head", "salmon spiked hair",
					"navy uniform", "red collar and boots"],
				"preferred": ["red eyes", "open smirk", "compact vinyl-figure proportions"],
				"informational": ["rear hair and uniform completion are symmetric"],
			},
		},
	}
