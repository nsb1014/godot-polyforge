extends RefCounted
## Small named-part recipe demonstrating the standalone compiler contract.

const Assembly := preload("res://addons/polyforge/core/assembly.gd")
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

func build() -> Dictionary:
	var gunmetal := Stock.material("gunmetal", Color("605d59"), 0.55, 0.72)
	var dark := Stock.material("dark_joint", Color("24211f"), 0.35, 0.84)
	var bronze := Stock.material("bronze", Color("a47749"), 0.64, 0.58)
	var gold := Stock.material("gold_trim", Color("d0a15c"), 0.72, 0.46)
	var glow := Stock.glow_material("visor_glow", Color("20eee0"), 2.0)

	var asset := Assembly.new()
	asset.add("torso", _part(Stock.sphere(1.0, 14, 7), gunmetal),
		_xf(Vector3(0, 2.1, 0), Vector3.ZERO, Vector3(1.05, 0.72, 0.62)),
		{"tags": ["body", "armor"]})
	asset.add("collar", _part(Stock.torus(0.50, 0.68, 20, 7), dark),
		_xf(Vector3(0, 2.63, 0), Vector3.ZERO, Vector3(1.25, 1.0, 0.9)),
		{"tags": ["joint"]})
	asset.add("helmet", _part(Stock.sphere(0.58, 14, 7), bronze),
		_xf(Vector3(0, 2.96, 0.04), Vector3.ZERO, Vector3(1.0, 0.82, 0.88)),
		{"tags": ["head", "armor"]})
	asset.add("helmet_cap", _part(Stock.box(Vector3(0.40, 0.11, 0.34)), gold),
		_xf(Vector3(0, 3.37, 0.02)), {"tags": ["head", "trim"]})
	asset.add("visor", _part(Stock.sphere(0.30, 16, 5), glow),
		_xf(Vector3(0, 3.01, 0.50), Vector3.ZERO, Vector3(1.48, 0.27, 0.15)),
		{"tags": ["emissive", "front"]})
	asset.add("chest_badge", _part(Stock.cylinder(0.33, 0.33, 0.12, 6), bronze),
		_xf(Vector3(0, 2.13, 0.64), Vector3(90, 0, 0)), {"tags": ["armor"]})

	for side in [-1.0, 1.0]:
		var suffix := "L" if side > 0.0 else "R"
		asset.add("pauldron_" + suffix, _part(Stock.sphere(0.61, 12, 6), bronze),
			_xf(Vector3(side * 1.08, 2.54, 0.04), Vector3.ZERO, Vector3(1.0, 0.76, 0.88)),
			{"tags": ["armor", "side"]})
		asset.add("upper_arm_" + suffix, _part(Stock.cylinder(0.22, 0.20, 0.62, 10), dark),
			_xf(Vector3(side * 1.10, 1.98, 0.0)), {"tags": ["limb"]})
		asset.add("bracer_" + suffix, _part(Stock.cylinder(0.44, 0.35, 0.58, 10), bronze),
			_xf(Vector3(side * 1.12, 1.43, 0.02)), {"tags": ["armor", "limb"]})
		asset.add("fist_" + suffix, _part(Stock.sphere(0.45, 12, 6), gunmetal),
			_xf(Vector3(side * 1.12, 0.97, 0.09), Vector3.ZERO, Vector3(1.0, 0.90, 0.95)),
			{"tags": ["hand"]})
		asset.add("thigh_" + suffix, _part(Stock.cylinder(0.27, 0.24, 0.58, 10), dark),
			_xf(Vector3(side * 0.43, 1.04, 0.0)), {"tags": ["limb"]})
		asset.add("shin_" + suffix, _part(Stock.cylinder(0.27, 0.23, 0.46, 10), bronze),
			_xf(Vector3(side * 0.43, 0.53, 0.02)), {"tags": ["armor", "limb"]})
		asset.add("boot_" + suffix, _part(Stock.box(Vector3(0.58, 0.30, 0.76)), gunmetal),
			_xf(Vector3(side * 0.43, 0.18, 0.16)), {"tags": ["foot"]})

	return {
		"name": "bronze_guardian",
		"category": "character",
		"assembly": asset,
		"triangle_budget": 6500,
		"checks": [Checks.require_axis_ratio("torso", 0, "torso", 1, 1.2, 1.8)],
		"anchors": {
			"head": Vector3(0, 2.96, 0.04),
			"chest": Vector3(0, 2.13, 0.64),
			"ground": Vector3.ZERO,
		},
		"front": "+Z",
		"metadata": {"description": "Chunky armored robot example"},
	}
