extends RefCounted
## Complex reference proof: rigid masses, interfaces, tension members, then appearance.

const Component := preload("res://addons/polyforge/core/component.gd")
const SurfaceTypes := preload("res://addons/polyforge/core/surface_types.gd")
const Parameters := preload("res://addons/polyforge/core/parameters.gd")
const Stock := preload("res://addons/polyforge/core/stock.gd")
const TopologyBudget := preload("res://addons/polyforge/core/topology_budget.gd")
const Checks := preload("res://addons/polyforge/quality/checks.gd")
const CanonicalArtifact := preload("res://addons/polyforge/core/canonical_artifact.gd")
const AssetIntent := preload("res://addons/polyforge/core/asset_intent.gd")
const DesignBrief := preload("res://addons/polyforge/core/design_brief.gd")
const ResolvedDesign := preload("res://addons/polyforge/core/resolved_design.gd")
const CohesionContract := preload("res://addons/polyforge/core/cohesion_contract.gd")
const PlausibilityContract := preload("res://addons/polyforge/core/plausibility_contract.gd")
const AppearanceStyleBinding := preload("res://addons/polyforge/core/appearance_style_binding.gd")
const ReferenceProfile := preload("res://addons/polyforge/core/reference_profile.gd")
const AssemblyPlan := preload("res://addons/polyforge/core/assembly_plan.gd")
const SolvedAssembly := preload("res://addons/polyforge/core/solved_assembly.gd")
const ComponentCatalog := preload("res://addons/polyforge/core/component_catalog.gd")
const RigidAssemblySolver := preload("res://addons/polyforge/core/rigid_assembly_solver.gd")
const InterfacePlan := preload("res://addons/polyforge/core/interface_plan.gd")
const SuspensionPlan := preload("res://addons/polyforge/core/suspension_plan.gd")
const AssemblyCompiler := preload("res://addons/polyforge/build/assembly_compiler.gd")
const RigidInterfaceCompiler := preload("res://addons/polyforge/build/rigid_interface_compiler.gd")
const SuspensionCompiler := preload("res://addons/polyforge/build/suspension_compiler.gd")
const GeometryFingerprint := preload("res://addons/polyforge/core/geometry_fingerprint.gd")
const StageRunner := preload("res://addons/polyforge/build/stage_runner.gd")
const StyleCompiler := preload("res://addons/polyforge/build/style_compiler.gd")

func _xf(position: Vector3, rotation_degrees := Vector3.ZERO,
		scale := Vector3.ONE) -> Transform3D:
	var basis := Basis.from_euler(Vector3(deg_to_rad(rotation_degrees.x),
		deg_to_rad(rotation_degrees.y), deg_to_rad(rotation_degrees.z)))
	return Transform3D(basis.scaled(scale), position)

func _between_y(a: Vector3, b: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var guide := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) <= 0.95 else Vector3.RIGHT
	var x := y.cross(guide).normalized()
	return Transform3D(Basis(x, y, x.cross(y).normalized()), (a + b) * 0.5)

func _options(construction: String, role: String, tags = PackedStringArray(),
		repetition := "unique", options := {}) -> Dictionary:
	return {"tags": PackedStringArray(tags), "surface": SurfaceTypes.classify(
		construction, role, repetition, "static", options)}

func _socket(type: String, accepts: Array, radius: float) -> Dictionary:
	return {"type": type, "accepts": PackedStringArray(accepts),
		"allowed_twist_degrees": PackedFloat32Array([0.0]), "cardinality": 1,
		"position_tolerance": 0.0001, "rotation_tolerance_degrees": 0.01,
		"clearance_radius": radius}

func _slots() -> Dictionary:
	return {
		"body.canvas": {"display_name": "warm balloon canvas", "affects_geometry": false,
			"color": Color("eee3cf"), "metallic": 0.0, "roughness": 0.86},
		"structure.brass": {"display_name": "weathered brass", "affects_geometry": false,
			"color": Color("b98b55"), "metallic": 0.34, "roughness": 0.58},
		"basket.wood": {"display_name": "basket wood", "affects_geometry": false,
			"color": Color("76513b"), "metallic": 0.0, "roughness": 0.82},
		"fabric.blue": {"display_name": "periwinkle fabric", "affects_geometry": false,
			"color": Color("596a9e"), "metallic": 0.0, "roughness": 0.72},
		"rope.fiber": {"display_name": "braided rope", "affects_geometry": false,
			"color": Color("9a7045"), "metallic": 0.0, "roughness": 0.92},
		"effect.cyan": {"display_name": "aether cyan", "affects_geometry": false,
			"color": Color("42dbe5"), "metallic": 0.0, "roughness": 0.25,
			"emission_enabled": true, "emission": Color("42dbe5"),
			"emission_energy": 1.8},
	}

