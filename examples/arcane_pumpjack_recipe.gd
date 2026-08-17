extends RefCounted
## Rigged vapor derrick reference. The model uses a constrained four-bar drive,
## play-size topology selection, reusable static framing, and a profile horsehead.

const Assembly := preload("res://addons/polyforge/core/assembly.gd")
const Component := preload("res://addons/polyforge/core/component.gd")
const SurfaceTypes := preload("res://addons/polyforge/core/surface_types.gd")
const Parameters := preload("res://addons/polyforge/core/parameters.gd")
const Stock := preload("res://addons/polyforge/core/stock.gd")
const PolyMesh := preload("res://addons/polyforge/core/mesh.gd")
const TopologyBudget := preload("res://addons/polyforge/core/topology_budget.gd")
const Rig := preload("res://addons/polyforge/core/rig.gd")
const AnimationClip := preload("res://addons/polyforge/core/animation.gd")
const MechanicalConstraints := preload("res://addons/polyforge/core/mechanical_constraints.gd")
const Checks := preload("res://addons/polyforge/quality/checks.gd")

func _xf(position: Vector3, rotation_degrees := Vector3.ZERO) -> Transform3D:
	var radians := Vector3(deg_to_rad(rotation_degrees.x),
		deg_to_rad(rotation_degrees.y), deg_to_rad(rotation_degrees.z))
	return Transform3D(Basis.from_euler(radians), position)

func _part(mesh: PrimitiveMesh, material: Material) -> PrimitiveMesh:
	return Stock.with_material(mesh, material)

func _options(construction: String, role: String, tags = PackedStringArray(),
		extra := {}) -> Dictionary:
	var result := extra.duplicate(true)
	var repetition := str(result.get("repetition", "unique"))
	var motion := str(result.get("motion", "static"))
	var surface_options: Dictionary = result.get("surface_options", {})
	result.erase("repetition")
	result.erase("motion")
	result.erase("surface_options")
	result.tags = PackedStringArray(tags)
	result.surface = SurfaceTypes.classify(construction, role, repetition, motion,
		surface_options)
	return result

func _add(asset, name: String, mesh: Mesh, transform: Transform3D,
		construction: String, role: String, tags = PackedStringArray(), extra := {}) -> void:
	asset.add(name, mesh, transform, _options(construction, role, tags, extra))

func _beam_xf(a: Vector3, b: Vector3) -> Transform3D:
	var x := (b - a).normalized()
	var guide := Vector3.UP
	if absf(x.dot(guide)) > 0.96:
		guide = Vector3.FORWARD
	var z := x.cross(guide).normalized()
	var y := z.cross(x).normalized()
	return Transform3D(Basis(x, y, z), (a + b) * 0.5)

func _between_y(a: Vector3, b: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var guide := Vector3.FORWARD
	if absf(y.dot(guide)) > 0.95:
		guide = Vector3.RIGHT
	var x := y.cross(guide).normalized()
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x, y, z), (a + b) * 0.5)

func _profile_mesh(outline_xy: Array, depth: float, material: Material) -> ArrayMesh:
	var outline_xz := []
	for point: Vector2 in outline_xy:
		outline_xz.append(Vector2(point.x, -point.y))
	var poly = PolyMesh.extrude_poly(outline_xz, depth, 1.0, -depth * 0.5)
	poly.transform(Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0)),
		Vector3.ZERO))
	var mesh: ArrayMesh = poly.to_meshes()[""]
	mesh.surface_set_material(0, material)
	return mesh

func _beam_component(id: String, length: float, thickness: float, depth: float,
		material: Material, repetition := "unique", motion := "static") -> RefCounted:
	var beam := Component.new(id)
	beam.add("core", _part(Stock.box(Vector3(length, thickness, depth)), material),
		Transform3D.IDENTITY, _options("prismatic", "structural", ["beam"], {
			"repetition": repetition, "motion": motion,
			"surface_options": {"minimum_slenderness": 1.5}}))
	beam.define_socket("end_a", _xf(Vector3(-length * 0.5, 0.0, 0.0)))
	beam.define_socket("end_b", _xf(Vector3(length * 0.5, 0.0, 0.0)))
	return beam

func _place_beam(parent, name: String, beam, a: Vector3, b: Vector3) -> void:
	parent.instance(name, beam, _beam_xf(a, b))

