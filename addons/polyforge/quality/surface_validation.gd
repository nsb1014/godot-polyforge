extends RefCounted
## Geometry-aware checks selected by component surface semantics.

const Checks := preload("res://addons/polyforge/quality/checks.gd")
const SurfaceTypes := preload("res://addons/polyforge/core/surface_types.gd")

static func _axes(size: Vector3) -> Array[float]:
	return [size.x, size.y, size.z]

static func evaluate(parts: Array, required := false) -> Dictionary:
	var failures := PackedStringArray()
	var warnings := PackedStringArray()
	var measurements := []
	var counts := {}
	for part in parts:
		var descriptor = part.get("surface", {})
		if not descriptor is Dictionary or descriptor.is_empty():
			if required:
				failures.append("%s: surface classification is missing" % part.name)
			continue
		var descriptor_failures := SurfaceTypes.validate(descriptor)
		for failure in descriptor_failures:
			failures.append("%s: %s" % [part.name, failure])
		if not descriptor_failures.is_empty():
			continue
		var construction := str(descriptor.construction)
		var role := str(descriptor.role)
		var key := construction + ":" + role
		counts[key] = int(counts.get(key, 0)) + 1
		var geometry := Checks.geometry(part)
		var axes := _axes(geometry.aabb.size)
		axes.sort()
		var minimum_axis: float = maxf(axes[0], 0.000001)
		var maximum_axis: float = maxf(axes[2], 0.000001)
		if construction == "plate":
			var maximum_thickness_ratio := float(descriptor.get(
				"maximum_thickness_ratio", 0.35))
			var ratio := minimum_axis / maximum_axis
			measurements.append({"part": part.name, "type": "plate_thickness_ratio",
				"value": ratio, "maximum": maximum_thickness_ratio})
			if ratio > maximum_thickness_ratio:
				failures.append("%s: plate thickness ratio %.3f exceeds %.3f" % [
					part.name, ratio, maximum_thickness_ratio])
		elif construction == "prismatic":
			var minimum_slenderness := float(descriptor.get("minimum_slenderness", 1.5))
			var slenderness := maximum_axis / maxf(axes[1], 0.000001)
			measurements.append({"part": part.name, "type": "prismatic_slenderness",
				"value": slenderness, "minimum": minimum_slenderness})
			if slenderness < minimum_slenderness:
				failures.append("%s: prismatic slenderness %.3f is below %.3f" % [
					part.name, slenderness, minimum_slenderness])
		elif construction == "swept" or role == "conduit":
			var radius := float(descriptor.get("radius", 0.0))
			measurements.append({"part": part.name, "type": "conduit_radius",
				"value": radius})
			if radius <= 0.0:
				failures.append("%s: swept/conduit surfaces require a positive radius" % part.name)
		elif construction == "revolved":
			var axis := str(descriptor.get("axis", ""))
			if not axis in ["x", "y", "z"]:
				failures.append("%s: revolved surfaces require axis x, y, or z" % part.name)
		if role == "interface" and str(descriptor.get("socket", "")) == "":
			warnings.append("%s: interface surface has no named socket" % part.name)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"measurements": measurements, "counts": counts}
