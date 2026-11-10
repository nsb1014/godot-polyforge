extends RefCounted
## Static reference study. All coordinates are in a four-unit authoring frame.
## Height scales that frame uniformly; thickness behind the image is inferred.

const Assembly := preload("res://addons/polyforge/core/assembly.gd")
const Parameters := preload("res://addons/polyforge/core/parameters.gd")
const Shape := preload("res://addons/polyforge/core/measured_shape.gd")
const Stock := preload("res://addons/polyforge/core/stock.gd")
const SurfaceTypes := preload("res://addons/polyforge/core/surface_types.gd")
const Checks := preload("res://addons/polyforge/quality/checks.gd")
const Intent := preload("res://addons/polyforge/core/asset_intent.gd")
const Resolved := preload("res://addons/polyforge/core/resolved_design.gd")
const Binding := preload("res://addons/polyforge/core/appearance_style_binding.gd")
const Style := preload("res://addons/polyforge/build/style_compiler.gd")
const Stages := preload("res://addons/polyforge/build/stage_runner.gd")
const Canonical := preload("res://addons/polyforge/core/canonical_artifact.gd")
const Reference := preload("res://addons/polyforge/core/reference_profile.gd")

const REFERENCE_SHA := "64f7a9ab586a343bc96efab38c149a99084cde31f1611665dc52ace09cd10543"
var asset
var unit := 1.0
var tolerance := 0.012
var shapes: Array = []
var curve_evidence: Array = []
var slots := {}
var layer_fits: Array = []
var grips: Array = []

func parameters() -> Dictionary:
	return {
		"height": Parameters.scale(3.6, 2.8, 4.4, "m", "Assumed horn-tip stature"),
		"detail": Parameters.number(1.0, 0.6, 1.8, "ratio", "Tessellation fidelity; shape stays fixed"),
	}

func _add(name: String, mesh: Mesh, position: Vector3, basis: Basis,
		material: String, construction := "organic", role := "primary_silhouette") -> void:
	mesh.surface_set_material(0, slots[material])
	asset.add(name, mesh, Transform3D(basis.scaled(Vector3.ONE * unit), position * unit),
		{"tags": [material, name.get_slice("_", 0)],
		"surface": SurfaceTypes.classify(construction, role, "unique", "static", {"axis": "y"})})

func _poly(name: String, poly, material: String, position := Vector3.ZERO,
		basis := Basis.IDENTITY, construction := "lofted", smooth := 55.0) -> void:
	_add(name, poly.to_meshes(smooth)[""], position, basis, material, construction)

func _ellipsoid(name: String, center: Vector3, radii: Vector3, material: String,
		rotation := Vector3.ZERO) -> void:
	shapes.append({"name": name, "type": "ellipsoid", "center": center, "radii": radii,
		"rotation": rotation, "slot": material})

func _loft(name: String, stations: Array, material: String, position := Vector3.ZERO,
		basis := Basis.IDENTITY) -> void:
	shapes.append({"name": name, "type": "elliptical_stations", "stations": stations,
		"position": position, "basis": basis, "slot": material})

func _limb(name: String, start: Vector3, end: Vector3, radius: float,
		material: String, depth_ratio := 0.86) -> void:
	var length := start.distance_to(end)
	var basis := Basis(Quaternion(Vector3.UP, (end - start).normalized()))
	_loft(name, [Vector3(radius * 0.68, 0, radius * depth_ratio * 0.68),
		Vector3(radius, length * 0.28, radius * depth_ratio),
		Vector3(radius * 0.92, length * 0.70, radius * depth_ratio * 0.92),
		Vector3(radius * 0.65, length, radius * depth_ratio * 0.65)], material, start, basis)

func _tube(name: String, controls: Array, start_radius: float, end_radius: float,
		material: String) -> void:
	shapes.append({"name": name, "type": "cubic_tube", "controls": controls,
		"start_radius": start_radius, "end_radius": end_radius, "slot": material})

