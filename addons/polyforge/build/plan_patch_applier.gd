extends RefCounted
## Applies only whitelisted operations to a duplicate plan and enforces author locks.

const AssemblyPlan := preload("res://addons/polyforge/core/assembly_plan.gd")

static func _failure(code: String, message: String, entities := []) -> Dictionary:
	return {"code": code, "severity": "error", "message": message,
		"entities": entities}

static func apply(plan, patch) -> Dictionary:
	if plan == null or str(plan.get("artifact_type")) != "assembly_plan":
		return {"ok": false, "diagnostics": [_failure("PATCH_PLAN_REQUIRED",
			"plan patch applier requires an AssemblyPlan")]}
	if patch == null or str(patch.get("artifact_type")) != "plan_patch":
		return {"ok": false, "diagnostics": [_failure("PATCH_ARTIFACT_REQUIRED",
			"plan patch applier requires a PlanPatch")]}
	var plan_errors: PackedStringArray = plan.validate()
	if not plan_errors.is_empty():
		return {"ok": false, "diagnostics": [_failure("PATCH_SOURCE_PLAN_INVALID",
			"; ".join(plan_errors))]}
	var patch_errors: PackedStringArray = patch.validate()
	if not patch_errors.is_empty():
		return {"ok": false, "diagnostics": [_failure("PATCH_INVALID",
			"; ".join(patch_errors))]}
	if str(patch.payload.base_plan_hash) != plan.content_hash():
		return {"ok": false, "diagnostics": [_failure("PATCH_BASE_HASH_MISMATCH",
			"patch does not target the supplied plan")]}
	var source: Dictionary = plan.payload.duplicate(true)
	var locks := PackedStringArray(source.get("locks", []))
	for operation in patch.payload.operations:
		var kind := str(operation.kind)
		if kind == "set_connection_twist":
			var connection_id := str(operation.connection_id)
			var parent_lock := "connection:%s" % connection_id
			var field_lock := "%s.twist_degrees" % parent_lock
			if locks.has(parent_lock) or locks.has(field_lock):
				return {"ok": false, "diagnostics": [_failure("PATCH_TARGET_LOCKED",
					"repair cannot modify locked connection twist",
					[connection_id, field_lock])]}
			var found := false
			for index in range(source.connections.size()):
				if str(source.connections[index].get("id", "")) == connection_id:
					source.connections[index]["twist_degrees"] = float(
						operation.twist_degrees)
					found = true
					break
			if not found:
				return {"ok": false, "diagnostics": [_failure("PATCH_TARGET_MISSING",
					"repair references an unknown connection", [connection_id])]}
		else:
			return {"ok": false, "diagnostics": [_failure("PATCH_OPERATION_UNSUPPORTED",
				"unsupported patch operation", [kind])]}
	var result := AssemblyPlan.new(source.design_hash, source.catalog_hash,
		source.root_instance, source.instances, source.connections,
		source.get("keepouts", []), "polyforge.plan_patch_applier.v1",
		source.get("locks", []))
	var errors: PackedStringArray = result.validate()
	if not errors.is_empty():
		return {"ok": false, "diagnostics": [_failure("PATCH_RESULT_INVALID",
			"; ".join(errors))]}
	return {"ok": true, "plan": result, "diagnostics": []}
