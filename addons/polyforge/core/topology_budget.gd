extends RefCounted
## Deterministic authored topology selection and triangle accounting.
##
## Segment selection works in projected pixels so recipes can choose the cheapest
## primitive that still satisfies a play-size silhouette error. Statistics distinguish
## rendered triangles from unique mesh-resource storage: repeated Component instances
## contribute to rendered cost but share one unique mesh cost.

const Lint := preload("res://addons/polyforge/quality/lint_core.gd")

const QUALITY_PROFILES := {
	"preview": {"silhouette_error_px": 1.25, "maximum_radial_segments": 12,
		"maximum_bend_degrees": 30.0},
	"runtime": {"silhouette_error_px": 0.75, "maximum_radial_segments": 18,
		"maximum_bend_degrees": 22.5},
	"hero": {"silhouette_error_px": 0.35, "maximum_radial_segments": 32,
		"maximum_bend_degrees": 12.0},
}

static func profile(name := "runtime", overrides := {}) -> Dictionary:
	var key := str(name)
	assert(QUALITY_PROFILES.has(key), "unknown topology quality profile: " + key)
	var result: Dictionary = QUALITY_PROFILES[key].duplicate(true)
	result.name = key
	for field in overrides:
		result[field] = overrides[field]
	assert(float(result.silhouette_error_px) > 0.0,
		"silhouette_error_px must be positive")
	assert(int(result.maximum_radial_segments) >= 3,
		"maximum_radial_segments must be at least 3")
	assert(float(result.maximum_bend_degrees) > 0.0,
		"maximum_bend_degrees must be positive")
	return result

static func radial_segments(projected_radius_px: float, supplied_profile := {},
		minimum := 3) -> int:
	var quality := profile("runtime") if supplied_profile.is_empty() else supplied_profile
	var radius := maxf(projected_radius_px, 0.0)
	var error := float(quality.silhouette_error_px)
	var maximum := int(quality.maximum_radial_segments)
	if radius <= error:
		return mini(maximum, maxi(minimum, 3))
	# Polygon sagitta: error = radius * (1 - cos(PI / segments)).
	var cosine := clampf(1.0 - error / radius, -1.0, 1.0)
	var angle := acos(cosine)
	var selected := maximum if angle <= 0.0000001 else ceili(PI / angle)
	return clampi(selected, maxi(minimum, 3), maximum)

static func sweep_subdivisions(path: Array, supplied_profile := {}) -> int:
	var quality := profile("runtime") if supplied_profile.is_empty() else supplied_profile
	if path.size() < 3:
		return maxi(path.size() - 1, 1)
	var total_bend := 0.0
	for index in range(1, path.size() - 1):
		var incoming: Vector3 = (path[index] - path[index - 1]).normalized()
		var outgoing: Vector3 = (path[index + 1] - path[index]).normalized()
		if incoming.is_zero_approx() or outgoing.is_zero_approx():
			continue
		total_bend += rad_to_deg(acos(clampf(incoming.dot(outgoing), -1.0, 1.0)))
	return maxi(path.size() - 1, ceili(total_bend / float(quality.maximum_bend_degrees)))

static func _component_key(part: Dictionary) -> String:
	var path := str(part.get("component_path", ""))
	if path != "":
		return path.get_slice("/", 0)
	var component_id := str(part.get("component_id", ""))
	return component_id if component_id != "" else str(part.name)

static func statistics(parts: Array, quality_profile := "runtime") -> Dictionary:
	var rendered := 0
	var unique := 0
	var seen_meshes := {}
	var components := {}
	var constructions := {}
	var roles := {}
	for part in parts:
		var triangles := Lint.triangle_count(part.mesh)
		rendered += triangles
		var mesh_id: int = part.mesh.get_instance_id()
		if not seen_meshes.has(mesh_id):
			seen_meshes[mesh_id] = true
			unique += triangles
		var component := _component_key(part)
		components[component] = int(components.get(component, 0)) + triangles
		var surface = part.get("surface", {})
		if surface is Dictionary:
			var construction := str(surface.get("construction", "unclassified"))
			var role := str(surface.get("role", "unclassified"))
			constructions[construction] = int(constructions.get(construction, 0)) + triangles
			roles[role] = int(roles.get(role, 0)) + triangles
	return {
		"quality_profile": str(quality_profile),
		"rendered_triangles": rendered,
		"unique_triangles": unique,
		"components": components,
		"constructions": constructions,
		"roles": roles,
	}

static func evaluate(parts: Array, policy := {}, legacy_rendered_budget := -1) -> Dictionary:
	var normalized := policy.duplicate(true) if policy is Dictionary else {}
	var quality_name := str(normalized.get("quality_profile", "runtime"))
	var stats := statistics(parts, quality_name)
	var failures := PackedStringArray()
	var warnings := PackedStringArray()
	var rendered_budget := int(normalized.get("rendered_triangles", legacy_rendered_budget))
	var unique_budget := int(normalized.get("unique_triangles", -1))
	var waiver_reason := str(normalized.get("waiver_reason", "")).strip_edges()
	if rendered_budget > 0 and int(stats.rendered_triangles) > rendered_budget:
		var message := "rendered triangle budget: %d > %d" % [
			int(stats.rendered_triangles), rendered_budget]
		if waiver_reason == "": failures.append(message)
		else: warnings.append(message + " (waived: " + waiver_reason + ")")
	if unique_budget > 0 and int(stats.unique_triangles) > unique_budget:
		var message := "unique triangle budget: %d > %d" % [
			int(stats.unique_triangles), unique_budget]
		if waiver_reason == "": failures.append(message)
		else: warnings.append(message + " (waived: " + waiver_reason + ")")
	var component_budgets = normalized.get("components", {})
	if component_budgets is Dictionary:
		for raw_name in component_budgets:
			var name := str(raw_name)
			var budget := int(component_budgets[raw_name])
			var actual := int(stats.components.get(name, 0))
			if budget > 0 and actual > budget:
				var message := "component %s triangle budget: %d > %d" % [name, actual, budget]
				if waiver_reason == "": failures.append(message)
				else: warnings.append(message + " (waived: " + waiver_reason + ")")
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"policy": normalized, "statistics": stats}
