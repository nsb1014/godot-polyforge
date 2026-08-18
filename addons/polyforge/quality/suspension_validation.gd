extends RefCounted
## Independently validates suspension provenance, emitted members, and paired lengths.

const CanonicalArtifact := preload("res://addons/polyforge/core/canonical_artifact.gd")
const GeometryFingerprint := preload("res://addons/polyforge/core/geometry_fingerprint.gd")

static func evaluate(spec: Dictionary) -> Dictionary:
	var failures := PackedStringArray()
	var measurements := []
	var contracts: Dictionary = spec.get("contracts", {})
	var has_suspension := contracts.has("suspension_plan") or \
		contracts.has("suspension_compilation")
	if not has_suspension:
		return {"ok": true, "available": false, "failures": failures,
			"measurements": measurements}
	for name in ["solved_assembly", "suspension_plan", "suspension_compilation"]:
		if not contracts.has(name):
			failures.append("SUSPENSION_MISSING_CONTRACT: " + name)
	if not failures.is_empty():
		return {"ok": false, "available": true, "failures": failures,
			"measurements": measurements}
	var solved: Dictionary = contracts.solved_assembly
	var plan: Dictionary = contracts.suspension_plan
	var compilation: Dictionary = contracts.suspension_compilation
	var solved_hash := CanonicalArtifact.hash_value(solved)
	var plan_hash := CanonicalArtifact.hash_value(plan)
	if str(plan.payload.get("solved_assembly_hash", "")) != solved_hash or \
			str(compilation.payload.get("solved_assembly_hash", "")) != solved_hash:
		failures.append("SUSPENSION_SOLVED_HASH_MISMATCH")
	if str(compilation.payload.get("suspension_plan_hash", "")) != plan_hash:
		failures.append("SUSPENSION_PLAN_HASH_MISMATCH")
	if str(plan.payload.get("input_geometry_hash", "")) != str(
			compilation.payload.get("input_geometry_hash", "")):
		failures.append("SUSPENSION_INPUT_GEOMETRY_HASH_MISMATCH")
	if str(compilation.payload.get("output_geometry_hash", "")) != \
			GeometryFingerprint.assembly_hash(spec.assembly):
		failures.append("SUSPENSION_OUTPUT_GEOMETRY_HASH_MISMATCH")
	var evidence_by_id := {}
	for evidence in compilation.payload.get("members", []):
		evidence_by_id[str(evidence.get("id", ""))] = evidence
	for member in plan.payload.get("members", []):
		var id := str(member.get("id", ""))
		if not evidence_by_id.has(id):
			failures.append("SUSPENSION_MEMBER_MISSING: " + id)
			continue
		var evidence: Dictionary = evidence_by_id[id]
		var length := float(evidence.get("length", 0.0))
		var minimum := float(member.get("minimum_length", 0.0))
		var maximum := float(member.get("maximum_length", 0.0))
		var ok := length >= minimum and length <= maximum
		measurements.append({"type": "suspension_length", "id": id,
			"length": length, "minimum": minimum, "maximum": maximum, "ok": ok})
		if not ok:
			failures.append("SUSPENSION_LENGTH_OUT_OF_RANGE: " + id)
		if spec.assembly.find(str(evidence.get("part_name", ""))) == null:
			failures.append("SUSPENSION_PART_MISSING: " + id)
		var paired_with := str(member.get("paired_with", ""))
		if paired_with != "" and id < paired_with and evidence_by_id.has(paired_with):
			var delta := absf(length - float(evidence_by_id[paired_with].length))
			var tolerance := float(member.get("pair_tolerance", 0.0))
			var pair_ok := delta <= tolerance
			measurements.append({"type": "suspension_pair", "first": id,
				"second": paired_with, "delta": delta, "tolerance": tolerance,
				"ok": pair_ok})
			if not pair_ok:
				failures.append("SUSPENSION_PAIR_LENGTH_MISMATCH: %s/%s" % [id,
					paired_with])
	return {"ok": failures.is_empty(), "available": true, "failures": failures,
		"measurements": measurements, "members": evidence_by_id.size()}
