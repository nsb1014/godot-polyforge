extends RefCounted
## Verifies declared support paths and the geometry evidence bound to each causal edge.

const CanonicalArtifact := preload("res://addons/polyforge/core/canonical_artifact.gd")

static func _required(relation: Dictionary) -> bool:
	return str(relation.get("authority", "")) == "required"

static func _issue(relation: Dictionary, message: String, failures: PackedStringArray,
		warnings: PackedStringArray) -> void:
	if _required(relation):
		failures.append(message)
	elif str(relation.get("authority", "")) == "preferred":
		warnings.append(message)

static func evaluate(spec: Dictionary) -> Dictionary:
	var failures := PackedStringArray()
	var warnings := PackedStringArray()
	var measurements := []
	var contracts: Dictionary = spec.get("contracts", {})
	if not contracts.has("plausibility_contract"):
		return {"ok": true, "available": false, "failures": failures,
			"warnings": warnings, "measurements": measurements}
	if not contracts.has("design_brief"):
		return {"ok": false, "available": true,
			"failures": PackedStringArray(["PLAUSIBILITY_MISSING_DESIGN_BRIEF"]),
			"warnings": warnings, "measurements": measurements}
	var contract: Dictionary = contracts.plausibility_contract
	var brief_hash := CanonicalArtifact.hash_value(contracts.design_brief)
	if str(contract.payload.get("design_brief_hash", "")) != brief_hash:
		failures.append("PLAUSIBILITY_DESIGN_BRIEF_HASH_MISMATCH")
	var solved_connections := {}
	for connection in contracts.get("solved_assembly", {}).get("payload", {}).get(
			"connections", []):
		solved_connections[str(connection.get("id", ""))] = connection
	var interface_connections := {}
	for evidence in contracts.get("interface_compilation", {}).get("payload", {}).get(
			"connections", []):
		interface_connections[str(evidence.get("connection_id", ""))] = evidence
	var suspension_members := {}
	for evidence in contracts.get("suspension_compilation", {}).get("payload", {}).get(
			"members", []):
		suspension_members[str(evidence.get("id", ""))] = evidence
	var adjacency := {}
	var support_sources := {}
	var required_support := PackedStringArray()
	for node in contract.payload.get("nodes", []):
		var id := str(node.get("id", ""))
		adjacency[id] = PackedStringArray()
		if bool(node.get("support_source", false)):
			support_sources[id] = true
		if bool(node.get("requires_support", false)):
			required_support.append(id)
	for relation in contract.payload.get("relations", []):
		var id := str(relation.get("id", ""))
		var from := str(relation.get("from", ""))
		var to := str(relation.get("to", ""))
		var evidence: Dictionary = relation.get("evidence", {})
		var evidence_ok := true
		if str(relation.get("basis", "")) == "stylistic_hypothesis" and \
				_required(relation):
			evidence_ok = false
		var connection_id := str(evidence.get("connection_id", ""))
		if connection_id != "":
			evidence_ok = solved_connections.has(connection_id)
			if evidence_ok:
				var connection: Dictionary = solved_connections[connection_id]
				var endpoint_instances := PackedStringArray([str(connection.get("a", {}).get(
					"instance", "")), str(connection.get("b", {}).get("instance", ""))])
				evidence_ok = endpoint_instances.has(from) and endpoint_instances.has(to)
			if evidence_ok and bool(evidence.get("require_visible_interface", false)):
				evidence_ok = interface_connections.has(connection_id)
		var member_ids: Array = evidence.get("suspension_members", [])
		if _required(relation) and connection_id == "" and member_ids.is_empty():
			evidence_ok = false
		if not member_ids.is_empty():
			for member_id in member_ids:
				if not suspension_members.has(str(member_id)):
					evidence_ok = false
					continue
				var member_evidence: Dictionary = suspension_members[str(member_id)]
				var endpoint_instances := PackedStringArray([str(member_evidence.get(
					"a_endpoint", {}).get("instance", "")), str(member_evidence.get(
					"b_endpoint", {}).get("instance", ""))])
				if not endpoint_instances.has(from) or not endpoint_instances.has(to):
					evidence_ok = false
				if bool(evidence.get("require_terminations", false)):
					var terminations: Dictionary = member_evidence.get(
						"terminations", {})
					if not terminations.has("a") or not terminations.has("b"):
						evidence_ok = false
		measurements.append({"type": "causal_relation", "id": id,
			"from": from, "to": to, "kind": str(relation.get("kind", "")),
			"basis": str(relation.get("basis", "")),
			"authority": str(relation.get("authority", "")), "ok": evidence_ok})
		if not evidence_ok:
			_issue(relation, "PLAUSIBILITY_RELATION_EVIDENCE_MISSING: " + id,
				failures, warnings)
		elif _required(relation) and adjacency.has(from) and adjacency.has(to):
			adjacency[from].append(to)
	for start in required_support:
		var reached_source := support_sources.has(start)
		var reached := {start: true}
		var pending := [start]
		while not pending.is_empty() and not reached_source:
			var current: String = pending.pop_back()
			for neighbor in adjacency.get(current, PackedStringArray()):
				if support_sources.has(neighbor):
					reached_source = true
					break
				if not reached.has(neighbor):
					reached[neighbor] = true
					pending.append(neighbor)
		measurements.append({"type": "support_path", "node": start,
			"reaches_source": reached_source, "ok": reached_source})
		if not reached_source:
			failures.append("PLAUSIBILITY_SUPPORT_PATH_MISSING: " + start)
	return {"ok": failures.is_empty(), "available": true, "failures": failures,
		"warnings": warnings, "measurements": measurements,
		"domain": str(contract.payload.get("domain", "")),
		"support_sources": support_sources.size(),
		"required_support_nodes": required_support.size()}