func _plate(name: String, points: Array, depth: float, material: String,
		position := Vector3.ZERO, rotation := 0.0) -> void:
	var polygon := PackedVector2Array()
	for point in points:
		polygon.append(point)
	shapes.append({"name": name, "type": "extruded_profile", "outline": polygon,
		"depth": depth, "position": position, "rotation": rotation, "slot": material})

func _rod(name: String, start: Vector3, end: Vector3, radius: float, material: String) -> void:
	var direction := end - start
	_loft(name, [Vector3(radius, 0, radius), Vector3(radius, direction.length(), radius)],
		material, start, Basis(Quaternion(Vector3.UP, direction.normalized())))

func _ring(name: String, center: Vector3, inner: float, outer: float,
		material: String, basis := Basis.IDENTITY) -> void:
	shapes.append({"name": name, "type": "torus", "center": center,
		"inner": inner, "outer": outer, "basis": basis, "slot": material})

func _definition(name: String) -> Dictionary:
	for definition in shapes:
		if definition.name == name:
			return definition
	assert(false, "Unknown shape owner: " + name)
	return {}

func _fitted_armor(name: String, owner: String, start: float, end: float,
		clearance: float) -> Array:
	var body := _definition(owner)
	var stations: Array = body.stations
	var heights: Array = [start]
	for station in stations:
		if station.y > start and station.y < end:
			heights.append(station.y)
	heights.append(end)
	var shell: Array = []
	for height in heights:
		var section := Shape.section_at(stations, height)
		shell.append(Vector3(section.x + clearance, section.y, section.z + clearance))
	_loft(name, shell, "steel", body.position, body.basis)
	layer_fits.append({"inner": owner, "outer": name, "start": start, "end": end,
		"minimum_clearance": clearance * .25})
	return shell

func _arc(name: String, center: Vector3, axis: Vector3, radial: Vector3,
		bend: float, radius: float, start: float, end: float) -> void:
	shapes.append({"name": name, "type": "arc_tube", "center": center, "axis": axis,
		"radial": radial, "bend_radius": bend, "radius": radius,
		"start": start, "end": end, "slot": "hide"})

func _grip(suffix: String, center: Vector3, axis: Vector3, elbow: Vector3) -> Vector3:
	var toward_elbow := elbow - center
	var palm_normal := (toward_elbow - axis * toward_elbow.dot(axis)).normalized()
	var across := palm_normal.cross(axis)
	var palm_frame := Basis(axis, across, palm_normal)
	_ellipsoid("hand_" + suffix, center + palm_normal * .182,
		Vector3(.21, .142, .09), "hide", palm_frame.get_euler())
	for finger in range(4):
		var finger_center := center + axis * ((finger - 1.5) * .103)
		_arc("finger_%s_%d" % [suffix, finger], finger_center, axis, palm_normal,
			.135, .046, deg_to_rad(10), deg_to_rad(250))
	_arc("thumb_" + suffix, center + axis * .225, axis, palm_normal,
		.15, .06, deg_to_rad(-15), deg_to_rad(-125))
	var wrist := center + palm_normal * .285
	grips.append({"suffix": suffix, "center": center, "axis": axis,
		"handle_radius": .078, "minimum_clearance": .004,
		"maximum_contact_gap": .025, "wrist": wrist})
	return wrist

