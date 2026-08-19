extends SceneTree

const PolyMesh := preload("res://addons/polyforge/core/mesh.gd")
const SurfaceAttach := preload("res://addons/polyforge/core/surface_attach.gd")
const SurfaceDecal := preload("res://addons/polyforge/core/surface_decal.gd")
const Paint := preload("res://addons/polyforge/core/paint.gd")
const Assembly := preload("res://addons/polyforge/core/assembly.gd")
const Component := preload("res://addons/polyforge/core/component.gd")
const Attachments := preload("res://addons/polyforge/core/attachments.gd")
const Stock := preload("res://addons/polyforge/core/stock.gd")
const Parameters := preload("res://addons/polyforge/core/parameters.gd")
const AssetRecipe := preload("res://addons/polyforge/core/asset_recipe.gd")
const Lint := preload("res://addons/polyforge/quality/lint_core.gd")
const Checks := preload("res://addons/polyforge/quality/checks.gd")
const Readability := preload("res://addons/polyforge/quality/readability.gd")
const Symmetry := preload("res://addons/polyforge/quality/symmetry.gd")
const TopologyBudget := preload("res://addons/polyforge/core/topology_budget.gd")
const Rig := preload("res://addons/polyforge/core/rig.gd")
const AnimationClip := preload("res://addons/polyforge/core/animation.gd")
const RigValidation := preload("res://addons/polyforge/quality/rig_validation.gd")
const SurfaceTypes := preload("res://addons/polyforge/core/surface_types.gd")
const MechanicalConstraints := preload("res://addons/polyforge/core/mechanical_constraints.gd")
const Zone := preload("res://addons/polyforge/terrain/zone.gd")
const ViewerExport := preload("res://addons/polyforge/exporters/viewer_export.gd")
const GLTFExport := preload("res://addons/polyforge/exporters/gltf_export.gd")
const ManifestExport := preload("res://addons/polyforge/exporters/manifest_export.gd")
const PreviewExport := preload("res://addons/polyforge/exporters/preview_export.gd")
const BuildPipeline := preload("res://addons/polyforge/build/build_pipeline.gd")
const CanonicalArtifact := preload("res://addons/polyforge/core/canonical_artifact.gd")
const AssetIntent := preload("res://addons/polyforge/core/asset_intent.gd")
const ResolvedDesign := preload("res://addons/polyforge/core/resolved_design.gd")
const DesignBrief := preload("res://addons/polyforge/core/design_brief.gd")
const CohesionContract := preload("res://addons/polyforge/core/cohesion_contract.gd")
const PlausibilityContract := preload("res://addons/polyforge/core/plausibility_contract.gd")
const InterfacePlan := preload("res://addons/polyforge/core/interface_plan.gd")
const InterfaceCompilation := preload("res://addons/polyforge/core/interface_compilation.gd")
const SuspensionPlan := preload("res://addons/polyforge/core/suspension_plan.gd")
const SuspensionCompilation := preload("res://addons/polyforge/core/suspension_compilation.gd")
const AppearanceStyleBinding := preload("res://addons/polyforge/core/appearance_style_binding.gd")
const FourBarSolver := preload("res://addons/polyforge/core/four_bar_solver.gd")
const GeometryFingerprint := preload("res://addons/polyforge/core/geometry_fingerprint.gd")
const StageRunner := preload("res://addons/polyforge/build/stage_runner.gd")
const StyleCompiler := preload("res://addons/polyforge/build/style_compiler.gd")
const SocketContract := preload("res://addons/polyforge/core/socket_contract.gd")
const ComponentCatalog := preload("res://addons/polyforge/core/component_catalog.gd")
const AssemblyPlan := preload("res://addons/polyforge/core/assembly_plan.gd")
const SolvedAssembly := preload("res://addons/polyforge/core/solved_assembly.gd")
const RigidAssemblySolver := preload("res://addons/polyforge/core/rigid_assembly_solver.gd")
const AssemblyCompiler := preload("res://addons/polyforge/build/assembly_compiler.gd")
const SuspensionCompiler := preload("res://addons/polyforge/build/suspension_compiler.gd")
const PlanPatch := preload("res://addons/polyforge/core/plan_patch.gd")
const PlanPatchApplier := preload("res://addons/polyforge/build/plan_patch_applier.gd")
const CandidateGenerator := preload("res://addons/polyforge/build/assembly_candidate_generator.gd")
const AssemblyCandidateSet := preload("res://addons/polyforge/core/assembly_candidate_set.gd")
const RepairRegistry := preload("res://addons/polyforge/build/repair_registry.gd")
const RigidTwistRepair := preload("res://addons/polyforge/core/rigid_twist_repair.gd")
const CandidateRepairStage := preload("res://addons/polyforge/build/candidate_repair_stage.gd")
const CandidateRepairReport := preload("res://addons/polyforge/core/candidate_repair_report.gd")
const CandidateSelection := preload("res://addons/polyforge/core/candidate_selection.gd")
const CandidateSelector := preload("res://addons/polyforge/build/candidate_selector.gd")
const RigidSolutionValidation := preload("res://addons/polyforge/quality/rigid_solution_validation.gd")
const ProcessValidation := preload("res://addons/polyforge/quality/process_validation.gd")
const ReferenceValidation := preload("res://addons/polyforge/quality/reference_validation.gd")
const CohesionValidation := preload("res://addons/polyforge/quality/cohesion_validation.gd")
const MassHierarchyValidation := preload("res://addons/polyforge/quality/mass_hierarchy_validation.gd")
const SuspensionValidation := preload("res://addons/polyforge/quality/suspension_validation.gd")
const PlausibilityValidation := preload("res://addons/polyforge/quality/plausibility_validation.gd")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _material(name: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name
	material.vertex_color_use_as_albedo = true
	return material

func _rigid_socket(type: String, accepts: Array, twists := [0.0],
		cardinality := 1) -> Dictionary:
	return {"type": type, "accepts": PackedStringArray(accepts),
		"allowed_twist_degrees": PackedFloat32Array(twists),
		"cardinality": cardinality, "position_tolerance": 0.0001,
		"rotation_tolerance_degrees": 0.01, "clearance_radius": 0.1}

func _rigid_test_catalog(bridge_right := 1.0, bridge_type := "mate",
		with_clearance := false):
	var root := Component.new("test_root")
	root.define_typed_socket("left", Transform3D(Basis.IDENTITY, Vector3(-1.0, 0.0, 0.0)),
		_rigid_socket("mount", ["mate"]))
	root.define_typed_socket("right", Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 0.0)),
		_rigid_socket("mount", ["mate"]))
	var bridge := Component.new("test_bridge")
	bridge.define_typed_socket("left", Transform3D(Basis.IDENTITY, Vector3(-1.0, 0.0, 0.0)),
		_rigid_socket(bridge_type, ["mount"]))
	bridge.define_typed_socket("right", Transform3D(Basis.IDENTITY,
		Vector3(bridge_right, 0.0, 0.0)), _rigid_socket(bridge_type, ["mount"]))
	var catalog := ComponentCatalog.new()
	catalog.register("test.root", "1.0.0", root)
	var clearances := []
	if with_clearance:
		clearances = [{"id": "bridge_body", "center": Vector3.ZERO, "radius": 0.5}]
	catalog.register("test.bridge", "1.0.0", bridge, clearances)
	return catalog

func _rigid_test_plan(catalog, connections: Array, instances := [], keepouts := []):
	if instances.is_empty():
		instances = [
			{"id": "root", "component_id": "test.root",
				"fixed_transform": Transform3D.IDENTITY},
			{"id": "bridge", "component_id": "test.bridge"},
		]
	return AssemblyPlan.new("test_design_hash", catalog.content_hash(), "root",
		instances, connections, keepouts)

func _has_diagnostic(result: Dictionary, code: String) -> bool:
	for diagnostic in result.get("diagnostics", []):
		if str(diagnostic.get("code", "")) == code:
			return true
	return false

func _has_prefix(messages, prefix: String) -> bool:
	for message in messages:
		if str(message).begins_with(prefix):
			return true
	return false

func _candidate(report, id: String) -> Dictionary:
	for candidate in report.payload.candidates:
		if str(candidate.id) == id:
			return candidate
	return {}

