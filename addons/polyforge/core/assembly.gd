extends RefCounted
## Named, transformable subparts. Names survive long enough for semantic lint and exports.

var parts: Array[Dictionary] = []
var component_instances: Array[Dictionary] = []
var sockets: Dictionary = {}
var _frames: Array[Transform3D] = [Transform3D.IDENTITY]

func current_frame() -> Transform3D:
	return _frames[_frames.size() - 1]

func push_frame(local_transform: Transform3D) -> void:
	_frames.append(current_frame() * local_transform)

func pop_frame() -> void:
	assert(_frames.size() > 1, "cannot pop the assembly root frame")
	_frames.pop_back()

func add(name: String, mesh: Mesh, local_transform := Transform3D.IDENTITY,
		options := {}) -> Dictionary:
	assert(name != "", "named parts require a non-empty name")
	assert(mesh != null, "named parts require a mesh")
	assert(find(name) == null, "duplicate part name: " + name)
	var record := {
		"name": name,
		"mesh": mesh,
		"transform": current_frame() * local_transform,
		"intentional_overlaps": PackedStringArray(options.get("intentional_overlaps", [])),
		"tags": PackedStringArray(options.get("tags", [])),
		"surface": options.get("surface", {}),
		"component_id": str(options.get("component_id", "")),
		"source_part": str(options.get("source_part", name)),
		"component_path": str(options.get("component_path", "")),
		"instance_path": str(options.get("instance_path", "")),
	}
	parts.append(record)
	return record

func instance_component(instance_name: String, component,
		local_transform := Transform3D.IDENTITY, options := {}) -> Array[Dictionary]:
	assert(instance_name != "", "component instances require a non-empty name")
	var root_path := str(options.get("instance_path", instance_name))
	var root_transform := current_frame() * local_transform
	var flattened: Dictionary = component.flattened(root_path, root_transform)
	for instance in flattened.instances:
		component_instances.append(instance)
	for socket_name in flattened.sockets:
		sockets[socket_name] = flattened.sockets[socket_name]
	var emitted: Array[Dictionary] = []
	for part in flattened.parts:
		var safe_path := str(part.component_path).replace("/", "__")
		var emitted_name := safe_path + "__" + str(part.source_part)
		emitted.append(add(emitted_name, part.mesh, part.transform, {
			"intentional_overlaps": part.intentional_overlaps,
			"tags": part.tags,
			"surface": part.surface,
			"component_id": part.component_id,
			"source_part": part.source_part,
			"component_path": part.component_path,
			"instance_path": root_path,
		}))
	return emitted

func define_socket(name: String, transform: Transform3D) -> void:
	sockets[name] = current_frame() * transform

func socket(name: String) -> Transform3D:
	assert(sockets.has(name), "unknown assembly socket: " + name)
	return sockets[name]

func part_names_for_instance(instance_path: String) -> PackedStringArray:
	var names := PackedStringArray()
	for part in parts:
		var path := str(part.get("component_path", ""))
		if path == instance_path or path.begins_with(instance_path + "/"):
			names.append(str(part.name))
	return names

func add_polymesh(name: String, poly, tag_materials: Dictionary,
		local_transform := Transform3D.IDENTITY, options := {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var emitted: Dictionary = poly.to_meshes()
	for tag in emitted:
		var mesh: ArrayMesh = emitted[tag]
		mesh.surface_set_material(0, tag_materials.get(tag, tag_materials.get("", null)))
		var child_name := name if str(tag) == "" else "%s:%s" % [name, tag]
		out.append(add(child_name, mesh, local_transform, options))
	return out

func find(name: String):
	for part in parts:
		if part.name == name:
			return part
	return null

func allow_overlap(a: String, b: String) -> void:
	var pa = find(a)
	var pb = find(b)
	assert(pa != null and pb != null, "overlap names must exist")
	if not pa.intentional_overlaps.has(b):
		pa.intentional_overlaps.append(b)
	if not pb.intentional_overlaps.has(a):
		pb.intentional_overlaps.append(a)

func merged_mesh() -> ArrayMesh:
	var by_material := {}
	for part in parts:
		var mesh: Mesh = part.mesh
		for si in range(mesh.get_surface_count()):
			var material = mesh.surface_get_material(si)
			if not by_material.has(material):
				by_material[material] = []
			by_material[material].append([mesh, si, part.transform])
	var out: ArrayMesh = null
	for material in by_material:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for entry in by_material[material]:
			st.append_from(entry[0], entry[1], entry[2])
		st.set_material(material)
		out = st.commit(out)
	return out

## Mirror an emitted mesh across world X while rebuilding triangles so front faces remain
## front-facing. Useful for exact bilateral assemblies.
static func mirror_x(mesh: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in range(mesh.get_surface_count()):
		var src: Array = mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX].duplicate()
		var normals := PackedVector3Array()
		if src[Mesh.ARRAY_NORMAL] != null:
			normals = (src[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
		for i in range(verts.size()):
			verts[i].x = -verts[i].x
			if not normals.is_empty():
				normals[i].x = -normals[i].x
		var idx := PackedInt32Array()
		if src[Mesh.ARRAY_INDEX] == null or (src[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
			idx.resize(verts.size())
			for i in range(idx.size()):
				idx[i] = i
		else:
			idx = (src[Mesh.ARRAY_INDEX] as PackedInt32Array).duplicate()
		for ti in range(0, idx.size() - 2, 3):
			var swap := idx[ti + 1]
			idx[ti + 1] = idx[ti + 2]
			idx[ti + 2] = swap
		src[Mesh.ARRAY_VERTEX] = verts
		src[Mesh.ARRAY_NORMAL] = normals if not normals.is_empty() else null
		src[Mesh.ARRAY_INDEX] = idx
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src)
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(si))
	return out
