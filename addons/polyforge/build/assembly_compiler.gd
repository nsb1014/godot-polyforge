extends RefCounted
## Compiles geometry only from an accepted SolvedAssembly artifact.

const Assembly := preload("res://addons/polyforge/core/assembly.gd")

static func compile(catalog, solved) -> Dictionary:
	var failures := PackedStringArray()
	if solved == null or str(solved.get("artifact_type")) != "solved_assembly":
		return {"ok": false, "failures": PackedStringArray([
			"GEOMETRY_REQUIRES_SOLVED_ASSEMBLY"]), "assembly": null}
	for failure in solved.validate():
		failures.append("INVALID_SOLVED_ASSEMBLY: " + failure)
	if solved.payload.catalog_hash != catalog.content_hash():
		failures.append("SOLVED_ASSEMBLY_CATALOG_HASH_MISMATCH")
	if not failures.is_empty():
		return {"ok": false, "failures": failures, "assembly": null}
	var assembly := Assembly.new()
	var by_id := {}
	for instance in solved.payload.instances:
		by_id[str(instance.id)] = instance
	var ids := PackedStringArray(by_id.keys())
	ids.sort()
	for id in ids:
		var instance: Dictionary = by_id[id]
		var component_id := str(instance.component_id)
		if not catalog.has(component_id):
			failures.append("GEOMETRY_UNKNOWN_COMPONENT: %s" % component_id)
			continue
		assembly.instance_component(id, catalog.component(component_id),
			solved.payload.transforms[id])
	return {"ok": failures.is_empty(), "failures": failures, "assembly": assembly,
		"plan_hash": solved.payload.plan_hash, "solved_assembly_hash": solved.content_hash(),
		"instances": ids}
