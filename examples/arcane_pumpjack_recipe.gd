extends RefCounted
## Vapor/arcane derrick reference asset. Structural repetition is authored as reusable
## components; deliberate process-equipment asymmetry remains outside symmetry contracts.

const Assembly := preload("res://addons/polyforge/core/assembly.gd")
const Component := preload("res://addons/polyforge/core/component.gd")
const SurfaceTypes := preload("res://addons/polyforge/core/surface_types.gd")
const Attachments := preload("res://addons/polyforge/core/attachments.gd")
const Parameters := preload("res://addons/polyforge/core/parameters.gd")
const Stock := preload("res://addons/polyforge/core/stock.gd")
const Checks := preload("res://addons/polyforge/quality/checks.gd")

func _xf(position: Vector3, rotation_degrees := Vector3.ZERO) -> Transform3D:
	var radians := Vector3(deg_to_rad(rotation_degrees.x),
		deg_to_rad(rotation_degrees.y), deg_to_rad(rotation_degrees.z))
	return Transform3D(Basis.from_euler(radians), position)

func _part(mesh: PrimitiveMesh, material: Material) -> PrimitiveMesh:
	return Stock.with_material(mesh, material)

func _surface(construction: String, role: String, options := {}) -> Dictionary:
	return SurfaceTypes.describe(construction, role, options)

func _options(construction: String, role: String, tags = PackedStringArray(),
		extra := {}) -> Dictionary:
	var result := extra.duplicate(true)
	result.tags = PackedStringArray(tags)
	result.surface = _surface(construction, role,
		result.get("surface_options", {}))
	result.erase("surface_options")
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

func _beam_component(id: String, length: float, thickness: float, depth: float,
		body: Material, trim: Material, inset: Material) -> RefCounted:
	var beam := Component.new(id)
	beam.add("core", _part(Stock.box(Vector3(length * 0.82, thickness, depth)), body),
		Transform3D.IDENTITY, _options("prismatic", "structural", ["beam"], {
			"surface_options": {"minimum_slenderness": 1.5}}))
	var cap_mesh := _part(Stock.box(Vector3(length * 0.10, thickness * 1.22,
		depth * 1.18)), trim)
	beam.add("cap_a", cap_mesh, _xf(Vector3(-length * 0.455, 0.0, 0.0)),
		_options("shell", "interface", ["beam", "end_cap"], {
			"surface_options": {"socket": "end_a"}}))
	beam.add("cap_b", cap_mesh, _xf(Vector3(length * 0.455, 0.0, 0.0)),
		_options("shell", "interface", ["beam", "end_cap"], {
			"surface_options": {"socket": "end_b"}}))
	beam.add("inset", _part(Stock.box(Vector3(length * 0.48, thickness * 0.32,
		depth * 1.04)), inset), Transform3D.IDENTITY,
		_options("plate", "trim", ["beam", "inset"], {
			"surface_options": {"maximum_thickness_ratio": 0.22}}))
	beam.define_socket("end_a", _xf(Vector3(-length * 0.5, 0.0, 0.0)))
	beam.define_socket("end_b", _xf(Vector3(length * 0.5, 0.0, 0.0)))
	return beam

func _place_beam(parent, name: String, beam, a: Vector3, b: Vector3) -> void:
	parent.instance(name, beam, _beam_xf(a, b))