func _termination(size: float) -> Dictionary:
	return {"family": "tension.eyelet", "material_slot": "structure.brass",
		"inner_radius": size * 0.012, "outer_radius": size * 0.022,
		"boss_height": size * 0.040, "segments": 6,
		"minimum_host_overlap": 0.04, "endpoint_tolerance": size * 0.0001,
		"maximum_surface_distance": size * 0.012}

func _envelope(size: float, materials: Dictionary, segments: int) -> RefCounted:
	var c := Component.new("aerostat_envelope_v1")
	var r := size * 0.30
	c.add("canvas", Stock.with_material(Stock.sphere(r, segments + 4, 10), materials.canvas),
		_xf(Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.90, 1.0)),
		_options("organic", "primary_silhouette", ["envelope", "primary"], "centered"))
	for ring in [
		{"name": "equator", "y": 0.0, "inner": 0.275, "outer": 0.306},
		{"name": "upper_band", "y": r * 0.42, "inner": 0.245, "outer": 0.268},
		{"name": "lower_band", "y": -r * 0.42, "inner": 0.245, "outer": 0.268},
	]:
		c.add(str(ring.name), Stock.with_material(Stock.torus(size * float(ring.inner),
			size * float(ring.outer), segments + 6, 5), materials.brass),
			_xf(Vector3(0.0, float(ring.y), 0.0)),
			_options("revolved", "structural", ["harness", "primary"], "centered",
				{"axis": "y"}))
	# Segmented ribs follow the envelope instead of cutting across it.
	for rib_index in range(6):
		var azimuth := TAU * float(rib_index) / 6.0
		for segment_index in range(4):
			var t0 := float(segment_index) / 4.0
			var t1 := float(segment_index + 1) / 4.0
			var p0_angle := lerpf(0.10, PI - 0.10, t0)
			var p1_angle := lerpf(0.10, PI - 0.10, t1)
			var p0 := Vector3(cos(azimuth) * sin(p0_angle) * r * 1.015,
				cos(p0_angle) * r * 0.90, sin(azimuth) * sin(p0_angle) * r * 1.015)
			var p1 := Vector3(cos(azimuth) * sin(p1_angle) * r * 1.015,
				cos(p1_angle) * r * 0.90, sin(azimuth) * sin(p1_angle) * r * 1.015)
			c.add("rib_%02d_%02d" % [rib_index, segment_index],
				Stock.with_material(Stock.cylinder(size * 0.011, size * 0.011,
					p0.distance_to(p1), 7), materials.brass), _between_y(p0, p1),
				_options("swept", "structural", ["harness", "primary"], "radial_repeat",
					{"radius": size * 0.011}))
	# Four fabric swags establish a coherent repeated layer below the equator.
	for swag_index in range(4):
		var azimuth := TAU * float(swag_index) / 4.0 + PI * 0.25
		var tangent := Vector3(-sin(azimuth), 0.0, cos(azimuth))
		var center := Vector3(cos(azimuth), 0.0, sin(azimuth)) * r * 0.86
		var left := center - tangent * r * 0.34 + Vector3.UP * r * 0.03
		var sag := center + Vector3.DOWN * r * 0.25
		var right := center + tangent * r * 0.34 + Vector3.UP * r * 0.03
		for edge in [[left, sag], [sag, right]]:
			c.add("swag_%02d_%02d" % [swag_index, 0 if edge[0] == left else 1],
				Stock.with_material(Stock.cylinder(size * 0.032, size * 0.032,
					edge[0].distance_to(edge[1]), 8), materials.blue),
				_between_y(edge[0], edge[1]),
				_options("swept", "trim", ["fabric", "tertiary"], "radial_repeat",
					{"radius": size * 0.032}))
	c.add("top_cap", Stock.with_material(Stock.cylinder(r * 0.22, r * 0.18,
		size * 0.10, segments), materials.brass), _xf(Vector3(0.0, r * 0.87, 0.0)),
		_options("revolved", "structural", ["harness", "primary"], "centered", {"axis": "y"}))
	c.add("top_lens", Stock.with_material(Stock.cylinder(r * 0.095, r * 0.095,
		size * 0.018, segments), materials.cyan), _xf(Vector3(0.0, r * 0.93, 0.0)),
		_options("revolved", "effect_anchor", ["aether", "tertiary"], "centered", {"axis": "y"}))
	var outward_left := Basis.from_euler(Vector3(0.0, 0.0, PI * 0.5))
	var outward_right := Basis.from_euler(Vector3(0.0, 0.0, -PI * 0.5))
	c.define_typed_socket("pod_left", Transform3D(outward_left, Vector3(-r, 0.0, 0.0)),
		_socket("pod_mount", ["pod_hanger"], size * 0.05))
	c.define_typed_socket("pod_right", Transform3D(outward_right, Vector3(r, 0.0, 0.0)),
		_socket("pod_mount", ["pod_hanger"], size * 0.05))
	c.define_typed_socket("basket_position", _xf(Vector3(0.0, -size * 0.66, 0.0)),
		_socket("basket_position", ["basket_hanger"], 0.0))
	c.define_typed_socket("lantern_position", _xf(Vector3(0.0, -size * 0.39, 0.0)),
		_socket("lantern_position", ["lantern_hanger"], 0.0))
	var ax := size * 0.15
	var az := size * 0.10
	var ay := -size * 0.22
	for anchor in [
		{"name": "rope_fl", "p": Vector3(-ax, ay, az)},
		{"name": "rope_fr", "p": Vector3(ax, ay, az)},
		{"name": "rope_bl", "p": Vector3(-ax, ay, -az)},
		{"name": "rope_br", "p": Vector3(ax, ay, -az)},
	]:
		c.define_typed_socket(str(anchor.name), _xf(anchor.p),
			_socket("tension_anchor", ["tension_anchor"], 0.0))
	c.define_typed_socket("lantern_anchor", _xf(Vector3(0.0, -r * 0.92, 0.0)),
		_socket("tension_anchor", ["tension_anchor"], 0.0))
	return c

