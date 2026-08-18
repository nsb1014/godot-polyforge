extends RefCounted
## Static typed-socket proof: plan -> rigid solve -> geometry -> appearance.

const Component := preload("res://addons/polyforge/core/component.gd")
const SurfaceTypes := preload("res://addons/polyforge/core/surface_types.gd")
const Parameters := preload("res://addons/polyforge/core/parameters.gd")
const Stock := preload("res://addons/polyforge/core/stock.gd")
const TopologyBudget := preload("res://addons/polyforge/core/topology_budget.gd")
const Checks := preload("res://addons/polyforge/quality/checks.gd")
const CanonicalArtifact := preload("res://addons/polyforge/core/canonical_artifact.gd")
const AssetIntent := preload("res://addons/polyforge/core/asset_intent.gd")
const ResolvedDesign := preload("res://addons/polyforge/core/resolved_design.gd")
const AppearanceStyleBinding := preload("res://addons/polyforge/core/appearance_style_binding.gd")
const AssemblyPlan := preload("res://addons/polyforge/core/assembly_plan.gd")
const SolvedAssembly := preload("res://addons/polyforge/core/solved_assembly.gd")
const ComponentCatalog := preload("res://addons/polyforge/core/component_catalog.gd")
const RigidAssemblySolver := preload("res://addons/polyforge/core/rigid_assembly_solver.gd")
const GeometryFingerprint := preload("res://addons/polyforge/core/geometry_fingerprint.gd")
const AssemblyCompiler := preload("res://addons/polyforge/build/assembly_compiler.gd")
const StageRunner := preload("res://addons/polyforge/build/stage_runner.gd")
const StyleCompiler := preload("res://addons/polyforge/build/style_compiler.gd")
const PlanPatch := preload("res://addons/polyforge/core/plan_patch.gd")
const CandidateGenerator := preload("res://addons/polyforge/build/assembly_candidate_generator.gd")
const RepairRegistry := preload("res://addons/polyforge/build/repair_registry.gd")
const RigidTwistRepair := preload("res://addons/polyforge/core/rigid_twist_repair.gd")
const CandidateRepairStage := preload("res://addons/polyforge/build/candidate_repair_stage.gd")
const CandidateSelector := preload("res://addons/polyforge/build/candidate_selector.gd")

func _xf(position: Vector3, rotation_degrees := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(rotation_degrees.x),
		deg_to_rad(rotation_degrees.y), deg_to_rad(rotation_degrees.z))), position)

func _options(construction: String, role: String, tags = PackedStringArray(),
		repetition := "unique", surface_options := {}) -> Dictionary:
	return {"tags": PackedStringArray(tags), "surface": SurfaceTypes.classify(
		construction, role, repetition, "static", surface_options)}

func _socket(type: String, accepts: Array, radius: float) -> Dictionary:
	return {"type": type, "accepts": PackedStringArray(accepts),
		"allowed_twist_degrees": PackedFloat32Array([0.0]), "cardinality": 1,
		"position_tolerance": 0.0001, "rotation_tolerance_degrees": 0.01,
		"clearance_radius": radius}

func _appearance_slots() -> Dictionary:
	return {
		"body.stone": {"display_name": "sandstone_brass", "affects_geometry": false,
			"color": Color("9a744f"), "metallic": 0.28, "roughness": 0.78},
		"trim.gold": {"display_name": "relay_trim", "affects_geometry": false,
			"color": Color("d0a66a"), "metallic": 0.52, "roughness": 0.50},
		"recess.dark": {"display_name": "relay_recess", "affects_geometry": false,
			"color": Color("51443d"), "metallic": 0.20, "roughness": 0.88},
		"effect.arcane": {"display_name": "relay_amethyst", "affects_geometry": false,
			"color": Color("8d4bd1"), "metallic": 0.0, "roughness": 0.34,
			"emission_enabled": true, "emission": Color("8d4bd1"),
			"emission_energy": 1.45},
	}

