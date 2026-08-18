extends RefCounted
## Routes diagnostics to explicit repair capabilities; it never edits a plan.

var _operators: Dictionary = {}

func register(repair_operator) -> void:
	var id := str(repair_operator.descriptor().get("id", ""))
	assert(id != "" and not _operators.has(id), "repair operators require unique IDs")
	_operators[id] = repair_operator

func propose(plan, diagnostics: Array, attempt: int) -> Dictionary:
	var ids := PackedStringArray(_operators.keys())
	ids.sort()
	for diagnostic in diagnostics:
		for id in ids:
			var repair_operator = _operators[id]
			if repair_operator.supports(plan, diagnostic):
				return repair_operator.propose(plan, diagnostic, attempt)
	return {"ok": false, "diagnostics": [{"code": "REPAIR_EXHAUSTED",
		"severity": "error", "message": "no operator supports remaining diagnostics",
		"entities": diagnostics.map(func(item): return item.get("code", ""))}]}
