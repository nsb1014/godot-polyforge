extends "res://addons/polyforge/core/solver_stage.gd"
## Specialized rigid socket propagation, loop verification, and keepout clearance.

const SocketContract := preload("res://addons/polyforge/core/socket_contract.gd")

var catalog

func _init(p_catalog = null) -> void:
	catalog = p_catalog

func descriptor() -> Dictionary:
	return {
		"id": "polyforge.rigid.socket_assembly",
		"version": "1.0.0",
		"problem_types": ["rigid.socket_assembly"],
		"constraint_kinds": ["rigid.socket_mate", "rigid.clearance"],
		"deterministic": true,
		"exact": true,
	}

func supports(problem: Dictionary) -> bool:
	if str(problem.get("problem_type", "")) != "rigid.socket_assembly":
		return false
	for constraint in problem.get("constraints", []):
		if not descriptor().constraint_kinds.has(str(constraint.get("kind", ""))):
			return false
	return problem.get("plan", {}) is Dictionary

func _result(status: String, diagnostics: Array, statistics := {}, solution := {},
		evidence := {}) -> Dictionary:
	return {"status": status, "solution": solution, "evidence": evidence,
		"diagnostics": diagnostics, "provenance": descriptor(),
		"statistics": statistics}

func _diagnostic(code: String, message: String, entities := [], extra := {}) -> Dictionary:
	var result := extra.duplicate(true)
	result["code"] = code
	result["severity"] = "error"
	result["message"] = message
	result["entities"] = entities
	return result

func _instance_map(plan: Dictionary) -> Dictionary:
	var result := {}
	for instance in plan.get("instances", []):
		result[str(instance.get("id", ""))] = instance
	return result

func _endpoint(instance_map: Dictionary, endpoint: Dictionary) -> Dictionary:
	var instance_id := str(endpoint.get("instance", ""))
	if not instance_map.has(instance_id):
		return {"ok": false, "code": "RIGID_UNKNOWN_INSTANCE",
			"message": "unknown instance %s" % instance_id}
	var component_id := str(instance_map[instance_id].get("component_id", ""))
	if not catalog.has(component_id):
		return {"ok": false, "code": "RIGID_UNKNOWN_COMPONENT",
			"message": "unknown component %s" % component_id}
	var socket_name := str(endpoint.get("socket", ""))
	var socket: Dictionary = catalog.socket(component_id, socket_name)
	if socket.is_empty():
		return {"ok": false, "code": "RIGID_UNKNOWN_SOCKET",
			"message": "component %s has no typed socket %s" % [component_id, socket_name]}
	return {"ok": true, "instance_id": instance_id, "component_id": component_id,
		"socket_name": socket_name, "local_transform": socket.transform,
		"contract": socket.contract}

func _world_socket(transforms: Dictionary, endpoint: Dictionary) -> Transform3D:
	return transforms[endpoint.instance_id] * endpoint.local_transform

func _residual(expected: Transform3D, actual: Transform3D) -> Dictionary:
	var delta := expected.affine_inverse() * actual
	var rotation := Quaternion(delta.basis.orthonormalized())
	return {"position": delta.origin.length(),
		"rotation_degrees": absf(rad_to_deg(rotation.get_angle()))}

func _prevalidate(plan: Dictionary, instance_map: Dictionary) -> Array:
	var diagnostics := []
	var usage := {}
	for connection in plan.get("connections", []):
		var connection_id := str(connection.get("id", ""))
		var a := _endpoint(instance_map, connection.get("a", {}))
		var b := _endpoint(instance_map, connection.get("b", {}))
		for endpoint in [a, b]:
			if not bool(endpoint.get("ok", false)):
				diagnostics.append(_diagnostic(str(endpoint.code), str(endpoint.message),
					[connection_id]))
		if not bool(a.get("ok", false)) or not bool(b.get("ok", false)):
			continue
		if a.instance_id == b.instance_id:
			diagnostics.append(_diagnostic("RIGID_SELF_CONNECTION",
				"connection endpoints must belong to different instances", [connection_id]))
			continue
		if not SocketContract.compatible(a.contract, b.contract):
			diagnostics.append(_diagnostic("RIGID_SOCKET_TYPE_MISMATCH",
				"socket types %s and %s do not accept one another" % [
					a.contract.type, b.contract.type], [connection_id,
					"%s/%s" % [a.instance_id, a.socket_name],
					"%s/%s" % [b.instance_id, b.socket_name]], {
						"first_type": a.contract.type, "second_type": b.contract.type}))
		var twist := float(connection.get("twist_degrees", 0.0))
		if not SocketContract.twist_allowed(a.contract, twist) or \
				not SocketContract.twist_allowed(b.contract, twist):
			diagnostics.append(_diagnostic("RIGID_ORIENTATION_UNSUPPORTED",
				"twist %.3f° is not allowed by both sockets" % twist, [connection_id],
				{"twist_degrees": twist}))
		for endpoint in [a, b]:
			var key := "%s/%s" % [endpoint.instance_id, endpoint.socket_name]
			usage[key] = int(usage.get(key, 0)) + 1
			if int(usage[key]) > int(endpoint.contract.get("cardinality", 1)):
				diagnostics.append(_diagnostic("RIGID_SOCKET_CARDINALITY_EXCEEDED",
					"socket %s exceeds cardinality %d" % [key,
						int(endpoint.contract.get("cardinality", 1))], [connection_id, key]))
	return diagnostics

