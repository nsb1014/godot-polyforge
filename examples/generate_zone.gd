extends SceneTree

const Zone := preload("res://addons/polyforge/terrain/zone.gd")
const Assembly := preload("res://addons/polyforge/core/assembly.gd")
const ViewerExport := preload("res://addons/polyforge/exporters/viewer_export.gd")

func _initialize() -> void:
	var spec := Zone.Spec.new(Vector2(120.0, 90.0), Vector2i(80, 60), 42)
	spec.water_level = 0.0
	spec.add_landform(Zone.base(2.0))
	spec.add_landform(Zone.rim(14.0, 18.0))
	spec.add_landform(Zone.hill(Vector2(-20.0, 8.0), 26.0, 11.0))
	spec.add_landform(Zone.basin(Vector2(22.0, -9.0), 18.0, 5.0))
	spec.add_landform(Zone.noise(16.0, 1.4, 3))
	spec.add_landform(Zone.spline([
		Vector2(-55.0, -12.0), Vector2(-10.0, 3.0), Vector2(48.0, 16.0)], 5.0, -2.0))
	spec.add_surface(Zone.surface_default("grass", Color("657a45")))
	spec.add_surface(Zone.surface_slope_above(34.0, "rock", Color("776e61")))
	spec.add_surface(Zone.surface_near_water(1.5, "shore", Color("b59b68")))
	spec.add_scatter(Zone.scatter("tree", 45, {
		"maximum_slope": 25.0,
		"minimum_spacing": 4.0,
		"scale": Vector2(0.75, 1.25),
	}))

	var terrain = Zone.build_terrain(spec)
	var materials := {}
	for tag in ["grass", "rock", "shore"]:
		var material := StandardMaterial3D.new()
		material.resource_name = tag
		material.vertex_color_use_as_albedo = true
		materials[tag] = material
	var assembly := Assembly.new()
	assembly.add_polymesh("terrain", terrain, materials)
	var mesh := assembly.merged_mesh()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://out"))
	ViewerExport.write_json(mesh, "res://out/example_zone_viewer.json", "example_zone")
	ViewerExport.write_embedded_html(mesh, "res://viewer/template.html",
		"res://out/example_zone.html", "example_zone")
	print("zone: %d scatter placements" % Zone.scatter_placements(spec).size())
	quit()
