extends RefCounted
## Independently recomputes rigid hard constraints from plan, catalog, and transforms.

const SocketContract := preload("res://addons/polyforge/core/socket_contract.gd")

static func _diagnostic(code: String, message: String, entities := [], extra := {}) -> Dictionary:
	var result := extra.duplicate(true)
	result.merge({"code": code, "severity": "error", "message": message,
		"entities": entities}, true)
	return result

static func _instance_map(plan) -> Dictionary:
	var result := {}
	for instance in plan.payload.instances:
		result[str(instance.id)] = instance
	return result

static func _endpoint(catalog, instances: Dictionary, endpoint: Dictionary) -> Dictionary:
	var instance_id := str(endpoint.get("instance", ""))
	if not instances.has(instance_id):
		return {}
	var component_id := str(instances[instance_id].component_id)
	var socket: Dictionary = catalog.socket(component_id, str(endpoint.get("socket", "")))
	if socket.is_empty():
		return {}
	return {"instance_id": instance_id, "component_id": component_id,
		"socket_name": str(endpoint.get("socket", "")),
		"local_transform": socket.transform, "contract": socket.contract}

static func _residual(expected: Transform3D, actual: Transform3D) -> Dictionary:
	var delta := expected.affine_inverse() * actual
	return {"position": delta.origin.length(), "rotation_degrees":
		absf(rad_to_deg(Quaternion(delta.basis.orthonormalized()).get_angle()))}

static func evaluate(catalog, plan, solution: Dictionary) -> Dictionary:
	var diagnostics := []
	var measurements := []
	if plan == null or str(plan.get("artifact_type")) != "assembly_plan":
		return {"ok": false, "diagnostics": [_diagnostic("VALIDATION_PLAN_REQUIRED",
			"rigid validation requires an AssemblyPlan")], "measurements": [], "metrics": {}}
	if str(plan.payload.catalog_hash) != catalog.content_hash():
		diagnostics.append(_diagnostic("VALIDATION_CATALOG_HASH_MISMATCH",
			"plan and active catalog differ"))
	var instances := _instance_map(plan)
	var transforms: Dictionary = solution.get("transforms", {})
	for instance_id in instances:
		if not transforms.has(instance_id) or not transforms[instance_id] is Transform3D:
			diagnostics.append(_diagnostic("VALIDATION_TRANSFORM_MISSING",
				"candidate has no valid instance transform", [instance_id]))
	for instance_id in transforms:
		if not instances.has(instance_id):
			diagnostics.append(_diagnostic("VALIDATION_UNKNOWN_TRANSFORM",
				"candidate contains an unknown instance transform", [instance_id]))
	if not diagnostics.is_empty():
		return {"ok": false, "diagnostics": diagnostics,
			"measurements": measurements, "metrics": {}}
	var usage := {}
	var max_position := 0.0
	var max_rotation := 0.0
	for instance_id in instances:
		var instance: Dictionary = instances[instance_id]
		if instance.has("fixed_transform") or instance_id == str(plan.payload.root_instance):
			var expected_fixed: Transform3D = instance.get("fixed_transform",
				Transform3D.IDENTITY)
			var fixed_residual := _residual(expected_fixed, transforms[instance_id])
			var fixed_ok: bool = fixed_residual.position <= 0.000001 and \
				fixed_residual.rotation_degrees <= 0.0001
			measurements.append({"kind": "fixed_transform", "instance": instance_id,
				"position": fixed_residual.position,
				"rotation_degrees": fixed_residual.rotation_degrees, "ok": fixed_ok})
			if not fixed_ok:
				diagnostics.append(_diagnostic("VALIDATION_FIXED_TRANSFORM_CHANGED",
					"candidate changed a fixed instance transform", [instance_id],
					fixed_residual))
	for connection in plan.payload.connections:
		var id := str(connection.id)
		var a := _endpoint(catalog, instances, connection.a)
		var b := _endpoint(catalog, instances, connection.b)
		if a.is_empty() or b.is_empty():
			diagnostics.append(_diagnostic("VALIDATION_ENDPOINT_MISSING",
				"connection endpoint cannot be resolved", [id]))
			continue
		if not SocketContract.compatible(a.contract, b.contract):
			diagnostics.append(_diagnostic("VALIDATION_SOCKET_TYPE_MISMATCH",
				"connection socket contracts are incompatible", [id]))
		var twist := float(connection.get("twist_degrees", 0.0))
		if not SocketContract.twist_allowed(a.contract, twist) or \
				not SocketContract.twist_allowed(b.contract, twist):
			diagnostics.append(_diagnostic("VALIDATION_ORIENTATION_UNSUPPORTED",
				"connection twist is not allowed", [id], {"measured": twist}))
		for endpoint in [a, b]:
			var key := "%s/%s" % [endpoint.instance_id, endpoint.socket_name]
			usage[key] = int(usage.get(key, 0)) + 1
			if int(usage[key]) > int(endpoint.contract.cardinality):
				diagnostics.append(_diagnostic("VALIDATION_CARDINALITY_EXCEEDED",
					"socket connection count exceeds cardinality", [id, key]))
		var expected: Transform3D = transforms[a.instance_id] * a.local_transform * \
			SocketContract.twist_transform(twist)
		var actual: Transform3D = transforms[b.instance_id] * b.local_transform
		var residual := _residual(expected, actual)
		var position_tolerance := minf(float(a.contract.position_tolerance),
			float(b.contract.position_tolerance))
		var rotation_tolerance := minf(float(a.contract.rotation_tolerance_degrees),
			float(b.contract.rotation_tolerance_degrees))
		var ok: bool = residual.position <= position_tolerance and \
			residual.rotation_degrees <= rotation_tolerance
		measurements.append({"kind": "socket_residual", "connection": id,
			"position": residual.position, "rotation_degrees": residual.rotation_degrees,
			"position_tolerance": position_tolerance,
			"rotation_tolerance_degrees": rotation_tolerance, "ok": ok})
		max_position = maxf(max_position, residual.position)
		max_rotation = maxf(max_rotation, residual.rotation_degrees)
		if not ok:
			diagnostics.append(_diagnostic("VALIDATION_LOOP_INCONSISTENT",
				"independent connection residual exceeds tolerance", [id], residual))
	var minimum_margin := INF
	for instance_id in transforms:
		var component_id := str(instances[instance_id].component_id)
		for volume in catalog.descriptor(component_id).get("clearance_volumes", []):
			var center: Vector3 = transforms[instance_id] * volume.center
			for keepout in plan.payload.get("keepouts", []):
				if str(keepout.get("allow_instance", "")) == instance_id:
					continue
				var required := float(volume.radius) + float(keepout.radius)
				var measured := center.distance_to(keepout.center)
				var margin := measured - required
				minimum_margin = minf(minimum_margin, margin)
				var ok := margin >= -0.000001
				measurements.append({"kind": "clearance", "instance": instance_id,
					"volume": volume.id, "keepout": keepout.id,
					"measured": measured, "required": required,
					"margin": margin, "ok": ok})
				if not ok:
					diagnostics.append(_diagnostic("VALIDATION_CLEARANCE_BLOCKED",
						"independent clearance check intersects keepout",
						[instance_id, volume.id, keepout.id],
						{"measured": measured, "required": required}))
	if is_inf(minimum_margin):
		minimum_margin = 0.0
	return {"ok": diagnostics.is_empty(), "diagnostics": diagnostics,
		"measurements": measurements, "metrics": {
			"max_position_residual": max_position,
			"max_rotation_residual": max_rotation,
			"minimum_clearance_margin": minimum_margin}}
