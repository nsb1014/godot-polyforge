extends RefCounted
## Parameterized arcane pumpjack inspired by the supplied concept-art reference.
##
## Smoke is intentionally represented by an exhaust anchor. Particle effects belong in the
## consuming Godot scene; the compiled GLB remains a deterministic, reusable hard-surface asset.

const Assembly := preload("res://addons/polyforge/core/assembly.gd")
const Attachments := preload("res://addons/polyforge/core/attachments.gd")
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

func _beam_transform(a: Vector3, b: Vector3) -> Transform3D:
	var delta := b - a
	return _xf((a + b) * 0.5, Vector3(0.0, 0.0,
		rad_to_deg(atan2(delta.y, delta.x))))

func _add_beam(asset, name: String, a: Vector3, b: Vector3, thickness: float,
		depth: float, material: Material, tags = PackedStringArray()) -> void:
	asset.add(name, _part(Stock.box(Vector3(a.distance_to(b), thickness, depth)), material),
		_beam_transform(a, b), {"tags": tags})

func _between_y(a: Vector3, b: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var heading := Vector3.FORWARD
	if absf(y.dot(heading)) > 0.95:
		heading = Vector3.RIGHT
	var x := y.cross(heading).normalized()
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x, y, z), (a + b) * 0.5)

func _add_pipe(asset, name: String, points: Array, radius: float,
		material: Material) -> void:
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		asset.add("%s_%02d" % [name, i],
			_part(Stock.cylinder(radius, radius, a.distance_to(b), 10), material),
			_between_y(a, b), {"tags": ["pipe", "arcane"]})

