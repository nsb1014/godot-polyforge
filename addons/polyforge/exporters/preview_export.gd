extends RefCounted
## Neutral-studio four-view contact sheets rendered by Godot itself.
##
## Rendering can be unavailable with a dummy headless renderer. That is reported as an
## export warning; GLB, manifest, and browser-viewer output remain deterministic.

const Readability := preload("res://addons/polyforge/quality/readability.gd")
const BACKGROUND := Color("d9dde3")

static func _environment() -> WorldEnvironment:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
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

static func _add_studio(viewport: SubViewport, scene: Node3D) -> Camera3D:
	viewport.add_child(_environment())
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
		panel_size := Vector2i(420, 500)) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = panel_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.transparent_bg = false
	var camera := _add_studio(viewport, scene)
	tree.root.add_child(viewport)

	var center := bounds.get_center()
	var distance := _fit_distance(bounds, camera.fov)
	var sheet := Image.create(panel_size.x * 4, panel_size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(BACKGROUND)
	var yaws := [0.0, 38.0, 90.0, 180.0]
	for i in range(yaws.size()):
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
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, panel_size), Vector2i(i * panel_size.x, 0))
	var error := sheet.save_png(path)
	viewport.queue_free()
	return {"ok": error == OK, "error": error, "path": path}

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
	camera.position = _camera_position(center, distance, 0.0)
	camera.look_at(center, Vector3.UP)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		viewport.queue_free()
		return {"available": false, "ok": false,
			"issues": PackedStringArray(["Godot renderer did not produce a play-size image"]),
			"policy": policy}
	var report := Readability.analyze(image, policy)
	viewport.queue_free()
	return report
