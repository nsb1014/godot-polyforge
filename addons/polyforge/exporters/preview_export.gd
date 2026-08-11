extends RefCounted
## Neutral-studio four-view contact sheets rendered by Godot itself.
##
## Rendering can be unavailable with a dummy headless renderer. That is reported as an
## export warning; GLB, manifest, and browser-viewer output remain deterministic.

const Readability := preload("res://addons/polyforge/quality/readability.gd")
const BACKGROUND := Color("d9dde3")

static func _environment(background := BACKGROUND) -> WorldEnvironment:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = background
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	return world

static func _camera_position(center: Vector3, distance: float, yaw_deg: float) -> Vector3:
	var yaw := deg_to_rad(yaw_deg)
	return center + Vector3(sin(yaw) * distance, distance * 0.16, cos(yaw) * distance)

static func _fit_distance(bounds: AABB, fov_degrees: float) -> float:
	var radius := bounds.size.length() * 0.5
	return maxf(radius / maxf(sin(deg_to_rad(fov_degrees) * 0.5), 0.01) * 1.15, 1.0)

static func _add_studio(viewport: SubViewport, scene: Node3D,
		background := BACKGROUND) -> Camera3D:
	viewport.add_child(_environment(background))
	viewport.add_child(scene)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 145.0, 0.0)
	fill.light_energy = 0.45
	viewport.add_child(fill)
	var camera := Camera3D.new()
	camera.fov = 28.0
	viewport.add_child(camera)
	return camera

static func render_contact_sheet(tree: SceneTree, scene: Node3D, bounds: AABB, path: String,
		panel_size := Vector2i(420, 500), view_set := "octants") -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = panel_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.transparent_bg = false
	var camera := _add_studio(viewport, scene)
	tree.root.add_child(viewport)

	var center := bounds.get_center()
	var distance := _fit_distance(bounds, camera.fov)
	var yaws := Readability.view_angles(view_set)
	var columns := mini(4, yaws.size())
	var rows := ceili(float(yaws.size()) / float(columns))
	var sheet := Image.create(panel_size.x * columns, panel_size.y * rows,
		false, Image.FORMAT_RGBA8)
	sheet.fill(BACKGROUND)
	var label := Label.new()
	label.position = Vector2(12.0, 10.0)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 22)
	viewport.add_child(label)
	for i in range(yaws.size()):
		label.text = "%d°" % roundi(yaws[i])
		camera.position = _camera_position(center, distance, yaws[i])
		camera.look_at(center, Vector3.UP)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		if image == null or image.is_empty():
			viewport.queue_free()
			return {"ok": false, "error": ERR_UNAVAILABLE,
				"message": "Godot renderer did not produce a preview image"}
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, panel_size),
			Vector2i((i % columns) * panel_size.x, (i / columns) * panel_size.y))
	var error := sheet.save_png(path)
	viewport.queue_free()
	return {"ok": error == OK, "error": error, "path": path}

static func _capture(viewport: SubViewport) -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image != null and not image.is_empty() and image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image

static func _mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is MeshInstance3D:
			result.append(node)
		for child in node.get_children():
			pending.append(child)
	return result

static func _id_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

static func _count_color(image: Image, color: Color, tolerance := 0.08) -> int:
	if image == null or image.is_empty():
		return 0
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if absf(pixel.r - color.r) + absf(pixel.g - color.g) + absf(pixel.b - color.b) <= tolerance:
				count += 1
	return count

static func _measure_visibility(viewport: SubViewport, instances: Array[MeshInstance3D],
		critical: Dictionary, yaw: float) -> Dictionary:
	var palette := [Color.RED, Color.LIME, Color.BLUE, Color.YELLOW,
		Color.MAGENTA, Color.CYAN, Color("ff7f00"), Color("7fff00")]
	var by_name := {}
	var groups := {}
	var original_visibility := {}
	var original_materials := {}
	var blocker_material := _id_material(Color.BLACK)
	for instance in instances:
		by_name[str(instance.name)] = instance
		original_visibility[instance] = instance.visible
		original_materials[instance] = instance.material_override
		instance.visible = true
		instance.material_override = blocker_material
	var names := critical.keys()
	for index in range(names.size()):
		var name := str(names[index])
		var rule = critical[name]
		var member_names = rule.get("members", [name]) if rule is Dictionary else [name]
		var members: Array[MeshInstance3D] = []
		for member_name in member_names:
			if by_name.has(str(member_name)):
				members.append(by_name[str(member_name)])
				by_name[str(member_name)].material_override = _id_material(
					palette[index % palette.size()])
		groups[name] = members
	var combined := await _capture(viewport)
	var reports := {}
	var issues := PackedStringArray()
	for index in range(names.size()):
		var name := str(names[index])
		var rule = critical[name]
		if not Readability.view_is_required(rule, yaw):
			continue
		var members: Array[MeshInstance3D] = groups[name]
		if members.is_empty():
			reports[name] = {"visible_fraction": 0.0, "visible_pixels": 0,
				"potential_pixels": 0, "ok": false}
			issues.append("critical part %s is missing" % name)
			continue
		for instance in instances:
			instance.visible = members.has(instance)
		var isolated := await _capture(viewport)
		var color: Color = palette[index % palette.size()]
		var visible_pixels := _count_color(combined, color)
		var potential_pixels := _count_color(isolated, color)
		var fraction := float(visible_pixels) / maxf(float(potential_pixels), 1.0)
		var minimum := float(rule.get("minimum_visible_fraction", 0.35)) \
			if rule is Dictionary else float(rule)
		var ok := potential_pixels > 0 and fraction >= minimum
		reports[name] = {"visible_fraction": snappedf(fraction, 0.001),
			"visible_pixels": visible_pixels, "potential_pixels": potential_pixels,
			"minimum": minimum, "ok": ok}
		if not ok:
			issues.append("critical part %s visibility %.3f is below %.3f" % [
				name, fraction, minimum])
	for instance in instances:
		instance.visible = original_visibility[instance]
		instance.material_override = original_materials[instance]
	return {"parts": reports, "issues": issues}

static func measure_readability(tree: SceneTree, scene: Node3D, bounds: AABB,
		policy: Dictionary) -> Dictionary:
	var side := int(policy.target_pixels) * int(policy.supersample)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(side, side)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.transparent_bg = false
	var camera := _add_studio(viewport, scene)
	tree.root.add_child(viewport)
	var center := bounds.get_center()
	var distance := _fit_distance(bounds, camera.fov)
	var reports := []
	var instances := _mesh_instances(scene)
	for yaw in Readability.view_angles(str(policy.view_set)):
		camera.position = _camera_position(center, distance, yaw)
		camera.look_at(center, Vector3.UP)
		var image := await _capture(viewport)
		if image == null or image.is_empty():
			viewport.queue_free()
			return {"available": false, "ok": false,
				"issues": PackedStringArray(["Godot renderer did not produce a play-size image"]),
				"policy": policy}
		var report := Readability.analyze(image, policy)
		var visibility := {"parts": {}, "issues": PackedStringArray()}
		if not policy.critical_parts.is_empty():
			visibility = await _measure_visibility(viewport, instances,
				policy.critical_parts, yaw)
		reports.append({"yaw": yaw, "readability": report,
			"part_visibility": visibility.parts, "issues": visibility.issues})
	viewport.queue_free()
	return Readability.aggregate_views(reports, policy)
