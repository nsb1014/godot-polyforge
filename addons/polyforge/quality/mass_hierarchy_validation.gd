extends RefCounted
## Multi-view projected-area hierarchy measured against recipe-declared bands.

static func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var ordered: Array = values.duplicate()
	ordered.sort()
	var middle := ordered.size() / 2
	if ordered.size() % 2 == 1:
		return float(ordered[middle])
	return (float(ordered[middle - 1]) + float(ordered[middle])) * 0.5

static func _median_absolute_deviation(values: Array, center: float) -> float:
	var deviations := []
	for value in values:
		deviations.append(absf(float(value) - center))
	return _median(deviations)

static func _issue(required: bool, message: String, failures: PackedStringArray,
		warnings: PackedStringArray) -> void:
	if required:
		failures.append(message)
	else:
		warnings.append(message)

static func evaluate(readability: Dictionary, cohesion_record: Dictionary) -> Dictionary:
	var failures := PackedStringArray()
	var warnings := PackedStringArray()
	var measurements := []
	if cohesion_record.is_empty():
		return {"ok": true, "available": false, "failures": failures,
			"warnings": warnings, "measurements": measurements, "score": 1.0,
			"confidence": 0.0}
	var contract: Dictionary = cohesion_record.get("payload", cohesion_record)
	var groups: Array = contract.get("mass_groups", [])
	var required := bool(contract.get("visual_required", false))
	if groups.is_empty():
		return {"ok": true, "available": false, "failures": failures,
			"warnings": warnings, "measurements": measurements, "score": 1.0,
			"confidence": 0.0}
	if not bool(readability.get("available", false)):
		_issue(required, "MASS_HIERARCHY_RENDER_UNAVAILABLE", failures, warnings)
		return {"ok": failures.is_empty(), "available": false, "failures": failures,
			"warnings": warnings, "measurements": measurements, "score": 0.0,
			"confidence": 0.0}
	var shares_by_id := {}
	for group in groups:
		shares_by_id[str(group.id)] = []
	for view in readability.get("views", []):
		var total := 0.0
		for group in groups:
			total += float(view.get("part_visibility", {}).get(str(group.id), {}).get(
				"potential_pixels", 0))
		if total <= 0.0:
			continue
		for group in groups:
			var id := str(group.id)
			var pixels := float(view.get("part_visibility", {}).get(id, {}).get(
				"potential_pixels", 0))
			shares_by_id[id].append(pixels / total)
	var medians := {}
	var quality := []
	var stability := []
	for group in groups:
		var id := str(group.id)
		var share := _median(shares_by_id[id])
		var minimum := float(group.get("minimum_share", 0.0))
		var maximum := float(group.get("maximum_share", 1.0))
		var target := float(group.get("target_share", (minimum + maximum) * 0.5))
		var deviation := _median_absolute_deviation(shares_by_id[id], share)
		var ok: bool = not shares_by_id[id].is_empty() and share >= minimum and \
			share <= maximum
		medians[id] = share
		var target_span := maxf(target - minimum if share <= target else maximum - target,
			0.000001)
		var target_score := clampf(1.0 - absf(share - target) / target_span, 0.0, 1.0)
		measurements.append({"type": "mass_share", "group": id,
			"tier": str(group.get("tier", "")), "median_share": snappedf(share, 0.001),
			"minimum": minimum, "target": target, "maximum": maximum,
			"median_absolute_deviation": snappedf(deviation, 0.001),
			"target_score": snappedf(target_score, 0.001),
			"samples": shares_by_id[id].size(), "ok": ok})
		if not ok:
			_issue(required,
				"MASS_HIERARCHY_SHARE_OUT_OF_RANGE: %s measured %.3f required %.3f..%.3f" % [
					id, share, minimum, maximum], failures, warnings)
		quality.append(target_score)
		stability.append(clampf(1.0 - deviation / maxf(share, 0.000001), 0.0, 1.0))
	for rule in contract.get("dominance_rules", []):
		var higher := str(rule.get("higher", ""))
		var lower := str(rule.get("lower", ""))
		var minimum_ratio := float(rule.get("minimum_ratio", 1.0))
		var target_ratio := float(rule.get("target_ratio", minimum_ratio * 1.5))
		var ratio := float(medians.get(higher, 0.0)) / maxf(
			float(medians.get(lower, 0.0)), 0.000001)
		var ok: bool = ratio >= minimum_ratio
		var target_score := clampf((ratio - 1.0) / maxf(target_ratio - 1.0, 0.000001),
			0.0, 1.0)
		measurements.append({"type": "dominance", "higher": higher, "lower": lower,
			"ratio": snappedf(ratio, 0.001), "minimum_ratio": minimum_ratio,
			"target_ratio": target_ratio, "target_score": snappedf(target_score, 0.001),
			"ok": ok})
		if not ok:
			_issue(required,
				"MASS_HIERARCHY_DOMINANCE_FAILED: %s/%s measured %.3f required %.3f" % [
					higher, lower, ratio, minimum_ratio], failures, warnings)
		quality.append(target_score)
	var score := 1.0
	if not quality.is_empty():
		score = 0.0
		for value in quality:
			score += float(value)
		score /= float(quality.size())
	var confidence := float(shares_by_id.values()[0].size()) / maxf(
		float(readability.get("views", []).size()), 1.0)
	if not stability.is_empty():
		var stability_mean := 0.0
		for value in stability:
			stability_mean += float(value)
		confidence *= stability_mean / float(stability.size())
	return {"ok": failures.is_empty(), "available": true, "required": required,
		"failures": failures, "warnings": warnings, "measurements": measurements,
		"median_shares": medians, "score": snappedf(score, 0.001),
		"confidence": snappedf(confidence, 0.001),
		"valid_views": shares_by_id.values()[0].size(),
		"requested_views": readability.get("views", []).size()}