func _compile_shapes(definitions: Array) -> void:
	for definition in definitions:
		var name: String = definition.name
		var material: String = definition.slot
		match definition.type:
			"ellipsoid":
				var radii: Vector3 = definition.radii
				var sides := Shape.radial_segments(maxf(radii.x, maxf(radii.y, radii.z)), tolerance)
				_add(name, Stock.sphere(1.0, sides, maxi(4, sides / 2)), definition.center,
					Basis.from_euler(definition.rotation) * Basis.from_scale(radii), material)
			"elliptical_stations":
				_poly(name, Shape.loft(definition.stations, tolerance), material,
					definition.position, definition.basis)
			"cubic_tube":
				var compiled := Shape.curved_tube(definition.controls, definition.start_radius,
					definition.end_radius, tolerance * 0.5)
				assert(compiled.ok, str(compiled.get("error", "")))
				curve_evidence.append({"name": name, "samples": compiled.points.size(),
					"centerline_error_bound_m": compiled.maximum_chord_error_bound * unit,
					"ring_error_bound_m": compiled.radial_error_bound * unit,
					"tolerance_m": tolerance * 0.5 * unit})
				_poly(name, compiled.mesh, material, Vector3.ZERO, Basis.IDENTITY, "organic", 65.0)
			"extruded_profile":
				_poly(name, Shape.extruded_profile(definition.outline, definition.depth), material,
					definition.position, Basis(Vector3.FORWARD, definition.rotation), "profile", -1.0)
			"arc_tube":
				_poly(name, Shape.arc_tube(definition.center, definition.axis, definition.radial,
					definition.bend_radius, definition.radius, definition.start, definition.end,
					minf(tolerance * .25, .003)), material, Vector3.ZERO, Basis.IDENTITY, "organic", 65.0)
			"loft_band":
				_poly(name, Shape.loft_band(definition.stations, definition.start, definition.end,
					definition.width, definition.offset, definition.thickness), material,
					Vector3.ZERO, Basis.IDENTITY, "profile", 55.0)

			"torus":
				var sides := Shape.radial_segments(definition.outer, tolerance * 0.5)
				_add(name, Stock.torus(definition.inner, definition.outer, sides, 8),
					definition.center, definition.basis, material, "revolved", "trim")
			_:
				assert(false, "Unknown measured shape: " + str(definition.type))

