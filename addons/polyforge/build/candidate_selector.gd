extends RefCounted
## Hard constraints determine eligibility; explicit soft objectives rank valid plans only.

const AssemblyPlan := preload("res://addons/polyforge/core/assembly_plan.gd")
const CandidateSelection := preload("res://addons/polyforge/core/candidate_selection.gd")
const RigidValidation := preload("res://addons/polyforge/quality/rigid_solution_validation.gd")
const SUPPORTED_METRICS := ["repair_count", "max_position_residual",
	"max_rotation_residual", "minimum_clearance_margin"]

static func default_objectives() -> Array:
	return [
		{"metric": "repair_count", "direction": "min"},
		{"metric": "max_position_residual", "direction": "min"},
	]

static func _less(a: Dictionary, b: Dictionary, objectives: Array) -> bool:
	for objective in objectives:
		var metric := str(objective.get("metric", ""))
		var direction := str(objective.get("direction", "min"))
		var av := float(a.metrics.get(metric, INF if direction == "min" else -INF))
		var bv := float(b.metrics.get(metric, INF if direction == "min" else -INF))
		if not is_equal_approx(av, bv):
			return av < bv if direction == "min" else av > bv
	return str(a.id) < str(b.id)

static func _sort(records: Array, objectives: Array) -> void:
	for index in range(1, records.size()):
		var item = records[index]
		var cursor := index - 1
		while cursor >= 0 and _less(item, records[cursor], objectives):
			records[cursor + 1] = records[cursor]
			cursor -= 1
		records[cursor + 1] = item

static func select(catalog, repair_report, objectives := []) -> Dictionary:
	if catalog == null or repair_report == null or \
			str(repair_report.get("artifact_type")) != "candidate_repair_report":
		return {"ok": false, "artifact": null, "selected_plan": null,
			"failures": PackedStringArray(["CANDIDATE_SELECTION_INPUT_INVALID"]),
			"rejected": []}
	var report_errors: PackedStringArray = repair_report.validate()
	if not report_errors.is_empty():
		return {"ok": false, "artifact": null, "selected_plan": null,
			"failures": report_errors, "rejected": []}
	var ranking: Array = objectives.duplicate(true) if not objectives.is_empty() \
		else default_objectives()
	for objective in ranking:
		if not SUPPORTED_METRICS.has(str(objective.get("metric", ""))) or \
				not ["min", "max"].has(str(objective.get("direction", ""))):
			return {"ok": false, "artifact": null, "selected_plan": null,
				"failures": PackedStringArray(["CANDIDATE_OBJECTIVE_UNSUPPORTED"]),
				"rejected": []}
	var eligible := []
	var rejected := []
	var plans := {}
	for candidate in repair_report.payload.candidates:
		var id := str(candidate.id)
		if str(candidate.status) != "solved":
			rejected.append({"id": id, "reason": "solver_rejected",
				"diagnostics": candidate.solve_diagnostics})
			continue
		var plan = AssemblyPlan.from_canonical_dict(candidate.plan)
		var validation := RigidValidation.evaluate(catalog, plan, candidate.solution)
		if not validation.ok:
			rejected.append({"id": id, "reason": "hard_validation_failed",
				"diagnostics": validation.diagnostics})
			continue
		var metrics: Dictionary = validation.metrics.duplicate(true)
		metrics["repair_count"] = int(candidate.repair_count)
		var record := {"id": id, "plan_hash": plan.content_hash(),
			"metrics": metrics, "validation": validation,
			"repair_count": int(candidate.repair_count)}
		eligible.append(record)
		plans[id] = plan
	if eligible.is_empty():
		return {"ok": false, "artifact": null, "selected_plan": null,
			"failures": PackedStringArray(["CANDIDATE_SELECTION_NO_VALID_PLAN"]),
			"rejected": rejected}
	_sort(eligible, ranking)
	var selected: Dictionary = eligible[0]
	var artifact := CandidateSelection.new(repair_report.content_hash(), selected.id,
		selected.plan_hash, ranking, eligible, rejected)
	var errors := artifact.validate()
	return {"ok": errors.is_empty(), "artifact": artifact,
		"selected_plan": plans[selected.id], "failures": errors,
		"eligible": eligible, "rejected": rejected}