func _ellipsoid_surface_z(center: Vector3, radii: Vector3, point: Vector2) -> float:
	var nx := (point.x - center.x) / radii.x
	var ny := (point.y - center.y) / radii.y
	var radial := nx * nx + ny * ny
	if radial >= 1.0:
		return -INF
	return center.z + radii.z * sqrt(maxf(0.0, 1.0 - radial))

func _mesh_clears_ellipsoid(mesh: ArrayMesh, center: Vector3, radii: Vector3,
		tolerance := 0.00001) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in range(0, indices.size(), 3):
		var a := vertices[indices[index]]
		var b := vertices[indices[index + 1]]
		var c := vertices[indices[index + 2]]
		var samples := [(a + b) * 0.5, (b + c) * 0.5, (c + a) * 0.5,
			(a + b + c) / 3.0]
		for sample in samples:
			var surface_z := _ellipsoid_surface_z(center, radii,
				Vector2(sample.x, sample.y))
			if sample.z + tolerance < surface_z:
				return false
	return true

func _mesh_has_degenerate_triangles(mesh: ArrayMesh,
		tolerance := 0.000000000001) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in range(0, indices.size(), 3):
		var a := vertices[indices[index]]
		var b := vertices[indices[index + 1]]
		var c := vertices[indices[index + 2]]
		if (c - a).cross(b - a).length_squared() <= tolerance:
			return true
	return false

func _mesh_normals_follow_geometry(mesh: ArrayMesh) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var expected := PackedVector3Array()
	expected.resize(vertices.size())
	for index in range(0, indices.size(), 3):
		var a_index := indices[index]
		var b_index := indices[index + 1]
		var c_index := indices[index + 2]
		var face_normal := (vertices[c_index] - vertices[a_index]).cross(
			vertices[b_index] - vertices[a_index])
		expected[a_index] = expected[a_index] + face_normal
		expected[b_index] = expected[b_index] + face_normal
		expected[c_index] = expected[c_index] + face_normal
	for index in range(normals.size()):
		if expected[index].length_squared() <= 0.000000000001 or \
				normals[index].dot(expected[index].normalized()) < 0.9999:
			return false
	return true

