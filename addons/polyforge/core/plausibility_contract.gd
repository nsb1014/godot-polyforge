extends "res://addons/polyforge/core/canonical_artifact.gd"
## Domain-owned causal structure and evidence policy. This is not a universal realism score.

const BASES := ["observed", "functional_inference", "stylistic_hypothesis"]
const AUTHORITIES := ["required", "preferred", "informational"]

func _init(design_brief_hash := "", domain := "", nodes := [], relations := [],
		completion_policy := {}, producer := "polyforge.plausibility_contract.v1") -> void:
	super("plausibility_contract", {
		"design_brief_hash": str(design_brief_hash),
		"domain": str(domain),
		"nodes": nodes,
		"relations": relations,
		"completion_policy": {
			"unobserved_geometry": str(completion_policy.get("unobserved_geometry",
				"minimal_cohesive")),
			"stylistic_hypotheses": str(completion_policy.get("stylistic_hypotheses",
				"non_blocking")),
		},
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	if str(payload.get("design_brief_hash", "")) == "":
		errors.append("plausibility contract requires a design brief hash")
	if str(payload.get("domain", "")) == "":
		errors.append("plausibility contract requires a domain")
	var node_ids := PackedStringArray()
	var source_count := 0
	for node in payload.get("nodes", []):
		var id := str(node.get("id", ""))
		if id == "" or node_ids.has(id):
			errors.append("plausibility nodes require unique stable IDs")
		else:
			node_ids.append(id)
		if str(node.get("role", "")) == "":
			errors.append("plausibility node %s requires a role" % id)
		if bool(node.get("support_source", false)):
			source_count += 1
	if source_count == 0:
		errors.append("plausibility contract requires a support source")
	var relation_ids := PackedStringArray()
	for relation in payload.get("relations", []):
		var id := str(relation.get("id", ""))
		if id == "" or relation_ids.has(id):
			errors.append("plausibility relations require unique stable IDs")
		else:
			relation_ids.append(id)
		for endpoint in ["from", "to"]:
			if not node_ids.has(str(relation.get(endpoint, ""))):
				errors.append("plausibility relation %s has unknown %s node" % [id,
					endpoint])
		if str(relation.get("kind", "")) == "":
			errors.append("plausibility relation %s requires a kind" % id)
		if not BASES.has(str(relation.get("basis", ""))):
			errors.append("plausibility relation %s has an invalid evidence basis" % id)
		if not AUTHORITIES.has(str(relation.get("authority", ""))):
			errors.append("plausibility relation %s has invalid authority" % id)
		if str(relation.get("basis", "")) == "stylistic_hypothesis" and \
				str(relation.get("authority", "")) == "required":
			errors.append("stylistic hypotheses cannot become required causal relations")
	var policy: Dictionary = payload.get("completion_policy", {})
	if str(policy.get("unobserved_geometry", "")) != "minimal_cohesive":
		errors.append("unobserved geometry must use the minimal cohesive completion policy")
	if str(policy.get("stylistic_hypotheses", "")) != "non_blocking":
		errors.append("stylistic hypotheses must remain non-blocking")
	return errors

static func from_canonical_dict(record: Dictionary):
	var source: Dictionary = record.get("payload", {})
	return load("res://addons/polyforge/core/plausibility_contract.gd").new(
		str(source.get("design_brief_hash", "")), str(source.get("domain", "")),
		source.get("nodes", []), source.get("relations", []),
		source.get("completion_policy", {}), str(record.get("producer_version", "")))