func _derrick_bent(size: float, deck_y: float, pivot_y: float,
		sand: Material, sand_light: Material, dark: Material, arcane: Material) -> RefCounted:
	var bent := Component.new("derrick_bent_v2")
	var foot_y := deck_y + size * 0.03
	var foot_x := size * 0.21
	var top_x := size * 0.025
	var leg_a := Vector3(-foot_x, foot_y, 0.0)
	var leg_b := Vector3(-top_x, pivot_y, 0.0)
	var leg_length := leg_a.distance_to(leg_b)
	var leg := _beam_component("derrick_leg", leg_length, size * 0.055,
		size * 0.045, sand, sand_light, dark)
	_place_beam(bent, "left_leg", leg, leg_a, leg_b)
	_place_beam(bent, "right_leg", leg,
		Vector3(foot_x, foot_y, 0.0), Vector3(top_x, pivot_y, 0.0))
	var cross_y := deck_y + size * 0.24
	var cross_half := size * 0.145
	var cross := _beam_component("derrick_cross_member", cross_half * 2.0,
		size * 0.045, size * 0.040, dark, sand_light, sand)
	_place_beam(bent, "cross_member", cross,
		Vector3(-cross_half, cross_y, 0.0), Vector3(cross_half, cross_y, 0.0))
	var brace_a := Vector3(-foot_x * 0.82, foot_y + size * 0.06, 0.0)
	var brace_b := Vector3(cross_half * 0.82, cross_y + size * 0.03, 0.0)
	var diagonal := _beam_component("derrick_diagonal", brace_a.distance_to(brace_b),
		size * 0.032, size * 0.032, sand_light, sand, dark)
	_place_beam(bent, "diagonal_up", diagonal, brace_a, brace_b)
	_place_beam(bent, "diagonal_down", diagonal,
		Vector3(-brace_a.x, brace_a.y, 0.0), Vector3(-brace_b.x, brace_b.y, 0.0))
	var cheek_mesh := _part(Stock.box(Vector3(size * 0.10, size * 0.13,
		size * 0.030)), sand_light)
	bent.add("pivot_cheek_left", cheek_mesh, _xf(Vector3(-size * 0.055,
		pivot_y - size * 0.015, 0.0)), _options("plate", "interface", ["pivot"], {
			"surface_options": {"maximum_thickness_ratio": 0.28, "socket": "pivot"}}))
	bent.add("pivot_cheek_right", cheek_mesh, _xf(Vector3(size * 0.055,
		pivot_y - size * 0.015, 0.0)), _options("plate", "interface", ["pivot"], {
			"surface_options": {"maximum_thickness_ratio": 0.28, "socket": "pivot"}}))
	bent.add("bearing", _part(Stock.cylinder(size * 0.078, size * 0.078,
		size * 0.052, 14), arcane), _xf(Vector3(0.0, pivot_y, 0.0),
		Vector3(90.0, 0.0, 0.0)), _options("revolved", "interface", ["pivot"], {
			"surface_options": {"axis": "y", "socket": "pivot"}}))
	bent.define_socket("pivot", _xf(Vector3(0.0, pivot_y, 0.0)))
	bent.define_socket("left_foot", _xf(leg_a))
	bent.define_socket("right_foot", _xf(Vector3(foot_x, foot_y, 0.0)))
	return bent

func _walking_beam(size: float, boom_left: Vector3, boom_right: Vector3,
		frame_depth: float, sand: Material, sand_light: Material,
		dark: Material) -> RefCounted:
	var assembly := Component.new("walking_beam_assembly_v2")
	var rail_length := boom_left.distance_to(boom_right)
	var rail := _beam_component("walking_beam_rail", rail_length, size * 0.073,
		size * 0.045, sand, sand_light, dark)
	var rail_z := frame_depth * 0.38
	_place_beam(assembly, "front_rail", rail,
		boom_left + Vector3(0.0, 0.0, rail_z), boom_right + Vector3(0.0, 0.0, rail_z))
	_place_beam(assembly, "back_rail", rail,
		boom_left - Vector3(0.0, 0.0, rail_z), boom_right - Vector3(0.0, 0.0, rail_z))
	var spine := _beam_component("walking_beam_spine", rail_length, size * 0.10,
		frame_depth * 0.30, dark, sand_light, sand)
	_place_beam(assembly, "spine", spine, boom_left, boom_right)
	var rib := _beam_component("walking_beam_depth_rib", frame_depth * 0.80,
		size * 0.050, size * 0.060, sand_light, sand, dark)
	for index in range(4):
		var center := boom_left.lerp(boom_right, float(index + 1) / 5.0)
		_place_beam(assembly, "depth_rib_%02d" % index, rib,
			center - Vector3(0.0, 0.0, frame_depth * 0.40),
			center + Vector3(0.0, 0.0, frame_depth * 0.40))
	assembly.define_socket("pivot", _xf(Vector3(0.0, (boom_left.y + boom_right.y) * 0.5, 0.0)))
	assembly.define_socket("horsehead", _xf(boom_left))
	return assembly