func _derrick_bent(size: float, deck_y: float, pivot_y: float,
		stone: Material, trim: Material, dark: Material, radial_segments: int) -> RefCounted:
	var bent := Component.new("derrick_bent_v3")
	var foot_y := deck_y + size * 0.035
	var foot_x := size * 0.22
	var top_x := size * 0.035
	var left_foot := Vector3(-foot_x, foot_y, 0.0)
	var left_top := Vector3(-top_x, pivot_y, 0.0)
	var leg := _beam_component("derrick_leg", left_foot.distance_to(left_top),
		size * 0.055, size * 0.045, stone, "paired")
	_place_beam(bent, "left_leg", leg, left_foot, left_top)
	_place_beam(bent, "right_leg", leg, Vector3(foot_x, foot_y, 0.0),
		Vector3(top_x, pivot_y, 0.0))
	var cross_y := deck_y + size * 0.28
	var cross_half := size * 0.15
	var cross := _beam_component("derrick_cross", cross_half * 2.0,
		size * 0.045, size * 0.040, dark, "paired")
	_place_beam(bent, "cross", cross, Vector3(-cross_half, cross_y, 0.0),
		Vector3(cross_half, cross_y, 0.0))
	var brace_start := Vector3(-foot_x * 0.82, foot_y + size * 0.09, 0.0)
	var brace_end := Vector3(cross_half * 0.78, cross_y + size * 0.02, 0.0)
	var diagonal := _beam_component("derrick_brace", brace_start.distance_to(brace_end),
		size * 0.030, size * 0.030, trim, "paired")
	_place_beam(bent, "brace_left", diagonal, brace_start, brace_end)
	_place_beam(bent, "brace_right", diagonal,
		Vector3(-brace_start.x, brace_start.y, 0.0),
		Vector3(-brace_end.x, brace_end.y, 0.0))
	bent.add("bearing", _part(Stock.cylinder(size * 0.073, size * 0.073,
		size * 0.055, radial_segments), trim), _xf(Vector3(0.0, pivot_y, 0.0),
		Vector3(90.0, 0.0, 0.0)), _options("revolved", "interface", ["pivot"], {
			"repetition": "paired", "surface_options": {"axis": "y", "socket": "pivot"}}))
	bent.define_socket("pivot", _xf(Vector3(0.0, pivot_y, 0.0)))
	return bent

func _walking_beam(size: float, front_length: float, rear_length: float,
		frame_depth: float, stone: Material, trim: Material, dark: Material,
		arcane: Material) -> RefCounted:
	var beam := Component.new("walking_beam_v3")
	var total := front_length + rear_length
	var center_x := (rear_length - front_length) * 0.5
	var plate_outline := [
		Vector2(-front_length, size * 0.055),
		Vector2(rear_length * 0.84, size * 0.075),
		Vector2(rear_length, size * 0.025),
		Vector2(rear_length * 0.90, -size * 0.080),
		Vector2(-front_length * 0.92, -size * 0.070),
	]
	var inset_outline := [
		Vector2(-front_length * 0.72, size * 0.020),
		Vector2(rear_length * 0.66, size * 0.034),
		Vector2(rear_length * 0.78, size * 0.002),
		Vector2(rear_length * 0.70, -size * 0.036),
		Vector2(-front_length * 0.68, -size * 0.032),
	]
	var plate_mesh := _profile_mesh(plate_outline, size * 0.035, stone)
	var inset_mesh := _profile_mesh(inset_outline, size * 0.010, dark)
	for side in [-1.0, 1.0]:
		var name := "front_plate" if side > 0.0 else "back_plate"
		beam.add(name, plate_mesh, _xf(Vector3(0.0, 0.0, float(side) * frame_depth * 0.27)),
			_options("profile", "primary_silhouette", ["walking_beam", "moving"], {
				"repetition": "paired", "motion": "rigid",
				"surface_options": {"maximum_thickness_ratio": 0.18}}))
		beam.add("front_inset" if side > 0.0 else "back_inset", inset_mesh,
			_xf(Vector3(0.0, 0.0, float(side) * frame_depth * 0.36)),
			_options("profile", "decorative", ["walking_beam", "moving", "inset"], {
				"repetition": "paired", "motion": "rigid",
				"surface_options": {"maximum_thickness_ratio": 0.12}}))
	beam.add("spine", _part(Stock.box(Vector3(total * 0.92, size * 0.10,
		frame_depth * 0.38)), stone), _xf(Vector3(center_x, 0.0, 0.0)),
		_options("prismatic", "mechanism", ["walking_beam", "moving"], {
			"motion": "rigid", "surface_options": {"minimum_slenderness": 2.0}}))
	var rib_mesh := _part(Stock.box(Vector3(size * 0.050, size * 0.11,
		frame_depth * 0.74)), trim)
	for index in range(3):
		var x := lerpf(-front_length * 0.72, rear_length * 0.72, float(index) / 2.0)
		beam.add("rib_%02d" % index, rib_mesh, _xf(Vector3(x, 0.0, 0.0)),
			_options("prismatic", "mechanism", ["walking_beam", "moving"], {
				"repetition": "centered", "motion": "rigid",
				"surface_options": {"minimum_slenderness": 1.40}}))
	beam.add("pivot_boss", _part(Stock.cylinder(size * 0.090, size * 0.090,
		frame_depth * 0.86, 10), trim), _xf(Vector3.ZERO, Vector3(90.0, 0.0, 0.0)),
		_options("revolved", "interface", ["walking_beam", "moving", "pivot"], {
			"motion": "rigid", "surface_options": {"axis": "y", "socket": "pivot"}}))
	beam.add("pivot_lens", _part(Stock.cylinder(size * 0.047, size * 0.047,
		size * 0.016, 5), arcane),
		_xf(Vector3(0.0, 0.0, frame_depth * 0.47), Vector3(90.0, 0.0, 0.0)),
		_options("revolved", "effect_anchor", ["walking_beam", "moving", "arcane"], {
			"motion": "rigid", "surface_options": {"axis": "y"}}))
	beam.define_socket("pivot", Transform3D.IDENTITY)
	beam.define_socket("horsehead", _xf(Vector3(-front_length, 0.0, 0.0)))
	return beam

