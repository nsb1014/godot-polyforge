extends "res://addons/polyforge/core/canonical_artifact.gd"
## Complete bounded repair histories and provisional solver results.

const CanonicalArtifact := preload("res://addons/polyforge/core/canonical_artifact.gd")

func _init(candidate_set_hash := "", candidates := [], max_attempts := 0,
		producer := "polyforge.candidate_repair_stage.v1") -> void:
	super("candidate_repair_report", {
		"candidate_set_hash": str(candidate_set_hash),
		"candidates": candidates,
		"max_attempts": int(max_attempts),
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	if str(payload.get("candidate_set_hash", "")) == "":
		errors.append("repair report requires a candidate set hash")
	if int(payload.get("max_attempts", 0)) < 0:
		errors.append("repair report max attempts must not be negative")
	var ids := {}
	for candidate in payload.get("candidates", []):
		var id := str(candidate.get("id", ""))
		if id == "" or ids.has(id):
			errors.append("repair report candidates require unique stable IDs")
		ids[id] = true
		if not ["solved", "rejected"].has(str(candidate.get("status", ""))):
			errors.append("repair report candidate %s has invalid status" % id)
		var plan: Dictionary = candidate.get("plan", {})
		if str(plan.get("artifact_type", "")) != "assembly_plan" or \
				str(candidate.get("plan_hash", "")) != CanonicalArtifact.hash_value(plan):
			errors.append("repair report candidate %s plan hash mismatch" % id)
		if int(candidate.get("repair_count", -1)) != \
				candidate.get("repair_history", []).size():
			errors.append("repair report candidate %s repair count mismatch" % id)
		var expected_hash := str(candidate.get("initial_plan_hash", ""))
		if expected_hash == "":
			errors.append("repair report candidate %s requires an initial plan hash" % id)
		for repair in candidate.get("repair_history", []):
			var patch: Dictionary = repair.get("patch", {})
			if str(patch.get("artifact_type", "")) != "plan_patch" or \
					str(repair.get("input_plan_hash", "")) != expected_hash or \
					str(patch.get("payload", {}).get("base_plan_hash", "")) != expected_hash:
				errors.append("repair report candidate %s patch chain mismatch" % id)
			expected_hash = str(repair.get("output_plan_hash", ""))
		if expected_hash != str(candidate.get("plan_hash", "")):
			errors.append("repair report candidate %s final patch hash mismatch" % id)
		if int(candidate.get("attempts", -1)) < 0 or int(candidate.get("attempts", -1)) > \
				int(payload.get("max_attempts", 0)):
			errors.append("repair report candidate %s exceeded attempt budget" % id)
		if str(candidate.get("status", "")) == "solved" and \
				candidate.get("solution", {}).is_empty():
			errors.append("solved repair candidate %s requires a solution" % id)
	return errors

static func from_canonical_dict(record: Dictionary):
	var source: Dictionary = CanonicalArtifact.decanonicalize(record.get("payload", {}))
	return load("res://addons/polyforge/core/candidate_repair_report.gd").new(
		str(source.get("candidate_set_hash", "")), source.get("candidates", []),
		int(source.get("max_attempts", 0)), str(record.get("producer_version", "")))
