extends "res://addons/polyforge/core/canonical_artifact.gd"
## Explicit upstream repair proposal. It never mutates its source plan.

const SUPPORTED_OPERATIONS := ["set_connection_twist"]

func _init(base_plan_hash := "", operator := {}, diagnostic_codes := [],
		operations := [], attempt := 0,
		producer := "polyforge.plan_patch.v1") -> void:
	super("plan_patch", {
		"base_plan_hash": str(base_plan_hash),
		"operator": operator,
		"diagnostic_codes": PackedStringArray(diagnostic_codes),
		"operations": operations,
		"attempt": int(attempt),
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	if str(payload.get("base_plan_hash", "")) == "":
		errors.append("plan patch requires a base plan hash")
	var operator: Dictionary = payload.get("operator", {})
	if str(operator.get("id", "")) == "" or str(operator.get("version", "")) == "":
		errors.append("plan patch requires a versioned operator")
	if int(payload.get("attempt", -1)) < 0:
		errors.append("plan patch attempt must not be negative")
	if payload.get("operations", []).is_empty():
		errors.append("plan patch requires at least one operation")
	var operation_ids := {}
	for operation in payload.get("operations", []):
		var id := str(operation.get("id", ""))
		if id == "" or operation_ids.has(id):
			errors.append("plan patch operations require unique stable IDs")
		operation_ids[id] = true
		var kind := str(operation.get("kind", ""))
		if not SUPPORTED_OPERATIONS.has(kind):
			errors.append("unsupported plan patch operation: %s" % kind)
		if kind == "set_connection_twist":
			if str(operation.get("connection_id", "")) == "":
				errors.append("twist patch requires a connection ID")
			var value = operation.get("twist_degrees")
			if not value is int and not value is float:
				errors.append("twist patch value must be numeric")
			elif not is_finite(float(value)):
				errors.append("twist patch value must be finite")
	return errors

static func from_canonical_dict(record: Dictionary):
	var canonical := load("res://addons/polyforge/core/canonical_artifact.gd")
	var source: Dictionary = canonical.decanonicalize(record.get("payload", {}))
	return load("res://addons/polyforge/core/plan_patch.gd").new(
		str(source.get("base_plan_hash", "")), source.get("operator", {}),
		source.get("diagnostic_codes", []), source.get("operations", []),
		int(source.get("attempt", 0)), str(record.get("producer_version", "")))
