extends RefCounted
## Machine-readable build manifest for runtime integration and agent inspection.

const Checks := preload("res://addons/polyforge/quality/checks.gd")
const Lint := preload("res://addons/polyforge/quality/lint_core.gd")

static func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func _basis(value: Basis) -> Array:
	return [_v3(value.x), _v3(value.y), _v3(value.z)]

static func _json_value(value):
	if value is Vector3:
		return _v3(value)
	if value is Vector2:
		return [value.x, value.y]
	if value is Color:
		return [value.r, value.g, value.b, value.a]
	if value is Transform3D:
		return {"origin": _v3(value.origin), "basis": _basis(value.basis)}
	if value is Dictionary:
		var result := {}
		for key in value:
			result[str(key)] = _json_value(value[key])
		return result
	if value is Array or value is PackedStringArray:
		var array := []
		for item in value:
			array.append(_json_value(item))
		return array
	return value

static func _materials(mesh: Mesh) -> PackedStringArray:
	var names := PackedStringArray()
	for si in range(mesh.get_surface_count()):
		var material := mesh.surface_get_material(si)
		var material_name := "surface_%d" % si
		if material != null and material.resource_name != "":
			material_name = material.resource_name
		if not names.has(material_name):
			names.append(material_name)
	return names

static func data(spec: Dictionary, validation: Dictionary, outputs: Dictionary) -> Dictionary:
	var part_records := []
	var total_triangles := 0
	var bounds := AABB()
	var have_bounds := false
	var all_materials := PackedStringArray()
	for part in spec.assembly.parts:
		var geometry := Checks.geometry(part)
		var triangles := Lint.triangle_count(part.mesh)
		total_triangles += triangles
		if not geometry.vertices.is_empty():
			bounds = geometry.aabb if not have_bounds else bounds.merge(geometry.aabb)
			have_bounds = true
		var materials := _materials(part.mesh)
		for material_name in materials:
			if not all_materials.has(material_name):
				all_materials.append(material_name)
		part_records.append({
			"name": part.name,
			"triangles": triangles,
			"materials": materials,
			"transform": part.get("transform", Transform3D.IDENTITY),
			"bounds": {
				"position": geometry.aabb.position,
				"size": geometry.aabb.size,
			},
			"tags": part.get("tags", PackedStringArray()),
			"component_id": part.get("component_id", ""),
			"source_part": part.get("source_part", part.name),
			"component_path": part.get("component_path", ""),
			"instance_path": part.get("instance_path", ""),
			"surface": part.get("surface", {}),
		})
	var manifest := {
		"format": "godot-polyforge-manifest",
		"format_version": 7,
		"generator": "Godot PolyForge",
		"name": spec.name,
		"category": spec.category,
		"front": spec.front,
		"loose": spec.loose,
		"triangles": total_triangles,
		"triangle_budget": spec.triangle_budget,
		"topology": validation.get("topology", {}),
		"rig": spec.rig.snapshot() if spec.rig != null else {},
		"contracts": spec.contracts,
		"process": spec.process,
		"style_compilation": spec.style_compilation,
		"reference_profile": spec.reference_profile,
		"reference_evidence": validation.get("reference", {}),
		"visual_evidence": validation.get("visual_evidence", {}),
		"materials": all_materials,
		"parts": part_records,
		"component_instances": spec.assembly.get("component_instances"),
		"sockets": spec.assembly.get("sockets"),
		"bounds": {
			"position": bounds.position if have_bounds else Vector3.ZERO,
			"size": bounds.size if have_bounds else Vector3.ZERO,
		},
		"anchors": spec.anchors,
		"attachments": spec.attachments,
		"symmetry": spec.symmetry,
		"parameters": spec.parameters,
		"metadata": spec.metadata,
		"validation": validation,
		"outputs": outputs,
	}
	return _json_value(manifest)

static func write(spec: Dictionary, validation: Dictionary, outputs: Dictionary,
		path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data(spec, validation, outputs), "  "))
	return OK