func _foundation(size: float, span: float, base_height: float,
		segments: int, materials: Dictionary) -> RefCounted:
	var component := Component.new("relay_foundation_v1")
	component.add("base", Stock.with_material(Stock.cylinder(size * 0.48,
		size * 0.48, base_height, segments), materials.stone),
		_xf(Vector3(0.0, base_height * 0.5, 0.0)),
		_options("revolved", "contact", ["foundation"], "centered", {"axis": "y"}))
	component.add("deck", Stock.with_material(Stock.cylinder(size * 0.39,
		size * 0.43, base_height * 0.34, segments), materials.trim),
		_xf(Vector3(0.0, base_height * 1.02, 0.0)),
		_options("revolved", "contact", ["foundation", "deck"], "centered", {"axis": "y"}))
	component.add("inlay", Stock.with_material(Stock.torus(size * 0.28,
		size * 0.34, segments + 2, 4), materials.arcane),
		_xf(Vector3(0.0, base_height * 1.05, 0.0)),
		_options("revolved", "decorative", ["foundation", "arcane"], "centered", {"axis": "y"}))
	var mount_y := base_height * 1.20
	component.define_typed_socket("left_support", _xf(Vector3(-span * 0.5, mount_y, 0.0)),
		_socket("support_mount", ["support_foot"], size * 0.07))
	component.define_typed_socket("right_support", _xf(Vector3(span * 0.5, mount_y, 0.0)),
		_socket("support_mount", ["support_foot"], size * 0.07))
	component.define_typed_socket("core_mount", _xf(Vector3(0.0, mount_y, 0.0)),
		_socket("core_mount", ["core_foot"], size * 0.08))
	return component

func _column(size: float, height: float, materials: Dictionary) -> RefCounted:
	var component := Component.new("relay_column_v1")
	var width := size * 0.105
	component.add("shaft", Stock.with_material(Stock.box(Vector3(width, height,
		width * 0.82)), materials.stone), _xf(Vector3(0.0, height * 0.5, 0.0)),
		_options("prismatic", "structural", ["support"], "paired"))
	component.add("foot", Stock.with_material(Stock.box(Vector3(width * 1.45,
		size * 0.075, width * 1.25)), materials.trim),
		_xf(Vector3(0.0, size * 0.0375, 0.0)),
		_options("prismatic", "interface", ["support", "socket"], "paired",
			{"minimum_slenderness": 1.0, "socket": "foot"}))
	component.add("capital", Stock.with_material(Stock.box(Vector3(width * 1.55,
		size * 0.09, width * 1.30)), materials.trim),
		_xf(Vector3(0.0, height - size * 0.045, 0.0)),
		_options("prismatic", "interface", ["support", "socket"], "paired",
			{"minimum_slenderness": 1.0, "socket": "beam_mount"}))
	component.add("rune", Stock.with_material(Stock.box(Vector3(width * 0.30,
		height * 0.54, width * 0.12)), materials.arcane),
		_xf(Vector3(0.0, height * 0.52, width * 0.47)),
		_options("prismatic", "effect_anchor", ["support", "arcane"], "paired"))
	component.define_typed_socket("foot", Transform3D.IDENTITY,
		_socket("support_foot", ["support_mount"], width * 0.70))
	component.define_typed_socket("beam_mount", _xf(Vector3(0.0, height, 0.0)),
		_socket("beam_mount", ["beam_end"], width * 0.75))
	return component

func _lintel(size: float, span: float, materials: Dictionary) -> RefCounted:
	var component := Component.new("relay_lintel_v1")
	var height := size * 0.13
	component.add("beam", Stock.with_material(Stock.box(Vector3(span + size * 0.18,
		height, size * 0.11)), materials.stone), _xf(Vector3(0.0, height * 0.5, 0.0)),
		_options("prismatic", "structural", ["lintel", "primary_silhouette"], "centered"))
	component.add("lower_trim", Stock.with_material(Stock.box(Vector3(span + size * 0.10,
		size * 0.035, size * 0.135)), materials.trim),
		_xf(Vector3(0.0, size * 0.018, 0.0)),
		_options("prismatic", "trim", ["lintel"], "centered"))
	component.add("recess", Stock.with_material(Stock.box(Vector3(span * 0.36,
		height * 0.52, size * 0.012)), materials.dark),
		_xf(Vector3(0.0, height * 0.58, size * 0.061)),
		_options("prismatic", "decorative", ["lintel", "recess"], "centered"))
	component.add("lens", Stock.with_material(Stock.sphere(size * 0.075, 10, 5),
		materials.arcane), _xf(Vector3(0.0, height * 0.60, size * 0.075)),
		_options("organic", "effect_anchor", ["lintel", "arcane"], "centered"))
	component.define_typed_socket("left_end", _xf(Vector3(-span * 0.5, 0.0, 0.0)),
		_socket("beam_end", ["beam_mount"], size * 0.08))
	component.define_typed_socket("right_end", _xf(Vector3(span * 0.5, 0.0, 0.0)),
		_socket("beam_end", ["beam_mount"], size * 0.08))
	return component

