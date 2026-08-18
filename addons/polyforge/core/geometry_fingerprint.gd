extends RefCounted
## Appearance-independent assembly fingerprint used to enforce stage ownership.

const CanonicalArtifact := preload("res://addons/polyforge/core/canonical_artifact.gd")

static func _surface_geometry(mesh: Mesh, surface: int) -> Dictionary:
	var arrays: Array = mesh.surface_get_arrays(surface)
	return {
		"primitive": Mesh.PRIMITIVE_TRIANGLES,
		"vertices": arrays[Mesh.ARRAY_VERTEX] if arrays[Mesh.ARRAY_VERTEX] != null else [],
		"indices": arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else [],
		"slot": _slot_id(mesh.surface_get_material(surface), surface),
	}

static func _slot_id(material: Material, surface: int) -> String:
	if material != null and str(material.resource_name) != "":
		return str(material.resource_name)
	return "surface_%d" % surface

static func assembly_payload(assembly) -> Dictionary:
	var parts := []
	for part in assembly.parts:
		var surfaces := []
		for surface in range(part.mesh.get_surface_count()):
			surfaces.append(_surface_geometry(part.mesh, surface))
		parts.append({
			"name": part.name,
			"transform": part.transform,
			"surfaces": surfaces,
			"tags": part.get("tags", PackedStringArray()),
			"surface_semantics": part.get("surface", {}),
			"component_id": part.get("component_id", ""),
			"source_part": part.get("source_part", ""),
			"component_path": part.get("component_path", ""),
			"instance_path": part.get("instance_path", ""),
		})
	return {"parts": parts, "sockets": assembly.sockets}

static func assembly_hash(assembly) -> String:
	return CanonicalArtifact.hash_value(assembly_payload(assembly))
