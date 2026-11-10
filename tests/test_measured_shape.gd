extends SceneTree

const Attachments := preload("res://addons/polyforge/core/attachments.gd")
const Shape := preload("res://addons/polyforge/core/measured_shape.gd")
const Lint := preload("res://addons/polyforge/quality/lint_core.gd")
const Recipe := preload("res://addons/polyforge/core/asset_recipe.gd")
const Fingerprint := preload("res://addons/polyforge/core/geometry_fingerprint.gd")
const Fit := preload("res://addons/polyforge/quality/fit_validation.gd")
const Checks := preload("res://addons/polyforge/quality/checks.gd")
const Canonical := preload("res://addons/polyforge/core/canonical_artifact.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	var controls := [Vector3.ZERO, Vector3(1, 2, -.5), Vector3(-1, 3, .5), Vector3(0, 4, 0)]
	var previous_samples := 0
	for tolerance in [.08, .02, .005]:
		var sampled := Shape.sample_curve(controls, tolerance)
		check(sampled.ok, "Curve sampling succeeds")
		check(sampled.points.size() >= previous_samples, "Tighter tolerance never reduces samples")
		previous_samples = sampled.points.size()
		check(sampled.points.front() == controls.front() and sampled.points.back() == controls.back(),
			"Cubic endpoints survive adaptive sampling")
		check(sampled.maximum_chord_error_bound <= tolerance, "Reported bound meets requested tolerance")
		for i in range(sampled.points.size() - 1):
			for j in range(21):
				var fraction := float(j) / 20
				var t := lerpf(sampled.parameters[i], sampled.parameters[i + 1], fraction)
				var chord: Vector3 = sampled.points[i].lerp(sampled.points[i + 1], fraction)
				check(chord.distance_to(Shape.bezier(controls, t)) <= tolerance + .000001,
					"Independent dense sampling respects centerline error")
	check(not Shape.sample_curve(controls, .000001, 0).ok, "Unmet tolerance fails at depth limit")
	check(not Shape.sample_curve([], .01).ok, "Missing controls are rejected")
	check(not Shape.sample_curve(controls, NAN).ok, "Nonfinite tolerance is rejected")
	check(not Shape.sample_curve(controls, 0).ok, "Zero tolerance is rejected")
	check(not Shape.curved_tube(controls, -.1, .1, .01).ok, "Negative radius is rejected")
	check(not Shape.curved_tube([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO],
		.1, .1, .01).ok, "Collapsed tube is rejected")
	check(not Shape.curved_tube([Vector3.ZERO, Vector3.UP, Vector3.UP, Vector3.ZERO],
		.1, .1, .01).ok, "Reversing cusp is rejected")
	var tube := Shape.curved_tube(controls, .2, .03, .01)
	check(tube.ok and Lint.check_polymesh(tube.mesh, -1, true).is_empty(),
		"Curved tube is closed with consistent winding")
	check(tube.radial_error_bound <= .01, "Ring approximation meets radial tolerance")
	var stations := [Vector3(.4, 0, .2), Vector3(.8, 1, .5), Vector3(.3, 2, .25)]
	var loft = Shape.loft(stations, .01)
	check(Lint.check_polymesh(loft, -1, true).is_empty(), "Measured loft is closed and oriented")
	check(loft.aabb().size.is_equal_approx(Vector3(1.6, 2, 1)), "Loft preserves measured extrema")
	var polygon := PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(2, 1),
		Vector2(1, .5), Vector2(0, 1)])
	for reversed in [false, true]:
		if reversed:
			polygon.reverse()
		var profile = Shape.extruded_profile(polygon, .2)
		check(Lint.check_polymesh(profile, -1, true).is_empty(), "Concave extrusion accepts either winding")

	var arc = Shape.arc_tube(Vector3.ZERO, Vector3.UP, Vector3.RIGHT,
		.15, .04, 0.0, PI * 1.4, .003)
	check(Lint.check_polymesh(arc, -1, true).is_empty(), "Curled finger is a closed oriented mesh")
	var band = Shape.loft_band(stations, Vector2(-.15, .4), Vector2(.1, 1.6), .1, .01, .025)
	check(Lint.check_polymesh(band, -1, true).is_empty(), "Conformed strap is a closed oriented mesh")
	var inner = Shape.loft([Vector3(.3, 0, .3), Vector3(.3, 1, .3)], .005)
	var shell = Shape.loft([Vector3(.5, 0, .5), Vector3(.5, 1, .5)], .005)
	var inner_geometry := Checks.geometry({"mesh": inner.to_meshes()[""]})
	var shell_geometry := Checks.geometry({"mesh": shell.to_meshes()[""]})
	check(Fit.shell_clearance(inner_geometry, shell_geometry, Transform3D.IDENTITY, .1, .9) > .18,
		"Independent shell rays measure positive clearance")
	check(Fit.shell_clearance(shell_geometry, inner_geometry, Transform3D.IDENTITY, .1, .9) < 0.0,
		"Reversed nested layers fail clearance")
	var triangle := {"vertices": PackedVector3Array([Vector3(1, 0, -.5),
		Vector3(1, 0, .5), Vector3(1.5, 1, 0)]), "triangles": [PackedInt32Array([0, 1, 2])]}
	check(is_equal_approx(Fit.cylinder_clearance(triangle, Vector3.ZERO, Vector3.UP, .5), .5),
		"Handle clearance uses triangle interiors")
	triangle.vertices = PackedVector3Array([Vector3(-1, 0, -.5), Vector3(1, 0, -.5), Vector3(0, 1, .5)])
	check(Fit.cylinder_clearance(triangle, Vector3.ZERO, Vector3.UP, .5) < 0.0,
		"Handle penetration is detected even when every triangle vertex is outside")

	var first := Recipe.load_file("res://examples/minotaur_recipe.gd")
	var second := Recipe.load_file("res://examples/minotaur_recipe.gd")
	check(Fingerprint.assembly_hash(first.assembly) == Fingerprint.assembly_hash(second.assembly),
		"Repeated builds produce identical geometry")
	var coarse := Recipe.load_file("res://examples/minotaur_recipe.gd", {"detail": .6})
	var fine := Recipe.load_file("res://examples/minotaur_recipe.gd", {"detail": 1.8})
	check(Canonical.hash_value(coarse.metadata.shape_definitions) ==
		Canonical.hash_value(fine.metadata.shape_definitions), "Fidelity changes preserve source shapes")
	for spec in [coarse, fine]:
		var fit_rules: Array = []
		for rule in spec.checks:
			if rule.type in ["shell_clearance", "cylinder_clearance"]:
				fit_rules.append(rule)
		check(fit_rules.size() == 17, "Five armor fits and twelve grip fits are mandatory")
		var fit_result := Checks.evaluate(spec.assembly.parts, fit_rules)
		check(fit_result.failures.is_empty(), "Fidelity boundary passes armor and grip checks: " +
			str(fit_result.failures))

	for spec in [first, coarse, fine]:
		check(Checks.evaluate(spec.assembly.parts, spec.checks).failures.is_empty(),
			"All fit and anatomical order rules pass")
		check(Attachments.validate(spec.assembly, spec.attachments).ok, "Horn mounts are valid")
		for suffix in ["L", "R"]:
			var horn = spec.assembly.find("horn_" + suffix)
			var root_position: Vector3 = horn.transform.origin / .9
			check(absf(root_position.x) > .24 and absf(root_position.x) < .35 and
				root_position.y > 3.40 and root_position.y < 3.57 and absf(root_position.z - .035) < .07,
				"Horn root occupies upper lateral skull, independently bounded from reference")
			var geometry := Checks.geometry(horn)
			check(geometry.aabb.end.y > 3.8 * .9 and geometry.aabb.end.y < 4.15 * .9,
				"Horn tips rise above forehead without excessive height")
	var thumb = first.assembly.find("thumb_R")
	var original_thumb: Transform3D = thumb.transform
	var shaft_axis := Vector3(2.63, 1.54, 0).normalized()
	thumb.transform.origin += shaft_axis * .45 * .9
	var flipped := Checks.evaluate(first.assembly.parts, first.checks)
	check(not flipped.failures.is_empty(), "Flipped anatomical thumb fails semantic order")
	var clearance_only: Array = []
	for rule in first.checks:
		if rule.type == "cylinder_clearance":
			clearance_only.append(rule)
	check(Checks.evaluate(first.assembly.parts, clearance_only).failures.is_empty(),
		"Negative control: clearance alone cannot detect flipped hand")
	thumb.transform = original_thumb
	var horn = first.assembly.find("horn_L")
	var original_horn: Transform3D = horn.transform
	horn.transform.origin += Vector3(.15, 0, 0)
	check(not Attachments.validate(first.assembly, first.attachments).ok,
		"Displaced horn is rejected")
	horn.transform = original_horn
	horn.transform.basis = horn.transform.basis.rotated(Vector3.UP, PI)
	check(not Attachments.validate(first.assembly, first.attachments).ok,
		"Rotated horn is rejected even though its root has not moved")
	horn.transform = original_horn

	var coarse_count := 0
	var fine_count := 0
	for i in range(coarse.assembly.parts.size()):
		coarse_count += Lint.triangle_count(coarse.assembly.parts[i].mesh)
		fine_count += Lint.triangle_count(fine.assembly.parts[i].mesh)
	check(fine_count > coarse_count, "Higher fidelity produces more geometry")
	print("measured_shape: %d checks, %d failures; preview=%d hero=%d triangles" %
		[checks, failures, coarse_count, fine_count])
	quit(0 if failures == 0 else 1)