func parameters() -> Dictionary:
	return {
		"size": Parameters.scale(6.0, 4.8, 7.2, "m",
			"Overall platform diameter; every physical measurement derives from it."),
		"boom_reach": Parameters.number(1.0, 0.82, 1.16, "ratio",
			"Horizontal reach of the walking beam and horsehead relative to the tower."),
		"tank_scale": Parameters.number(1.0, 0.80, 1.22, "ratio",
			"Arcane reservoir radius and connected pipe clearance multiplier."),
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
	var tower_pivot_y: float = p.derive("tower.pivot_y", "size", 0.64)
	var boom_length: float = p.computed("boom.length", size * 0.62 * boom_reach,
		["size", "boom_reach"], "size * 0.62 * boom_reach")
	var tank_radius: float = p.computed("tank.radius", size * 0.10 * tank_scale,
		["size", "tank_scale"], "size * 0.10 * tank_scale")
	var tank_center_y: float = p.computed("tank.center_y",
		deck_y + tank_radius * 1.18, ["platform.deck_y", "tank.radius"],
		"platform.deck_y + tank.radius * 1.18")
	var pipe_radius: float = p.derive("pipe.radius", "size", 0.025)
	var frame_depth: float = p.derive("frame.depth", "size", 0.105)

	var sand := Stock.material("sandstone_metal", Color("b58a55"), 0.52, 0.68)
	var sand_light := Stock.material("sandstone_trim", Color("d2aa70"), 0.44, 0.56)
	var dark := Stock.material("dark_mechanism", Color("4c413b"), 0.62, 0.72)
	var steel := Stock.material("polished_steel", Color("8b8580"), 0.74, 0.38)
	var arcane := Stock.glow_material("arcane_amethyst", Color("8d48d2"), 2.25)
	var arcane_dark := Stock.glow_material("arcane_pipe", Color("68408d"), 1.3)

	var asset := Assembly.new()
	asset.add("platform", _part(Stock.cylinder(base_radius, base_radius,
		base_height, 12), sand), _xf(Vector3(0.0, base_height * 0.5, 0.0)),
		{"tags": ["foundation"]})
	asset.add("platform_inlay", _part(Stock.torus(base_radius * 0.73,
		base_radius * 0.79, 24, 6), arcane_dark),
		_xf(Vector3(0.0, base_height * 1.02, 0.0)), {"tags": ["arcane", "trim"]})
	for i in range(12):
		var angle := TAU * float(i) / 12.0
		var rim_position := Vector3(cos(angle), 0.0, sin(angle)) * base_radius * 0.91
		rim_position.y = base_height * 0.72
		asset.add("rim_block_%02d" % i,
			_part(Stock.box(Vector3(size * 0.12, base_height * 1.45, size * 0.15)), sand_light),
			_xf(rim_position, Vector3(0.0, -rad_to_deg(angle), 0.0)),
			{"tags": ["foundation", "trim"]})

	asset.add("lower_plinth", _part(Stock.box(Vector3(size * 0.36,
		size * 0.12, size * 0.30)), dark),
		_xf(Vector3(0.08 * size, deck_y + size * 0.06, -size * 0.03)),
		{"tags": ["foundation", "machine"]})
	asset.add("upper_plinth", _part(Stock.box(Vector3(size * 0.28,
		size * 0.10, size * 0.24)), sand),
		_xf(Vector3(0.04 * size, deck_y + size * 0.15, -size * 0.02)),
		{"tags": ["foundation", "machine"]})

	# A-frame tower, duplicated in depth so the side views retain a readable load-bearing cage.
	for side_z in [-1.0, 1.0]:
		var z: float = float(side_z) * frame_depth * 0.5
		_add_beam(asset, "tower_leg_left_%s" % ("front" if side_z > 0.0 else "back"),
			Vector3(-size * 0.20, deck_y + size * 0.03, z),
			Vector3(-size * 0.025, tower_pivot_y, z), size * 0.055,
			size * 0.06, sand, ["tower", "brace"])
		_add_beam(asset, "tower_leg_right_%s" % ("front" if side_z > 0.0 else "back"),
			Vector3(size * 0.22, deck_y + size * 0.03, z),
			Vector3(size * 0.025, tower_pivot_y, z), size * 0.055,
			size * 0.06, sand, ["tower", "brace"])
		_add_beam(asset, "tower_cross_%s" % ("front" if side_z > 0.0 else "back"),
			Vector3(-size * 0.14, deck_y + size * 0.22, z),
			Vector3(size * 0.14, deck_y + size * 0.22, z), size * 0.045,
			size * 0.055, dark, ["tower", "brace"])
	asset.add("tower_pivot", _part(Stock.cylinder(size * 0.095, size * 0.095,
		frame_depth * 1.55, 16), sand_light),
		_xf(Vector3(0.0, tower_pivot_y, 0.0), Vector3(90.0, 0.0, 0.0)),
		{"tags": ["joint"]})
	asset.add("tower_pivot_core", _part(Stock.cylinder(size * 0.060, size * 0.060,
		frame_depth * 1.72, 16), arcane),
		_xf(Vector3(0.0, tower_pivot_y, 0.0), Vector3(90.0, 0.0, 0.0)),
		{"tags": ["joint", "arcane"]})

	var boom_left := Vector3(-boom_length * 0.54, tower_pivot_y + size * 0.13, 0.0)
	var boom_right := Vector3(boom_length * 0.46, tower_pivot_y - size * 0.055, 0.0)
	_add_beam(asset, "walking_beam", boom_left, boom_right, size * 0.105,
		frame_depth, sand, ["boom", "moving"])
	_add_beam(asset, "walking_beam_inset", boom_left + Vector3(size * 0.045, 0.0, frame_depth * 0.57),
		boom_right - Vector3(size * 0.045, 0.0, -frame_depth * 0.57),
		size * 0.035, size * 0.018, dark, ["boom", "trim"])
	var horsehead_center := boom_left + Vector3(-size * 0.015, -size * 0.015,
		frame_depth * 0.06)
	asset.add("horsehead", _part(Stock.capsule(size * 0.115, size * 0.50,
		12, 6), sand_light), _xf(horsehead_center, Vector3(0.0, 0.0, -9.0),
		Vector3(0.72, 1.0, 0.72)), {"tags": ["boom", "moving"]})
	asset.add("horsehead_face", _part(Stock.capsule(size * 0.075, size * 0.42,
		12, 6), sand), _xf(horsehead_center + Vector3(0.0, 0.0, frame_depth * 0.48),
		Vector3(0.0, 0.0, -9.0), Vector3(0.70, 1.0, 0.40)),
		{"tags": ["boom", "trim"]})
	for accent_index in range(3):
		asset.add("horsehead_arcane_%02d" % accent_index,
			_part(Stock.box(Vector3(size * 0.075, size * 0.035, size * 0.018)), arcane),
			_xf(horsehead_center + Vector3(0.0, size * (0.105 - accent_index * 0.105),
				frame_depth * 0.76), Vector3(0.0, 0.0, -9.0)),
			{"tags": ["arcane", "accent"]})

	# Polish rod and lower linkage make the extreme boom-reach sweep geometrically meaningful.
	var rod_x := horsehead_center.x
	var rod_top := horsehead_center.y - size * 0.22
	var rod_bottom := deck_y + size * 0.20
	asset.add("polish_rod", _part(Stock.cylinder(size * 0.025, size * 0.025,
		rod_top - rod_bottom, 10), steel),
		_xf(Vector3(rod_x, (rod_top + rod_bottom) * 0.5, 0.0)),
		{"tags": ["linkage", "moving"]})
	asset.add("polish_rod_collar", _part(Stock.cylinder(size * 0.055, size * 0.055,
		size * 0.10, 12), arcane),
		_xf(Vector3(rod_x, rod_bottom + size * 0.08, 0.0)),
		{"tags": ["linkage", "arcane"]})

	asset.add("pump_body", _part(Stock.cylinder(body_radius, body_radius,
		body_length, 16), sand),
		_xf(Vector3(size * 0.06, body_y, -size * 0.02), Vector3(0.0, 0.0, 90.0)),
		{"tags": ["machine", "pressure_vessel"]})
	asset.add("pump_endcap_left", _part(Stock.cylinder(body_radius * 1.08,
		body_radius * 1.08, size * 0.045, 16), sand_light),
		_xf(Vector3(size * 0.06 - body_length * 0.52, body_y, -size * 0.02),
			Vector3(0.0, 0.0, 90.0)), {"tags": ["machine", "trim"]})
	asset.add("pump_endcap_right", _part(Stock.cylinder(body_radius * 1.08,
		body_radius * 1.08, size * 0.045, 16), sand_light),
		_xf(Vector3(size * 0.06 + body_length * 0.52, body_y, -size * 0.02),
			Vector3(0.0, 0.0, 90.0)), {"tags": ["machine", "trim"]})

	var attachments := Attachments.new(asset)
	var wheel_depth := size * 0.065
	var wheel_frame := attachments.surface("drive_wheel_mount", "pump_body",
		Vector3(size * 0.06, body_y, body_radius + size * 0.10), {
			"child": "drive_wheel",
			"heading": Vector3.UP,
			"inset": -wheel_depth * 0.48,
			"max_hint_distance": size * 0.13,
			"position_tolerance": size * 0.0001,
		})
	asset.add("drive_wheel", _part(Stock.cylinder(size * 0.115, size * 0.115,
		wheel_depth, 14), sand_light), wheel_frame, {"tags": ["machine", "moving"]})
	asset.add("drive_wheel_hub", _part(Stock.cylinder(size * 0.035, size * 0.035,
		wheel_depth * 1.12, 12), dark),
		Transform3D(wheel_frame.basis, wheel_frame.origin - wheel_frame.basis.y * size * 0.005),
		{"tags": ["machine", "moving"]})

	var stack_height := size * 0.24
	var stack_frame := attachments.surface("exhaust_stack_mount", "pump_body",
		Vector3(size * 0.02, body_y + body_radius + size * 0.08, -size * 0.02), {
			"child": "exhaust_stack",
			"heading": Vector3.FORWARD,
			"inset": -stack_height * 0.46,
			"max_hint_distance": size * 0.10,
			"position_tolerance": size * 0.0001,
		})
	asset.add("exhaust_stack", _part(Stock.cylinder(size * 0.055, size * 0.075,
		stack_height, 12), sand_light), stack_frame,
		{"tags": ["machine", "exhaust"]})
	asset.add("exhaust_lip", _part(Stock.torus(size * 0.045, size * 0.075,
		16, 6), dark), Transform3D(stack_frame.basis,
		stack_frame.origin + stack_frame.basis.y * stack_height * 0.52),
		{"tags": ["exhaust", "trim"]})

	# Mirrored arcane reservoirs, with dimensions tied to their own tank radius.
	var tank_x := size * 0.34
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0.0 else "R"
		var center := Vector3(side * tank_x, tank_center_y, size * 0.07)
		asset.add("tank_core_" + suffix,
			_part(Stock.sphere(tank_radius, 14, 7), arcane),
			_xf(center, Vector3.ZERO, Vector3(0.86, 1.06, 0.86)),
			{"tags": ["tank", "arcane"]})
		asset.add("tank_base_" + suffix,
			_part(Stock.cylinder(tank_radius * 1.18, tank_radius * 1.18,
				size * 0.075, 14), dark),
			_xf(Vector3(center.x, deck_y + size * 0.035, center.z)),
			{"tags": ["tank", "mount"]})
		asset.add("tank_cap_" + suffix,
			_part(Stock.cylinder(tank_radius * 1.16, tank_radius * 1.08,
				size * 0.10, 14), sand_light),
			_xf(Vector3(center.x, center.y + tank_radius * 0.88, center.z)),
			{"tags": ["tank", "trim"]})
		asset.add("tank_ring_" + suffix,
			_part(Stock.torus(tank_radius * 0.94, tank_radius * 1.12, 16, 6), sand),
			_xf(Vector3(center.x, center.y - tank_radius * 0.70, center.z)),
			{"tags": ["tank", "trim"]})

	var pipe_z := size * 0.19
	var left_tank_top := Vector3(-tank_x, tank_center_y + tank_radius * 0.58, pipe_z)
	var right_tank_top := Vector3(tank_x, tank_center_y + tank_radius * 0.60, pipe_z)
	_add_pipe(asset, "left_feed", [
		left_tank_top,
		Vector3(-tank_x, body_y + body_radius * 0.35, pipe_z),
		Vector3(size * 0.06 - body_length * 0.48, body_y + body_radius * 0.35, pipe_z),
	], pipe_radius, arcane_dark)
	_add_pipe(asset, "right_return", [
		right_tank_top,
		Vector3(tank_x, deck_y + size * 0.10, pipe_z),
		Vector3(size * 0.16, deck_y + size * 0.10, pipe_z),
		Vector3(size * 0.16, body_y - body_radius * 0.25, pipe_z),
	], pipe_radius, arcane_dark)
	var crank_center := Vector3(size * 0.28, body_y + size * 0.06, pipe_z * 0.78)
	asset.add("crank_disk", _part(Stock.cylinder(size * 0.095, size * 0.095,
		size * 0.055, 14), dark),
		_xf(crank_center, Vector3(90.0, 0.0, 0.0)), {"tags": ["moving", "linkage"]})
	_add_pipe(asset, "crank_link", [
		crank_center + Vector3(size * 0.05, size * 0.02, 0.0),
		Vector3(boom_right.x - size * 0.10, boom_right.y - size * 0.04, pipe_z * 0.78),
	], pipe_radius * 0.72, steel)

	return {
		"name": "arcane_pumpjack",
		"category": "structure",
		"assembly": asset,
		"triangle_budget": 14000,
		"checks": [
			Checks.require_axis_size("platform", 0, base_radius * 2.0, size * 0.015),
			Checks.require_axis_ratio("walking_beam", 0, "walking_beam", 1, 1.70, 3.20),
			Checks.require_not_buried("drive_wheel", "pump_body"),
		],
		"anchors": {
			"deck_center": Vector3(0.0, deck_y, 0.0),
			"boom_pivot": Vector3(0.0, tower_pivot_y, 0.0),
			"exhaust": stack_frame.origin + stack_frame.basis.y * stack_height * 0.55,
			"left_tank_feed": left_tank_top,
			"right_tank_return": right_tank_top,
		},
		"attachments": attachments.snapshot(),
		"readability": {
			"target_pixels": 72,
			"supersample": 2,
			"view_set": "octants",
			"minimum_regions": 3,
			"minimum_contrast": 0.055,
			"minimum_stroke_px": 1.25,
			"critical_parts": {
				"walking_beam": {"minimum_visible_fraction": 0.12},
				"horsehead": {"minimum_visible_fraction": 0.10},
				"tank_core_L": {"minimum_visible_fraction": 0.18,
					"views": [0.0, 45.0, 315.0]},
				"tank_core_R": {"minimum_visible_fraction": 0.18,
					"views": [0.0, 45.0, 315.0]},
				"crank_disk": {"minimum_visible_fraction": 0.12,
					"views": [0.0, 45.0, 315.0]},
			},
			"required": true,
		},
		"front": "+Z",
		"metadata": {
			"description": "Parameterized arcane pumpjack with sampled machine attachments",
			"reference": "User-supplied concept image; smoke represented by the exhaust anchor",
		},
	}
