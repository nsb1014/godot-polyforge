extends SceneTree

const PolyMesh := preload("res://addons/polyforge/core/mesh.gd")
const SurfaceAttach := preload("res://addons/polyforge/core/surface_attach.gd")
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
const AppearanceStyleBinding := preload("res://addons/polyforge/core/appearance_style_binding.gd")
const FourBarSolver := preload("res://addons/polyforge/core/four_bar_solver.gd")
const GeometryFingerprint := preload("res://addons/polyforge/core/geometry_fingerprint.gd")
const StageRunner := preload("res://addons/polyforge/build/stage_runner.gd")
const StyleCompiler := preload("res://addons/polyforge/build/style_compiler.gd")

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

func _initialize() -> void:
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
	check(vapor_derrick.style_compilation.geometry_hash_before ==
		vapor_derrick.style_compilation.geometry_hash_after and
		vapor_derrick.rig.provenance.geometry_hash ==
		vapor_derrick.style_compilation.geometry_hash_after,
		"style and rig stages enforce geometry ownership through matching hashes")

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
	check(manifest.format_version == 7 and manifest.has("parameters") and
		manifest.has("attachments") and manifest.has("component_instances") and
		manifest.has("topology") and manifest.has("rig"),
		"manifest v7 records components, topology, rig data, and authored metadata")

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
