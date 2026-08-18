extends RefCounted
## Deterministically expands one base plan into geometry-free candidate plans.

const CandidateSet := preload("res://addons/polyforge/core/assembly_candidate_set.gd")
const PlanPatchApplier := preload("res://addons/polyforge/build/plan_patch_applier.gd")

static func descriptor() -> Dictionary:
	return {"id": "polyforge.assembly_candidate_generator", "version": "1.0.0",
		"deterministic": true, "geometry_free": true}

static func generate(base_plan, proposals := []) -> Dictionary:
	var failures := PackedStringArray()
	if base_plan == null or str(base_plan.get("artifact_type")) != "assembly_plan":
		return {"ok": false, "failures": PackedStringArray([
			"CANDIDATE_BASE_PLAN_REQUIRED"]), "plans": {}, "artifact": null}
	for error in base_plan.validate():
		failures.append("CANDIDATE_BASE_PLAN_INVALID: " + error)
	if not failures.is_empty():
		return {"ok": false, "failures": failures, "plans": {}, "artifact": null}
	var plans := {"baseline": base_plan}
	var records := [{"id": "baseline", "plan_hash": base_plan.content_hash(),
		"plan": base_plan.to_canonical_dict(), "proposal_patch": {}}]
	var ordered: Array = proposals.duplicate()
	ordered.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	for proposal in ordered:
		var id := str(proposal.get("id", ""))
		if id == "" or plans.has(id):
			failures.append("CANDIDATE_ID_INVALID: %s" % id)
			continue
		var patch = proposal.get("patch")
		var applied := PlanPatchApplier.apply(base_plan, patch)
		if not applied.ok:
			failures.append("CANDIDATE_PATCH_REJECTED: %s: %s" % [id,
				str(applied.diagnostics)])
			continue
		var plan = applied.plan
		plans[id] = plan
		records.append({"id": id, "plan_hash": plan.content_hash(),
			"plan": plan.to_canonical_dict(),
			"proposal_patch": patch.to_canonical_dict()})
	if not failures.is_empty():
		return {"ok": false, "failures": failures, "plans": plans,
			"artifact": null}
	var artifact := CandidateSet.new(base_plan.content_hash(), records, descriptor())
	var errors := artifact.validate()
	return {"ok": errors.is_empty(), "failures": errors, "plans": plans,
		"artifact": artifact}
