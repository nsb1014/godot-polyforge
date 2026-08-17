extends RefCounted
## Structural rig, skin-binding, and animation-loop validation.

static func _finite_transform(value: Transform3D) -> bool:
	var values := [value.origin.x, value.origin.y, value.origin.z,
		value.basis.x.x, value.basis.x.y, value.basis.x.z,
		value.basis.y.x, value.basis.y.y, value.basis.y.z,
		value.basis.z.x, value.basis.z.y, value.basis.z.z]
	for number in values:
		if not is_finite(number): return false
	return absf(value.basis.determinant()) > 0.0000001

static func _transform_error(first: Transform3D, second: Transform3D) -> float:
	if first == second:
		return 0.0
	var position_error := first.origin.distance_to(second.origin)
	var rotation_error := first.basis.get_rotation_quaternion().angle_to(
		second.basis.get_rotation_quaternion())
	var scale_error := first.basis.get_scale().distance_to(second.basis.get_scale())
	return maxf(position_error, maxf(rotation_error, scale_error))

static func evaluate(rig, assembly, loop_tolerance := 0.0001) -> Dictionary:
	var failures := PackedStringArray()
	var warnings := PackedStringArray()
	var measurements := []
	if rig == null:
		return {"ok": true, "failures": failures, "warnings": warnings,
			"measurements": measurements, "bones": 0, "bindings": 0, "clips": 0}
	var names := PackedStringArray()
	for index in range(rig.bones.size()):
		var bone: Dictionary = rig.bones[index]
		var name := str(bone.get("name", ""))
		var parent := str(bone.get("parent", ""))
		if name == "": failures.append("bone %d has no name" % index)
		if names.has(name): failures.append("duplicate bone name: " + name)
		if parent != "" and not names.has(parent):
			failures.append("bone %s has missing or forward parent %s" % [name, parent])
		var rest = bone.get("rest", Transform3D.IDENTITY)
		if not rest is Transform3D or not _finite_transform(rest):
			failures.append("bone %s has a non-finite or non-invertible rest transform" % name)
		names.append(name)
	for raw_part in rig.bindings:
		var part_name := str(raw_part)
		var part = assembly.find(part_name)
		if part == null:
			failures.append("binding references missing part: " + part_name)
			continue
		var binding: Dictionary = rig.bindings[raw_part]
		var mode := str(binding.get("mode", ""))
		var influences = binding.get("influences", [])
		if not influences is Array or influences.is_empty() or influences.size() > 4:
			failures.append("binding %s must have one to four influences" % part_name)
			continue
		var total := 0.0
		for influence in influences:
			var bone_name := str(influence.get("bone", ""))
			var weight := float(influence.get("weight", -1.0))
			if not names.has(bone_name): failures.append(
				"binding %s references missing bone %s" % [part_name, bone_name])
			if weight < 0.0: failures.append("binding %s has a negative weight" % part_name)
			total += weight
		if absf(total - 1.0) > 0.0001:
			failures.append("binding %s weights total %.6f instead of 1" % [part_name, total])
		if mode == "rigid" and (influences.size() != 1 or
				absf(float(influences[0].weight) - 1.0) > 0.000001):
			failures.append("rigid binding %s must have one weight of 1.0" % part_name)
		elif not mode in ["rigid", "deformable"]:
			failures.append("binding %s has unknown mode %s" % [part_name, mode])
	for clip in rig.clips:
		for bone_name in clip.tracks:
			if not names.has(str(bone_name)):
				failures.append("clip %s animates missing bone %s" % [clip.name, bone_name])
			var keys: Array = clip.tracks[bone_name]
			if keys.is_empty(): continue
			for key in keys:
				if not key.transform is Transform3D or not _finite_transform(key.transform):
					failures.append("clip %s has an invalid %s transform" % [clip.name, bone_name])
			if bool(clip.loop):
				var error := _transform_error(keys[0].transform, keys[-1].transform)
				measurements.append({"clip": clip.name, "bone": bone_name,
					"type": "loop_closure_error", "value": error,
					"maximum": loop_tolerance})
				if error > loop_tolerance:
					failures.append("clip %s bone %s loop error %.6f exceeds %.6f" % [
						clip.name, bone_name, error, loop_tolerance])
	for motion in rig.motion_reports:
		var report: Dictionary = motion.report
		var tolerances: Dictionary = motion.tolerances
		if not bool(report.get("ok", false)):
			failures.append("motion %s did not solve: %s" % [motion.name,
				str(report.get("error", "unknown constraint failure"))])
			continue
		for entry in [
			["maximum_fixed_length_error", float(tolerances.get("fixed_length", 0.0001))],
			["loop_closure_error", float(tolerances.get("loop_closure", loop_tolerance))],
		]:
			var field := str(entry[0])
			var maximum := float(entry[1])
			var value := float(report.get(field, INF))
			measurements.append({"motion": motion.name, "type": field,
				"value": value, "maximum": maximum})
			if value > maximum:
				failures.append("motion %s %s %.6f exceeds %.6f" % [
					motion.name, field, value, maximum])
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"measurements": measurements, "bones": rig.bones.size(),
		"bindings": rig.bindings.size(), "clips": rig.clips.size()}