func _pod(size: float, materials: Dictionary, segments: int) -> RefCounted:
	var c := Component.new("aerostat_pod_v1")
	c.add("housing", Stock.with_material(Stock.cylinder(size * 0.065, size * 0.080,
		size * 0.12, segments), materials.brass), _xf(Vector3(0.0, size * 0.045, 0.0)),
		_options("revolved", "enclosure", ["pod", "tertiary"], "paired", {"axis": "y"}))
	c.add("lens", Stock.with_material(Stock.cylinder(size * 0.043, size * 0.043,
		size * 0.012, segments), materials.cyan), _xf(Vector3(0.0, size * 0.108, 0.0)),
		_options("revolved", "effect_anchor", ["pod", "aether", "tertiary"], "paired", {"axis": "y"}))
	c.define_typed_socket("mount", Transform3D.IDENTITY,
		_socket("pod_hanger", ["pod_mount"], size * 0.05))
	return c

func _basket(size: float, materials: Dictionary, segments: int) -> RefCounted:
	var c := Component.new("aerostat_basket_v1")
	var radius := size * 0.15
	var height := size * 0.22
	c.add("body", Stock.with_material(Stock.cylinder(radius * 0.82, radius,
		height, segments), materials.wood), _xf(Vector3(0.0, -height * 0.5, 0.0)),
		_options("revolved", "enclosure", ["basket", "secondary"], "centered", {"axis": "y"}))
	for ring in [{"name": "rim", "y": 0.0, "scale": 1.08},
		{"name": "lower_ring", "y": -height * 0.88, "scale": 0.86}]:
		c.add(str(ring.name), Stock.with_material(Stock.torus(radius * float(ring.scale) * 0.82,
			radius * float(ring.scale), segments + 4, 5), materials.blue if ring.name == "rim" else materials.brass),
			_xf(Vector3(0.0, float(ring.y), 0.0)), _options("revolved", "structural",
				["basket", "secondary"], "centered", {"axis": "y"}))
	for slat_index in range(8):
		var angle := TAU * float(slat_index) / 8.0
		var p := Vector3(cos(angle), 0.0, sin(angle)) * radius * 0.88
		c.add("slat_%02d" % slat_index, Stock.with_material(Stock.box(Vector3(
			size * 0.035, height * 0.92, size * 0.025)), materials.brass),
			_xf(Vector3(p.x, -height * 0.48, p.z), Vector3(0.0, -rad_to_deg(angle), 0.0)),
			_options("prismatic", "structural", ["basket", "secondary"], "radial_repeat"))
	c.add("front_plate", Stock.with_material(Stock.box(Vector3(size * 0.12,
		height * 0.78, size * 0.035)), materials.brass),
		_xf(Vector3(0.0, -height * 0.48, radius * 0.91)),
		_options("prismatic", "trim", ["basket", "secondary"], "unique",
			{"minimum_slenderness": 1.0}))
	c.add("front_gem", Stock.with_material(Stock.sphere(size * 0.030, 8, 4), materials.cyan),
		_xf(Vector3(0.0, -height * 0.45, radius * 0.94), Vector3.ZERO,
			Vector3(0.75, 1.0, 0.38)), _options("organic", "effect_anchor",
			["basket", "aether", "tertiary"], "unique"))
	c.add("rear_plate", Stock.with_material(Stock.box(Vector3(size * 0.10,
		height * 0.62, size * 0.030)), materials.brass),
		_xf(Vector3(0.0, -height * 0.50, -radius * 0.91)),
		_options("prismatic", "trim", ["basket", "secondary"], "unique",
			{"minimum_slenderness": 1.0}))
	c.add("rear_gem", Stock.with_material(Stock.sphere(size * 0.025, 8, 4), materials.cyan),
		_xf(Vector3(0.0, -height * 0.48, -radius * 0.94), Vector3.ZERO,
			Vector3(0.75, 1.0, 0.38)), _options("organic", "effect_anchor",
			["basket", "aether", "tertiary"], "unique"))
	for side in [-1.0, 1.0]:
		c.add("bag_left" if side < 0.0 else "bag_right",
			Stock.with_material(Stock.capsule(size * 0.055, size * 0.13, 8, 4), materials.blue),
			_xf(Vector3(float(side) * radius * 1.24, -height * 0.48, 0.0)),
			_options("organic", "decorative", ["basket", "tertiary"], "paired"))
	c.define_typed_socket("hanger", Transform3D.IDENTITY,
		_socket("basket_hanger", ["basket_position"], 0.0))
	var sx := radius * 0.78
	var sz := radius * 0.56
	for anchor in [
		{"name": "rope_fl", "p": Vector3(-sx, 0.0, sz)},
		{"name": "rope_fr", "p": Vector3(sx, 0.0, sz)},
		{"name": "rope_bl", "p": Vector3(-sx, 0.0, -sz)},
		{"name": "rope_br", "p": Vector3(sx, 0.0, -sz)},
	]:
		c.define_typed_socket(str(anchor.name), _xf(anchor.p),
			_socket("tension_anchor", ["tension_anchor"], 0.0))
	return c

