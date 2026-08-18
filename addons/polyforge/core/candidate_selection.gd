extends "res://addons/polyforge/core/canonical_artifact.gd"
## Hard-gate validation evidence plus deterministic soft-objective selection.

func _init(repair_report_hash := "", selected_candidate_id := "",
		selected_plan_hash := "", objectives := [], eligible := [], rejected := [],
		producer := "polyforge.candidate_selector.v1") -> void:
	super("candidate_selection", {
		"repair_report_hash": str(repair_report_hash),
		"selected_candidate_id": str(selected_candidate_id),
		"selected_plan_hash": str(selected_plan_hash),
		"objectives": objectives,
		"eligible": eligible,
		"rejected": rejected,
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	if str(payload.get("repair_report_hash", "")) == "":
		errors.append("candidate selection requires a repair report hash")
	if str(payload.get("selected_candidate_id", "")) == "" or \
			str(payload.get("selected_plan_hash", "")) == "":
		errors.append("candidate selection requires a selected valid plan")
	if payload.get("eligible", []).is_empty():
		errors.append("candidate selection requires at least one eligible candidate")
	var selected_found := false
	for candidate in payload.get("eligible", []):
		if str(candidate.get("id", "")) == str(payload.get("selected_candidate_id", "")):
			selected_found = str(candidate.get("plan_hash", "")) == \
				str(payload.get("selected_plan_hash", ""))
	if not selected_found:
		errors.append("selected candidate must be present in eligible records")
	return errors

static func from_canonical_dict(record: Dictionary):
	var canonical := load("res://addons/polyforge/core/canonical_artifact.gd")
	var source: Dictionary = canonical.decanonicalize(record.get("payload", {}))
	return load("res://addons/polyforge/core/candidate_selection.gd").new(
		str(source.get("repair_report_hash", "")),
		str(source.get("selected_candidate_id", "")),
		str(source.get("selected_plan_hash", "")), source.get("objectives", []),
		source.get("eligible", []), source.get("rejected", []),
		str(record.get("producer_version", "")))
