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
		if mesh is ArrayMesh and \
				(mesh as ArrayMesh).surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
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

static func _global_rests(rig) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for bone in rig.bones:
		var parent_index: int = rig.bone_index(str(bone.parent))
		out.append(bone.rest if parent_index < 0 else out[parent_index] * bone.rest)
	return out

static func assembly_data(assembly, rig = null, model_name := "polyforge_model") -> Dictionary:
	var verts := []
	var tris := []
	var triangle_materials := []
	var materials := []
	var colors := []
	var skin := []
	var y_min := INF
	var y_max := -INF
	var bones := [{"n": "root", "p": -1, "h": [0.0, 0.0, 0.0]}]
	var root_bone := 0
	if rig != null and not rig.bones.is_empty():
		bones = []
		var rests := _global_rests(rig)
		for bone_index in range(rig.bones.size()):
			var bone: Dictionary = rig.bones[bone_index]
			var parent_index: int = rig.bone_index(str(bone.parent))
			var origin: Vector3 = rests[bone_index].origin
			bones.append({"n": str(bone.name), "p": parent_index,
				"h": [origin.x, origin.y, origin.z]})
		root_bone = maxi(rig.bone_index("root"), 0)
	for part in assembly.parts:
		var transform: Transform3D = part.get("transform", Transform3D.IDENTITY)
		var binding = rig.bindings.get(str(part.name), null) if rig != null else null
		var bone_index := root_bone
		if binding != null and not binding.influences.is_empty():
			bone_index = rig.bone_index(str(binding.influences[0].bone))
		for surface_index in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(surface_index)
			var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices := _indices(arrays)
			var offset: int = verts.size() / 3
			var material: Material = part.mesh.surface_get_material(surface_index)
			var base := _material_color(material)
			var material_name := material.resource_name if material != null and \
				material.resource_name != "" else "%s_surface_%d" % [part.name, surface_index]
			var material_index := materials.size()
			materials.append({"name": material_name, "rgb": [base.r, base.g, base.b]})
			var source_colors := PackedColorArray()
			if arrays[Mesh.ARRAY_COLOR] != null: source_colors = arrays[Mesh.ARRAY_COLOR]
			for vertex_index in range(source_vertices.size()):
				var vertex: Vector3 = transform * source_vertices[vertex_index]
				verts.append(vertex.x); verts.append(vertex.y); verts.append(vertex.z)
				y_min = minf(y_min, vertex.y); y_max = maxf(y_max, vertex.y)
				var color := source_colors[vertex_index] if not source_colors.is_empty() else base
				colors.append(color.r); colors.append(color.g); colors.append(color.b)
				skin.append([bone_index, 1.0, -1])
			for triangle_index in range(0, indices.size() - 2, 3):
				tris.append(indices[triangle_index] + offset)
				tris.append(indices[triangle_index + 1] + offset)
				tris.append(indices[triangle_index + 2] + offset)
				triangle_materials.append(material_index)
	var animations := []
	if rig != null:
		for clip in rig.clips:
			var tracks := []
			tracks.resize(rig.bones.size())
			for bone_index in range(rig.bones.size()):
				var bone_name := str(rig.bones[bone_index].name)
				if not clip.tracks.has(bone_name): continue
				var keys := []
				for key in clip.tracks[bone_name]:
					var pose: Transform3D = key.transform
					var rotation := pose.basis.get_rotation_quaternion()
					keys.append({"t": float(key.time),
						"r": [rotation.x, rotation.y, rotation.z, rotation.w],
						"p": [pose.origin.x, pose.origin.y, pose.origin.z]})
				tracks[bone_index] = keys
			animations.append({"name": str(clip.name), "dur": float(clip.duration),
				"loop": bool(clip.loop), "tracks": tracks})
	return {"name": model_name, "height": maxf(y_max - y_min, 0.0),
		"verts": verts, "tris": tris, "triMat": triangle_materials,
		"mats": materials, "vcols": colors, "skin": skin,
		"bones": bones, "anims": animations}

static func data(source, model_name := "polyforge_model", rig = null) -> Dictionary:
	return mesh_data(source, model_name) if source is Mesh else \
		assembly_data(source, rig, model_name)

static func write_json(source, path: String, model_name := "polyforge_model", rig = null) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data(source, model_name, rig)))
	return OK

static func write_embedded_html(source, template_path: String, output_path: String,
		model_name := "polyforge_model", rig = null) -> Error:
	var template := FileAccess.get_file_as_string(template_path)
	if template == "":
		return FileAccess.get_open_error()
	var json := JSON.stringify(data(source, model_name, rig))
	template = template.replace("null /*__DATA__*/", json)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(template)
	return OK