func _horsehead(size: float, frame_depth: float, stone: Material,
		trim: Material, dark: Material, arcane: Material) -> RefCounted:
	var head := Component.new("horsehead_v3")
	var outline := [
		Vector2(-size * 0.060, size * 0.18), Vector2(size * 0.090, size * 0.16),
		Vector2(size * 0.140, size * 0.10), Vector2(size * 0.165, 0.0),
		Vector2(size * 0.150, -size * 0.13), Vector2(size * 0.095, -size * 0.25),
		Vector2(size * 0.015, -size * 0.32), Vector2(-size * 0.075, -size * 0.29),
		Vector2(-size * 0.115, -size * 0.18), Vector2(-size * 0.095, -size * 0.02),
	]
	var inner_outline := [
		Vector2(-size * 0.025, size * 0.135), Vector2(size * 0.065, size * 0.12),
		Vector2(size * 0.105, size * 0.06), Vector2(size * 0.115, -size * 0.06),
		Vector2(size * 0.080, -size * 0.19), Vector2(size * 0.010, -size * 0.255),
		Vector2(-size * 0.045, -size * 0.23), Vector2(-size * 0.070, -size * 0.13),
		Vector2(-size * 0.060, -size * 0.01),
	]
	var plate_mesh := _profile_mesh(outline, size * 0.032, trim)
	var face_mesh := _profile_mesh(inner_outline, size * 0.016, stone)
	for side in [-1.0, 1.0]:
		var name := "front_plate" if side > 0.0 else "back_plate"
		head.add(name, plate_mesh, _xf(Vector3(0.0, 0.0, float(side) * frame_depth * 0.31)),
			_options("profile", "primary_silhouette", ["horsehead", "moving"], {
				"repetition": "paired", "motion": "rigid",
				"surface_options": {"maximum_thickness_ratio": 0.18}}))
		head.add("front_face" if side > 0.0 else "back_face", face_mesh,
			_xf(Vector3(0.0, 0.0, float(side) * frame_depth * 0.36)),
			_options("profile", "trim", ["horsehead", "moving"], {
				"repetition": "paired", "motion": "rigid",
				"surface_options": {"maximum_thickness_ratio": 0.14}}))
		var face_z := float(side) * frame_depth * 0.405
		head.add("front_slot" if side > 0.0 else "back_slot",
			_part(Stock.box(Vector3(size * 0.040, size * 0.175, size * 0.012)), dark),
			_xf(Vector3(size * 0.025, -size * 0.045, face_z), Vector3(0.0, 0.0, -8.0)),
			_options("prismatic", "decorative", ["horsehead", "moving", "slot"], {
				"repetition": "paired", "motion": "rigid"}))
		for gem_index in range(2):
			var gem_y := size * (0.085 if gem_index == 0 else -0.205)
			head.add(("front_gem" if side > 0.0 else "back_gem") + "_%02d" % gem_index,
				_part(Stock.cylinder(size * 0.028, size * 0.028, size * 0.018, 8), arcane),
				_xf(Vector3(size * 0.020, gem_y, face_z), Vector3(90.0, 0.0, 0.0)),
				_options("revolved", "effect_anchor", ["horsehead", "moving", "arcane"], {
					"repetition": "paired", "motion": "rigid",
					"surface_options": {"axis": "y"}}))
	var spacer := _part(Stock.box(Vector3(size * 0.055, size * 0.055,
		frame_depth * 0.64)), trim)
	for index in range(3):
		head.add("spacer_%02d" % index, spacer,
			_xf(Vector3(size * (0.015 + index * 0.025), size * (0.03 - index * 0.10), 0.0)),
			_options("prismatic", "mechanism", ["horsehead", "moving"], {
				"repetition": "centered", "motion": "rigid"}))
	return head