func _clearance(plan: Dictionary, instance_map: Dictionary,
		transforms: Dictionary) -> Dictionary:
	var diagnostics := []
	var measurements := []
	for instance_id in transforms:
		var component_id := str(instance_map[instance_id].component_id)
		var descriptor_record: Dictionary = catalog.descriptor(component_id)
		for volume in descriptor_record.get("clearance_volumes", []):
			var world_center: Vector3 = transforms[instance_id] * volume.get("center", Vector3.ZERO)
			var radius := float(volume.get("radius", 0.0))
			for keepout in plan.get("keepouts", []):
				if str(keepout.get("allow_instance", "")) == instance_id:
					continue
				var required := radius + float(keepout.get("radius", 0.0))
				var measured := world_center.distance_to(keepout.get("center", Vector3.ZERO))
				var ok := measured + 0.000001 >= required
				measurements.append({"instance": instance_id,
					"volume": volume.get("id", "clearance"),
					"keepout": keepout.get("id", "keepout"),
					"measured": measured, "required": required, "ok": ok})
				if not ok:
					diagnostics.append(_diagnostic("RIGID_CLEARANCE_BLOCKED",
						"clearance volume intersects keepout", [instance_id,
							volume.get("id", "clearance"), keepout.get("id", "keepout")],
						{"measured": measured, "required": required}))
	return {"ok": diagnostics.is_empty(), "diagnostics": diagnostics,
		"measurements": measurements}

func solve(problem: Dictionary, context := {}) -> Dictionary:
	if not supports(problem):
		return super(problem, context)
	if catalog == null:
		return _result("error", [_diagnostic("RIGID_CATALOG_MISSING",
			"rigid solver requires a component catalog")])
	var plan: Dictionary = problem.plan
	if str(plan.get("catalog_hash", "")) != catalog.content_hash():
		return _result("error", [_diagnostic("RIGID_CATALOG_HASH_MISMATCH",
			"plan catalog hash does not match the active catalog")])
	var instance_map := _instance_map(plan)
	var diagnostics := _prevalidate(plan, instance_map)
	if not diagnostics.is_empty():
		return _result("unsatisfiable", diagnostics,
			{"placements": 0, "passes": 0})
	var root_id := str(plan.get("root_instance", ""))
	if not instance_map.has(root_id):
		return _result("error", [_diagnostic("RIGID_ROOT_MISSING",
			"root instance is absent", [root_id])])
	var transforms := {}
	for instance_id in instance_map:
		var instance: Dictionary = instance_map[instance_id]
		if instance.has("fixed_transform"):
			transforms[instance_id] = instance.fixed_transform
	transforms[root_id] = instance_map[root_id].get("fixed_transform", Transform3D.IDENTITY)
	var max_passes := maxi(1, int(context.get("max_passes", instance_map.size() + 1)))
	var passes := 0
	while transforms.size() < instance_map.size() and passes < max_passes:
		passes += 1
		var progress := false
		for connection in plan.connections:
			var a := _endpoint(instance_map, connection.a)
			var b := _endpoint(instance_map, connection.b)
			var a_known := transforms.has(a.instance_id)
			var b_known := transforms.has(b.instance_id)
			var twist := SocketContract.twist_transform(
				float(connection.get("twist_degrees", 0.0)))
			if a_known and not b_known:
				var target_b := _world_socket(transforms, a) * twist
				transforms[b.instance_id] = target_b * b.local_transform.affine_inverse()
				progress = true
			elif b_known and not a_known:
				var target_a := _world_socket(transforms, b) * twist.affine_inverse()
				transforms[a.instance_id] = target_a * a.local_transform.affine_inverse()
				progress = true
		if not progress:
			break
	if transforms.size() != instance_map.size():
		var missing := PackedStringArray()
		for instance_id in instance_map:
			if not transforms.has(instance_id):
				missing.append(instance_id)
		return _result("unsatisfiable", [_diagnostic("RIGID_DISCONNECTED_GRAPH",
			"not every instance is reachable from a fixed root", missing)],
			{"placements": transforms.size(), "passes": passes})
	var residuals := []
	for connection in plan.connections:
		var a := _endpoint(instance_map, connection.a)
		var b := _endpoint(instance_map, connection.b)
		var expected := _world_socket(transforms, a) * SocketContract.twist_transform(
			float(connection.get("twist_degrees", 0.0)))
		var actual := _world_socket(transforms, b)
		var residual := _residual(expected, actual)
		var position_tolerance := minf(float(a.contract.position_tolerance),
			float(b.contract.position_tolerance))
		var rotation_tolerance := minf(float(a.contract.rotation_tolerance_degrees),
			float(b.contract.rotation_tolerance_degrees))
		var ok: bool = residual.position <= position_tolerance and \
			residual.rotation_degrees <= rotation_tolerance
		residuals.append({"connection": connection.id,
			"position": residual.position, "rotation_degrees": residual.rotation_degrees,
			"position_tolerance": position_tolerance,
			"rotation_tolerance_degrees": rotation_tolerance, "ok": ok})
		if not ok:
			diagnostics.append(_diagnostic("RIGID_LOOP_INCONSISTENT",
				"connection closure exceeds socket tolerance", [connection.id], residual))
	var clearance := _clearance(plan, instance_map, transforms)
	for diagnostic in clearance.diagnostics:
		diagnostics.append(diagnostic)
	if not diagnostics.is_empty():
		return _result("unsatisfiable", diagnostics,
			{"placements": transforms.size(), "passes": passes}, {},
			{"residuals": residuals, "clearance": clearance.measurements})
	return _result("solved", [], {"placements": transforms.size(),
		"passes": passes, "connections": plan.connections.size()}, {
		"instances": plan.instances,
		"transforms": transforms,
		"connections": plan.connections,
		"residuals": residuals,
		"clearance": clearance.measurements,
	}, {"residuals": residuals, "clearance": clearance.measurements})