func _horsehead(size: float, frame_depth: float, sand: Material,
		sand_light: Material, arcane: Material) -> RefCounted:
	var head := Component.new("horsehead_assembly_v2")
	var plate := Component.new("horsehead_plate")
	var plate_depth := size * 0.036
	plate.add("outer", _part(Stock.capsule(size * 0.105, size * 0.49, 12, 6),
		sand_light), Transform3D.IDENTITY, _options("shell", "silhouette", ["horsehead"]))
	var insert_mesh := _part(Stock.box(Vector3(size * 0.075, size * 0.032,
		plate_depth * 1.20)), arcane)
	for index in range(3):
		plate.add("insert_%02d" % index, insert_mesh,
			_xf(Vector3(0.0, size * (0.105 - index * 0.105), 0.0)),
			_options("shell", "decorative", ["horsehead", "arcane"]))
	var plate_z := frame_depth * 0.39
	head.instance("front_plate", plate, _xf(Vector3(0.0, 0.0, plate_z),
		Vector3(0.0, 0.0, -9.0)))
	head.instance("back_plate", plate, _xf(Vector3(0.0, 0.0, -plate_z),
		Vector3(0.0, 0.0, -9.0)))
	var spacer := _beam_component("horsehead_spacer", plate_z * 2.0,
		size * 0.045, size * 0.045, sand, sand_light, arcane)
	for index in range(3):
		var y: float = size * (0.13 - float(index) * 0.13)
		_place_beam(head, "spacer_%02d" % index, spacer,
			Vector3(0.0, y, -plate_z), Vector3(0.0, y, plate_z))
	return head

func _tank_component(size: float, radius: float, _deck_y: float,
		sand: Material, sand_light: Material, dark: Material,
		arcane: Material) -> RefCounted:
	var tank := Component.new("vapor_reservoir")
	tank.add("core", _part(Stock.sphere(radius, 14, 7), arcane),
		_xf(Vector3.ZERO), _options("sculpted", "enclosure", ["tank", "arcane"]))
	tank.add("base", _part(Stock.cylinder(radius * 1.18, radius * 1.18,
		size * 0.075, 14), dark), _xf(Vector3(0.0, -radius * 1.12, 0.0)),
		_options("revolved", "contact", ["tank", "mount"], {
			"surface_options": {"axis": "y"}}))
	tank.add("cap", _part(Stock.cylinder(radius * 1.16, radius * 1.08,
		size * 0.10, 14), sand_light), _xf(Vector3(0.0, radius * 0.88, 0.0)),
		_options("revolved", "interface", ["tank"], {
			"surface_options": {"axis": "y", "socket": "feed"}}))
	tank.add("ring", _part(Stock.torus(radius * 0.94, radius * 1.12, 16, 6), sand),
		_xf(Vector3(0.0, -radius * 0.70, 0.0)),
		_options("revolved", "trim", ["tank"], {"surface_options": {"axis": "y"}}))
	tank.define_socket("feed", _xf(Vector3(0.0, radius * 1.10, 0.0)))
	return tank