func _core(size: float, materials: Dictionary, segments: int) -> RefCounted:
	var component := Component.new("relay_core_v1")
	component.add("pedestal", Stock.with_material(Stock.cylinder(size * 0.10,
		size * 0.13, size * 0.15, segments), materials.trim),
		_xf(Vector3(0.0, size * 0.075, 0.0)),
		_options("revolved", "contact", ["core"], "centered", {"axis": "y"}))
	component.add("housing", Stock.with_material(Stock.cylinder(size * 0.075,
		size * 0.10, size * 0.24, segments), materials.dark),
		_xf(Vector3(0.0, size * 0.23, 0.0)),
		_options("revolved", "enclosure", ["core"], "centered", {"axis": "y"}))
	component.add("crystal", Stock.with_material(Stock.sphere(size * 0.105, 10, 5),
		materials.arcane), _xf(Vector3(0.0, size * 0.38, 0.0)),
		_options("organic", "effect_anchor", ["core", "arcane"], "centered"))
	component.define_typed_socket("foot", Transform3D.IDENTITY,
		_socket("core_foot", ["core_mount"], size * 0.10))
	return component

func parameters() -> Dictionary:
	return {
		"size": Parameters.scale(4.0, 3.2, 5.2, "m",
			"Overall relay foundation diameter."),
		"span_ratio": Parameters.number(1.0, 0.82, 1.18, "ratio",
			"Support and lintel span relative to foundation size."),
	}

