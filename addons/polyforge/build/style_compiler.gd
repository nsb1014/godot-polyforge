extends RefCounted
## Material-slot compiler. It is forbidden from changing the geometry fingerprint.

const GeometryFingerprint := preload("res://addons/polyforge/core/geometry_fingerprint.gd")

static func slot(id: String) -> StandardMaterial3D:
	assert(id != "", "material slots require stable IDs")
	var material := StandardMaterial3D.new()
	material.resource_name = id
	material.albedo_color = Color.WHITE
	material.roughness = 1.0
	return material

static func _color(value, fallback := Color.WHITE) -> Color:
	if value is Color:
		return value
	if value is String and Color.html_is_valid(value):
		return Color(value)
	if value is Array and value.size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]),
			float(value[3]) if value.size() > 3 else 1.0)
	return fallback

static func _compile_material(slot_id: String, spec: Dictionary) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	# The resource name remains the stable slot ID. Human names live in the binding.
	material.resource_name = slot_id
	material.albedo_color = _color(spec.get("color", Color.WHITE))
	material.metallic = float(spec.get("metallic", 0.0))
	material.roughness = float(spec.get("roughness", 0.8))
	if bool(spec.get("emission_enabled", false)):
		material.emission_enabled = true
		material.emission = _color(spec.get("emission", material.albedo_color),
			material.albedo_color)
		material.emission_energy_multiplier = float(spec.get("emission_energy", 1.0))
	return material

static func apply(assembly, binding) -> Dictionary:
	var failures := PackedStringArray()
	var before := GeometryFingerprint.assembly_hash(assembly)
	var specs: Dictionary = binding.slots()
	var compiled := {}
	for slot_id in specs:
		compiled[str(slot_id)] = _compile_material(str(slot_id), specs[slot_id])
	var visited := {}
	var used := PackedStringArray()
	for part in assembly.parts:
		var mesh: Mesh = part.mesh
		var mesh_id := mesh.get_instance_id()
		if visited.has(mesh_id):
			continue
		visited[mesh_id] = true
		for surface in range(mesh.get_surface_count()):
			var current := mesh.surface_get_material(surface)
			var slot_id := str(current.resource_name) if current != null else "surface_%d" % surface
			if not compiled.has(slot_id):
				failures.append("STYLE_UNKNOWN_SLOT: %s" % slot_id)
				continue
			mesh.surface_set_material(surface, compiled[slot_id])
			if not used.has(slot_id):
				used.append(slot_id)
	var after := GeometryFingerprint.assembly_hash(assembly)
	if before != after:
		failures.append("STYLE_MUTATED_GEOMETRY")
	for slot_id in compiled:
		if not used.has(slot_id):
			failures.append("STYLE_UNUSED_SLOT: %s" % slot_id)
	return {
		"ok": failures.is_empty(),
		"failures": failures,
		"geometry_hash_before": before,
		"geometry_hash_after": after,
		"appearance_binding_hash": binding.content_hash(),
		"used_slots": used,
	}
