extends RefCounted
## Hard geometry-level cohesion checks. Validation observes and never repairs.

const CanonicalArtifact := preload("res://addons/polyforge/core/canonical_artifact.gd")
const GeometryFingerprint := preload("res://addons/polyforge/core/geometry_fingerprint.gd")

static func _artifact(contracts: Dictionary, name: String) -> Dictionary:
	return contracts.get(name, {})

static func _part_exists(assembly, name: String) -> bool:
	return assembly.find(name) != null

static func evaluate(spec: Dictionary) -> Dictionary:
	var failures := PackedStringArray()
	var warnings := PackedStringArray()
	var measurements := []
	var contracts: Dictionary = spec.get("contracts", {})
	var names := ["design_brief", "cohesion_contract", "interface_plan",
		"interface_compilation", "solved_assembly"]
	var available := false
	for name in names:
		available = available or contracts.has(name)
	if not available:
		return {"ok": true, "available": false, "failures": failures,
			"warnings": warnings, "measurements": measurements}
	for name in names:
		if not contracts.has(name):
			failures.append("COHESION_MISSING_CONTRACT: " + name)
	if not failures.is_empty():
		return {"ok": false, "available": true, "failures": failures,
			"warnings": warnings, "measurements": measurements}
	var brief := _artifact(contracts, "design_brief")
	var cohesion := _artifact(contracts, "cohesion_contract")
	var plan := _artifact(contracts, "interface_plan")
	var compilation := _artifact(contracts, "interface_compilation")
	var solved := _artifact(contracts, "solved_assembly")
	var brief_hash := CanonicalArtifact.hash_value(brief)
	var cohesion_hash := CanonicalArtifact.hash_value(cohesion)
	var plan_hash := CanonicalArtifact.hash_value(plan)
	var solved_hash := CanonicalArtifact.hash_value(solved)
	if str(cohesion.payload.get("design_brief_hash", "")) != brief_hash:
		failures.append("COHESION_DESIGN_BRIEF_HASH_MISMATCH")
	if str(plan.payload.get("cohesion_contract_hash", "")) != cohesion_hash:
		failures.append("COHESION_INTERFACE_PLAN_HASH_MISMATCH")
	if str(plan.payload.get("solved_assembly_hash", "")) != solved_hash or \
			str(compilation.payload.get("solved_assembly_hash", "")) != solved_hash:
		failures.append("COHESION_SOLVED_ASSEMBLY_HASH_MISMATCH")
	if str(compilation.payload.get("interface_plan_hash", "")) != plan_hash:
		failures.append("COHESION_COMPILATION_PLAN_HASH_MISMATCH")
	if str(compilation.payload.get("output_geometry_hash", "")) != \
			GeometryFingerprint.assembly_hash(spec.assembly):
		failures.append("COHESION_OUTPUT_GEOMETRY_HASH_MISMATCH")
	var brief_groups := {}
	for group in brief.payload.get("mass_hierarchy", []):
		brief_groups[str(group.get("id", ""))] = str(group.get("tier", ""))
	for group in cohesion.payload.get("mass_groups", []):
		var group_id := str(group.get("id", ""))
		if not brief_groups.has(group_id) or brief_groups[group_id] != str(
				group.get("tier", "")):
			failures.append("COHESION_MASS_GROUP_NOT_IN_BRIEF: " + group_id)
	var solved_connections := {}
	for connection in solved.payload.get("connections", []):
		solved_connections[str(connection.get("id", ""))] = connection
	var treatment_by_id := {}
	for treatment in plan.payload.get("treatments", []):
		treatment_by_id[str(treatment.get("connection_id", ""))] = treatment
	var evidence_by_id := {}
	for evidence in compilation.payload.get("connections", []):
		evidence_by_id[str(evidence.get("connection_id", ""))] = evidence
	var profile_id := str(cohesion.payload.get("interface_grammar", {}).get(
		"profile_id", ""))
	var allowed_families: Array = cohesion.payload.get("interface_grammar", {}).get(
		"allowed_families", [])
	var adjacency := {}
	for instance_id in cohesion.payload.get("backbone_instances", []):
		adjacency[str(instance_id)] = PackedStringArray()
	for raw_id in cohesion.payload.get("backbone_connections", []):
		var id := str(raw_id)
		if not solved_connections.has(id):
			failures.append("COHESION_UNKNOWN_BACKBONE_CONNECTION: " + id)
			continue
		if not treatment_by_id.has(id) or not evidence_by_id.has(id):
			failures.append("COHESION_UNTREATED_CONNECTION: " + id)
			continue
		var treatment: Dictionary = treatment_by_id[id]
		var evidence: Dictionary = evidence_by_id[id]
		if str(treatment.get("profile_id", "")) != profile_id or \
				str(evidence.get("profile_id", "")) != profile_id:
			failures.append("COHESION_PROFILE_MISMATCH: " + id)
		if not allowed_families.has(str(treatment.get("family", ""))):
			failures.append("COHESION_INTERFACE_FAMILY_NOT_ALLOWED: " + id)
		var minimum := float(treatment.get("minimum_endpoint_overlap", 0.0))
		var a_overlap := float(evidence.get("a_overlap", 0.0))
		var b_overlap := float(evidence.get("b_overlap", 0.0))
		var overlap_ok := a_overlap >= minimum and b_overlap >= minimum
		measurements.append({"type": "interface_overlap", "connection_id": id,
			"a_overlap": a_overlap, "b_overlap": b_overlap, "minimum": minimum,
			"ok": overlap_ok})
		if not overlap_ok:
			failures.append("COHESION_ENDPOINT_OVERLAP_FAILED: %s measured %.4f/%.4f required %.4f" % [
				id, a_overlap, b_overlap, minimum])
		if not _part_exists(spec.assembly, str(evidence.get("part_name", ""))):
			failures.append("COHESION_INTERFACE_PART_MISSING: " + id)
		var connection: Dictionary = solved_connections[id]
		var a := str(connection.get("a", {}).get("instance", ""))
		var b := str(connection.get("b", {}).get("instance", ""))
		if adjacency.has(a) and adjacency.has(b):
			adjacency[a].append(b)
			adjacency[b].append(a)
	var backbone: Array = cohesion.payload.get("backbone_instances", [])
	if not backbone.is_empty():
		var reached := {str(backbone[0]): true}
		var pending := [str(backbone[0])]
		while not pending.is_empty():
			var current: String = pending.pop_back()
			for neighbor in adjacency.get(current, PackedStringArray()):
				if not reached.has(neighbor):
					reached[neighbor] = true
					pending.append(neighbor)
		for instance_id in backbone:
			if not reached.has(str(instance_id)):
				failures.append("COHESION_BACKBONE_DISCONNECTED: " + str(instance_id))
	return {"ok": failures.is_empty(), "available": true, "failures": failures,
		"warnings": warnings, "measurements": measurements,
		"profile_id": profile_id, "backbone_instances": backbone.size()}
