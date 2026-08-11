extends RefCounted
## Geometry-sampled attachment frames with manifest provenance and regression checks.

const SurfaceAttach := preload("surface_attach.gd")

var assembly
var records: Dictionary = {}

func _init(target_assembly) -> void:
	assembly = target_assembly

func surface(name: String, host_part: String, approximate_position: Vector3,
		options := {}) -> Transform3D:
	assert(name != "", "attachment needs a stable name")
	assert(not records.has(name), "duplicate attachment name: " + name)
	var host = assembly.find(host_part)
	if host == null:
		records[name] = {"valid": false, "host": host_part,
			"query": approximate_position, "message": "unknown host part"}
		return Transform3D(Basis.IDENTITY, approximate_position)
	var hit := SurfaceAttach.closest_point(
		host.mesh, approximate_position, host.get("transform", Transform3D.IDENTITY))
	if not hit.valid:
		records[name] = {"valid": false, "host": host_part,
			"query": approximate_position, "message": "host has no triangle surface"}
		return Transform3D(Basis.IDENTITY, approximate_position)
	var inset := float(options.get("inset", 0.0))
	var heading: Vector3 = options.get("heading", Vector3.FORWARD)
	var frame := SurfaceAttach.frame_from_hit(hit, inset, heading)
	records[name] = {
		"valid": true,
		"host": host_part,
		"child": str(options.get("child", "")),
		"query": approximate_position,
		"position": hit.position,
		"normal": hit.normal,
		"frame": frame,
		"surface": hit.surface,
		"triangle": hit.triangle,
		"hint_distance": hit.distance,
		"inset": inset,
		"heading": heading,
		"max_hint_distance": float(options.get("max_hint_distance", INF)),
		"position_tolerance": float(options.get("position_tolerance", 0.0001)),
	}
	return frame

func snapshot() -> Dictionary:
	return records.duplicate(true)

static func validate(target_assembly, snapshot: Dictionary) -> Dictionary:
	var failures := PackedStringArray()
	var warnings := PackedStringArray()
	var measurements := []
	for raw_name in snapshot:
		var name := str(raw_name)
		var record: Dictionary = snapshot[raw_name]
		if not bool(record.get("valid", false)):
			failures.append("attachment %s is invalid: %s" % [
				name, record.get("message", "surface sample failed")])
			continue
		var host = target_assembly.find(str(record.host))
		if host == null:
			failures.append("attachment %s references unknown host %s" % [name, record.host])
			continue
		var hit := SurfaceAttach.closest_point(
			host.mesh, record.query, host.get("transform", Transform3D.IDENTITY))
		if not hit.valid:
			failures.append("attachment %s host no longer has a triangle surface" % name)
			continue
		var tolerance := maxf(float(record.get("position_tolerance", 0.0001)), 0.0000001)
		var sampled_position: Vector3 = hit.position
		var recorded_position: Vector3 = record.position
		var sampled_normal: Vector3 = hit.normal
		var recorded_normal: Vector3 = record.normal
		var sample_drift: float = sampled_position.distance_to(recorded_position)
		var normal_dot: float = sampled_normal.dot(recorded_normal)
		var hint_distance := float(hit.distance)
		measurements.append({
			"attachment": name,
			"host": record.host,
			"sample_drift": sample_drift,
			"normal_dot": normal_dot,
			"hint_distance": hint_distance,
		})
		if sample_drift > tolerance:
			failures.append("attachment %s surface sample drifted %.6f beyond %.6f" % [
				name, sample_drift, tolerance])
		if normal_dot < 0.99:
			failures.append("attachment %s surface normal changed direction" % name)
		if hint_distance > float(record.get("max_hint_distance", INF)):
			failures.append("attachment %s hint is %.6f from host surface, beyond %.6f" % [
				name, hint_distance, float(record.max_hint_distance)])
		var child_name := str(record.get("child", ""))
		if child_name != "":
			var child = target_assembly.find(child_name)
			if child == null:
				failures.append("attachment %s names missing child %s" % [name, child_name])
			else:
				var child_transform: Transform3D = child.transform
				var recorded_frame: Transform3D = record.frame
				var child_distance: float = child_transform.origin.distance_to(recorded_frame.origin)
				measurements[-1]["child_distance"] = child_distance
				if child_distance > tolerance:
					failures.append("attachment %s child %s moved %.6f from sampled frame" % [
						name, child_name, child_distance])
		if int(record.surface) < 0 or int(record.triangle) < 0:
			warnings.append("attachment %s did not retain a surface/triangle identifier" % name)
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": warnings, "measurements": measurements}
