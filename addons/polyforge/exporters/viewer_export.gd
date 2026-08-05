extends RefCounted
## Export static Godot meshes to the JSON contract used by viewer/template.html.
## The contract and viewer originate in WAM's viewer_export.py and template.html by
## Elliott Dehn, used with permission. See NOTICE.md.

static func _indices(arr: Array) -> PackedInt32Array:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var raw = arr[Mesh.ARRAY_INDEX]
	if raw != null and not (raw as PackedInt32Array).is_empty():
		return raw
	var idx := PackedInt32Array()
	idx.resize(verts.size())
	for i in range(idx.size()):
		idx[i] = i
	return idx

static func _material_color(material: Material) -> Color:
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).albedo_color
	return Color.WHITE

static func mesh_data(mesh: Mesh, model_name := "polyforge_model") -> Dictionary:
	assert(mesh != null, "viewer export needs a mesh")
	var verts := []
	var tris := []
	var triangle_materials := []
	var materials := []
	var colors := []
	var skin := []
	var y_min := INF
	var y_max := -INF
	for si in range(mesh.get_surface_count()):
		if mesh.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arr := mesh.surface_get_arrays(si)
		var src: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx := _indices(arr)
		var offset: int = verts.size() / 3
		var material: Material = mesh.surface_get_material(si)
		var base := _material_color(material)
		var material_name := material.resource_name if material != null and material.resource_name != "" else "surface_%d" % si
		materials.append({"name": material_name, "rgb": [base.r, base.g, base.b]})
		var src_colors := PackedColorArray()
		if arr[Mesh.ARRAY_COLOR] != null:
			src_colors = arr[Mesh.ARRAY_COLOR]
		for vi in range(src.size()):
			var v := src[vi]
			verts.append(v.x); verts.append(v.y); verts.append(v.z)
			y_min = minf(y_min, v.y); y_max = maxf(y_max, v.y)
			var color := src_colors[vi] if not src_colors.is_empty() else base
			colors.append(color.r); colors.append(color.g); colors.append(color.b)
			skin.append([0, 1.0, -1])
		for ti in range(0, idx.size() - 2, 3):
			tris.append(idx[ti] + offset)
			tris.append(idx[ti + 1] + offset)
			tris.append(idx[ti + 2] + offset)
			triangle_materials.append(si)
	return {
		"name": model_name,
		"height": maxf(y_max - y_min, 0.0) if y_min < INF else 0.0,
		"verts": verts,
		"tris": tris,
		"triMat": triangle_materials,
		"mats": materials,
		"vcols": colors,
		"skin": skin,
		"bones": [{"n": "root", "p": -1, "h": [0.0, 0.0, 0.0]}],
		"anims": [],
	}

static func write_json(mesh: Mesh, path: String, model_name := "polyforge_model") -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(mesh_data(mesh, model_name)))
	return OK

static func write_embedded_html(mesh: Mesh, template_path: String, output_path: String,
		model_name := "polyforge_model") -> Error:
	var template := FileAccess.get_file_as_string(template_path)
	if template == "":
		return FileAccess.get_open_error()
	var json := JSON.stringify(mesh_data(mesh, model_name))
	template = template.replace("null /*__DATA__*/", json)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(template)
	return OK