func _tank_component(size: float, radius: float, stone: Material,
		trim: Material, dark: Material, arcane: Material, radial_segments: int) -> RefCounted:
	var tank := Component.new("vapor_reservoir_v3")
	tank.add("core", _part(Stock.sphere(radius, radial_segments, 5), arcane),
		Transform3D.IDENTITY, _options("organic", "enclosure", ["tank", "arcane"], {
			"repetition": "paired"}))
	tank.add("base", _part(Stock.cylinder(radius * 1.12, radius * 1.12,
		size * 0.07, radial_segments), stone), _xf(Vector3(0.0, -radius * 1.08, 0.0)),
		_options("revolved", "contact", ["tank", "mount"], {
			"repetition": "paired", "surface_options": {"axis": "y"}}))
	tank.add("cap", _part(Stock.cylinder(radius * 1.10, radius * 0.92,
		size * 0.09, radial_segments), trim), _xf(Vector3(0.0, radius * 0.92, 0.0)),
		_options("revolved", "interface", ["tank"], {"repetition": "paired",
			"surface_options": {"axis": "y", "socket": "feed"}}))
	tank.add("band", _part(Stock.torus(radius * 0.88, radius * 1.05,
		radial_segments, 4), stone), _xf(Vector3(0.0, -radius * 0.58, 0.0)),
		_options("revolved", "trim", ["tank"], {"repetition": "paired",
			"surface_options": {"axis": "y"}}))
	tank.add("lid", _part(Stock.cylinder(radius * 0.52, radius * 0.52,
		size * 0.055, radial_segments), dark),
		_xf(Vector3(0.0, radius * 1.20, 0.0)),
		_options("revolved", "trim", ["tank", "lid"], {"repetition": "paired",
			"surface_options": {"axis": "y"}}))
	tank.define_socket("feed", _xf(Vector3(0.0, radius * 1.14, 0.0)))
	return tank

func _add_pipe(asset, name: String, points: Array, radius: float,
		material: Material, radial_segments: int) -> void:
	for index in range(points.size() - 1):
		var a: Vector3 = points[index]
		var b: Vector3 = points[index + 1]
		_add(asset, "%s_%02d" % [name, index],
			_part(Stock.cylinder(radius, radius, a.distance_to(b), radial_segments), material),
			_between_y(a, b), "swept", "conduit", ["pipe"], {
				"surface_options": {"radius": radius}})
	for index in range(1, points.size() - 1):
		_add(asset, "%s_elbow_%02d" % [name, index],
			_part(Stock.sphere(radius * 1.10, radial_segments, 4), material),
			_xf(points[index]), "organic", "conduit", ["pipe", "elbow"], {
				"repetition": "centered", "surface_options": {"radius": radius}})

func _bind_instance(rig, asset, instance_name: String, bone_name: String) -> void:
	for part_name in asset.part_names_for_instance(instance_name):
		rig.bind_rigid(part_name, bone_name)

func parameters() -> Dictionary:
	return {
		"size": Parameters.scale(6.0, 4.8, 7.2, "m",
			"Overall platform diameter; every physical measurement derives from it."),
		"boom_reach": Parameters.number(1.0, 0.82, 1.16, "ratio",
			"Walking-beam reach relative to the derrick."),
		"tank_scale": Parameters.number(1.0, 0.80, 1.22, "ratio",
			"Reservoir radius and pipe-clearance multiplier."),
	}

