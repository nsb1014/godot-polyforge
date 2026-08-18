extends RefCounted
## Bounded diagnostic/patch/re-solve loop. Solver success remains provisional.

const RepairReport := preload("res://addons/polyforge/core/candidate_repair_report.gd")
const PlanPatchApplier := preload("res://addons/polyforge/build/plan_patch_applier.gd")

static func run(candidate_generation: Dictionary, solver, registry,
		max_attempts := 2) -> Dictionary:
	if not bool(candidate_generation.get("ok", false)):
		return {"ok": false, "artifact": null,
			"failures": PackedStringArray(["candidate generation failed"])}
	if solver == null or registry == null or max_attempts < 0:
		return {"ok": false, "artifact": null,
			"failures": PackedStringArray(["candidate repair configuration invalid"])}
	var candidate_set = candidate_generation.artifact
	var candidate_errors: PackedStringArray = candidate_set.validate()
	if not candidate_errors.is_empty():
		return {"ok": false, "artifact": null, "failures": candidate_errors}
	var records := []
	var ids := PackedStringArray(candidate_generation.plans.keys())
	ids.sort()
	for id in ids:
		var plan = candidate_generation.plans[id]
		var initial_plan_hash: String = plan.content_hash()
		var history := []
		var last_result := {}
		var status := "rejected"
		var attempts := 0
		while true:
			last_result = solver.solve({"problem_type": "rigid.socket_assembly",
				"plan": plan.payload, "constraints": [
					{"kind": "rigid.socket_mate"}, {"kind": "rigid.clearance"}]})
			if str(last_result.status) == "solved":
				status = "solved"
				break
			if attempts >= max_attempts:
				break
			attempts += 1
			var proposal: Dictionary = registry.propose(plan, last_result.diagnostics, attempts)
			if not proposal.ok:
				last_result["diagnostics"] = proposal.diagnostics
				break
			var applied := PlanPatchApplier.apply(plan, proposal.patch)
			if not applied.ok:
				last_result["diagnostics"] = applied.diagnostics
				break
			history.append({"patch": proposal.patch.to_canonical_dict(),
				"input_plan_hash": plan.content_hash(),
				"output_plan_hash": applied.plan.content_hash()})
			plan = applied.plan
		records.append({"id": id, "status": status,
			"initial_plan_hash": initial_plan_hash,
			"plan": plan.to_canonical_dict(), "plan_hash": plan.content_hash(),
			"solution": last_result.get("solution", {}),
			"solve_diagnostics": last_result.get("diagnostics", []),
			"repair_history": history, "repair_count": history.size(),
			"attempts": attempts})
	var artifact := RepairReport.new(candidate_set.content_hash(), records, max_attempts)
	var errors := artifact.validate()
	return {"ok": errors.is_empty(), "artifact": artifact, "failures": errors}
