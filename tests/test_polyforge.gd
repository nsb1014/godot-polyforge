extends SceneTree

const PolyMesh := preload("res://addons/polyforge/core/mesh.gd")
const SurfaceAttach := preload("res://addons/polyforge/core/surface_attach.gd")
const Paint := preload("res://addons/polyforge/core/paint.gd")
const Assembly := preload("res://addons/polyforge/core/assembly.gd")
const Attachments := preload("res://addons/polyforge/core/attachments.gd")
const Stock := preload("res://addons/polyforge/core/stock.gd")
const Parameters := preload("res://addons/polyforge/core/parameters.gd")
const AssetRecipe := preload("res://addons/polyforge/core/asset_recipe.gd")
const Lint := preload("res://addons/polyforge/quality/lint_core.gd")
const Checks := preload("res://addons/polyforge/quality/checks.gd")
const Readability := preload("res://addons/polyforge/quality/readability.gd")
const Zone := preload("res://addons/polyforge/terrain/zone.gd")
const ViewerExport := preload("res://addons/polyforge/exporters/viewer_export.gd")
const GLTFExport := preload("res://addons/polyforge/exporters/gltf_export.gd")
const ManifestExport := preload("res://addons/polyforge/exporters/manifest_export.gd")
const BuildPipeline := preload("res://addons/polyforge/build/build_pipeline.gd")

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
	var multiview := Readability.aggregate_views([
		{"yaw": 0.0, "readability": readability, "issues": PackedStringArray()},
		{"yaw": 180.0, "readability": readability, "issues": PackedStringArray([
			"critical part linkage visibility 0.2 is below 0.35"])},
	], {"view_set": "cardinal"})
	check(not multiview.ok and multiview.worst_view == 0.0 and
		str(multiview.issues[0]).begins_with("view 180°"),
		"multi-view aggregation preserves angle-qualified semantic failures")

	var asset := Assembly.new()
	mesh.surface_set_material(0, _material("body"))
	asset.add("body", mesh)
	var mirrored := Assembly.mirror_x(mesh)
	asset.add("mirror", mirrored, Transform3D(Basis.IDENTITY, Vector3(3.0, 0.0, 0.0)))
	var result := Checks.evaluate(asset.parts, [Checks.require_gap("body", "mirror", 0.5)])
	check(result.failures.is_empty(), "named gap check passes separated parts")
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
	check(manifest.format_version == 4 and manifest.has("parameters") and manifest.has("attachments"),
		"manifest records parameter provenance and geometry-sampled attachments")

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
