extends RefCounted
## Godot-native glTF/GLB export and round-trip inspection.
##
## Preserved mode creates one named MeshInstance3D per Assembly part. Merged mode emits a
## single material-batched MeshInstance3D. Both paths use Godot's GLTFDocument directly.

const Lint := preload("res://addons/polyforge/quality/lint_core.gd")

static func _node_name(value: String) -> String:
	var clean := value.strip_edges()
	return clean if clean != "" else "part"

static func scene_from_parts(asset_name: String, parts: Array) -> Node3D:
	var root := Node3D.new()
	root.name = _node_name(asset_name)
	for part in parts:
		var instance := MeshInstance3D.new()
		instance.name = _node_name(str(part.name))
		instance.mesh = part.mesh
		instance.transform = part.get("transform", Transform3D.IDENTITY)
		root.add_child(instance)
		instance.owner = root
	return root

static func scene_from_merged(asset_name: String, assembly) -> Node3D:
	var root := Node3D.new()
	root.name = _node_name(asset_name)
	var instance := MeshInstance3D.new()
	instance.name = _node_name(asset_name) + "_merged"
	instance.mesh = assembly.merged_mesh()
	root.add_child(instance)
	instance.owner = root
	return root

static func write_scene(root: Node, path: String) -> Error:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(root, state)
	if error != OK:
		return error
	return document.write_to_filesystem(state, path)

static func write_preserved(asset_name: String, assembly, path: String) -> Error:
	var root := scene_from_parts(asset_name, assembly.parts)
	var error := write_scene(root, path)
	root.free()
	return error

static func write_merged(asset_name: String, assembly, path: String) -> Error:
	var root := scene_from_merged(asset_name, assembly)
	var error := write_scene(root, path)
	root.free()
	return error

static func _mesh_instances(root: Node) -> Array:
	var out := []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is MeshInstance3D:
			out.append(node)
		for child in node.get_children():
			pending.append(child)
	return out

## Import the emitted GLB through Godot again. This is the compatibility test that catches
## exporter output which writes successfully but cannot be consumed by the target engine.
static func inspect(path: String) -> Dictionary:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		return {"ok": false, "error": error, "path": path}
	var root := document.generate_scene(state)
	if root == null:
		return {"ok": false, "error": ERR_CANT_CREATE, "path": path}
	var instances := _mesh_instances(root)
	var nodes := PackedStringArray()
	var triangles := 0
	var surfaces := 0
	for instance in instances:
		nodes.append(str(instance.name))
		if instance.mesh is ArrayMesh:
			triangles += Lint.triangle_count(instance.mesh)
			surfaces += instance.mesh.get_surface_count()
	var result := {
		"ok": true,
		"path": path,
		"mesh_nodes": nodes,
		"mesh_count": instances.size(),
		"surfaces": surfaces,
		"triangles": triangles,
		"extensions_used": state.json.get("extensionsUsed", []),
		"extensions_required": state.json.get("extensionsRequired", []),
	}
	root.free()
	return result
