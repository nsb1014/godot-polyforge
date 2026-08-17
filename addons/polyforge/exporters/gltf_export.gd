extends RefCounted
## Godot-native glTF/GLB export and round-trip inspection.
##
## Preserved mode creates one named MeshInstance3D per Assembly part. Merged mode emits a
## single material-batched MeshInstance3D. Both paths use Godot's GLTFDocument directly.

const Lint := preload("res://addons/polyforge/quality/lint_core.gd")

static func _node_name(value: String) -> String:
	var clean := value.strip_edges()
	return clean if clean != "" else "part"

static func _transformed_skinned_mesh(mesh: Mesh, transform: Transform3D,
		influences: Array, rig) -> ArrayMesh:
	var out := ArrayMesh.new()
	var normal_basis := transform.basis.inverse().transposed()
	for surface_index in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
		var normals := PackedVector3Array()
		if arrays[Mesh.ARRAY_NORMAL] != null:
			normals = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
		for vertex_index in range(vertices.size()):
			vertices[vertex_index] = transform * vertices[vertex_index]
			if not normals.is_empty():
				normals[vertex_index] = (normal_basis * normals[vertex_index]).normalized()
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		bones.resize(vertices.size() * 4)
		weights.resize(vertices.size() * 4)
		for vertex_index in range(vertices.size()):
			for influence_index in range(mini(influences.size(), 4)):
				var influence: Dictionary = influences[influence_index]
				bones[vertex_index * 4 + influence_index] = rig.bone_index(str(influence.bone))
				weights[vertex_index * 4 + influence_index] = float(influence.weight)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals if not normals.is_empty() else null
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1,
			mesh.surface_get_material(surface_index))
	return out

static func _global_rests(rig) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for bone in rig.bones:
		var rest: Transform3D = bone.rest
		var parent_index: int = rig.bone_index(str(bone.parent))
		out.append(rest if parent_index < 0 else out[parent_index] * rest)
	return out

static func _animation_player(root: Node3D, skeleton: Skeleton3D, rig) -> AnimationPlayer:
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.root_node = NodePath("..")
	root.add_child(player)
	player.owner = root
	var library := AnimationLibrary.new()
	player.add_animation_library("", library)
	for clip in rig.clips:
		var animation := Animation.new()
		animation.length = float(clip.duration)
		animation.loop_mode = Animation.LOOP_LINEAR if bool(clip.loop) else Animation.LOOP_NONE
		for raw_bone in clip.tracks:
			var bone_name := str(raw_bone)
			var path := NodePath(str(skeleton.name) + ":" + bone_name)
			var position_track := animation.add_track(Animation.TYPE_POSITION_3D)
			var rotation_track := animation.add_track(Animation.TYPE_ROTATION_3D)
			var scale_track := animation.add_track(Animation.TYPE_SCALE_3D)
			animation.track_set_path(position_track, path)
			animation.track_set_path(rotation_track, path)
			animation.track_set_path(scale_track, path)
			for key in clip.tracks[raw_bone]:
				var pose: Transform3D = key.transform
				animation.position_track_insert_key(position_track, float(key.time), pose.origin)
				animation.rotation_track_insert_key(rotation_track, float(key.time),
					pose.basis.get_rotation_quaternion())
				animation.scale_track_insert_key(scale_track, float(key.time), pose.basis.get_scale())
		library.add_animation(str(clip.name), animation)
	return player

static func scene_from_parts(asset_name: String, parts: Array, rig = null) -> Node3D:
	var root := Node3D.new()
	root.name = _node_name(asset_name)
	if rig != null and not rig.bones.is_empty():
		var skeleton := Skeleton3D.new()
		skeleton.name = "Skeleton3D"
		root.add_child(skeleton)
		skeleton.owner = root
		for bone in rig.bones:
			skeleton.add_bone(str(bone.name))
		for bone_index in range(rig.bones.size()):
			var bone: Dictionary = rig.bones[bone_index]
			skeleton.set_bone_parent(bone_index, rig.bone_index(str(bone.parent)))
			skeleton.set_bone_rest(bone_index, bone.rest)
		var skin := Skin.new()
		var global_rests := _global_rests(rig)
		for bone_index in range(global_rests.size()):
			skin.add_bind(bone_index, global_rests[bone_index].affine_inverse())
		for part in parts:
			var instance := MeshInstance3D.new()
			instance.name = _node_name(str(part.name))
			root.add_child(instance)
			instance.owner = root
			var binding = rig.bindings.get(str(part.name), null)
			if binding != null:
				instance.mesh = _transformed_skinned_mesh(part.mesh,
					part.get("transform", Transform3D.IDENTITY), binding.influences, rig)
				instance.skin = skin
				instance.skeleton = instance.get_path_to(skeleton)
			else:
				instance.mesh = part.mesh
				instance.transform = part.get("transform", Transform3D.IDENTITY)
		_animation_player(root, skeleton, rig)
		return root
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

static func write_preserved(asset_name: String, assembly, path: String, rig = null) -> Error:
	var root := scene_from_parts(asset_name, assembly.parts, rig)
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

static func _skeletons(root: Node) -> Array[Skeleton3D]:
	var out: Array[Skeleton3D] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Skeleton3D: out.append(node)
		for child in node.get_children(): pending.append(child)
	return out

static func _animation_players(root: Node) -> Array[AnimationPlayer]:
	var out: Array[AnimationPlayer] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is AnimationPlayer: out.append(node)
		for child in node.get_children(): pending.append(child)
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
	var skeletons := _skeletons(root)
	var players := _animation_players(root)
	var nodes := PackedStringArray()
	var bone_names := PackedStringArray()
	var animation_names := PackedStringArray()
	for skeleton in skeletons:
		for bone_index in range(skeleton.get_bone_count()):
			bone_names.append(skeleton.get_bone_name(bone_index))
	for player in players:
		for animation_name in player.get_animation_list():
			if animation_name != "RESET" and not animation_names.has(animation_name):
				animation_names.append(animation_name)
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
		"skeleton_count": skeletons.size(),
		"bones": bone_names,
		"animations": animation_names,
		"extensions_used": state.json.get("extensionsUsed", []),
		"extensions_required": state.json.get("extensionsRequired", []),
	}
	root.free()
	return result