func _initialize() -> void:
	var decal_material := Stock.material("decal_test", Color.BLACK)
	var decal_center := Vector3.ZERO
	var decal_radii := Vector3(2.0, 1.5, 1.0)
	var decal := SurfaceDecal.ellipsoid_capsule(decal_center, decal_radii,
		Vector2(0.35, 0.2), 0.7, 0.12, 28.0, decal_material, 0.001, 5)
	var repeated_decal := SurfaceDecal.ellipsoid_capsule(decal_center, decal_radii,
		Vector2(0.35, 0.2), 0.7, 0.12, 28.0, decal_material, 0.001, 5)
	check(decal.get_surface_count() == 1 and Lint.triangle_count(decal) > 10 and
		Lint.triangle_count(decal) == Lint.triangle_count(repeated_decal),
		"surface decal adaptively emits deterministic conformed topology")
	check(_mesh_clears_ellipsoid(decal, decal_center, decal_radii),
		"surface decal triangle interiors clear the host ellipsoid")
	check(_mesh_normals_follow_geometry(decal),
		"surface decal normals follow the generated geometry")

	var circular_patch := SurfaceDecal.ellipsoid_capsule_patch(decal_center,
		decal_radii, Vector2(-0.35, -0.2), 0.3, 0.3, 0.0, decal_material,
		0.01, 0.001, 3, 6)
	check(not _mesh_has_degenerate_triangles(circular_patch),
		"equal capsule dimensions emit a circle without duplicate vertices")

	var eye_patch := SurfaceDecal.ellipsoid_ellipse_patch(decal_center,
		decal_radii, Vector2(0.35, 0.2), Vector2(0.6, 0.28),
		-8.0, decal_material, 0.025, 0.001, 3, 12)
	check(eye_patch.get_surface_count() == 1 and Lint.triangle_count(eye_patch) == 60,
		"feathered patch emits deterministic concentric topology")
	var patch_arrays := eye_patch.surface_get_arrays(0)
	var patch_vertices: PackedVector3Array = patch_arrays[Mesh.ARRAY_VERTEX]
	var center_xy := Vector2(0.35, 0.2)
	var center_base := Vector3(center_xy.x, center_xy.y,
		_ellipsoid_surface_z(decal_center, decal_radii, center_xy))
	var center_host_normal := Vector3(center_base.x / 4.0,
		center_base.y / 2.25, center_base.z).normalized()
	var expected_center := center_base + center_host_normal * 0.026
	var edge_angle := TAU * 11.0 / 12.0
	var edge_xy := center_xy + Vector2(cos(edge_angle) * 0.3,
		sin(edge_angle) * 0.14).rotated(deg_to_rad(-8.0))
	var edge_base := Vector3(edge_xy.x, edge_xy.y,
		_ellipsoid_surface_z(decal_center, decal_radii, edge_xy))
	var edge_host_normal := Vector3(edge_base.x / 4.0,
		edge_base.y / 2.25, edge_base.z).normalized()
	var expected_edge := edge_base + edge_host_normal * 0.001
	var edge_index := patch_vertices.size() - 1
	check(patch_vertices[0].distance_to(expected_center) < 0.00001 and
		patch_vertices[edge_index].distance_to(expected_edge) < 0.00001,
		"feathered patch center height and flush rim derive from the same ellipsoid")
	check(_mesh_normals_follow_geometry(eye_patch),
		"feathered patch normals follow the embossed geometry")

	var intent_a := AssetIntent.new({"size": 2.0, "kind": "prop"},
		{"palette": "warm"}, [{"id": "reference", "sha256": "abc"}])
	var intent_b := AssetIntent.new({"kind": "prop", "size": 2.0},
		{"palette": "cool"}, [{"id": "reference", "sha256": "abc"}])
	check(intent_a.construction_hash() == intent_b.construction_hash() and
		intent_a.appearance_hash() != intent_b.appearance_hash(),
		"appearance intent changes do not invalidate construction intent")
	var intent_round_trip = AssetIntent.from_canonical_dict(intent_a.to_canonical_dict())
	check(intent_round_trip.content_hash() == intent_a.content_hash() and
		intent_round_trip.to_canonical_dict() == intent_a.to_canonical_dict(),
		"typed intent round-trips losslessly through the canonical dictionary wire format")
	var resolved_a := ResolvedDesign.new(intent_a.construction_hash(),
		{"units": "meters", "size": 2.0})
	var resolved_b := ResolvedDesign.new(intent_b.construction_hash(),
		{"size": 2.0, "units": "meters"})
	check(resolved_a.content_hash() == resolved_b.content_hash(),
		"canonical hashing is stable across dictionary insertion order")
	var brief := DesignBrief.new(intent_a.content_hash(), {"archetype": "test machine"}, [
		{"id": "primary", "tier": "primary"},
		{"id": "secondary", "tier": "secondary"},
		{"id": "tertiary", "tier": "tertiary"},
	], ["one readable core"], ["shared junction profile"])
	var cohesion_contract := CohesionContract.new(brief.content_hash(),
		["root", "bridge"], ["left_closure"], {"profile_id": "test.band.v1",
			"allowed_families": ["rigid.box_collar"]}, [
			{"id": "primary", "tier": "primary", "minimum_share": 0.55,
				"target_share": 0.65, "maximum_share": 0.80},
			{"id": "secondary", "tier": "secondary", "minimum_share": 0.15,
				"target_share": 0.25, "maximum_share": 0.35},
			{"id": "tertiary", "tier": "tertiary", "minimum_share": 0.04,
				"target_share": 0.10, "maximum_share": 0.15},
		], [{"higher": "primary", "lower": "secondary", "minimum_ratio": 2.0},
			{"higher": "secondary", "lower": "tertiary", "minimum_ratio": 1.5}], true)
	check(brief.validate().is_empty() and cohesion_contract.validate().is_empty() and
		DesignBrief.from_canonical_dict(brief.to_canonical_dict()).content_hash() ==
			brief.content_hash() and CohesionContract.from_canonical_dict(
			cohesion_contract.to_canonical_dict()).content_hash() ==
			cohesion_contract.content_hash(),
		"design and cohesion contracts round-trip as immutable canonical artifacts")
	var plausibility_contract := PlausibilityContract.new(brief.content_hash(),
		"test_suspension", [{"id": "source", "role": "support",
			"support_source": true}, {"id": "payload", "role": "mass",
				"requires_support": true}], [{"id": "support_edge", "from": "payload",
				"to": "source", "kind": "hangs_from", "basis": "functional_inference",
				"authority": "required", "evidence": {"suspension_members": ["cable"],
					"require_terminations": true}}])
	check(plausibility_contract.validate().is_empty() and
		PlausibilityContract.from_canonical_dict(
			plausibility_contract.to_canonical_dict()).content_hash() ==
			plausibility_contract.content_hash(),
		"causal plausibility contracts round-trip without promoting hypotheses")
	var invalid_hypothesis := PlausibilityContract.new(brief.content_hash(), "test", [
		{"id": "source", "role": "support", "support_source": true}], [{
			"id": "invented_wrap", "from": "source", "to": "source",
			"kind": "decorates", "basis": "stylistic_hypothesis",
			"authority": "required", "evidence": {}}])
	check(not invalid_hypothesis.validate().is_empty(),
		"stylistic hypotheses cannot silently become required realism constraints")
	var invalid_binding := AppearanceStyleBinding.new(intent_a.appearance_hash(), {
		"body": {"affects_geometry": true, "color": Color.WHITE}})
	check(not invalid_binding.validate().is_empty(),
		"appearance contracts reject geometry-affecting capabilities")
	var solver_contract := FourBarSolver.new()
	var unsupported := solver_contract.solve({"problem_type": "deform.character"})
	check(unsupported.status == "unsupported" and
		unsupported.diagnostics[0].code == "SOLVER_UNSUPPORTED_PROBLEM",
		"specialized solvers fail closed on unsupported problem domains")
	var solver_problem := {"problem_type": "mechanism.four_bar", "parameters": {
		"crank_center": Vector2.ZERO, "beam_pivot": Vector2(2.0, 1.6),
		"crank_radius": 0.45, "beam_rear_length": 1.6, "beam_front_length": 2.2,
		"pitman_length": 2.0, "branch_sign": 1.0}, "constraints": [
		{"kind": "mechanism.loop_closure"}]}
	var solved_a := solver_contract.solve(solver_problem, {"samples": 32})
	var solved_b := solver_contract.solve(solver_problem, {"samples": 32})
	check(solved_a.status == "solved" and CanonicalArtifact.hash_value(solved_a.solution) ==
		CanonicalArtifact.hash_value(solved_b.solution),
		"four-bar solver stage produces deterministic independently hashable evidence")
	var rigid_connections := [
		{"id": "left_closure", "a": {"instance": "root", "socket": "left"},
			"b": {"instance": "bridge", "socket": "left"}, "twist_degrees": 0.0},
		{"id": "right_closure", "a": {"instance": "root", "socket": "right"},
			"b": {"instance": "bridge", "socket": "right"}, "twist_degrees": 0.0},
	]
	check(SocketContract.validate(_rigid_socket("mount", ["mate"])).is_empty() and
		not SocketContract.validate(_rigid_socket("mount", ["mate"], [], 0)).is_empty(),
		"typed socket schema rejects empty orientation sets and invalid cardinality")
	var rigid_catalog = _rigid_test_catalog()
	var rigid_plan = _rigid_test_plan(rigid_catalog, rigid_connections)
	var rigid_solver := RigidAssemblySolver.new(rigid_catalog)
	var rigid_solved_a := rigid_solver.solve({"problem_type": "rigid.socket_assembly",
		"plan": rigid_plan.payload, "constraints": [{"kind": "rigid.socket_mate"}]})
	var rigid_solved_b := rigid_solver.solve({"problem_type": "rigid.socket_assembly",
		"plan": rigid_plan.payload, "constraints": [{"kind": "rigid.socket_mate"}]})
	check(rigid_solved_a.status == "solved" and
		CanonicalArtifact.hash_value(rigid_solved_a.solution) ==
		CanonicalArtifact.hash_value(rigid_solved_b.solution) and
		rigid_solved_a.solution.residuals[1].ok,
		"rigid socket solver deterministically closes a multiply constrained assembly")
	var rigid_artifact := SolvedAssembly.new(rigid_plan.content_hash(),
		rigid_catalog.content_hash(), rigid_solved_a.solution.instances,
		rigid_solved_a.solution.transforms, rigid_solved_a.solution.connections,
		rigid_solved_a.solution.residuals, rigid_solved_a.solution.clearance,
		rigid_solver.descriptor())
	check(rigid_artifact.validate().is_empty() and
		AssemblyCompiler.compile(rigid_catalog, rigid_artifact).ok,
		"geometry compiler accepts a validated solved assembly artifact")
	var solved_round_trip = SolvedAssembly.from_canonical_dict(
		rigid_artifact.to_canonical_dict())
	check(solved_round_trip.to_canonical_dict() == rigid_artifact.to_canonical_dict(),
		"solved assemblies round-trip typed transforms through the canonical wire format")
	check(not AssemblyCompiler.compile(rigid_catalog, rigid_plan).ok and
		AssemblyCompiler.compile(rigid_catalog, rigid_plan).failures[0] ==
		"GEOMETRY_REQUIRES_SOLVED_ASSEMBLY",
		"geometry ownership boundary rejects an unsolved assembly plan")
	var rigid_geometry = AssemblyCompiler.compile(rigid_catalog, rigid_artifact).assembly
	var suspension_plan := SuspensionPlan.new(rigid_artifact.content_hash(),
		GeometryFingerprint.assembly_hash(rigid_geometry), [{"id": "test_cable",
			"a": {"instance": "root", "socket": "left"},
			"b": {"instance": "root", "socket": "right"}, "radius": 0.02,
			"minimum_length": 1.9, "maximum_length": 2.1,
			"material_slot": "test.rope", "profile_id": "test.cable.v1"}])
	var suspension_result := SuspensionCompiler.compile(rigid_catalog, rigid_artifact,
		rigid_geometry, suspension_plan)
	check(suspension_result.ok and suspension_result.artifact.payload.members.size() == 1 and
		SuspensionPlan.from_canonical_dict(suspension_plan.to_canonical_dict()).content_hash() ==
			suspension_plan.content_hash() and SuspensionCompilation.from_canonical_dict(
			suspension_result.artifact.to_canonical_dict()).content_hash() ==
			suspension_result.artifact.content_hash(),
		"suspension plans compile deterministically and round-trip their evidence")
	var missing_socket_plan := SuspensionPlan.new(rigid_artifact.content_hash(),
		GeometryFingerprint.assembly_hash(rigid_geometry), [{"id": "bad_cable",
			"a": {"instance": "root", "socket": "missing"},
			"b": {"instance": "root", "socket": "right"}, "radius": 0.02,
			"minimum_length": 0.1, "maximum_length": 3.0,
			"material_slot": "test.rope", "profile_id": "test.cable.v1"}])
	var missing_socket_result := SuspensionCompiler.compile(rigid_catalog, rigid_artifact,
		rigid_geometry, missing_socket_plan)
	check(not missing_socket_result.ok and _has_prefix(missing_socket_result.failures,
		"SUSPENSION_UNKNOWN_ENDPOINT"),
		"suspension compilation fails closed on an unknown solved socket")
	var rigid_unsupported := rigid_solver.solve({"problem_type": "deform.character"})
	check(rigid_unsupported.status == "unsupported" and
		_has_diagnostic(rigid_unsupported, "SOLVER_UNSUPPORTED_PROBLEM"),
		"rigid solver fails closed instead of impersonating another domain solver")
	var bad_loop_catalog = _rigid_test_catalog(1.25)
	var bad_loop := RigidAssemblySolver.new(bad_loop_catalog).solve({
		"problem_type": "rigid.socket_assembly",
		"plan": _rigid_test_plan(bad_loop_catalog, rigid_connections).payload,
		"constraints": [{"kind": "rigid.socket_mate"}]})
	check(bad_loop.status == "unsatisfiable" and
		_has_diagnostic(bad_loop, "RIGID_LOOP_INCONSISTENT"),
		"rigid solver reports an over-constrained loop with a precise diagnostic")
	var mismatch_catalog = _rigid_test_catalog(1.0, "wrong_mate")
	var mismatch := RigidAssemblySolver.new(mismatch_catalog).solve({
		"problem_type": "rigid.socket_assembly",
		"plan": _rigid_test_plan(mismatch_catalog, [rigid_connections[0]]).payload,
		"constraints": [{"kind": "rigid.socket_mate"}]})
	check(mismatch.status == "unsatisfiable" and
		_has_diagnostic(mismatch, "RIGID_SOCKET_TYPE_MISMATCH"),
		"typed sockets reject semantically incompatible component interfaces")
	var bad_twist_connections := rigid_connections.duplicate(true)
	bad_twist_connections[0].twist_degrees = 90.0
	var bad_twist := rigid_solver.solve({"problem_type": "rigid.socket_assembly",
		"plan": _rigid_test_plan(rigid_catalog, bad_twist_connections).payload,
		"constraints": [{"kind": "rigid.socket_mate"}]})
	check(bad_twist.status == "unsatisfiable" and
		_has_diagnostic(bad_twist, "RIGID_ORIENTATION_UNSUPPORTED"),
		"typed sockets reject an orientation outside the declared twist set")
	var overbooked_connections := [rigid_connections[0], {
		"id": "duplicate_mount", "a": {"instance": "root", "socket": "left"},
		"b": {"instance": "bridge_2", "socket": "left"}, "twist_degrees": 0.0}]
	var overbooked := rigid_solver.solve({"problem_type": "rigid.socket_assembly",
		"plan": _rigid_test_plan(rigid_catalog, overbooked_connections, [
			{"id": "root", "component_id": "test.root",
				"fixed_transform": Transform3D.IDENTITY},
			{"id": "bridge", "component_id": "test.bridge"},
			{"id": "bridge_2", "component_id": "test.bridge"}]).payload,
		"constraints": [{"kind": "rigid.socket_mate"}]})
	check(overbooked.status == "unsatisfiable" and
		_has_diagnostic(overbooked, "RIGID_SOCKET_CARDINALITY_EXCEEDED"),
		"typed sockets reject connection counts above their declared cardinality")
	var disconnected := rigid_solver.solve({"problem_type": "rigid.socket_assembly",
		"plan": _rigid_test_plan(rigid_catalog, [], [
			{"id": "root", "component_id": "test.root",
				"fixed_transform": Transform3D.IDENTITY},
			{"id": "bridge", "component_id": "test.bridge"}]).payload,
		"constraints": [{"kind": "rigid.socket_mate"}]})
	check(disconnected.status == "unsatisfiable" and
		_has_diagnostic(disconnected, "RIGID_DISCONNECTED_GRAPH"),
		"rigid solver rejects instances unreachable from a fixed root")
	var clearance_catalog = _rigid_test_catalog(1.0, "mate", true)
	var blocked := RigidAssemblySolver.new(clearance_catalog).solve({
		"problem_type": "rigid.socket_assembly",
		"plan": _rigid_test_plan(clearance_catalog, [rigid_connections[0]], [], [
			{"id": "reserved_space", "center": Vector3.ZERO, "radius": 0.25}]).payload,
		"constraints": [{"kind": "rigid.socket_mate"}, {"kind": "rigid.clearance"}]})
	check(blocked.status == "unsatisfiable" and
		_has_diagnostic(blocked, "RIGID_CLEARANCE_BLOCKED"),
		"rigid solver rejects a solved placement that violates an explicit keepout")
	var plan_round_trip = AssemblyPlan.from_canonical_dict(rigid_plan.to_canonical_dict())
	check(plan_round_trip.validate().is_empty() and
		plan_round_trip.to_canonical_dict() == rigid_plan.to_canonical_dict(),
		"assembly plans round-trip typed transforms through the canonical wire format")
	var bad_twist_patch := PlanPatch.new(rigid_plan.content_hash(),
		{"id": "test.proposal", "version": "1.0.0"}, [], [{
			"id": "rotate_left", "kind": "set_connection_twist",
			"connection_id": "left_closure", "twist_degrees": 90.0}])
	var original_plan_hash := rigid_plan.content_hash()
	var patched := PlanPatchApplier.apply(rigid_plan, bad_twist_patch)
	check(patched.ok and rigid_plan.content_hash() == original_plan_hash and
		float(patched.plan.payload.connections[0].twist_degrees) == 90.0,
		"plan patches create a new plan without mutating their source artifact")
	var locked_plan := AssemblyPlan.new("test_design_hash", rigid_catalog.content_hash(),
		"root", rigid_plan.payload.instances, rigid_plan.payload.connections, [],
		"test.locked_plan.v1", ["connection:left_closure.twist_degrees"])
	var locked_patch := PlanPatch.new(locked_plan.content_hash(),
		{"id": "test.proposal", "version": "1.0.0"}, [], [{
			"id": "rotate_locked", "kind": "set_connection_twist",
			"connection_id": "left_closure", "twist_degrees": 90.0}])
	var locked_result := PlanPatchApplier.apply(locked_plan, locked_patch)
	check(not locked_result.ok and locked_result.diagnostics[0].code ==
		"PATCH_TARGET_LOCKED",
		"plan patches cannot modify author-locked relationships")
	var locked_round_trip = AssemblyPlan.from_canonical_dict(locked_plan.to_canonical_dict())
	check(locked_round_trip.to_canonical_dict() == locked_plan.to_canonical_dict(),
		"assembly plan locks remain stable across canonical serialization")
	var candidate_generation := CandidateGenerator.generate(rigid_plan, [{
		"id": "bad_twist", "patch": bad_twist_patch}])
	var repair_registry := RepairRegistry.new()
	repair_registry.register(RigidTwistRepair.new(rigid_catalog))
	var repair_a := CandidateRepairStage.run(candidate_generation, rigid_solver,
		repair_registry, 1)
	var repair_b := CandidateRepairStage.run(candidate_generation, rigid_solver,
		repair_registry, 1)
	check(repair_a.ok and repair_a.artifact.content_hash() ==
		repair_b.artifact.content_hash() and
		_candidate(repair_a.artifact, "bad_twist").status == "solved" and
		_candidate(repair_a.artifact, "bad_twist").repair_count == 1,
		"bounded repair deterministically converts a supported diagnostic into one patch")
	var candidate_set_round_trip = AssemblyCandidateSet.from_canonical_dict(
		candidate_generation.artifact.to_canonical_dict())
	var repair_round_trip = CandidateRepairReport.from_canonical_dict(
		repair_a.artifact.to_canonical_dict())
	check(candidate_set_round_trip.to_canonical_dict() ==
		candidate_generation.artifact.to_canonical_dict() and
		repair_round_trip.to_canonical_dict() == repair_a.artifact.to_canonical_dict(),
		"candidate and repair artifacts have one lossless canonical wire representation")
	var repair_exhausted := repair_registry.propose(rigid_plan,
		[{"code": "RIGID_SOCKET_TYPE_MISMATCH", "entities": ["left_closure"]}], 1)
	check(not repair_exhausted.ok and repair_exhausted.diagnostics[0].code ==
		"REPAIR_EXHAUSTED",
		"repair registry refuses diagnostics outside registered capabilities")
	var no_attempts := CandidateRepairStage.run(candidate_generation, rigid_solver,
		repair_registry, 0)
	check(no_attempts.ok and _candidate(no_attempts.artifact, "bad_twist").status ==
		"rejected" and _candidate(no_attempts.artifact, "bad_twist").repair_count == 0,
		"repair loop honors its attempt budget without hidden retries")
	var selection := CandidateSelector.select(rigid_catalog, repair_a.artifact)
	check(selection.ok and selection.artifact.payload.selected_candidate_id == "baseline" and
		selection.artifact.payload.eligible.size() == 2,
		"hard-valid candidates are ranked by explicit objectives after validation")
	var selection_round_trip = CandidateSelection.from_canonical_dict(
		selection.artifact.to_canonical_dict())
	check(selection_round_trip.to_canonical_dict() == selection.artifact.to_canonical_dict(),
		"candidate selection evidence round-trips losslessly")
	var invalid_objective := CandidateSelector.select(rigid_catalog, repair_a.artifact,
		[{"metric": "opaque_ai_score", "direction": "max"}])
	check(not invalid_objective.ok and invalid_objective.failures[0] ==
		"CANDIDATE_OBJECTIVE_UNSUPPORTED",
		"candidate policy rejects undeclared soft metrics instead of ranking opaquely")
	var forged_solution: Dictionary = rigid_solved_a.solution.duplicate(true)
	forged_solution.transforms.bridge = Transform3D(Basis.IDENTITY,
		Vector3(0.5, 0.0, 0.0))
	var forged_report := CandidateRepairReport.new("forged_candidate_set_hash", [{
		"id": "forged", "status": "solved", "plan": rigid_plan.to_canonical_dict(),
		"initial_plan_hash": rigid_plan.content_hash(),
		"plan_hash": rigid_plan.content_hash(), "solution": forged_solution,
		"solve_diagnostics": [], "repair_history": [], "repair_count": 0,
		"attempts": 0}], 0)
	var plan_before_validation := rigid_plan.content_hash()
	var forged_selection := CandidateSelector.select(rigid_catalog, forged_report)
	check(not forged_selection.ok and forged_selection.rejected[0].reason ==
		"hard_validation_failed" and rigid_plan.content_hash() == plan_before_validation,
		"selector independently rejects forged solver success without mutating the plan")
	var independent_validation := RigidSolutionValidation.evaluate(rigid_catalog,
		rigid_plan, rigid_solved_a.solution)
	var connection_measurements: Array = independent_validation.measurements.filter(
		func(item): return item.kind == "socket_residual")
	check(independent_validation.ok and connection_measurements.size() ==
		rigid_connections.size(),
		"independent validator recomputes every rigid connection from authoritative transforms")
	var translated_solution: Dictionary = rigid_solved_a.solution.duplicate(true)
	for instance_id in translated_solution.transforms:
		var transform: Transform3D = translated_solution.transforms[instance_id]
		translated_solution.transforms[instance_id] = Transform3D(transform.basis,
			transform.origin + Vector3(2.0, 0.0, 0.0))
	var translated_validation := RigidSolutionValidation.evaluate(rigid_catalog,
		rigid_plan, translated_solution)
	check(not translated_validation.ok and _has_diagnostic(translated_validation,
		"VALIDATION_FIXED_TRANSFORM_CHANGED"),
		"independent validator pins the root even when all relative connections still close")
	var stage_runner := StageRunner.new("contract_test")
	stage_runner.record("intent", "test.intent.v1", {}, intent_a)
	stage_runner.record("resolve", "test.resolve.v1",
		{"construction": intent_a.construction_hash()}, resolved_a)
	var stage_snapshot_a := stage_runner.snapshot()
	var stage_snapshot_b := stage_runner.snapshot()
	check(stage_snapshot_a.pipeline_hash == stage_snapshot_b.pipeline_hash and
		stage_snapshot_a.stages.size() == 2,
		"stage runner records a deterministic immutable dependency ledger")
	var style_asset := Assembly.new()
	style_asset.add("body", Stock.with_material(Stock.box(Vector3.ONE),
		StyleCompiler.slot("body.primary")))
	var style_geometry_hash := GeometryFingerprint.assembly_hash(style_asset)
	var style_binding := AppearanceStyleBinding.new(intent_a.appearance_hash(), {
		"body.primary": {"affects_geometry": false, "color": Color("aa7744"),
			"metallic": 0.4, "roughness": 0.7}})
	var style_result := StyleCompiler.apply(style_asset, style_binding)
	check(style_result.ok and style_result.geometry_hash_before == style_geometry_hash and
		style_result.geometry_hash_after == style_geometry_hash,
		"appearance compiler binds slots without changing the geometry fingerprint")

	var preview_quality := TopologyBudget.profile("preview")
	var runtime_quality := TopologyBudget.profile("runtime")
	var hero_quality := TopologyBudget.profile("hero")
	var preview_segments := TopologyBudget.radial_segments(40.0, preview_quality)
	var runtime_segments := TopologyBudget.radial_segments(40.0, runtime_quality)
	var hero_segments := TopologyBudget.radial_segments(40.0, hero_quality)
	check(preview_segments <= runtime_segments and runtime_segments <= hero_segments,
		"adaptive radial detail is deterministic and monotonic across quality profiles")
	check(TopologyBudget.sweep_subdivisions([
		Vector3.ZERO, Vector3.RIGHT, Vector3(1.0, 1.0, 0.0)], runtime_quality) >= 2,
		"adaptive sweep detail accounts for authored bend curvature")
	var extended_surface := SurfaceTypes.classify("profile", "primary_silhouette",
		"paired", "rigid", {"maximum_thickness_ratio": 0.2})
	check(SurfaceTypes.validate_extended(extended_surface).is_empty(),
		"part classification keeps construction, role, repetition, and motion orthogonal")
	var linkage := MechanicalConstraints.solve_four_bar({
		"crank_center": Vector2(0.0, 0.0), "beam_pivot": Vector2(2.0, 1.6),
		"crank_radius": 0.45, "beam_rear_length": 1.6, "beam_front_length": 2.2,
		"pitman_length": 2.0, "branch_sign": 1.0,
	}, 64)
	check(linkage.ok and linkage.samples.size() == 65 and
		linkage.maximum_fixed_length_error < 0.00001 and linkage.loop_closure_error < 0.00001,
		"constraint-baked four-bar motion stays connected and closes its loop")
	var clearance := MechanicalConstraints.validate_clearance(linkage, [{
		"name": "pitman", "start": "crank_pin", "end": "beam_rear_pin",
		"radius": 0.05,
	}], [{"name": "remote housing", "center": Vector3(0.0, 0.0, 3.0),
		"radius": 0.5}], 0.1)
	check(clearance.ok and clearance.minimum_clearance > clearance.required_clearance,
		"baked motion clearance checks moving links against static keepouts")

	var poly = PolyMesh.lathe([
		Vector2(0.0, -1.0), Vector2(0.8, -0.7), Vector2(1.0, 0.2), Vector2(0.0, 1.0)],
		12, 0.0, 7)
	check(Lint.check_polymesh(poly, 1000, true).is_empty(), "closed lathe passes structural lint")

	var alpha_before: float = poly.face_colors[0].a
	Paint.apply(poly, [Paint.height_gradient(Color("332211"), Color("ccbbaa"), -1.0, 1.0),
		Paint.noise(0.5, 0.08)], 9)
	check(is_equal_approx(poly.face_colors[0].a, alpha_before), "paint preserves COLOR.a")

	var emitted: Dictionary = poly.to_meshes()
	var mesh: ArrayMesh = emitted[""]
	check(Lint.check_mesh(mesh, 1000).is_empty(), "emitted mesh passes lint")
	check(Lint.check_determinism(mesh, poly.to_meshes()[""]).is_empty(), "mesh emission is deterministic")

	var hit := SurfaceAttach.closest_point(mesh, Vector3(2.0, 0.0, 0.0))
	check(hit.valid and hit.distance < 2.0, "surface attachment finds nearest triangle")
	var frame := SurfaceAttach.frame_from_hit(hit, 0.02)
	check(frame.basis.y.dot(hit.normal) > 0.999, "attachment frame follows surface normal")

	var mount_asset := Assembly.new()
	var mount_host := Stock.with_material(Stock.box(Vector3.ONE), _material("mount_host"))
	mount_asset.add("host", mount_host)
	var mounts := Attachments.new(mount_asset)
	var mount_frame := mounts.surface("top_socket", "host", Vector3(0, 1.0, 0), {
		"child": "marker", "max_hint_distance": 0.6, "position_tolerance": 0.0001})
	mount_asset.add("marker", Stock.with_material(
		Stock.box(Vector3(0.1, 0.1, 0.1)), _material("marker")), mount_frame)
	var mount_validation := Attachments.validate(mount_asset, mounts.snapshot())
	check(mount_validation.ok and mount_validation.measurements[0].child_distance < 0.0001,
		"geometry-sampled attachment remains bound to its emitted host surface")

	var readability_image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	readability_image.fill(Color("d9dde3"))
	readability_image.fill_rect(Rect2i(18, 10, 28, 44), Color("38312d"))
	readability_image.fill_rect(Rect2i(26, 18, 12, 18), Color("d0a15c"))
	var readability := Readability.analyze(readability_image, {
		"supersample": 1, "minimum_regions": 2,
		"minimum_contrast": 0.05, "minimum_stroke_px": 2.0})
	check(readability.ok and readability.regions >= 2 and readability.stroke_px >= 2.0,
		"play-size image analysis measures color regions, contrast, and feature thickness")
	check(Readability.view_angles("octants").size() == 8 and
		Readability.view_angles("cardinal") == [0.0, 90.0, 180.0, 270.0],
		"view policies select deterministic cardinal and octant camera sets")
	check(Readability.view_is_required({"members": ["rail_a", "rail_b"],
		"views": [45.0, 225.0]}, 225.0),
		"semantic visibility rules can bind a logical part to a named mesh group")
	var multiview := Readability.aggregate_views([
		{"yaw": 0.0, "readability": readability, "issues": PackedStringArray()},
		{"yaw": 180.0, "readability": readability, "issues": PackedStringArray([
			"critical part linkage visibility 0.2 is below 0.35"])},
	], {"view_set": "cardinal"})
	check(not multiview.ok and multiview.worst_view == 0.0 and
		str(multiview.issues[0]).begins_with("view 180°"),
		"multi-view aggregation preserves angle-qualified semantic failures")
	var id_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	id_image.set_pixel(0, 0, Color(0.0, 0.62, 0.0, 1.0))
	check(PreviewExport._count_color(id_image, Color.LIME) == 1,
		"visibility ID masks compare chroma independently of tone-mapped luminance")
	var studio_host := SubViewport.new()
	root.add_child(studio_host)
	PreviewExport._add_studio(studio_host, Node3D.new())
	var studio_env: Environment
	var studio_key: DirectionalLight3D
	var studio_fill: DirectionalLight3D
	for child in studio_host.get_children():
		if child is WorldEnvironment:
			studio_env = (child as WorldEnvironment).environment
		elif child is DirectionalLight3D and str(child.name) == "key":
			studio_key = child
		elif child is DirectionalLight3D and str(child.name) == "fill":
			studio_fill = child
	check(studio_env != null and studio_env.tonemap_mode == Environment.TONE_MAPPER_LINEAR,
		"preview studio uses linear tonemap so authored albedo is not filmic-lifted toward white")
	check(studio_env != null and is_equal_approx(studio_env.ambient_light_energy, 0.34),
		"preview studio ambient energy matches the bundled viewer Lambert term")
	check(studio_key != null and is_equal_approx(studio_key.light_energy, 0.60) and
		studio_key.rotation_degrees.is_equal_approx(Vector3(-48.0, -32.0, 0.0)),
		"preview studio key light keeps the existing direction at viewer key energy")
	check(studio_fill != null and is_equal_approx(studio_fill.light_energy, 0.16) and
		studio_fill.rotation_degrees.is_equal_approx(Vector3(-20.0, 145.0, 0.0)),
		"preview studio fill light keeps the existing direction at viewer fill energy")
	check(studio_env != null and studio_key != null and studio_fill != null and
		studio_env.ambient_light_energy + studio_key.light_energy +
			studio_fill.light_energy <= 1.15,
		"preview studio peak lighting stays within the bundled viewer energy budget")
	studio_host.queue_free()
	var paired_visibility := Readability.aggregate_views([
		{"yaw": 0.0, "readability": readability, "issues": PackedStringArray(),
			"part_visibility": {"front": {"visible_fraction": 0.72}}},
		{"yaw": 180.0, "readability": readability, "issues": PackedStringArray(),
			"part_visibility": {"back": {"visible_fraction": 0.68}}},
	], {"view_set": "cardinal", "visibility_pairs": [{"name": "paired bent",
		"first": "front", "second": "back", "views": [[0.0, 180.0]],
		"maximum_delta": 0.05}]})
	check(paired_visibility.ok and paired_visibility.visibility_balance.measurements.size() == 1,
		"paired rendered visibility accepts balanced reusable structure across opposite views")
	var hierarchy_readability := {"available": true, "views": [
		{"yaw": 0.0, "part_visibility": {
			"primary": {"potential_pixels": 650}, "secondary": {"potential_pixels": 250},
			"tertiary": {"potential_pixels": 100}}},
		{"yaw": 90.0, "part_visibility": {
			"primary": {"potential_pixels": 680}, "secondary": {"potential_pixels": 230},
			"tertiary": {"potential_pixels": 90}}},
		{"yaw": 180.0, "part_visibility": {
			"primary": {"potential_pixels": 620}, "secondary": {"potential_pixels": 270},
			"tertiary": {"potential_pixels": 110}}},
	]}
	var hierarchy := MassHierarchyValidation.evaluate(hierarchy_readability,
		cohesion_contract.to_canonical_dict())
	check(hierarchy.ok and hierarchy.score > 0.7 and hierarchy.confidence > 0.9 and
		float(hierarchy.median_shares.primary) > float(hierarchy.median_shares.secondary),
		"mass hierarchy scores recipe targets with robust multi-view confidence")
	var flat_hierarchy := hierarchy_readability.duplicate(true)
	for view in flat_hierarchy.views:
		view.part_visibility.primary.potential_pixels = 400
		view.part_visibility.secondary.potential_pixels = 400
		view.part_visibility.tertiary.potential_pixels = 200
	var rejected_hierarchy := MassHierarchyValidation.evaluate(flat_hierarchy,
		cohesion_contract.to_canonical_dict())
	check(not rejected_hierarchy.ok and _has_prefix(rejected_hierarchy.failures,
		"MASS_HIERARCHY_"),
		"mass hierarchy rejects locally plausible parts with no declared visual dominance")

	var module := Component.new("test_beam")
	var module_mesh := Stock.with_material(Stock.box(Vector3(2.0, 0.2, 0.2)),
		_material("module"))
	module.add("core", module_mesh, Transform3D.IDENTITY, {"surface": {
		"construction": "prismatic", "role": "structural", "minimum_slenderness": 2.0}})
	module.define_socket("end", Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 0.0)))
	var component_asset := Assembly.new()
	component_asset.instance_component("pair_front", module,
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 1.0)))
	component_asset.instance_component("pair_back", module,
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -1.0)))
	var symmetry_contract := [{"name": "test pair", "first": "pair_front",
		"second": "pair_back", "axis": "z", "tolerance": 0.0001}]
	var component_symmetry := Symmetry.evaluate(component_asset, symmetry_contract)
	check(component_symmetry.ok and component_asset.parts[0].mesh == component_asset.parts[1].mesh,
		"scoped symmetry requires paired instances to reuse one component mesh resource")
	check(not Symmetry.evaluate(component_asset, [{"name": "wrong plane",
		"first": "pair_front", "second": "pair_back", "axis": "z",
		"center": 0.1, "tolerance": 0.0001}]).ok,
		"scoped symmetry rejects a component pair that drifts off its declared plane")
	var component_spec := AssetRecipe.normalize({"name": "component_test",
		"assembly": component_asset, "require_surface_classification": true,
		"symmetry": symmetry_contract})
	var component_validation := BuildPipeline.validate(component_spec)
	check(component_validation.ok and component_validation.surfaces.counts.has(
		"prismatic:structural"),
		"surface taxonomy selects type-specific validation for component parts")
	var topology_stats := TopologyBudget.statistics(component_asset.parts)
	check(topology_stats.rendered_triangles == topology_stats.unique_triangles * 2,
		"topology statistics separate rendered instances from shared stored geometry")
	var topology_failure := TopologyBudget.evaluate(component_asset.parts, {
		"rendered_triangles": topology_stats.rendered_triangles - 1})
	check(not topology_failure.ok and not topology_failure.failures.is_empty(),
		"topology budgets reject unwaived rendered triangle overruns")
	var test_rig := Rig.new()
	test_rig.add_bone("root")
	test_rig.add_bone("beam", "root", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 1.0)))
	test_rig.bind_rigid("pair_front__core", "beam")
	var test_clip := AnimationClip.new("test_cycle", 1.0, true, 30.0)
	test_clip.add_key("beam", 0.0, Transform3D.IDENTITY)
	test_clip.add_key("beam", 0.5, Transform3D(Basis(Vector3.FORWARD, 0.25), Vector3.ZERO))
	test_clip.add_key("beam", 1.0, Transform3D.IDENTITY)
	test_rig.add_clip(test_clip)
	test_rig.add_motion_report("test_linkage", linkage,
		{"fixed_length": 0.00001, "loop_closure": 0.00001})
	var test_rig_validation := RigValidation.evaluate(test_rig, component_asset)
	check(test_rig_validation.ok and test_rig_validation.bones == 2 and
		test_rig_validation.clips == 1,
		"rig validation accepts a named rigid binding and closed animation loop")
	var rig_scene := GLTFExport.scene_from_parts("rig_test", component_asset.parts, test_rig)
	check(rig_scene.get_node_or_null("Skeleton3D") is Skeleton3D and
		rig_scene.get_node_or_null("AnimationPlayer") is AnimationPlayer,
		"rigged scene creation emits real Godot skeleton and animation nodes")
	rig_scene.free()
	var rig_glb_path := "user://polyforge_rig_roundtrip.glb"
	var rig_export_error := GLTFExport.write_preserved(
		"rig_test", component_asset, rig_glb_path, test_rig)
	check(rig_export_error == OK, "Godot writes a rigged GLB")
	if rig_export_error == OK:
		var rig_inspection := GLTFExport.inspect(rig_glb_path)
		check(rig_inspection.ok and rig_inspection.skeleton_count == 1 and
			rig_inspection.bones.has("beam") and rig_inspection.animations.has("test_cycle"),
			"GLB round trip preserves skeleton, bone names, and clip names")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(rig_glb_path))

	var asset := Assembly.new()
	mesh.surface_set_material(0, _material("body"))
	asset.add("body", mesh)
	var mirrored := Assembly.mirror_x(mesh)
	asset.add("mirror", mirrored, Transform3D(Basis.IDENTITY, Vector3(3.0, 0.0, 0.0)))
	var result := Checks.evaluate(asset.parts, [Checks.require_gap("body", "mirror", 0.5)])
	check(result.failures.is_empty(), "named gap check passes separated parts")
	var depth_result := Checks.evaluate(asset.parts, [
		Checks.require_axis_range("body", 2, 0.5, 3.0)])
	check(depth_result.failures.is_empty(),
		"named axis-range checks reject accidentally flattened geometry")
	check(Checks.noclip(asset.parts).is_empty(), "noclip passes separated parts")

	var spec := Zone.Spec.new(Vector2(20.0, 16.0), Vector2i(12, 10), 5)
	spec.add_landform(Zone.base(1.0)).add_landform(Zone.hill(Vector2.ZERO, 6.0, 3.0))
	spec.add_landform(Zone.noise(4.0, 0.2))
	spec.add_surface(Zone.surface_default("ground", Color("667744")))
	var terrain_a = Zone.build_terrain(spec)
	var terrain_b = Zone.build_terrain(spec)
	check(terrain_a.verts == terrain_b.verts, "zone generation is deterministic")
	check(not terrain_a.faces.is_empty(), "zone emits terrain faces")

	var viewer := ViewerExport.mesh_data(mesh, "test")
	check(viewer.verts.size() > 0 and viewer.tris.size() > 0, "viewer export contains geometry")
	check(viewer.bones.size() == 1 and viewer.skin.size() == viewer.verts.size() / 3,
		"static viewer contract supplies root skin")
	var rigged_viewer := ViewerExport.assembly_data(component_asset, test_rig, "rig_test")
	check(rigged_viewer.bones.size() == 2 and rigged_viewer.anims.size() == 1 and
		rigged_viewer.anims[0].tracks[1].size() == 3,
		"viewer contract includes rig bindings and sampled animation transforms")

	var stock_box := Stock.with_material(Stock.box(Vector3.ONE), _material("stock"))
	asset.add("stock_box", stock_box, Transform3D(Basis.IDENTITY, Vector3(6.0, 0.0, 0.0)))
	var scene := GLTFExport.scene_from_parts("named_test", asset.parts)
	check(scene.get_node_or_null("body") != null and scene.get_node_or_null("stock_box") != null,
		"preserved export scene keeps semantic part names")
	scene.free()

	var dimensions := Parameters.new({
		"height": Parameters.scale(3.4, 2.4, 5.0, "m", "canonical height"),
		"bulk": Parameters.number(1.0, 0.8, 1.25, "ratio", "horizontal multiplier"),
	}, {"height": 4.2})
	var torso_height := dimensions.derive("torso.height", "height", 0.42)
	var torso_width := dimensions.computed("torso.width",
		torso_height * dimensions.value("bulk") * 0.8,
		["torso.height", "bulk"], "torso.height * bulk * 0.8")
	var dimensions_snapshot := dimensions.snapshot()
	check(dimensions.errors.is_empty() and is_equal_approx(dimensions.value("height"), 4.2),
		"parameter overrides select a validated primary measurement")
	check(torso_width > 0.0 and dimensions_snapshot.derived["torso.width"].sources.has("torso.height"),
		"derived measurements retain their local dependency provenance")
	var dimension_cases := Parameters.sweep_cases(dimensions.schema)
	check(dimension_cases.size() == 9 and dimension_cases[-1].varied.size() == 2,
		"parameter sweep covers individual bounds and pairwise boundary interactions")

	var guardian := AssetRecipe.load_file("res://examples/bronze_guardian_recipe.gd",
		{"height": 2.4, "bulk": 1.25})
	var guardian_validation := BuildPipeline.validate(guardian)
	check(guardian_validation.failures.is_empty(),
		"parameterized guardian validates at a non-default measurement combination")
	var guardian_sweep := BuildPipeline.validate_sweep(AssetRecipe.load_sweep(
		"res://examples/bronze_guardian_recipe.gd"))
	check(guardian_sweep.ok and guardian_sweep.records.size() == 9,
		"parameter sweep validates Guardian single and pairwise boundary combinations")
	var vapor_derrick := AssetRecipe.load_file("res://examples/arcane_pumpjack_recipe.gd")
	var vapor_validation := BuildPipeline.validate(vapor_derrick)
	check(vapor_validation.ok and vapor_validation.process.stages == 6 and
		vapor_validation.reference.available and vapor_validation.reference.ok,
		"vapor derrick completes the staged process and reference-image semantic gate")
	check(vapor_validation.reference.reference_image.sha256 ==
		"e90f854563b3f8c19d7f30c6b67d1923ecb5727754a76b5fe68e2341ce8d5490" and
		vapor_validation.reference.measurements.size() >= 18,
		"reference evidence is pinned to the supplied image and reports measured semantics")
	var relaxed_reference := vapor_derrick.duplicate(true)
	relaxed_reference.anchors.boom_pivot = Vector3(999.0, 999.0, 999.0)
	var relaxed_validation := BuildPipeline.validate(relaxed_reference)
	check(relaxed_validation.ok and relaxed_validation.reference.ok and
		not relaxed_validation.reference.warnings.is_empty(),
		"preferred reference placement reports drift without overriding asset validity")
	var required_reference := ReferenceValidation.evaluate({
		"assembly": component_asset, "anchors": {}, "contracts": {},
		"reference_profile": {"payload": {
			"image": {"sha256": "required-test"},
			"semantic_groups": {"missing_signature": {"selector": {
				"names": ["does_not_exist"]}, "minimum": 1, "policy": "required"}},
			"anchors": {}, "required_appearance_slots": [], "proportions": [],
			"policies": {"semantic_groups": "required"}}}})
	check(not required_reference.ok and required_reference.failures.size() == 1,
		"required reference identity remains a hard semantic gate")
	check(vapor_derrick.style_compilation.geometry_hash_before ==
		vapor_derrick.style_compilation.geometry_hash_after and
		vapor_derrick.rig.provenance.geometry_hash ==
		vapor_derrick.style_compilation.geometry_hash_after,
		"style and rig stages enforce geometry ownership through matching hashes")
	var arcane_relay := AssetRecipe.load_file("res://examples/arcane_relay_recipe.gd")
	var relay_validation := BuildPipeline.validate(arcane_relay)
	check(relay_validation.ok and relay_validation.process.stages == 12 and
		arcane_relay.contracts.has("assembly_plan") and
		arcane_relay.contracts.has("solved_assembly") and
		arcane_relay.contracts.has("cohesion_contract") and
		arcane_relay.contracts.has("interface_compilation"),
		"static relay completes semantic brief, solve, interface, geometry, and style stages")
	check(arcane_relay.contracts.candidate_selection.payload.selected_candidate_id ==
		"baseline" and arcane_relay.contracts.candidate_repair_report.payload.candidates.size() == 2,
		"relay hard-gates two candidates and prefers the valid zero-repair baseline")
	var tampered_relay: Dictionary = arcane_relay.duplicate(true)
	tampered_relay.contracts.candidate_selection.payload.selected_plan_hash = "tampered"
	var tampered_process := ProcessValidation.evaluate(tampered_relay)
	check(not tampered_process.ok and tampered_process.failures.has(
		"PROCESS_SELECTION_PLAN_HASH_MISMATCH"),
		"process ledger rejects a candidate selection detached from its chosen plan")
	var reordered_relay: Dictionary = arcane_relay.duplicate(true)
	var stage_swap = reordered_relay.process.stages[2]
	reordered_relay.process.stages[2] = reordered_relay.process.stages[3]
	reordered_relay.process.stages[3] = stage_swap
	reordered_relay.process.erase("pipeline_hash")
	reordered_relay.process["pipeline_hash"] = CanonicalArtifact.hash_value(
		reordered_relay.process)
	var reordered_process := ProcessValidation.evaluate(reordered_relay)
	check(not reordered_process.ok and reordered_process.failures.has(
		"PROCESS_CANDIDATE_STAGE_ORDER_INVALID"),
		"process ledger rejects reordered proposal and repair ownership stages")
	check(arcane_relay.contracts.solved_assembly.payload.plan_hash ==
		CanonicalArtifact.hash_value(arcane_relay.contracts.assembly_plan) and
		arcane_relay.style_compilation.geometry_hash_before ==
		arcane_relay.style_compilation.geometry_hash_after,
		"relay provenance binds geometry to the accepted plan while style stays non-geometric")
	check(relay_validation.cohesion.ok and relay_validation.cohesion.available and
		relay_validation.cohesion.measurements.size() == 5 and
		arcane_relay.contracts.interface_plan.payload.solved_assembly_hash ==
			CanonicalArtifact.hash_value(arcane_relay.contracts.solved_assembly) and
		arcane_relay.contracts.interface_compilation.payload.base_geometry_hash !=
			arcane_relay.contracts.interface_compilation.payload.output_geometry_hash and
		arcane_relay.style_compilation.geometry_hash_after ==
			arcane_relay.contracts.interface_compilation.payload.output_geometry_hash,
		"relay adds measured junction geometry without reopening the solved assembly")
	var forged_cohesion: Dictionary = arcane_relay.duplicate(true)
	forged_cohesion.contracts.interface_compilation.payload.connections[0].a_overlap = 0.0
	var forged_result := CohesionValidation.evaluate(forged_cohesion)
	check(not forged_result.ok and _has_prefix(forged_result.failures,
		"COHESION_ENDPOINT_OVERLAP_FAILED"),
		"cohesion rejects a nominal socket connection reduced to point contact")
	var forged_family: Dictionary = arcane_relay.duplicate(true)
	forged_family.contracts.interface_plan.payload.treatments[0].family = \
		"rigid.unapproved_transition"
	var forged_family_result := CohesionValidation.evaluate(forged_family)
	check(not forged_family_result.ok and _has_prefix(forged_family_result.failures,
		"COHESION_INTERFACE_FAMILY_NOT_ALLOWED"),
		"cohesion rejects interface geometry outside the brief-owned grammar")
	var relay_residuals: Array = arcane_relay.contracts.solved_assembly.payload.residuals
	check(relay_residuals.size() == 5 and relay_residuals.all(
		func(residual): return bool(residual.get("ok", false))),
		"reference relay records passing residual evidence for every socket connection")
	var aerostat := AssetRecipe.load_file("res://examples/arcane_aerostat_recipe.gd")
	var aerostat_validation := BuildPipeline.validate(aerostat)
	check(aerostat_validation.ok and aerostat_validation.process.stages == 12 and
		aerostat_validation.suspension.ok and aerostat_validation.suspension.members == 5 and
		aerostat_validation.plausibility.ok and
		aerostat_validation.plausibility.required_support_nodes == 4 and
		aerostat.contracts.suspension_plan.payload.input_geometry_hash ==
			aerostat.contracts.interface_compilation.payload.output_geometry_hash and
		aerostat.style_compilation.geometry_hash_after ==
			aerostat.contracts.suspension_compilation.payload.output_geometry_hash,
		"aerostat preserves rigid, interface, suspension, and style ownership through one hash chain")
	var termination_count := 0
	for member in aerostat.contracts.suspension_compilation.payload.members:
		termination_count += member.get("terminations", {}).size()
	check(termination_count == 10,
		"every aerostat tension member terminates visibly at both causal endpoints")
	var forged_suspension: Dictionary = aerostat.duplicate(true)
	for evidence in forged_suspension.contracts.suspension_compilation.payload.members:
		if str(evidence.id) == "rope_fl":
			evidence.length += 0.5
	var forged_suspension_result := SuspensionValidation.evaluate(forged_suspension)
	check(not forged_suspension_result.ok and _has_prefix(
		forged_suspension_result.failures, "SUSPENSION_PAIR_LENGTH_MISMATCH"),
		"suspension validation rejects asymmetric paired load paths")
	var floating_termination: Dictionary = aerostat.duplicate(true)
	floating_termination.contracts.suspension_compilation.payload.members[0].terminations.a.host_overlap = 0.0
	var floating_termination_result := SuspensionValidation.evaluate(floating_termination)
	check(not floating_termination_result.ok and _has_prefix(
		floating_termination_result.failures, "SUSPENSION_TERMINATION_INVALID"),
		"suspension validation rejects visible hardware detached from its host")
	var missing_load_path: Dictionary = aerostat.duplicate(true)
	missing_load_path.contracts.plausibility_contract.payload.relations = []
	var missing_load_path_result := PlausibilityValidation.evaluate(missing_load_path)
	check(not missing_load_path_result.ok and _has_prefix(
		missing_load_path_result.failures, "PLAUSIBILITY_SUPPORT_PATH_MISSING"),
		"plausibility validation rejects masses without a causal support path")
	var misbound_evidence: Dictionary = aerostat.duplicate(true)
	for relation in misbound_evidence.contracts.plausibility_contract.payload.relations:
		if str(relation.id) == "left_pod_mount":
			relation.evidence.connection_id = "position_basket"
	var misbound_evidence_result := PlausibilityValidation.evaluate(misbound_evidence)
	check(not misbound_evidence_result.ok and _has_prefix(
		misbound_evidence_result.failures, "PLAUSIBILITY_RELATION_EVIDENCE_MISSING"),
		"plausibility evidence must bind the declared causal nodes, not merely exist")

	var recipe := AssetRecipe.normalize({
		"name": "named_test",
		"assembly": asset,
		"triangle_budget": 5000,
		"anchors": {"socket": Vector3(1.0, 2.0, 3.0)},
	})
	var validation := BuildPipeline.validate(recipe)
	check(validation.failures.is_empty(), "recipe passes the build validation gate")
	var manifest := ManifestExport.data(recipe, validation, {"glb": "named_test.glb"})
	check(manifest.parts.size() == 3 and manifest.anchors.socket == [1.0, 2.0, 3.0],
		"manifest preserves named parts and numeric anchors")
	check(manifest.format_version == 8 and manifest.has("parameters") and
		manifest.has("attachments") and manifest.has("component_instances") and
		manifest.has("socket_contracts") and manifest.has("topology") and
		manifest.has("rig"),
		"manifest v8 records typed sockets, components, topology, rig data, and metadata")

	var glb_path := "user://polyforge_roundtrip.glb"
	var export_error := GLTFExport.write_preserved("named_test", asset, glb_path)
	check(export_error == OK, "Godot writes preserved GLB")
	if export_error == OK:
		var inspection := GLTFExport.inspect(glb_path)
		check(inspection.ok and inspection.mesh_count == 3,
			"Godot re-imports the emitted GLB with all named meshes")
		check(inspection.mesh_nodes.has("body") and inspection.mesh_nodes.has("stock_box"),
			"round-trip import retains semantic node names")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(glb_path))

	print("test_polyforge: %d failures" % failures)
	quit(1 if failures > 0 else 0)