func _lantern(size: float, materials: Dictionary, segments: int) -> RefCounted:
	var c := Component.new("aerostat_lantern_v1")
	c.add("cap", Stock.with_material(Stock.cylinder(size * 0.047, size * 0.040,
		size * 0.055, segments), materials.brass), _xf(Vector3(0.0, -size * 0.030, 0.0)),
		_options("revolved", "trim", ["lantern", "tertiary"], "unique", {"axis": "y"}))
	c.add("glow", Stock.with_material(Stock.sphere(size * 0.055, 10, 5), materials.cyan),
		_xf(Vector3(0.0, -size * 0.092, 0.0), Vector3.ZERO, Vector3(0.78, 1.0, 0.78)),
		_options("organic", "effect_anchor", ["lantern", "aether", "tertiary"], "unique"))
	c.define_typed_socket("hanger", Transform3D.IDENTITY,
		_socket("lantern_hanger", ["lantern_position"], 0.0))
	c.define_typed_socket("top", Transform3D.IDENTITY,
		_socket("tension_anchor", ["tension_anchor"], 0.0))
	return c

func parameters() -> Dictionary:
	return {"size": Parameters.scale(5.0, 4.0, 6.0, "m", "Envelope diameter.")}

func build(p) -> Dictionary:
	var size: float = p.value("size")
	var quality := TopologyBudget.profile("runtime")
	var segments := TopologyBudget.radial_segments(8.0, quality, 10)
	var slots := _slots()
	var binding := AppearanceStyleBinding.new("", slots)
	var intent := AssetIntent.new({
		"asset_kind": "suspended_rigid_assembly",
		"semantic_parts": ["spherical envelope", "radial harness", "basket",
			"paired side pods", "four suspension ropes", "central aether lantern"],
		"functional_requirements": ["rigid socket closure", "paired rope lengths",
			"suspension does not mutate solved transforms", "readable mass hierarchy"],
		"geometry_style_requirements": {"shape_language": "soft sphere in chunky brass cage",
			"symmetry": "bilateral and radial", "reference_role": "semantic target"},
		"parameters": {"size": size},
	}, {"palette_family": "cream canvas, brass, periwinkle and cyan", "slots": slots})
	binding = AppearanceStyleBinding.new(intent.appearance_hash(), slots)
	var brief := DesignBrief.new(intent.content_hash(), {
		"archetype": "arcane passenger aerostat",
		"functional_read": "a buoyant envelope supports a clearly suspended basket",
	}, [{"id": "primary_envelope", "tier": "primary"},
		{"id": "secondary_basket", "tier": "secondary"},
		{"id": "tertiary_suspension", "tier": "tertiary"}],
		["segmented spherical harness", "four load ropes", "open basket",
			"paired cyan side pods", "central hanging lantern"],
		["inflated cream mass", "chunky brass bands", "taut thin lines",
			"restrained emissive accents"], {"required": ["archetype", "signature_features"],
			"preferred": ["mass hierarchy", "composition"],
			"informational": ["exact ornament", "pixel correspondence"]})
	var resolved := ResolvedDesign.new(intent.construction_hash(), {
		"units": "meters", "front": "+Z", "size": size,
		"solvers": [RigidAssemblySolver.new(ComponentCatalog.new()).descriptor(),
			SuspensionCompiler.descriptor()]})
	var cohesion := CohesionContract.new(brief.content_hash(),
		["envelope", "pod_left", "pod_right"], ["mount_pod_left", "mount_pod_right"],
		{"profile_id": "aerostat.brass_socket.v1",
			"allowed_families": ["rigid.cylinder_collar"]}, [
			{"id": "primary_envelope", "tier": "primary", "minimum_share": 0.52,
				"target_share": 0.62, "maximum_share": 0.76},
			{"id": "secondary_basket", "tier": "secondary", "minimum_share": 0.15,
				"target_share": 0.22, "maximum_share": 0.29},
			{"id": "tertiary_suspension", "tier": "tertiary", "minimum_share": 0.10,
				"target_share": 0.16, "maximum_share": 0.23},
		], [{"higher": "primary_envelope", "lower": "secondary_basket",
			"minimum_ratio": 2.1, "target_ratio": 3.6},
			{"higher": "secondary_basket", "lower": "tertiary_suspension",
				"minimum_ratio": 1.05, "target_ratio": 1.35}], true)
	var plausibility := PlausibilityContract.new(brief.content_hash(),
		"suspended_vehicle", [
			{"id": "envelope", "role": "lift_and_harness", "support_source": true},
			{"id": "basket", "role": "payload", "requires_support": true},
			{"id": "lantern", "role": "hanging_accessory", "requires_support": true},
			{"id": "pod_left", "role": "mounted_accessory", "requires_support": true},
			{"id": "pod_right", "role": "mounted_accessory", "requires_support": true},
		], [
			{"id": "basket_load_path", "from": "basket", "to": "envelope",
				"kind": "hangs_from", "basis": "functional_inference",
				"authority": "required", "evidence": {"suspension_members": [
					"rope_fl", "rope_fr", "rope_bl", "rope_br"],
					"require_terminations": true}},
			{"id": "lantern_load_path", "from": "lantern", "to": "envelope",
				"kind": "hangs_from", "basis": "observed", "authority": "required",
				"evidence": {"suspension_members": ["lantern_drop"],
					"require_terminations": true}},
			{"id": "left_pod_mount", "from": "pod_left", "to": "envelope",
				"kind": "mounts_to", "basis": "observed", "authority": "required",
				"evidence": {"connection_id": "mount_pod_left",
					"require_visible_interface": true}},
			{"id": "right_pod_mount", "from": "pod_right", "to": "envelope",
				"kind": "mounts_to", "basis": "observed", "authority": "required",
				"evidence": {"connection_id": "mount_pod_right",
					"require_visible_interface": true}},
			{"id": "blue_drape_completion", "from": "envelope", "to": "envelope",
				"kind": "decorates", "basis": "stylistic_hypothesis",
				"authority": "informational", "evidence": {}},
		], {"unobserved_geometry": "minimal_cohesive",
			"stylistic_hypotheses": "non_blocking"})
	var reference := ReferenceProfile.new({"sha256":
		"872bce81ad35e2955751e95eadf3790a7049cae38a6261ed3f167c14136af2ab",
		"width": 1536, "height": 1536, "description": "attached arcane aerostat reference"}, {
		"envelope": {"selector": {"tags": ["envelope"]}, "minimum": 1},
		"harness": {"selector": {"tags": ["harness"]}, "minimum": 8},
		"basket": {"selector": {"tags": ["basket"]}, "minimum": 6},
		"suspension": {"selector": {"tags": ["suspension"]}, "minimum": 5},
		"aether_lights": {"selector": {"tags": ["aether"]}, "minimum": 4},
	}, {"envelope_center": {"minimum": Vector3(0.35, 0.52, 0.25),
		"maximum": Vector3(0.65, 0.78, 0.75)}, "basket_center": {
			"minimum": Vector3(0.35, 0.0, 0.25), "maximum": Vector3(0.65, 0.36, 0.75)}},
		["body.canvas", "structure.brass", "fabric.blue", "effect.cyan"], [{
			"name": "tall suspended composition", "numerator_axis": 1,
			"denominator_axis": 0, "minimum": 1.20, "maximum": 1.85}],
		"arcane_aerostat.reference_profile.v1", {"semantic_groups": "required",
			"anchors": "preferred", "appearance_slots": "required",
			"proportions": "preferred"})
	assert(intent.validate().is_empty() and brief.validate().is_empty() and
		cohesion.validate().is_empty() and plausibility.validate().is_empty() and
		resolved.validate().is_empty() and
		binding.validate().is_empty() and reference.validate().is_empty())
	var materials := {"canvas": StyleCompiler.slot("body.canvas"),
		"brass": StyleCompiler.slot("structure.brass"),
		"wood": StyleCompiler.slot("basket.wood"),
		"blue": StyleCompiler.slot("fabric.blue"), "rope": StyleCompiler.slot("rope.fiber"),
		"cyan": StyleCompiler.slot("effect.cyan")}
	var catalog := ComponentCatalog.new()
	catalog.register("aerostat.envelope", "1.0.0", _envelope(size, materials, segments))
	catalog.register("aerostat.pod", "1.0.0", _pod(size, materials, segments))
	catalog.register("aerostat.basket", "1.0.0", _basket(size, materials, segments))
	catalog.register("aerostat.lantern", "1.0.0", _lantern(size, materials, segments))
	var instances := [{"id": "envelope", "component_id": "aerostat.envelope",
		"fixed_transform": _xf(Vector3(0.0, size * 0.30, 0.0))},
		{"id": "pod_left", "component_id": "aerostat.pod"},
		{"id": "pod_right", "component_id": "aerostat.pod"},
		{"id": "basket", "component_id": "aerostat.basket"},
		{"id": "lantern", "component_id": "aerostat.lantern"}]
	var connections := [
		{"id": "mount_pod_left", "a": {"instance": "envelope", "socket": "pod_left"},
			"b": {"instance": "pod_left", "socket": "mount"}, "twist_degrees": 0.0},
		{"id": "mount_pod_right", "a": {"instance": "envelope", "socket": "pod_right"},
			"b": {"instance": "pod_right", "socket": "mount"}, "twist_degrees": 0.0},
		{"id": "position_basket", "a": {"instance": "envelope", "socket": "basket_position"},
			"b": {"instance": "basket", "socket": "hanger"}, "twist_degrees": 0.0},
		{"id": "position_lantern", "a": {"instance": "envelope", "socket": "lantern_position"},
			"b": {"instance": "lantern", "socket": "hanger"}, "twist_degrees": 0.0},
	]
	var plan := AssemblyPlan.new(resolved.content_hash(), catalog.content_hash(),
		"envelope", instances, connections)
	var solver := RigidAssemblySolver.new(catalog)
	var solve_result := solver.solve({"problem_type": "rigid.socket_assembly",
		"plan": plan.payload, "constraints": [{"kind": "rigid.socket_mate"}]})
	assert(solve_result.status == "solved", str(solve_result.diagnostics))
	var solution: Dictionary = solve_result.solution
	var solved := SolvedAssembly.new(plan.content_hash(), catalog.content_hash(),
		solution.instances, solution.transforms, solution.connections, solution.residuals,
		solution.clearance, solver.descriptor())
	var interface_plan := InterfacePlan.new(solved.content_hash(), cohesion.content_hash(), [
		{"connection_id": "mount_pod_left", "family": "rigid.cylinder_collar",
			"profile_id": "aerostat.brass_socket.v1", "material_slot": "structure.brass",
			"radius": size * 0.075, "height": size * 0.075, "segments": segments,
			"offset": Vector3.ZERO, "minimum_endpoint_overlap": 0.08},
		{"connection_id": "mount_pod_right", "family": "rigid.cylinder_collar",
			"profile_id": "aerostat.brass_socket.v1", "material_slot": "structure.brass",
			"radius": size * 0.075, "height": size * 0.075, "segments": segments,
			"offset": Vector3.ZERO, "minimum_endpoint_overlap": 0.08},
	])
	var base := AssemblyCompiler.compile(catalog, solved)
	var base_hash := GeometryFingerprint.assembly_hash(base.assembly)
	var interface_compilation := RigidInterfaceCompiler.compile(catalog, solved, interface_plan)
	assert(interface_compilation.ok, "; ".join(interface_compilation.failures))
	var suspension_members := []
	for id in ["rope_fl", "rope_fr", "rope_bl", "rope_br"]:
		var pair: String = {"rope_fl": "rope_fr", "rope_fr": "rope_fl",
			"rope_bl": "rope_br", "rope_br": "rope_bl"}[id]
		suspension_members.append({"id": id,
			"a": {"instance": "envelope", "socket": id},
			"b": {"instance": "basket", "socket": id}, "radius": size * 0.0065,
			"minimum_length": size * 0.30, "maximum_length": size * 0.60,
			"material_slot": "rope.fiber", "profile_id": "aerostat.rope.v1",
			"segments": 7, "paired_with": pair, "pair_tolerance": size * 0.002,
			"a_termination": _termination(size), "b_termination": _termination(size)})
	suspension_members.append({"id": "lantern_drop",
		"a": {"instance": "envelope", "socket": "lantern_anchor"},
		"b": {"instance": "lantern", "socket": "top"}, "radius": size * 0.006,
		"minimum_length": size * 0.06, "maximum_length": size * 0.32,
		"material_slot": "structure.brass", "profile_id": "aerostat.lantern_drop.v1",
		"segments": 7, "a_termination": _termination(size),
		"b_termination": _termination(size)})
	var suspension_plan := SuspensionPlan.new(solved.content_hash(),
		interface_compilation.output_geometry_hash, suspension_members)
	var suspension_compilation := SuspensionCompiler.compile(catalog, solved,
		interface_compilation.assembly, suspension_plan)
	assert(suspension_compilation.ok, "; ".join(suspension_compilation.failures))
	var asset = suspension_compilation.assembly
	var style_compilation := StyleCompiler.apply(asset, binding)
	assert(style_compilation.ok, "; ".join(style_compilation.failures))
	var stages := StageRunner.new("arcane_aerostat.segregated_pipeline_v1")
	stages.record("intent", "arcane_aerostat.intent.v1", {}, intent)
	stages.record("resolve_brief", "arcane_aerostat.brief.v1", {"asset_intent": intent.content_hash()}, brief)
	stages.record("resolve_plausibility", "arcane_aerostat.plausibility.v1",
		{"design_brief": brief.content_hash()}, plausibility)
	stages.record("resolve_design", "arcane_aerostat.resolver.v1", {"construction_intent": intent.construction_hash(), "design_brief": brief.content_hash(), "plausibility_contract": plausibility.content_hash()}, resolved)
	stages.record("plan_assembly", "arcane_aerostat.rigid_plan.v1", {"resolved_design": resolved.content_hash()}, plan)
	stages.record("solve_rigid", "polyforge.rigid.socket_assembly@1.0.0", {"assembly_plan": plan.content_hash()}, solved, solve_result.diagnostics)
	stages.record("plan_interfaces", "arcane_aerostat.interface_plan.v1", {"solved_assembly": solved.content_hash(), "cohesion_contract": cohesion.content_hash()}, interface_plan)
	stages.record("compile_geometry", "polyforge.solved_assembly_compiler.v1", {"solved_assembly": solved.content_hash()}, {"geometry_hash": base_hash, "parts": base.assembly.parts.size()})
	stages.record("compile_interfaces", "polyforge.rigid_interface_compiler@1.0.0", {"solved_assembly": solved.content_hash(), "interface_plan": interface_plan.content_hash(), "base_geometry": base_hash}, interface_compilation.artifact)
	stages.record("plan_suspension", "arcane_aerostat.suspension_plan.v1", {"solved_assembly": solved.content_hash(), "interface_geometry": interface_compilation.output_geometry_hash}, suspension_plan)
	stages.record("compile_suspension", "polyforge.suspension_compiler@1.0.0", {"suspension_plan": suspension_plan.content_hash(), "interface_geometry": interface_compilation.output_geometry_hash}, suspension_compilation.artifact)
	stages.record("compile_appearance", "polyforge.style_slots.v1", {"appearance_intent": intent.appearance_hash(), "geometry": suspension_compilation.output_geometry_hash}, style_compilation)
	var primary_parts: PackedStringArray = asset.part_names_for_instance("envelope")
	primary_parts.append_array(asset.part_names_for_instance("interfaces"))
	var secondary_parts: PackedStringArray = asset.part_names_for_instance("basket")
	var tertiary_parts: PackedStringArray = asset.part_names_for_instance("pod_left")
	tertiary_parts.append_array(asset.part_names_for_instance("pod_right"))
	tertiary_parts.append_array(asset.part_names_for_instance("lantern"))
	tertiary_parts.append_array(asset.part_names_for_instance("suspension"))
	return {"name": "arcane_aerostat", "category": "vehicle", "assembly": asset,
		"triangle_budget": 7600, "topology_budget": {"rendered_triangles": 7600,
			"unique_triangles": 7400}, "quality_profile": "runtime",
		"require_surface_classification": true, "require_part_classification": true,
		"contracts": {"asset_intent": intent.to_canonical_dict(),
			"design_brief": brief.to_canonical_dict(), "resolved_design": resolved.to_canonical_dict(),
			"plausibility_contract": plausibility.to_canonical_dict(),
			"cohesion_contract": cohesion.to_canonical_dict(), "component_catalog": catalog.snapshot(),
			"assembly_plan": plan.to_canonical_dict(), "solved_assembly": solved.to_canonical_dict(),
			"interface_plan": interface_plan.to_canonical_dict(),
			"interface_compilation": interface_compilation.artifact.to_canonical_dict(),
			"suspension_plan": suspension_plan.to_canonical_dict(),
			"suspension_compilation": suspension_compilation.artifact.to_canonical_dict(),
			"appearance_binding": binding.to_canonical_dict()},
		"process": stages.snapshot(), "style_compilation": CanonicalArtifact.canonicalize(style_compilation),
		"reference_profile": reference.to_canonical_dict(),
		"anchors": {"envelope_center": solution.transforms.envelope.origin,
			"basket_center": solution.transforms.basket.origin - Vector3.UP * size * 0.08},
		"symmetry": [], "checks": [Checks.require_axis_range("envelope__canvas", 0,
			size * 0.57, size * 0.62)], "front": "+Z", "loose": true,
		"readability": {"target_pixels": 96, "supersample": 2, "view_set": "octants",
			"minimum_regions": 2, "minimum_contrast": 0.035, "minimum_stroke_px": 1.0,
			"required": true, "critical_parts": {
				"primary_envelope": {"members": primary_parts, "minimum_visible_fraction": 0.18},
				"secondary_basket": {"members": secondary_parts, "minimum_visible_fraction": 0.06},
				"tertiary_suspension": {"members": tertiary_parts, "minimum_visible_fraction": 0.02}}},
		"metadata": {"description": "Reference-derived arcane aerostat with isolated rigid, interface, suspension, and style ownership", "solver": solver.descriptor(), "suspension_compiler": SuspensionCompiler.descriptor()}}