func build(p) -> Dictionary:
	var size: float = p.value("size")
	var boom_reach: float = p.value("boom_reach")
	var tank_scale: float = p.value("tank_scale")
	var base_radius: float = p.derive("platform.radius", "size", 0.5)
	var base_height: float = p.derive("platform.height", "size", 0.07)
	var deck_y: float = p.derive("platform.deck_y", "size", 0.105)
	var pivot_y: float = p.derive("tower.pivot_y", "size", 0.64)
	var frame_depth: float = p.derive("frame.depth", "size", 0.22)
	var tank_radius: float = p.computed("tank.radius", size * 0.095 * tank_scale,
		["size", "tank_scale"], "size * 0.095 * tank_scale")
	var quality := TopologyBudget.profile("runtime")
	var radial_segments := TopologyBudget.radial_segments(8.0, quality, 8)
	var pipe_segments := TopologyBudget.radial_segments(3.0, quality, 6)

	var stone := Stock.material("weathered_brass", Color("9d754c"), 0.46, 0.70)
	var trim := Stock.material("warm_trim", Color("c8a16b"), 0.40, 0.56)
	var dark := Stock.material("dark_mechanism", Color("695446"), 0.60, 0.76)
	var steel := Stock.material("polished_steel", Color("918c88"), 0.76, 0.34)
	var arcane := Stock.glow_material("vapor_amethyst", Color("8d48d2"), 1.65)
	var pipe_glow := Stock.glow_material("vapor_conduit", Color("68408d"), 0.90)

	var asset := Assembly.new()
	_add(asset, "platform", _part(Stock.cylinder(base_radius, base_radius,
		base_height, radial_segments), stone), _xf(Vector3(0.0, base_height * 0.5, 0.0)),
		"revolved", "contact", ["foundation"], {"repetition": "centered",
			"surface_options": {"axis": "y"}})
	_add(asset, "platform_deck", _part(Stock.cylinder(base_radius * 0.86,
		base_radius * 0.91, base_height * 0.34, radial_segments), trim),
		_xf(Vector3(0.0, base_height * 1.05, 0.0)), "revolved", "contact",
		["foundation", "deck"], {"repetition": "centered",
			"surface_options": {"axis": "y"}})
	_add(asset, "platform_inlay", _part(Stock.torus(base_radius * 0.72,
		base_radius * 0.79, radial_segments + 2, 4), pipe_glow),
		_xf(Vector3(0.0, base_height * 1.02, 0.0)), "revolved", "decorative",
		["arcane", "trim"], {"repetition": "centered", "surface_options": {"axis": "y"}})
	var rim := Component.new("platform_rim_block_v3")
	rim.add("block", _part(Stock.box(Vector3(size * 0.16, base_height * 1.30,
		size * 0.18)), trim), Transform3D.IDENTITY,
		_options("prismatic", "contact", ["foundation", "trim"], {
			"repetition": "radial_repeat",
			"surface_options": {"minimum_slenderness": 1.0}}))
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var position := Vector3(cos(angle), 0.0, sin(angle)) * base_radius * 0.89
		position.y = base_height * 0.70
		asset.instance_component("rim_%02d" % index, rim,
			_xf(position, Vector3(0.0, -rad_to_deg(angle), 0.0)))

	_add(asset, "machine_plinth", _part(Stock.box(Vector3(size * 0.36,
		size * 0.10, size * 0.29)), stone),
		_xf(Vector3(size * 0.14, deck_y + size * 0.050, -size * 0.04)),
		"prismatic", "contact", ["foundation"], {
			"surface_options": {"minimum_slenderness": 1.0}})
	_add(asset, "machine_plinth_cap", _part(Stock.box(Vector3(size * 0.32,
		size * 0.06, size * 0.25)), trim),
		_xf(Vector3(size * 0.14, deck_y + size * 0.125, -size * 0.04)),
		"prismatic", "contact", ["foundation", "machine"], {
			"surface_options": {"minimum_slenderness": 1.0}})
	var pump_center := Vector3(size * 0.10, deck_y + size * 0.23, -size * 0.05)
	_add(asset, "pump_body", _part(Stock.cylinder(size * 0.105, size * 0.105,
		size * 0.33, radial_segments), stone), _xf(pump_center, Vector3(0.0, 0.0, 90.0)),
		"revolved", "enclosure", ["machine"], {"surface_options": {"axis": "y"}})
	for side in [-1.0, 1.0]:
		_add(asset, "pump_endcap_%s" % ("left" if side < 0.0 else "right"),
			_part(Stock.cylinder(size * 0.125, size * 0.105, size * 0.045,
				radial_segments), trim),
			_xf(pump_center + Vector3(float(side) * size * 0.18, 0.0, 0.0),
				Vector3(0.0, 0.0, 90.0)), "revolved", "trim", ["machine", "endcap"], {
				"repetition": "paired", "surface_options": {"axis": "y"}})
	_add(asset, "pump_band", _part(Stock.torus(size * 0.106, size * 0.122,
		radial_segments, 4), trim), _xf(pump_center, Vector3(0.0, 0.0, 90.0)),
		"revolved", "trim", ["machine"], {"surface_options": {"axis": "y"}})
	_add(asset, "pump_badge", _part(Stock.box(Vector3(size * 0.13, size * 0.085,
		size * 0.018)), trim), _xf(pump_center + Vector3(0.0, 0.0, size * 0.112)),
		"prismatic", "decorative", ["machine", "badge"])
	_add(asset, "pump_badge_ring", _part(Stock.torus(size * 0.060, size * 0.082,
		radial_segments + 2, 4), dark),
		_xf(pump_center + Vector3(0.0, 0.0, size * 0.128), Vector3(90.0, 0.0, 0.0)),
		"revolved", "decorative", ["machine", "badge", "gear"], {
			"surface_options": {"axis": "y"}})
	_add(asset, "pump_indicator", _part(Stock.box(Vector3(size * 0.065,
		size * 0.018, size * 0.010)), arcane),
		_xf(pump_center + Vector3(0.0, size * 0.016, size * 0.123)),
		"prismatic", "effect_anchor", ["machine", "arcane"])
	_add(asset, "exhaust_stack", _part(Stock.cylinder(size * 0.045, size * 0.065,
		size * 0.24, radial_segments), trim),
		_xf(pump_center + Vector3(-size * 0.06, size * 0.22, 0.0)),
		"revolved", "effect_anchor", ["machine", "exhaust"], {
			"surface_options": {"axis": "y"}})
	_add(asset, "exhaust_lip", _part(Stock.torus(size * 0.047, size * 0.066,
		radial_segments, 4), trim),
		_xf(pump_center + Vector3(-size * 0.06, size * 0.35, 0.0)),
		"revolved", "trim", ["machine", "exhaust"], {
			"surface_options": {"axis": "y"}})
	for index in range(4):
		var vapor_offset := Vector3(size * (-0.06 + 0.025 * sin(float(index))),
			size * (0.39 + 0.075 * index), size * 0.012 * cos(float(index)))
		_add(asset, "vapor_plume_%02d" % index,
			_part(Stock.sphere(size * (0.045 + 0.008 * index), radial_segments, 4), arcane),
			_xf(pump_center + vapor_offset), "organic", "effect_anchor",
			["machine", "exhaust", "vapor"], {"repetition": "centered"})

	var bent := _derrick_bent(size, deck_y, pivot_y, stone, trim, dark, radial_segments)
	var bent_z := frame_depth * 0.43
	asset.instance_component("derrick_front", bent, _xf(Vector3(0.0, 0.0, bent_z)))
	asset.instance_component("derrick_back", bent, _xf(Vector3(0.0, 0.0, -bent_z)))
	var tie := _beam_component("derrick_depth_tie", bent_z * 2.0,
		size * 0.045, size * 0.045, trim, "centered")
	for index in range(3):
		var center := Vector3(0.0, deck_y + size * (0.18 + index * 0.19), 0.0)
		asset.instance_component("derrick_tie_%02d" % index, tie,
			_beam_xf(center - Vector3(0.0, 0.0, bent_z),
				center + Vector3(0.0, 0.0, bent_z)))
	_add(asset, "tower_pivot", _part(Stock.cylinder(size * 0.085, size * 0.085,
		frame_depth * 1.04, radial_segments), trim),
		_xf(Vector3(0.0, pivot_y, 0.0), Vector3(90.0, 0.0, 0.0)),
		"revolved", "interface", ["joint"], {"surface_options": {
			"axis": "y", "socket": "boom_pivot"}})

	var front_length := size * 0.34 * boom_reach
	var rear_length := size * 0.245 * boom_reach
	var crank_center_2d := Vector2(size * 0.225, deck_y + size * 0.20)
	var linkage := MechanicalConstraints.solve_four_bar({
		"crank_center": crank_center_2d,
		"beam_pivot": Vector2(0.0, pivot_y),
		"crank_radius": size * 0.055,
		"beam_rear_length": rear_length,
		"pitman_length": size * 0.29,
		"beam_front_length": front_length,
		"plane_z": 0.0,
		"phase": deg_to_rad(-60.0),
		"branch_sign": 1.0,
	}, 64)
	assert(bool(linkage.ok), str(linkage.get("error", "linkage solve failed")))
	var rest: Dictionary = linkage.samples[0].frames

	var walking := _walking_beam(size, front_length, rear_length, frame_depth,
		stone, trim, dark, arcane)
	asset.instance_component("walking_beam", walking, rest.walking_beam)
	var horsehead := _horsehead(size, frame_depth, stone, trim, dark, arcane)
	asset.instance_component("horsehead", horsehead, rest.horsehead)

	var crank_center := Vector3(crank_center_2d.x, crank_center_2d.y, 0.0)
	_add(asset, "crank_disk", _part(Stock.cylinder(size * 0.105, size * 0.105,
		size * 0.075, radial_segments), dark),
		_xf(crank_center + Vector3(0.0, 0.0, bent_z * 0.82), Vector3(90.0, 0.0, 0.0)),
		"revolved", "mechanism", ["moving", "linkage"], {"motion": "rigid",
			"surface_options": {"axis": "y", "socket": "crank"}})
	var rest_crank_pin: Vector3 = linkage.samples[0].crank_pin
	_add(asset, "crank_pin", _part(Stock.cylinder(size * 0.030, size * 0.030,
		bent_z * 0.40, pipe_segments), steel),
		_xf(rest_crank_pin + Vector3(0.0, 0.0, bent_z * 0.82),
			Vector3(90.0, 0.0, 0.0)), "revolved", "interface", ["moving", "linkage"], {
			"motion": "rigid", "surface_options": {"axis": "y", "socket": "crank_pin"}})
	_add(asset, "flywheel", _part(Stock.cylinder(size * 0.17, size * 0.17,
		size * 0.075, radial_segments + 2), trim),
		_xf(crank_center - Vector3(0.0, 0.0, bent_z * 0.82), Vector3(90.0, 0.0, 0.0)),
		"revolved", "mechanism", ["moving", "linkage"], {"motion": "rigid",
			"surface_options": {"axis": "y", "socket": "flywheel"}})
	_add(asset, "drive_axle", _part(Stock.cylinder(size * 0.035, size * 0.035,
		bent_z * 2.0, pipe_segments), steel),
		_xf(crank_center, Vector3(90.0, 0.0, 0.0)), "revolved", "mechanism",
		["moving", "linkage"], {"motion": "rigid", "surface_options": {"axis": "y"}})
	var rest_rear_pin: Vector3 = linkage.samples[0].beam_rear_pin
	var pitman_lane := bent_z * 0.82
	_add(asset, "pitman", _part(Stock.box(Vector3(size * 0.29,
		size * 0.045, size * 0.035)), steel), _beam_xf(
			rest_crank_pin + Vector3(0.0, 0.0, pitman_lane),
			rest_rear_pin + Vector3(0.0, 0.0, pitman_lane)),
		"prismatic", "mechanism", ["moving", "linkage"], {"motion": "rigid"})
	var rest_front_pin: Vector3 = linkage.samples[0].beam_front_pin
	var rod_bottom_y := deck_y + size * 0.12
	var rod_top_y := rest_front_pin.y - size * 0.18
	var rod_length := maxf(rod_top_y - rod_bottom_y, size * 0.30)
	_add(asset, "polish_rod", _part(Stock.cylinder(size * 0.022, size * 0.022,
		rod_length, pipe_segments), steel),
		_xf(Vector3(rest_front_pin.x, rod_bottom_y + rod_length * 0.5, bent_z * 0.48)),
		"revolved", "mechanism", ["moving", "linkage"], {"motion": "rigid",
			"surface_options": {"axis": "y"}})
	_add(asset, "pump_shaft", _part(Stock.cylinder(size * 0.045, size * 0.045,
		size * 0.20, pipe_segments), arcane),
		_xf(Vector3(rest_front_pin.x, rod_bottom_y, bent_z * 0.48)),
		"revolved", "mechanism", ["moving", "arcane"], {"motion": "rigid",
			"surface_options": {"axis": "y", "socket": "pump_shaft"}})

	var tank := _tank_component(size, tank_radius, stone, trim, dark, arcane,
		radial_segments)
	var tank_x := size * 0.34
	var tank_y := deck_y + tank_radius * 1.15
	var left_center := Vector3(-tank_x, tank_y, size * 0.13)
	var right_center := Vector3(tank_x, tank_y, -size * 0.13)
	asset.instance_component("left_reservoir", tank, _xf(left_center))
	asset.instance_component("right_reservoir", tank, _xf(right_center))
	var pipe_radius := size * 0.022
	_add_pipe(asset, "left_feed", [left_center + Vector3(0.0, tank_radius * 1.14, 0.0),
		Vector3(-tank_x, pump_center.y, size * 0.22),
		Vector3(pump_center.x - size * 0.16, pump_center.y, size * 0.22)],
		pipe_radius, pipe_glow, pipe_segments)
	_add_pipe(asset, "right_return", [right_center + Vector3(0.0, tank_radius * 1.14, 0.0),
		Vector3(tank_x, deck_y + size * 0.12, -size * 0.22),
		Vector3(pump_center.x + size * 0.15, deck_y + size * 0.12, -size * 0.22)],
		pipe_radius, pipe_glow, pipe_segments)

	var rig := Rig.new()
	rig.add_bone("root")
	for bone_name in ["crank", "flywheel", "walking_beam", "horsehead", "pitman",
			"polish_rod", "pump_shaft"]:
		rig.add_bone(bone_name, "root", rest[bone_name])
	_bind_instance(rig, asset, "walking_beam", "walking_beam")
	_bind_instance(rig, asset, "horsehead", "horsehead")
	for part_name in ["crank_disk", "crank_pin", "drive_axle"]:
		rig.bind_rigid(part_name, "crank")
	rig.bind_rigid("flywheel", "flywheel")
	rig.bind_rigid("pitman", "pitman")
	rig.bind_rigid("polish_rod", "polish_rod")
	rig.bind_rigid("pump_shaft", "pump_shaft")
	var clip := AnimationClip.new("pump_cycle", 2.4, true, 32.0)
	MechanicalConstraints.bake_clip(clip, linkage, rest)
	rig.add_clip(clip)
	rig.add_motion_report("four_bar_pump", linkage, {
		"fixed_length": size * 0.00001, "loop_closure": 0.00001})
	var clearance := MechanicalConstraints.validate_clearance(linkage, [{
		"name": "pitman", "start": "crank_pin", "end": "beam_rear_pin",
		"offset_z": pitman_lane, "radius": size * 0.023,
	}], [{
		"name": "pump_housing", "center": pump_center, "radius": size * 0.108,
	}], size * 0.01)
	rig.add_motion_report("mechanism_clearance", clearance)

	return {
		"name": "arcane_pumpjack",
		"category": "structure",
		"assembly": asset,
		"triangle_budget": 5500,
		"topology_budget": {
			"rendered_triangles": 5500,
			"unique_triangles": 4000,
			"components": {"walking_beam": 650, "horsehead": 650},
		},
		"quality_profile": "runtime",
		"require_surface_classification": true,
		"require_part_classification": true,
		"rig": rig,
		"symmetry": [
			{"name": "derrick front/back reuse", "first": "derrick_front",
				"second": "derrick_back", "axis": "z", "tolerance": size * 0.00001},
		],
		"checks": [
			Checks.require_axis_size("platform", 0, base_radius * 2.0, size * 0.015),
			Checks.require_axis_ratio("walking_beam__spine", 0,
				"walking_beam__spine", 1, 1.20, 8.0),
			Checks.require_axis_range("horsehead__front_plate", 2,
				size * 0.015, size * 0.05),
			Checks.require_axis_range("tower_pivot", 2, size * 0.20, size * 0.30),
		],
		"anchors": {
			"deck_center": Vector3(0.0, deck_y, 0.0),
			"boom_pivot": Vector3(0.0, pivot_y, 0.0),
			"exhaust": pump_center + Vector3(-size * 0.06, size * 0.35, 0.0),
			"vapor_outlet": rest_front_pin,
		},
		"readability": {
			"target_pixels": 72, "supersample": 2, "view_set": "octants",
			"minimum_regions": 3, "minimum_contrast": 0.045,
			"minimum_stroke_px": 1.0, "required": true,
			"critical_parts": {
				"derrick_front": {"minimum_visible_fraction": 0.06,
					"members": asset.part_names_for_instance("derrick_front"),
					"views": [0.0, 45.0, 315.0]},
				"walking_beam": {"minimum_visible_fraction": 0.08,
					"members": asset.part_names_for_instance("walking_beam")},
				"horsehead": {"minimum_visible_fraction": 0.07,
					"members": asset.part_names_for_instance("horsehead")},
			},
		},
		"front": "+Z",
		"metadata": {
			"description": "Rigged vapor derrick with an independently implemented four-bar drive",
			"reference_status": "Silhouette and material hierarchy matched to the supplied vapor-derrick concept",
			"intentional_asymmetry": ["staggered reservoirs", "process pipes"],
		},
	}