func _add_pipe(asset, name: String, points: Array, radius: float,
		material: Material) -> void:
	for index in range(points.size() - 1):
		var a: Vector3 = points[index]
		var b: Vector3 = points[index + 1]
		_add(asset, "%s_%02d" % [name, index],
			_part(Stock.cylinder(radius, radius, a.distance_to(b), 10), material),
			_between_y(a, b), "swept", "conduit", ["pipe"], {
				"surface_options": {"radius": radius}})
		if index > 0:
			_add(asset, "%s_elbow_%02d" % [name, index],
				_part(Stock.sphere(radius * 1.35, 10, 5), material), _xf(a),
				"swept", "conduit", ["pipe", "elbow"], {
					"surface_options": {"radius": radius}})

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
	var body_radius: float = p.derive("pump.body_radius", "size", 0.115)
	var body_length: float = p.derive("pump.body_length", "size", 0.31)
	var body_y: float = p.derive("pump.body_y", "size", 0.245)
	var pivot_y: float = p.derive("tower.pivot_y", "size", 0.64)
	var boom_length: float = p.computed("boom.length", size * 0.62 * boom_reach,
		["size", "boom_reach"], "size * 0.62 * boom_reach")
	var tank_radius: float = p.computed("tank.radius", size * 0.10 * tank_scale,
		["size", "tank_scale"], "size * 0.10 * tank_scale")
	var tank_center_y: float = p.computed("tank.center_y", deck_y + tank_radius * 1.18,
		["platform.deck_y", "tank.radius"], "platform.deck_y + tank.radius * 1.18")
	var pipe_radius: float = p.derive("pipe.radius", "size", 0.025)
	var frame_depth: float = p.derive("frame.depth", "size", 0.22)

	var sand := Stock.material("sandstone_metal", Color("b58a55"), 0.52, 0.68)
	var sand_light := Stock.material("sandstone_trim", Color("d2aa70"), 0.44, 0.56)
	var dark := Stock.material("dark_mechanism", Color("4c413b"), 0.62, 0.72)
	var steel := Stock.material("polished_steel", Color("8b8580"), 0.74, 0.38)
	var arcane := Stock.glow_material("arcane_amethyst", Color("8d48d2"), 2.25)
	var arcane_dark := Stock.glow_material("arcane_pipe", Color("68408d"), 1.3)

	var asset := Assembly.new()
	_add(asset, "platform", _part(Stock.cylinder(base_radius, base_radius,
		base_height, 12), sand), _xf(Vector3(0.0, base_height * 0.5, 0.0)),
		"revolved", "contact", ["foundation"], {"surface_options": {"axis": "y"}})
	_add(asset, "platform_inlay", _part(Stock.torus(base_radius * 0.73,
		base_radius * 0.79, 24, 6), arcane_dark),
		_xf(Vector3(0.0, base_height * 1.02, 0.0)), "revolved", "decorative",
		["arcane", "trim"], {"surface_options": {"axis": "y"}})
	var rim := Component.new("platform_rim_block")
	rim.add("block", _part(Stock.box(Vector3(size * 0.12, base_height * 1.45,
		size * 0.15)), sand_light), Transform3D.IDENTITY,
		_options("prismatic", "contact", ["foundation", "trim"], {
			"surface_options": {"minimum_slenderness": 1.0}}))
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		var position := Vector3(cos(angle), 0.0, sin(angle)) * base_radius * 0.91
		position.y = base_height * 0.72
		asset.instance_component("rim_%02d" % index, rim,
			_xf(position, Vector3(0.0, -rad_to_deg(angle), 0.0)))

	_add(asset, "lower_plinth", _part(Stock.box(Vector3(size * 0.36,
		size * 0.12, size * 0.30)), dark),
		_xf(Vector3(0.08 * size, deck_y + size * 0.06, -size * 0.03)),
		"prismatic", "contact", ["foundation"], {"surface_options": {"minimum_slenderness": 1.0}})
	_add(asset, "upper_plinth", _part(Stock.box(Vector3(size * 0.28,
		size * 0.10, size * 0.24)), sand),
		_xf(Vector3(0.04 * size, deck_y + size * 0.15, -size * 0.02)),
		"prismatic", "contact", ["foundation"], {"surface_options": {"minimum_slenderness": 1.0}})

	var bent := _derrick_bent(size, deck_y, pivot_y, sand, sand_light, dark, arcane)
	var bent_z := frame_depth * 0.43
	asset.instance_component("derrick_front", bent, _xf(Vector3(0.0, 0.0, bent_z)))
	asset.instance_component("derrick_back", bent, _xf(Vector3(0.0, 0.0, -bent_z)))
	var tie := _beam_component("derrick_depth_tie", bent_z * 2.0, size * 0.055,
		size * 0.050, sand_light, sand, dark)
	for index in range(3):
		var tie_center := Vector3(0.0, deck_y + size * (0.18 + index * 0.20), 0.0)
		asset.instance_component("derrick_tie_%02d" % index, tie,
			_beam_xf(tie_center - Vector3(0.0, 0.0, bent_z),
				tie_center + Vector3(0.0, 0.0, bent_z)))
	_add(asset, "tower_pivot", _part(Stock.cylinder(size * 0.095, size * 0.095,
		frame_depth * 1.12, 16), sand_light),
		_xf(Vector3(0.0, pivot_y, 0.0), Vector3(90.0, 0.0, 0.0)),
		"revolved", "interface", ["joint"], {
			"surface_options": {"axis": "y", "socket": "boom_pivot"}})
	_add(asset, "tower_pivot_core", _part(Stock.cylinder(size * 0.060, size * 0.060,
		frame_depth * 1.20, 16), arcane),
		_xf(Vector3(0.0, pivot_y, 0.0), Vector3(90.0, 0.0, 0.0)),
		"revolved", "interface", ["joint", "arcane"], {
			"surface_options": {"axis": "y", "socket": "boom_pivot"}})

	var boom_left := Vector3(-boom_length * 0.54, pivot_y + size * 0.13, 0.0)
	var boom_right := Vector3(boom_length * 0.46, pivot_y - size * 0.055, 0.0)
	var walking := _walking_beam(size, boom_left, boom_right, frame_depth,
		sand, sand_light, dark)
	asset.instance_component("walking_beam", walking)
	var horsehead_center := boom_left + Vector3(-size * 0.015, -size * 0.015, 0.0)
	var horsehead := _horsehead(size, frame_depth, sand, sand_light, arcane)
	asset.instance_component("horsehead", horsehead, _xf(horsehead_center))

	var rod_top := horsehead_center.y - size * 0.22
	var rod_bottom := deck_y + size * 0.20
	_add(asset, "polish_rod", _part(Stock.cylinder(size * 0.025, size * 0.025,
		rod_top - rod_bottom, 10), steel),
		_xf(Vector3(horsehead_center.x, (rod_top + rod_bottom) * 0.5, bent_z)),
		"revolved", "structural", ["linkage", "moving"], {"surface_options": {"axis": "y"}})
	_add(asset, "polish_rod_collar", _part(Stock.cylinder(size * 0.055,
		size * 0.055, size * 0.10, 12), arcane),
		_xf(Vector3(horsehead_center.x, rod_bottom + size * 0.08, bent_z)),
		"revolved", "interface", ["linkage", "arcane"], {
			"surface_options": {"axis": "y", "socket": "polish_rod"}})

	_add(asset, "pump_body", _part(Stock.cylinder(body_radius, body_radius,
		body_length, 16), sand), _xf(Vector3(size * 0.06, body_y, -size * 0.02),
		Vector3(0.0, 0.0, 90.0)), "revolved", "enclosure", ["machine"],
		{"surface_options": {"axis": "y"}})
	for side in [-1.0, 1.0]:
		var suffix: String = "left" if side < 0.0 else "right"
		_add(asset, "pump_endcap_" + suffix,
			_part(Stock.cylinder(body_radius * 1.08, body_radius * 1.08,
				size * 0.045, 16), sand_light),
			_xf(Vector3(size * 0.06 + float(side) * body_length * 0.52,
				body_y, -size * 0.02), Vector3(0.0, 0.0, 90.0)),
			"revolved", "enclosure", ["machine", "trim"], {
				"surface_options": {"axis": "y"}})

	var attachments := Attachments.new(asset)
	var wheel_depth := size * 0.065
	var wheel_frame := attachments.surface("drive_wheel_mount", "pump_body",
		Vector3(size * 0.06, body_y, body_radius + size * 0.10), {
			"child": "drive_wheel", "heading": Vector3.UP,
			"inset": -wheel_depth * 0.48, "max_hint_distance": size * 0.13,
			"position_tolerance": size * 0.0001})
	_add(asset, "drive_wheel", _part(Stock.cylinder(size * 0.115, size * 0.115,
		wheel_depth, 14), sand_light), wheel_frame, "revolved", "interface",
		["machine", "moving"], {"surface_options": {"axis": "y", "socket": "drive_wheel_mount"}})
	_add(asset, "drive_wheel_hub", _part(Stock.cylinder(size * 0.035, size * 0.035,
		wheel_depth * 1.12, 12), dark), Transform3D(wheel_frame.basis,
		wheel_frame.origin - wheel_frame.basis.y * size * 0.005),
		"revolved", "interface", ["machine", "moving"], {
			"surface_options": {"axis": "y", "socket": "drive_wheel_mount"}})
	var stack_height := size * 0.24
	var stack_frame := attachments.surface("exhaust_stack_mount", "pump_body",
		Vector3(size * 0.02, body_y + body_radius + size * 0.08, -size * 0.02), {
			"child": "exhaust_stack", "heading": Vector3.FORWARD,
			"inset": -stack_height * 0.46, "max_hint_distance": size * 0.10,
			"position_tolerance": size * 0.0001})
	_add(asset, "exhaust_stack", _part(Stock.cylinder(size * 0.055, size * 0.075,
		stack_height, 12), sand_light), stack_frame, "revolved", "conduit",
		["machine", "exhaust"], {"surface_options": {"axis": "y", "radius": size * 0.065}})
	_add(asset, "exhaust_lip", _part(Stock.torus(size * 0.045, size * 0.075,
		16, 6), dark), Transform3D(stack_frame.basis,
		stack_frame.origin + stack_frame.basis.y * stack_height * 0.52),
		"revolved", "trim", ["exhaust"], {"surface_options": {"axis": "y"}})

	var tank := _tank_component(size, tank_radius, deck_y, sand, sand_light, dark, arcane)
	var tank_x := size * 0.34
	var left_center := Vector3(-tank_x, tank_center_y, size * 0.12)
	var right_center := Vector3(tank_x, tank_center_y, -size * 0.12)
	asset.instance_component("left_reservoir", tank, _xf(left_center))
	asset.instance_component("right_reservoir", tank, _xf(right_center))
	var left_tank_top := left_center + Vector3(0.0, tank_radius * 1.10, 0.0)
	var right_tank_top := right_center + Vector3(0.0, tank_radius * 1.10, 0.0)
	_add_pipe(asset, "left_feed", [left_tank_top,
		Vector3(-tank_x, body_y + body_radius * 0.35, size * 0.23),
		Vector3(size * 0.06 - body_length * 0.48, body_y + body_radius * 0.35, size * 0.23),
		Vector3(size * 0.06 - body_length * 0.48, body_y + body_radius * 0.35, size * 0.08)],
		pipe_radius, arcane_dark)
	_add_pipe(asset, "right_return", [right_tank_top,
		Vector3(tank_x, deck_y + size * 0.10, -size * 0.22),
		Vector3(size * 0.16, deck_y + size * 0.10, -size * 0.22),
		Vector3(size * 0.16, body_y - body_radius * 0.25, -size * 0.22),
		Vector3(size * 0.16, body_y - body_radius * 0.25, -size * 0.07)],
		pipe_radius, arcane_dark)

	var crank_center := Vector3(size * 0.28, body_y + size * 0.06, size * 0.18)
	_add(asset, "crank_disk", _part(Stock.cylinder(size * 0.095, size * 0.095,
		size * 0.055, 14), dark), _xf(crank_center, Vector3(90.0, 0.0, 0.0)),
		"revolved", "interface", ["moving", "linkage"], {
			"surface_options": {"axis": "y", "socket": "crank"}})
	_add_pipe(asset, "crank_link", [crank_center + Vector3(size * 0.05, size * 0.02, 0.0),
		Vector3(boom_right.x - size * 0.10, boom_right.y - size * 0.04, bent_z)],
		pipe_radius * 0.72, steel)
	var rear_center := Vector3(size * 0.22, body_y + size * 0.07, -size * 0.27)
	_add(asset, "rear_flywheel", _part(Stock.cylinder(size * 0.15, size * 0.15,
		size * 0.07, 16), sand_light), _xf(rear_center, Vector3(90.0, 0.0, 0.0)),
		"revolved", "interface", ["moving", "rear_mechanism"], {
			"surface_options": {"axis": "y", "socket": "rear_drive"}})
	_add(asset, "rear_flywheel_hub", _part(Stock.cylinder(size * 0.052,
		size * 0.052, size * 0.095, 12), arcane),
		_xf(rear_center, Vector3(90.0, 0.0, 0.0)), "revolved", "interface",
		["moving", "rear_mechanism"], {"surface_options": {"axis": "y", "socket": "rear_drive"}})
	_add_pipe(asset, "drive_shaft", [rear_center + Vector3(0.0, 0.0, size * 0.03),
		Vector3(rear_center.x, rear_center.y, crank_center.z - size * 0.03)],
		pipe_radius * 1.35, steel)
	_add_pipe(asset, "rear_crank_link", [rear_center + Vector3(size * 0.09, size * 0.025, 0.0),
		Vector3(boom_right.x - size * 0.06, boom_right.y - size * 0.055, -bent_z)],
		pipe_radius * 0.82, steel)
	_add(asset, "rear_drive_pedestal", _part(Stock.box(Vector3(size * 0.18,
		size * 0.28, size * 0.16)), dark),
		_xf(Vector3(rear_center.x, deck_y + size * 0.14, rear_center.z)),
		"prismatic", "contact", ["foundation", "rear_mechanism"], {
			"surface_options": {"minimum_slenderness": 1.0}})

	var derrick_front_members := asset.part_names_for_instance("derrick_front")
	var derrick_back_members := asset.part_names_for_instance("derrick_back")
	var walking_members := asset.part_names_for_instance("walking_beam")
	var horsehead_members := asset.part_names_for_instance("horsehead")
	return {
		"name": "arcane_pumpjack",
		"category": "structure",
		"assembly": asset,
		"triangle_budget": 18000,
		"require_surface_classification": true,
		"symmetry": [
			{"name": "derrick front/back reuse", "first": "derrick_front",
				"second": "derrick_back", "axis": "z", "tolerance": size * 0.00001},
			{"name": "walking rail reuse", "first": "walking_beam/front_rail",
				"second": "walking_beam/back_rail", "axis": "z", "tolerance": size * 0.00001},
			{"name": "horsehead plate reuse", "first": "horsehead/front_plate",
				"second": "horsehead/back_plate", "axis": "z", "tolerance": size * 0.00001},
		],
		"checks": [
			Checks.require_axis_size("platform", 0, base_radius * 2.0, size * 0.015),
			Checks.require_axis_ratio("walking_beam__spine__core", 0,
				"walking_beam__spine__core", 1, 1.70, 5.0),
			Checks.require_axis_range("walking_beam__front_rail__core", 2,
				size * 0.02, size * 0.15),
			Checks.require_axis_range("horsehead__front_plate__outer", 2,
				size * 0.16, size * 0.30),
			Checks.require_axis_range("tower_pivot", 2, size * 0.20, size * 0.32),
			Checks.require_not_buried("drive_wheel", "pump_body"),
		],
		"anchors": {
			"deck_center": Vector3(0.0, deck_y, 0.0),
			"boom_pivot": Vector3(0.0, pivot_y, 0.0),
			"exhaust": stack_frame.origin + stack_frame.basis.y * stack_height * 0.55,
			"left_tank_feed": left_tank_top,
			"right_tank_return": right_tank_top,
		},
		"attachments": attachments.snapshot(),
		"readability": {
			"target_pixels": 72, "supersample": 2, "view_set": "octants",
			"minimum_regions": 3, "minimum_contrast": 0.055,
			"minimum_stroke_px": 1.25, "required": true,
			"critical_parts": {
				"derrick_front": {"minimum_visible_fraction": 0.08,
					"members": derrick_front_members,
					"views": [0.0, 45.0, 315.0]},
				"derrick_back": {"minimum_visible_fraction": 0.08,
					"members": derrick_back_members,
					"views": [135.0, 180.0, 225.0]},
				"walking_beam": {"minimum_visible_fraction": 0.12,
					"members": walking_members,
					"views": [0.0, 45.0, 135.0, 180.0, 225.0, 315.0]},
				"horsehead": {"minimum_visible_fraction": 0.10,
					"members": horsehead_members},
				"left_reservoir": {"minimum_visible_fraction": 0.15,
					"members": asset.part_names_for_instance("left_reservoir"),
					"views": [0.0, 315.0]},
				"right_reservoir": {"minimum_visible_fraction": 0.15,
					"members": asset.part_names_for_instance("right_reservoir"),
					"views": [135.0]},
			},
			"visibility_pairs": [{
				"name": "derrick front/back balance", "first": "derrick_front",
				"second": "derrick_back", "maximum_delta": 0.34,
				"views": [[0.0, 180.0], [45.0, 135.0], [315.0, 225.0]],
			}],
		},
		"front": "+Z",
		"metadata": {
			"description": "Component-authored vapor derrick with scoped structural symmetry",
			"reference": "User-supplied concept image; vapor is represented by the exhaust anchor",
			"intentional_asymmetry": ["staggered reservoirs", "process pipes", "rear drive train"],
		},
	}
