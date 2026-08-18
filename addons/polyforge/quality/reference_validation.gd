extends RefCounted
## Renderer-independent semantic evidence against a profile extracted from one image.

const Checks := preload("res://addons/polyforge/quality/checks.gd")

static func _bounds(parts: Array) -> AABB:
	var bounds := AABB()
	var initialized := false
	for part in parts:
		var geometry := Checks.geometry(part)
		if geometry.vertices.is_empty():
			continue
		bounds = geometry.aabb if not initialized else bounds.merge(geometry.aabb)
		initialized = true
	return bounds

static func _matches(part: Dictionary, selector: Dictionary) -> bool:
	if selector.get("names", []).has(str(part.name)):
		return true
	for prefix in selector.get("prefixes", []):
		if str(part.name).begins_with(str(prefix)):
			return true
	for tag in selector.get("tags", []):
		if part.get("tags", PackedStringArray()).has(str(tag)):
			return true
	return false

static func _normalized(anchor: Vector3, bounds: AABB) -> Vector3:
	return Vector3(
		(anchor.x - bounds.position.x) / maxf(bounds.size.x, 0.000000001),
		(anchor.y - bounds.position.y) / maxf(bounds.size.y, 0.000000001),
		(anchor.z - bounds.position.z) / maxf(bounds.size.z, 0.000000001))

static func _vector3(value, fallback := Vector3.ZERO) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary and str(value.get("$type", "")) == "Vector3":
		var components: Array = value.get("value", [])
		if components.size() == 3:
			return Vector3(float(components[0]), float(components[1]),
				float(components[2]))
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback

static func evaluate(spec: Dictionary) -> Dictionary:
	var failures := PackedStringArray()
	var measurements := []
	var record: Dictionary = spec.get("reference_profile", {})
	if record.is_empty():
		return {"ok": true, "available": false, "failures": failures,
			"measurements": measurements}
	var profile: Dictionary = record.get("payload", record)
	var parts: Array = spec.assembly.parts
	for group_name in profile.get("semantic_groups", {}):
		var rule: Dictionary = profile.semantic_groups[group_name]
		var count := 0
		for part in parts:
			if _matches(part, rule.get("selector", {})):
				count += 1
		var minimum := int(rule.get("minimum", 1))
		var ok := count >= minimum
		measurements.append({"type": "semantic_group", "name": group_name,
			"count": count, "minimum": minimum, "ok": ok})
		if not ok:
			failures.append("REFERENCE_MISSING_GROUP: %s measured %d required %d" % [
				group_name, count, minimum])
	var bounds := _bounds(parts)
	for anchor_name in profile.get("anchors", {}):
		var rule: Dictionary = profile.anchors[anchor_name]
		if not spec.anchors.has(anchor_name) or not spec.anchors[anchor_name] is Vector3:
			failures.append("REFERENCE_MISSING_ANCHOR: %s" % anchor_name)
			continue
		var normalized := _normalized(spec.anchors[anchor_name], bounds)
		var minimum := _vector3(rule.get("minimum", Vector3.ZERO), Vector3.ZERO)
		var maximum := _vector3(rule.get("maximum", Vector3.ONE), Vector3.ONE)
		var ok := normalized.x >= minimum.x and normalized.y >= minimum.y and \
			normalized.z >= minimum.z and normalized.x <= maximum.x and \
			normalized.y <= maximum.y and normalized.z <= maximum.z
		measurements.append({"type": "anchor", "name": anchor_name,
			"normalized": normalized, "minimum": minimum, "maximum": maximum,
			"ok": ok})
		if not ok:
			failures.append("REFERENCE_ANCHOR_OUT_OF_RANGE: %s" % anchor_name)
	var binding: Dictionary = spec.get("contracts", {}).get("appearance_binding", {})
	var slots: Dictionary = binding.get("payload", {}).get("slots", {})
	for slot_id in profile.get("required_appearance_slots", []):
		var ok := slots.has(str(slot_id))
		measurements.append({"type": "appearance_slot", "name": slot_id, "ok": ok})
		if not ok:
			failures.append("REFERENCE_MISSING_APPEARANCE_SLOT: %s" % slot_id)
	for rule in profile.get("proportions", []):
		var numerator := int(rule.get("numerator_axis", 1))
		var denominator := int(rule.get("denominator_axis", 0))
		var axes := [bounds.size.x, bounds.size.y, bounds.size.z]
		var ratio: float = axes[numerator] / maxf(axes[denominator], 0.000000001)
		var ok := ratio >= float(rule.get("minimum", 0.0)) and \
			ratio <= float(rule.get("maximum", INF))
		measurements.append({"type": "proportion", "name": rule.get("name", "ratio"),
			"ratio": ratio, "minimum": rule.get("minimum", 0.0),
			"maximum": rule.get("maximum", INF), "ok": ok})
		if not ok:
			failures.append("REFERENCE_PROPORTION_OUT_OF_RANGE: %s" % rule.get("name", "ratio"))
	return {"ok": failures.is_empty(), "available": true,
		"reference_image": profile.get("image", {}), "failures": failures,
		"measurements": measurements}