func build(p) -> Dictionary:
	var size: float = p.value("size")
	var span_ratio: float = p.value("span_ratio")
	var span: float = p.computed("relay.span", size * 0.53 * span_ratio,
		["size", "span_ratio"], "size * 0.53 * span_ratio")
	var base_height: float = p.derive("foundation.height", "size", 0.105)
	var column_height: float = p.derive("support.height", "size", 0.62)
	var quality := TopologyBudget.profile("runtime")
	var segments := TopologyBudget.radial_segments(7.0, quality, 8)
	var appearance_slots := _appearance_slots()
	var intent := AssetIntent.new({
		"asset_kind": "static_rigid_assembly",
		"semantic_parts": ["foundation", "paired supports", "lintel", "relay core"],
		"functional_requirements": ["typed socket compatibility", "dual-end closure",
			"keepout clearance", "bilateral support"],
		"geometry_style_requirements": {"shape_language": "arcane industrial shrine",
			"foundation_sides": 8, "paired_supports": true},
		"parameters": {"size": size, "span_ratio": span_ratio},
	}, {"palette_family": "weathered brass and amethyst", "slots": appearance_slots})
	var resolved := ResolvedDesign.new(intent.construction_hash(), {
		"units": "meters", "front": "+Z", "size": size, "span": span,
		"base_height": base_height, "column_height": column_height,
		"solver": {"id": "polyforge.rigid.socket_assembly", "version": "1.0.0"},
	})
	var binding := AppearanceStyleBinding.new(intent.appearance_hash(), appearance_slots)
	assert(intent.validate().is_empty() and resolved.validate().is_empty() and
		binding.validate().is_empty(), "relay intent contracts must validate")
	var materials := {"stone": StyleCompiler.slot("body.stone"),
		"trim": StyleCompiler.slot("trim.gold"),
		"dark": StyleCompiler.slot("recess.dark"),
		"arcane": StyleCompiler.slot("effect.arcane")}
	var catalog := ComponentCatalog.new()
	catalog.register("relay.foundation", "1.0.0",
		_foundation(size, span, base_height, segments, materials))
	catalog.register("relay.column", "1.0.0", _column(size, column_height, materials),
		[{"id": "column_body", "center": Vector3(0.0, column_height * 0.5, 0.0),
			"radius": size * 0.07}], {"role": "support"})
	catalog.register("relay.lintel", "1.0.0", _lintel(size, span, materials), [],
		{"role": "bridge"})
	catalog.register("relay.core", "1.0.0", _core(size, materials, segments),
		[{"id": "core_glow", "center": Vector3(0.0, size * 0.34, 0.0),
			"radius": size * 0.13}], {"role": "energy_core"})
	var instances := [
		{"id": "foundation", "component_id": "relay.foundation",
			"fixed_transform": Transform3D.IDENTITY},
		{"id": "left_column", "component_id": "relay.column"},
		{"id": "right_column", "component_id": "relay.column"},
		{"id": "lintel", "component_id": "relay.lintel"},
		{"id": "core", "component_id": "relay.core"},
	]
	var connections := [
		{"id": "mount_left", "a": {"instance": "foundation", "socket": "left_support"},
			"b": {"instance": "left_column", "socket": "foot"}, "twist_degrees": 0.0},
		{"id": "mount_right", "a": {"instance": "foundation", "socket": "right_support"},
			"b": {"instance": "right_column", "socket": "foot"}, "twist_degrees": 0.0},
		{"id": "bridge_left", "a": {"instance": "left_column", "socket": "beam_mount"},
			"b": {"instance": "lintel", "socket": "left_end"}, "twist_degrees": 0.0},
		{"id": "bridge_right", "a": {"instance": "right_column", "socket": "beam_mount"},
			"b": {"instance": "lintel", "socket": "right_end"}, "twist_degrees": 0.0},
		{"id": "mount_core", "a": {"instance": "foundation", "socket": "core_mount"},
			"b": {"instance": "core", "socket": "foot"}, "twist_degrees": 0.0},
	]
	var base_plan := AssemblyPlan.new(resolved.content_hash(), catalog.content_hash(),
		"foundation", instances, connections)
	assert(base_plan.validate().is_empty(), "relay assembly plan must validate")
	var solver := RigidAssemblySolver.new(catalog)
	var proposal_patch := PlanPatch.new(base_plan.content_hash(),
		{"id": "arcane_relay.variant_proposal", "version": "1.0.0"}, [], [{
			"id": "try_quarter_turn", "kind": "set_connection_twist",
			"connection_id": "bridge_right", "twist_degrees": 90.0}], 0,
		"arcane_relay.variant_proposal.v1")
	var candidates := CandidateGenerator.generate(base_plan, [{
		"id": "quarter_turn_proposal", "patch": proposal_patch}])
	assert(candidates.ok, "; ".join(candidates.failures))
	var repair_registry := RepairRegistry.new()
	repair_registry.register(RigidTwistRepair.new(catalog))
	var repair_result := CandidateRepairStage.run(candidates, solver, repair_registry, 2)
	assert(repair_result.ok, "; ".join(repair_result.failures))
	var selection := CandidateSelector.select(catalog, repair_result.artifact, [
		{"metric": "repair_count", "direction": "min"},
		{"metric": "max_position_residual", "direction": "min"}])
	assert(selection.ok, "; ".join(selection.failures))
	var plan = selection.selected_plan
	var solve_result := solver.solve({"problem_type": "rigid.socket_assembly",
		"plan": plan.payload, "constraints": [
			{"kind": "rigid.socket_mate"}, {"kind": "rigid.clearance"}]})
	assert(solve_result.status == "solved", str(solve_result.diagnostics))
	var solution: Dictionary = solve_result.solution
	var solved := SolvedAssembly.new(plan.content_hash(), catalog.content_hash(),
		solution.instances, solution.transforms, solution.connections,
		solution.residuals, solution.clearance, solver.descriptor())
	assert(solved.validate().is_empty(), "relay solved assembly must validate")
	var compiled := AssemblyCompiler.compile(catalog, solved)
	assert(compiled.ok, "; ".join(compiled.failures))
	var asset = compiled.assembly
	var geometry_hash := GeometryFingerprint.assembly_hash(asset)
	var style_compilation := StyleCompiler.apply(asset, binding)
	assert(style_compilation.ok, "; ".join(style_compilation.failures))
	var stages := StageRunner.new("arcane_relay.bounded_repair_v1")
	stages.record("intent", "arcane_relay.intent.v1", {}, intent)
	stages.record("resolve_design", "arcane_relay.resolver.v1",
		{"construction_intent": intent.construction_hash()}, resolved)
	stages.record("propose_candidates", "polyforge.assembly_candidate_generator@1.0.0",
		{"resolved_design": resolved.content_hash(), "catalog": catalog.content_hash()},
		candidates.artifact)
	stages.record("repair_candidates", "polyforge.candidate_repair_stage@1.0.0",
		{"candidate_set": candidates.artifact.content_hash()}, repair_result.artifact)
	stages.record("select_candidate", "polyforge.candidate_selector@1.0.0",
		{"repair_report": repair_result.artifact.content_hash()}, selection.artifact)
	stages.record("plan_assembly", "arcane_relay.selected_plan.v1",
		{"candidate_selection": selection.artifact.content_hash()}, plan)
	stages.record("solve_rigid", "polyforge.rigid.socket_assembly@1.0.0",
		{"assembly_plan": plan.content_hash()}, solved, solve_result.diagnostics)
	stages.record("compile_geometry", "polyforge.solved_assembly_compiler.v1",
		{"solved_assembly": solved.content_hash()}, {"geometry_hash": geometry_hash,
			"parts": asset.parts.size()})
	stages.record("compile_appearance", "polyforge.style_slots.v1",
		{"appearance_intent": intent.appearance_hash(), "geometry": geometry_hash},
		style_compilation)
	return {
		"name": "arcane_relay",
		"category": "structure",
		"assembly": asset,
		"triangle_budget": 3200,
		"topology_budget": {"rendered_triangles": 3200, "unique_triangles": 2600},
		"quality_profile": "runtime",
		"require_surface_classification": true,
		"require_part_classification": true,
		"contracts": {
			"asset_intent": intent.to_canonical_dict(),
			"resolved_design": resolved.to_canonical_dict(),
			"component_catalog": catalog.snapshot(),
			"candidate_set": candidates.artifact.to_canonical_dict(),
			"candidate_repair_report": repair_result.artifact.to_canonical_dict(),
			"candidate_selection": selection.artifact.to_canonical_dict(),
			"assembly_plan": plan.to_canonical_dict(),
			"solved_assembly": solved.to_canonical_dict(),
			"appearance_binding": binding.to_canonical_dict(),
		},
		"process": stages.snapshot(),
		"style_compilation": CanonicalArtifact.canonicalize(style_compilation),
		"symmetry": [{"name": "paired relay columns", "first": "left_column",
			"second": "right_column", "axis": "x", "tolerance": size * 0.00001}],
		"checks": [
			Checks.require_axis_size("foundation__base", 0, size * 0.96, size * 0.02),
			Checks.require_axis_size("lintel__beam", 0, span + size * 0.18, size * 0.02),
			Checks.require_axis_range("core__crystal", 1, size * 0.18, size * 0.24),
		],
		"anchors": {"core": asset.socket("foundation/core_mount").origin,
			"left_support": asset.socket("foundation/left_support").origin,
			"right_support": asset.socket("foundation/right_support").origin},
		"readability": {"target_pixels": 72, "supersample": 2,
			"view_set": "octants", "minimum_regions": 3, "minimum_contrast": 0.04,
			"minimum_stroke_px": 1.0, "required": true,
			"critical_parts": {
				"foundation": {"members": asset.part_names_for_instance("foundation"),
					"minimum_visible_fraction": 0.20},
				"supports": {"members": asset.part_names_for_instance("left_column") +
					asset.part_names_for_instance("right_column"),
					"minimum_visible_fraction": 0.12},
				"lintel": {"members": asset.part_names_for_instance("lintel"),
					"minimum_visible_fraction": 0.18},
				"core": {"members": asset.part_names_for_instance("core"),
					"minimum_visible_fraction": 0.10},
			}},
		"front": "+Z",
		"metadata": {"description": "Typed-socket relay selected through bounded plan repair",
			"solver": solver.descriptor(), "catalog_hash": catalog.content_hash()},
	}
