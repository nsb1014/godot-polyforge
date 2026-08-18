extends "res://addons/polyforge/core/canonical_artifact.gd"
## Geometry-free candidate plans emitted by one deterministic planner invocation.

const CanonicalArtifact := preload("res://addons/polyforge/core/canonical_artifact.gd")

func _init(base_plan_hash := "", candidates := [], planner := {},
		producer := "polyforge.assembly_candidate_generator.v1") -> void:
	super("assembly_candidate_set", {
		"base_plan_hash": str(base_plan_hash),
		"candidates": candidates,
		"planner": planner,
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	if str(payload.get("base_plan_hash", "")) == "":
		errors.append("candidate set requires a base plan hash")
	if payload.get("candidates", []).is_empty():
		errors.append("candidate set requires at least one plan")
	var ids := {}
	for candidate in payload.get("candidates", []):
		var id := str(candidate.get("id", ""))
		if id == "" or ids.has(id):
			errors.append("candidates require unique stable IDs")
		ids[id] = true
		var plan: Dictionary = candidate.get("plan", {})
		if str(plan.get("artifact_type", "")) != "assembly_plan":
			errors.append("candidate %s requires an assembly plan" % id)
		elif str(candidate.get("plan_hash", "")) != CanonicalArtifact.hash_value(plan):
			errors.append("candidate %s plan hash mismatch" % id)
		if id == "baseline" and str(candidate.get("plan_hash", "")) != \
				str(payload.get("base_plan_hash", "")):
			errors.append("baseline candidate must match the base plan hash")
	return errors

static func from_canonical_dict(record: Dictionary):
	var source: Dictionary = CanonicalArtifact.decanonicalize(record.get("payload", {}))
	return load("res://addons/polyforge/core/assembly_candidate_set.gd").new(
		str(source.get("base_plan_hash", "")), source.get("candidates", []),
		source.get("planner", {}), str(record.get("producer_version", "")))
