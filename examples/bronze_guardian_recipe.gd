extends RefCounted
## Small named-part recipe demonstrating the standalone compiler contract.

const Assembly := preload("res://addons/polyforge/core/assembly.gd")
const Parameters := preload("res://addons/polyforge/core/parameters.gd")
const Stock := preload("res://addons/polyforge/core/stock.gd")
const Checks := preload("res://addons/polyforge/quality/checks.gd")

func _xf(position: Vector3, rotation_degrees := Vector3.ZERO,
		scale := Vector3.ONE) -> Transform3D:
	var radians := Vector3(
		deg_to_rad(rotation_degrees.x),
		deg_to_rad(rotation_degrees.y),
		deg_to_rad(rotation_degrees.z))
	return Transform3D(Basis.from_euler(radians).scaled(scale), position)

func _part(mesh: PrimitiveMesh, material: Material) -> PrimitiveMesh:
	return Stock.with_material(mesh, material)

func parameters() -> Dictionary:
	return {
		"height": Parameters.scale(3.4, 2.4, 5.0, "m",
			"Overall character height; every physical measurement derives from it."),
		"bulk": Parameters.number(1.0, 0.8, 1.25, "ratio",
			"Dimensionless horizontal armor and stance multiplier."),
	}

func build(p) -> Dictionary:
	var height: float = p.value("height")
	var bulk: float = p.value("bulk")
	var torso_radius: float = p.derive("torso.radius", "height", 0.2941)
	var torso_y: float = p.derive("torso.center_y", "height", 0.6176)
	var torso_height: float = p.computed("torso.height", torso_radius * 1.44,
		["torso.radius"], "torso.radius * 2 * 0.72")
	var collar_y: float = p.derive("collar.center_y", "height", 0.7735)
	var collar_inner: float = p.derive("collar.inner_radius", "height", 0.1471)
	var collar_outer: float = p.derive("collar.outer_radius", "height", 0.2000)
	var head_y: float = p.derive("head.center_y", "height", 0.8706)
	var head_radius: float = p.derive("head.radius", "height", 0.1706)
	var cap_y: float = p.derive("head.cap_center_y", "height", 0.9912)
	var visor_y: float = p.derive("head.visor_center_y", "height", 0.8853)
	var visor_z: float = p.derive("head.visor_center_z", "height", 0.1471)
	var shoulder_x: float = p.computed("arm.shoulder_x", height * 0.3176 * bulk,
		["height", "bulk"], "height * 0.3176 * bulk")
	var hip_x: float = p.computed("leg.hip_x", height * 0.1265 * bulk,
		["height", "bulk"], "height * 0.1265 * bulk")
	var boot_y: float = p.derive("leg.boot_center_y", "height", 0.0529)
	var shin_y: float = p.derive("leg.shin_center_y", "height", 0.1559)
	var thigh_y: float = p.derive("leg.thigh_center_y", "height", 0.3059)
	var fist_y: float = p.derive("arm.fist_center_y", "height", 0.2853)
	var bracer_y: float = p.derive("arm.bracer_center_y", "height", 0.4206)
	var upper_arm_y: float = p.derive("arm.upper_center_y", "height", 0.5824)

	var gunmetal := Stock.material("gunmetal", Color("605d59"), 0.55, 0.72)
	var dark := Stock.material("dark_joint", Color("24211f"), 0.35, 0.84)
	var bronze := Stock.material("bronze", Color("a47749"), 0.64, 0.58)
	var gold := Stock.material("gold_trim", Color("d0a15c"), 0.72, 0.46)
	var glow := Stock.glow_material("visor_glow", Color("20eee0"), 2.0)

	var asset := Assembly.new()
	asset.add("torso", _part(Stock.sphere(torso_radius, 14, 7), gunmetal),
		_xf(Vector3(0, torso_y, 0), Vector3.ZERO, Vector3(1.05 * bulk, 0.72, 0.62 * bulk)),
		{"tags": ["body", "armor"]})
	asset.add("collar", _part(Stock.torus(collar_inner, collar_outer, 20, 7), dark),
		_xf(Vector3(0, collar_y, 0), Vector3.ZERO, Vector3(1.25 * bulk, 1.0, 0.9 * bulk)),
		{"tags": ["joint"]})
	asset.add("helmet", _part(Stock.sphere(head_radius, 14, 7), bronze),
		_xf(Vector3(0, head_y, height * 0.0118), Vector3.ZERO,
			Vector3(bulk, 0.82, 0.88 * bulk)),
		{"tags": ["head", "armor"]})
	asset.add("helmet_cap", _part(Stock.box(Vector3(
		height * 0.1176 * bulk, height * 0.0324, height * 0.1000 * bulk)), gold),
		_xf(Vector3(0, cap_y, height * 0.0059)), {"tags": ["head", "trim"]})
	asset.add("visor", _part(Stock.sphere(height * 0.0882, 16, 5), glow),
		_xf(Vector3(0, visor_y, visor_z), Vector3.ZERO, Vector3(1.48 * bulk, 0.27, 0.15)),
		{"tags": ["emissive", "front"]})
	asset.add("chest_badge", _part(Stock.cylinder(
		height * 0.0971 * bulk, height * 0.0971 * bulk, height * 0.0353, 6), bronze),
		_xf(Vector3(0, height * 0.6265, height * 0.1882 * bulk), Vector3(90, 0, 0)),
		{"tags": ["armor"]})

	for side in [-1.0, 1.0]:
		var suffix := "L" if side > 0.0 else "R"
		asset.add("pauldron_" + suffix, _part(Stock.sphere(height * 0.1794, 12, 6), bronze),
			_xf(Vector3(side * shoulder_x, height * 0.7471, height * 0.0118),
				Vector3.ZERO, Vector3(bulk, 0.76, 0.88 * bulk)),
			{"tags": ["armor", "side"]})
		asset.add("upper_arm_" + suffix, _part(Stock.cylinder(
			height * 0.0647 * bulk, height * 0.0588 * bulk, height * 0.1824, 10), dark),
			_xf(Vector3(side * shoulder_x * 1.0185, upper_arm_y, 0)), {"tags": ["limb"]})
		asset.add("bracer_" + suffix, _part(Stock.cylinder(
			height * 0.1294 * bulk, height * 0.1029 * bulk, height * 0.1706, 10), bronze),
			_xf(Vector3(side * shoulder_x * 1.0370, bracer_y, height * 0.0059)),
			{"tags": ["armor", "limb"]})
		asset.add("fist_" + suffix, _part(Stock.sphere(height * 0.1324 * bulk, 12, 6), gunmetal),
			_xf(Vector3(side * shoulder_x * 1.0370, fist_y, height * 0.0265),
				Vector3.ZERO, Vector3(1.0, 0.90 / bulk, 0.95)),
			{"tags": ["hand"]})
		asset.add("thigh_" + suffix, _part(Stock.cylinder(
			height * 0.0794 * bulk, height * 0.0706 * bulk, height * 0.1706, 10), dark),
			_xf(Vector3(side * hip_x, thigh_y, 0)), {"tags": ["limb"]})
		asset.add("shin_" + suffix, _part(Stock.cylinder(
			height * 0.0794 * bulk, height * 0.0676 * bulk, height * 0.1353, 10), bronze),
			_xf(Vector3(side * hip_x, shin_y, height * 0.0059)), {"tags": ["armor", "limb"]})
		asset.add("boot_" + suffix, _part(Stock.box(Vector3(
			height * 0.1706 * bulk, height * 0.0882, height * 0.2235 * bulk)), gunmetal),
			_xf(Vector3(side * hip_x, boot_y, height * 0.0471 * bulk)), {"tags": ["foot"]})

	return {
		"name": "bronze_guardian",
		"category": "character",
		"assembly": asset,
		"triangle_budget": 6500,
		"checks": [
			Checks.require_axis_ratio("torso", 0, "torso", 1, 1.1, 1.9),
			Checks.require_axis_size("torso", 1, torso_height, height * 0.01),
		],
		"anchors": {
			"head": Vector3(0, head_y, height * 0.0118),
			"chest": Vector3(0, height * 0.6265, height * 0.1882 * bulk),
			"ground": Vector3.ZERO,
		},
		"front": "+Z",
		"metadata": {"description": "Chunky armored robot parameterized by height and bulk"},
	}
