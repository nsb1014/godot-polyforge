extends RefCounted
## Scoped symmetry contracts for reusable component instances.

static func _find_instance(assembly, path: String):
	for instance in assembly.component_instances:
		if str(instance.instance_path) == path:
			return instance
	return null

static func _reflected(value: Vector3, axis: int, center: float) -> Vector3:
	var result := value
	result[axis] = center - (value[axis] - center)
	return result

static func _rigid(transform: Transform3D, tolerance: float) -> bool:
	var scale := transform.basis.get_scale().abs()
	return scale.distance_to(Vector3.ONE) <= tolerance

static func evaluate(assembly, contracts: Array) -> Dictionary:
	var failures := PackedStringArray()
	var measurements := []
	for contract in contracts:
		var name := str(contract.get("name", "symmetry"))
		var first_path := str(contract.get("first", ""))
		var second_path := str(contract.get("second", ""))
		var first = _find_instance(assembly, first_path)
		var second = _find_instance(assembly, second_path)
		if first == null or second == null:
			failures.append("%s: component instances '%s' and '%s' must both exist" % [
				name, first_path, second_path])
			continue
		if str(first.component_id) != str(second.component_id):
			failures.append("%s: paired instances use different components (%s vs %s)" % [
				name, first.component_id, second.component_id])
		var axis_name := str(contract.get("axis", "z"))
		var axis: int = int({"x": 0, "y": 1, "z": 2}.get(axis_name, -1))
		if axis < 0:
			failures.append("%s: symmetry axis must be x, y, or z" % name)
			continue
		var tolerance := float(contract.get("tolerance", 0.0001))
		var center := float(contract.get("center", 0.0))
		var expected := _reflected(first.transform.origin, axis, center)
		var error := expected.distance_to(second.transform.origin)
		measurements.append({"name": name, "type": "symmetry_origin_error",
			"value": error, "tolerance": tolerance})
		if error > tolerance:
			failures.append("%s: paired origins differ from %s reflection by %.6f" % [
				name, axis_name, error])
		if not _rigid(first.transform, tolerance) or not _rigid(second.transform, tolerance):
			failures.append("%s: strict component symmetry permits rigid transforms only" % name)
		var first_parts = assembly.part_names_for_instance(first_path)
		var second_parts = assembly.part_names_for_instance(second_path)
		if first_parts.size() != second_parts.size():
			failures.append("%s: paired instances emit different part counts" % name)
			continue
		for index in range(first_parts.size()):
			var first_part = assembly.find(first_parts[index])
			var second_part = assembly.find(second_parts[index])
			if first_part == null or second_part == null or first_part.mesh != second_part.mesh:
				failures.append("%s: paired part %d does not reuse the same mesh resource" % [
					name, index])
				break
	return {"ok": failures.is_empty(), "failures": failures,
		"measurements": measurements}