func build(p) -> Dictionary:
	asset = Assembly.new()
	shapes.clear()
	curve_evidence.clear()
	layer_fits.clear()
	grips.clear()
	unit = p.derive("authoring.unit", "height", 0.25)
	tolerance = 0.014 / p.value("detail")
	var palette := {
		"hide": {"color": "75482f", "roughness": 0.9},
		"muzzle": {"color": "51372c", "roughness": 0.9},
		"mane": {"color": "39241d", "roughness": 0.95},
		"fur": {"color": "8d7866", "roughness": 0.95},
		"steel": {"color": "434955", "metallic": 0.7, "roughness": 0.46},
		"edge": {"color": "8d939e", "metallic": 0.75, "roughness": 0.36},
		"gold": {"color": "c79852", "metallic": 0.65, "roughness": 0.4},
		"leather": {"color": "33251f", "roughness": 0.85},
		"cloth": {"color": "842b32", "roughness": 1.0},
		"ivory": {"color": "ddc9a5", "roughness": 0.65},
		"hoof": {"color": "29282b", "roughness": 0.7},
		"cyan": {"color": "04a7c9", "emission_enabled": true,
			"emission": "0084b0", "emission_energy": 0.7},
	}
	for key in palette:
		slots[key] = Style.slot(key)

	# Primary masses: wide chest, narrow waist, compact pelvis, separated legs.
	_loft("body_torso", [Vector3(.40, 1.56, .29), Vector3(.45, 1.88, .32),
		Vector3(.59, 2.25, .37), Vector3(.72, 2.63, .38), Vector3(.65, 2.83, .31),
		Vector3(.32, 2.98, .25)], "hide")
	_ellipsoid("body_pelvis", Vector3(0, 1.55, 0), Vector3(.53, .38, .33), "leather")
	_ellipsoid("neck", Vector3(0, 2.97, 0), Vector3(.34, .38, .28), "hide")
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0 else "R"
		var hip := Vector3(side * .34, 1.61, 0)
		var knee := Vector3(side * .56, .89, .06)
		var ankle := Vector3(side * .67, .28, -.025)
		_limb("thigh_" + suffix, hip, knee, .31, "hide")
		_limb("shin_" + suffix, knee, ankle, .23, "hide")
		for toe in [-1.0, 1.0]:
			_loft("hoof_%s_%s" % [suffix, str(toe)], [Vector3(.13, 0, .29),
				Vector3(.145, .09, .30), Vector3(.12, .23, .22), Vector3(.09, .30, .15)],
				"hoof", Vector3(ankle.x + toe * .145, 0, .13))
		_ellipsoid("knee_guard_" + suffix, knee + Vector3(0, .005, .19),
			Vector3(.28, .25, .13), "steel")
		_ellipsoid("knee_boss_" + suffix, knee + Vector3(0, .015, .31),
			Vector3(.12, .11, .055), "gold")
		var shin_length := knee.distance_to(ankle)
		var greave_stations := _fitted_armor("greave_" + suffix, "shin_" + suffix,
			shin_length * .12, shin_length * .88, .035)
		var shin_frame := Basis(Quaternion(Vector3.UP, (ankle - knee).normalized()))
		for level in [.14, .86]:
			var section := Shape.section_at(greave_stations, shin_length * level)
			var ellipse := Basis.from_scale(Vector3(1, 1, section.z / section.x))
			_ring("greave_rim_%s_%s" % [suffix, str(level)], knee.lerp(ankle, level),
				section.x - .015, section.x + .020, "gold", shin_frame * ellipse)
		# Layered hip plates, anchored to the belt.
		for j in range(3):
			_plate("hip_plate_%s_%d" % [suffix, j], [Vector2(-.13, .12),
				Vector2(.13, .12), Vector2(.17, -.25), Vector2(-.11, -.29)], .07,
				"steel", Vector3(side * (.28 + j * .15), 1.56 - j * .025, .33 - j * .055),
				side * .22)

	# Breastplate follows the measured body taper. Gold rims remain separate surfaces.
	var chest_stations := _fitted_armor("armor_breastplate", "body_torso", 1.95, 2.73, .04)
	for side in [-1.0, 1.0]:
		_rod("chest_rim_" + str(side), Vector3(0, 2.48, .405),
			Vector3(side * .57, 2.72, .24), .026, "gold")
	_loft("belt", [Vector3(.47, 1.76, .35), Vector3(.47, 1.91, .35)], "leather")
	_plate("belt_buckle", [Vector2(-.15, -.12), Vector2(.15, -.12),
		Vector2(.15, .12), Vector2(-.15, .12)], .065, "gold", Vector3(0, 1.84, .38))
	_plate("buckle_inset", [Vector2(-.10, -.075), Vector2(.10, -.075),
		Vector2(.10, .075), Vector2(-.10, .075)], .025, "leather", Vector3(0, 1.84, .425))
	_plate("tabard", [Vector2(-.24, 0), Vector2(.24, 0), Vector2(.21, -.78),
		Vector2(.09, -.98), Vector2(.02, -.86), Vector2(-.05, -.94), Vector2(-.22, -.76)],
		.035, "cloth", Vector3(0, 1.76, .39))
	_plate("tabard_crest", [Vector2(0, .20), Vector2(.05, .04), Vector2(.14, .15),
		Vector2(.11, -.03), Vector2(.035, -.10), Vector2(0, -.24),
		Vector2(-.035, -.10), Vector2(-.11, -.03), Vector2(-.14, .15), Vector2(-.05, .04)],
		.008, "gold", Vector3(0, 1.27, .414))
	_plate("back_tabard", [Vector2(-.23, 0), Vector2(.23, 0), Vector2(.20, -.55),
		Vector2(0, -.68), Vector2(-.20, -.55)], .03, "cloth", Vector3(0, 1.74, -.35))

	# Axe axis defines both grips. Arms terminate at those grips.
	var axe_start := Vector3(-1.03, 1.40, .67)
	var axe_end := Vector3(1.60, 2.94, .67)
	var axe_axis := (axe_end - axe_start).normalized()
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0 else "R"
		var shoulder := Vector3(side * .79, 2.75, 0)
		var elbow := Vector3(-1.01, 2.12, .18) if side < 0 else Vector3(1.02, 2.26, .20)
		var hand := axe_start.lerp(axe_end, .24 if side < 0 else .70)
		# The hidden shoulder volume is owned by the pauldron; exposed flesh starts below it.
		_limb("upper_arm_" + suffix, shoulder.lerp(elbow, .40), elbow, .34, "hide")
		var wrist := _grip(suffix, hand, axe_axis, elbow)
		var forearm_length := elbow.distance_to(wrist)
		var forearm_frame := Basis(Quaternion(Vector3.UP, (wrist - elbow).normalized()))
		_loft("forearm_" + suffix, [Vector3(.21, 0, .19),
			Vector3(.27, forearm_length * .28, .23),
			Vector3(.205, forearm_length * .70, .18),
			Vector3(.115, forearm_length, .105)], "hide", elbow, forearm_frame)
		var bracer_stations := _fitted_armor("bracer_" + suffix, "forearm_" + suffix,
			forearm_length * .18, forearm_length * .86, .035)
		for fraction in [.20, .84]:
			var section := Shape.section_at(bracer_stations, forearm_length * fraction)
			var ellipse := Basis.from_scale(Vector3(1, 1, section.z / section.x))
			_ring("bracer_rim_%s_%s" % [suffix, str(fraction)], elbow.lerp(wrist, fraction),
				section.x - .015, section.x + .020, "gold", forearm_frame * ellipse)
		# Overlapping metal shoulder shells, largest toward the top.
		for layer in range(3):
			var width := .48 - layer * .035
			var center := shoulder + Vector3(side * .035 * layer, .11 - layer * .13, 0)
			_loft("pauldron_%s_%d" % [suffix, layer], [Vector3(width, -.08, .40),
				Vector3(width * .95, .07, .38), Vector3(width * .67, .25, .27),
				Vector3(width * .18, .31, .10)], "steel", center)
			_loft("pauldron_trim_%s_%d" % [suffix, layer], [Vector3(width + .012, -.095, .412),
				Vector3(width + .012, -.055, .412)], "gold" if layer == 0 else "edge", center)
		for spike in range(2):
			var base := shoulder + Vector3(side * (.18 + spike * .15), .25, -.03)
			_tube("shoulder_spike_%s_%d" % [suffix, spike], [base, base + Vector3(side * .04, .10, 0),
				base + Vector3(side * .12, .22, 0), base + Vector3(side * .14, .28, 0)], .105, .015, "edge")

	# Bull skull, projecting muzzle, brow and eyes.
	_loft("head_skull", [Vector3(.19, 2.95, .17), Vector3(.29, 3.12, .24),
		Vector3(.34, 3.36, .25), Vector3(.29, 3.54, .20), Vector3(.15, 3.62, .13)],
		"hide", Vector3(0, 0, .035))
	_ellipsoid("muzzle", Vector3(0, 3.13, .31), Vector3(.265, .18, .24), "hide")
	_ellipsoid("nose", Vector3(0, 3.16, .49), Vector3(.22, .105, .085), "muzzle")
	_ellipsoid("lower_jaw", Vector3(0, 2.995, .33), Vector3(.205, .075, .16), "muzzle")
	_ring("nose_ring", Vector3(0, 3.055, .572), .074, .101, "gold", Basis(Vector3.RIGHT, PI * .5))
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0 else "R"
		_ellipsoid("nostril_" + suffix, Vector3(side * .115, 3.18, .56),
			Vector3(.047, .028, .015), "mane", Vector3(0, 0, side * .3))
		_ellipsoid("eye_socket_" + suffix, Vector3(side * .18, 3.36, .239),
			Vector3(.10, .067, .045), "mane", Vector3(0, 0, side * .23))
		_ellipsoid("eye_" + suffix, Vector3(side * .182, 3.36, .274),
			Vector3(.064, .025, .019), "cyan", Vector3(0, 0, side * .23))
		_limb("brow_" + suffix, Vector3(side * .07, 3.395, .27),
			Vector3(side * .29, 3.46, .17), .065, "hide")
		_ellipsoid("ear_" + suffix, Vector3(side * .36, 3.41, -.01),
			Vector3(.19, .075, .11), "muzzle", Vector3(0, 0, side * .15))
		var root := Vector3(side * .26, 3.53, -.01)
		_tube("horn_" + suffix, [root, Vector3(side * 1.02, 3.31, -.035),
			Vector3(side * 1.06, 3.78, -.055), Vector3(side * .84, 4.0, -.06)], .17, .015, "ivory")
		_ring("horn_cuff_" + suffix, root + Vector3(side * .12, -.015, 0),
			.147, .185, "steel", Basis(Vector3.FORWARD, PI * .5))
		for band in [-.04, .04]:
			_ring("horn_band_%s_%s" % [suffix, str(band)], root + Vector3(side * (.12 + band), -.015, 0),
				.165, .19, "gold", Basis(Vector3.FORWARD, PI * .5))
		# Mane and fur collar tufts are intentionally asymmetric in depth.
		for tuft in range(6):
			var center := Vector3(side * (.30 + .045 * sin(tuft)), 3.43 - tuft * .095, -.12)
			_tube("mane_%s_%d" % [suffix, tuft], [center, center + Vector3(side * .10, -.04, -.02),
				center + Vector3(side * .13, -.12, .01), center + Vector3(side * .07, -.20, .05)],
				.11, .015, "mane")
		for tuft in range(6):
			var center := Vector3(side * (.28 + tuft * .073), 2.99 - tuft * .022, .06)
			_tube("collar_fur_%s_%d" % [suffix, tuft], [center, center + Vector3(0, -.04, .11),
				center + Vector3(side * .035, -.14, .18), center + Vector3(side * .05, -.20, .17)],
				.10, .015, "fur")
	for tuft in range(5):
		var x := (tuft - 2) * .085
		_tube("forelock_%d" % tuft, [Vector3(x, 3.56, .02), Vector3(x + .035, 3.73 - absf(x) * .4, .10),
			Vector3(x * .7 + .025, 3.63, .26), Vector3(x * .55, 3.46 + absf(x) * .4, .28)], .075, .015, "mane")
	for tuft in range(3):
		var x := (tuft - 1) * .09
		_tube("beard_%d" % tuft, [Vector3(x, 3.02, .20), Vector3(x, 2.97, .26),
			Vector3(x * .7, 2.85, .27), Vector3(x * .6, 2.81, .25)], .075, .015, "mane")
	_tube("tail", [Vector3(.20, 1.55, -.27), Vector3(.75, 1.45, -.65),
		Vector3(.98, 1.02, -.47), Vector3(1.12, .84, -.30)], .065, .04, "hide")
	_tube("tail_tuft", [Vector3(1.07, .93, -.34), Vector3(1.16, .86, -.31),
		Vector3(1.20, .73, -.29), Vector3(1.14, .61, -.27)], .10, .015, "mane")

	# A broad rear mane closes the inferred skull/neck silhouette.
	_ellipsoid("mane_back", Vector3(0, 3.31, -.16), Vector3(.32, .33, .16), "mane")
	for tuft in range(5):
		var x := (tuft - 2) * .105
		_tube("mane_back_tuft_%d" % tuft, [Vector3(x, 3.31, -.27),
			Vector3(x * 1.1, 3.17, -.33), Vector3(x * .9, 2.98, -.31),
			Vector3(x * .8, 2.87, -.25)], .105, .015, "mane")
	# Diagonal leather harness and buckle follow the front armor surface.
	shapes.append({"name": "chest_harness", "type": "loft_band", "stations": chest_stations,
		"start": Vector2(-.46, 2.65), "end": Vector2(.07, 2.04), "width": .13,
		"offset": .008, "thickness": .025, "slot": "leather"})
	var buckle_center := Vector2(-.33, 2.50)
	var buckle_section := Shape.section_at(chest_stations, buckle_center.y)
	var buckle_z := buckle_section.z * sqrt(1.0 - pow(buckle_center.x / buckle_section.x, 2))
	_plate("harness_buckle", [Vector2(-.095, -.12), Vector2(.095, -.12),
		Vector2(.095, .12), Vector2(-.095, .12)], .035,
		"gold", Vector3(buckle_center.x, buckle_center.y, buckle_z + .045), -.66)
	_plate("harness_buckle_inset", [Vector2(-.055, -.08), Vector2(.055, -.08),
		Vector2(.055, .08), Vector2(-.055, .08)], .025,
		"leather", Vector3(buckle_center.x, buckle_center.y, buckle_z + .072), -.66)
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0 else "R"
		for rivet in range(3):
			var x: float = side * (.60 + rivet * .15)
			_ellipsoid("pauldron_rivet_%s_%d" % [suffix, rivet], Vector3(x, 2.81, .385),
				Vector3(.028, .028, .022), "gold")
		_tube("tusk_" + suffix, [Vector3(side * .19, 3.02, .44),
			Vector3(side * .235, 3.06, .48), Vector3(side * .235, 3.11, .49),
			Vector3(side * .21, 3.15, .47)], .032, .015, "ivory")
		for tuft in range(4):
			var x: float = side * .67 + (tuft - 1.5) * .10
			_tube("ankle_fur_%s_%d" % [suffix, tuft], [Vector3(x, .35, .10),
				Vector3(x, .29, .22), Vector3(x, .23, .27), Vector3(x, .18, .25)],
				.06, .015, "mane")

	# The diagonal two-handed axe is generated in its own frame.
	_rod("axe_shaft", axe_start, axe_end, .069, "leather")
	var axe_basis := Basis(Quaternion(Vector3.UP, axe_axis))
	for band in range(15):
		var t := .07 + band * .051
		_ring("axe_wrap_%d" % band, axe_start.lerp(axe_end, t), .066, .078, "muzzle", axe_basis)
	_ring("axe_pommel", axe_start, .06, .105, "gold", axe_basis)
	var head_center := axe_end - axe_axis * .14
	var angle := atan2(axe_axis.x, axe_axis.y)
	var blade := [Vector2(.04, -.25), Vector2(.29, -.28), Vector2(.52, -.52),
		Vector2(.68, -.43), Vector2(.83, -.18), Vector2(.85, .18), Vector2(.72, .48),
		Vector2(.51, .66), Vector2(.48, .33), Vector2(.26, .24), Vector2(.04, .25)]
	for side in [-1.0, 1.0]:
		var outline: Array = []
		for point in blade:
			outline.append(Vector2(point.x * side, point.y))
		_plate("axe_blade_" + str(side), outline, .11, "steel", head_center, angle)
		var edge_outline: Array = []
		for index in [2, 3, 4, 5, 6, 7]:
			edge_outline.append(Vector2(blade[index].x * side, blade[index].y))
		for index in [7, 6, 5, 4, 3, 2]:
			edge_outline.append(Vector2((blade[index].x - .075) * side, blade[index].y * .89))
		_plate("axe_edge_" + str(side), edge_outline, .025, "edge", head_center + Vector3(0, 0, .067), angle)
	_plate("axe_socket", [Vector2(-.14, -.32), Vector2(.14, -.32), Vector2(.14, .34),
		Vector2(-.14, .34)], .22, "gold", head_center, angle)
	_plate("axe_crystal", [Vector2(0, -.18), Vector2(.10, 0), Vector2(0, .19),
		Vector2(-.10, 0)], .065, "cyan", head_center + Vector3(0, 0, .15), angle)

	var construction := {"height": p.value("height"), "authoring_unit": unit,
		"shapes": shapes, "hidden_geometry": "authored estimate", "pose": "static two-handed axe"}
	var intent := Intent.new(construction, palette, [{"sha256": REFERENCE_SHA}])
	var resolved := Resolved.new(intent.construction_hash(), construction)
	var binding := Binding.new(intent.appearance_hash(), palette)
	_compile_shapes(resolved.payload.design.shapes)
	var style := Style.apply(asset, binding)
	assert(style.ok, str(style.failures))
	var stages := Stages.new("minotaur.measured_shape.v1")
	stages.record("intent", "minotaur.reference_study.v1", {}, intent)
	stages.record("resolve_design", "minotaur.measured_shape.v1",
		{"construction_intent": intent.construction_hash()}, resolved)
	stages.record("compile_geometry", "polyforge.measured_shape.v1",
		{"resolved_design": resolved.content_hash()}, {"geometry_hash": style.geometry_hash_before,
		"curve_evidence": curve_evidence, "tessellation_tolerance": tolerance * unit})
	stages.record("compile_appearance", "polyforge.style_slots.v1",
		{"geometry": style.geometry_hash_before, "appearance_intent": intent.appearance_hash()}, style)
	var fit_checks: Array = []
	for fit in layer_fits:
		var owner := _definition(fit.inner)
		fit_checks.append({"type": "shell_clearance", "a": fit.inner, "b": fit.outer,
			"frame": Transform3D(owner.basis, owner.position * unit),
			"start": fit.start * unit, "end": fit.end * unit,
			"minimum": fit.minimum_clearance * unit})
	for grip in grips:
		var members: Array = ["hand_" + grip.suffix, "thumb_" + grip.suffix]
		for finger in range(4):
			members.append("finger_%s_%d" % [grip.suffix, finger])
		for member in members:
			fit_checks.append({"type": "cylinder_clearance", "a": member,
				"center": grip.center * unit, "axis": grip.axis,
				"radius": grip.handle_radius * unit, "minimum": grip.minimum_clearance * unit,
				"maximum": grip.maximum_contact_gap * unit})

	var reference := Reference.new({"sha256": REFERENCE_SHA,
		"subject": "rightmost minotaur", "authority": "single-view visual estimates"}, {
		"horns": {"selector": {"names": ["horn_L", "horn_R"]}, "minimum": 2},
		"bull_face": {"selector": {"names": ["muzzle", "nose_ring"]}, "minimum": 2},
		"split_hooves": {"selector": {"prefixes": ["hoof_"]}, "minimum": 4},
		"weapon": {"selector": {"names": ["axe_shaft", "axe_crystal"]}, "minimum": 2},
		"red_tabard": {"selector": {"names": ["tabard"]}, "minimum": 1},
	})
	return {"name": "minotaur", "category": "character", "assembly": asset,
		"triangle_budget": 32000, "topology_budget": {"rendered_triangles": 32000},
		"require_part_classification": true, "front": "+Z",
		"checks": [Checks.require_axis_size("body_torso", 0, 1.44 * unit, .0001 * unit),
			Checks.require_axis_size("body_torso", 1, 1.42 * unit, .0001 * unit),
			Checks.require_axis_size("head_skull", 0, .68 * unit, .0001 * unit),
			Checks.require_axis_size("tabard", 1, .98 * unit, .0001 * unit)] + fit_checks,
		"anchors": {"head": Vector3(0, 3.36, .035) * unit,
			"left_grip": axe_start.lerp(axe_end, .24) * unit,
			"right_grip": axe_start.lerp(axe_end, .70) * unit, "ground": Vector3.ZERO},
		"contracts": {"asset_intent": intent.to_canonical_dict(),
			"resolved_design": resolved.to_canonical_dict(), "appearance_binding": binding.to_canonical_dict()},
		"process": stages.snapshot(), "style_compilation": Canonical.canonicalize(style),
		"reference_profile": reference.to_canonical_dict(),
		"readability": {"target_pixels": 128, "minimum_regions": 3,
			"minimum_contrast": .04, "minimum_stroke_px": 1.0},
		"metadata": {"description": "Measured-profile minotaur reference study",
			"reference_sha256": REFERENCE_SHA, "assumptions": ["3.6m default height",
				"depth and back are inferred", "static pose", "hand-authored measurement targets"],
			"shape_definitions": Canonical.canonicalize(shapes),
			"curve_evidence": curve_evidence,
			"layer_fits": layer_fits, "grips": Canonical.canonicalize(grips),
			"error_scope": "Centerline chords and cross-section rings; not full surface or image-match error"}}
