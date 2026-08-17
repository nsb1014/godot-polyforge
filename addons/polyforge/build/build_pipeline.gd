extends RefCounted
## Godot-native PolyForge build pipeline.

const Checks := preload("res://addons/polyforge/quality/checks.gd")
const Lint := preload("res://addons/polyforge/quality/lint_core.gd")
const Readability := preload("res://addons/polyforge/quality/readability.gd")
const Attachments := preload("res://addons/polyforge/core/attachments.gd")
const SurfaceValidation := preload("res://addons/polyforge/quality/surface_validation.gd")
const Symmetry := preload("res://addons/polyforge/quality/symmetry.gd")
const TopologyBudget := preload("res://addons/polyforge/core/topology_budget.gd")
const RigValidation := preload("res://addons/polyforge/quality/rig_validation.gd")
const GLTFExport := preload("res://addons/polyforge/exporters/gltf_export.gd")
const ManifestExport := preload("res://addons/polyforge/exporters/manifest_export.gd")
const PreviewExport := preload("res://addons/polyforge/exporters/preview_export.gd")
const ViewerExport := preload("res://addons/polyforge/exporters/viewer_export.gd")

static func default_options() -> Dictionary:
	return {
		"out_dir": "res://dist",
		"mode": "preserve",
		"write_glb": true,
		"write_viewer": true,
		"write_preview": true,
		"measure_readability": true,
		"measure_sweep_readability": true,
		"view_set": "",
		"sweep_view_set": "",
		"viewer_template": "res://addons/polyforge/viewer/template.html",
		"force": false,
		"sweep_specs": [],
	}

static func _safe_name(value: String) -> String:
	var safe := value.to_snake_case()
	for character in ["/", "\\", ":", ".."]:
		safe = safe.replace(character, "_")
	return safe if safe != "" else "asset"

static func _ensure_directory(path: String) -> Error:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

static func _bounds(parts: Array) -> AABB:
	var result := AABB()
	var initialized := false
	for part in parts:
		var geometry := Checks.geometry(part)
		if geometry.vertices.is_empty():
			continue
		result = geometry.aabb if not initialized else result.merge(geometry.aabb)
		initialized = true
	return result

static func validate(spec: Dictionary) -> Dictionary:
	var failures := PackedStringArray()
	var warnings := PackedStringArray()
	var measurements := []
	var triangles := 0
	for failure in spec.parameters.get("errors", PackedStringArray()):
		failures.append("parameters: " + str(failure))
	if spec.assembly.parts.is_empty():
		failures.append("assembly has no named parts")
	if str(spec.front) == "":
		warnings.append("recipe does not declare which direction is front")
	for part in spec.assembly.parts:
		if str(part.name) == "":
			failures.append("assembly contains an unnamed part")
		var part_failures := Lint.check_mesh(part.mesh)
		for failure in part_failures:
			failures.append("%s: %s" % [part.name, failure])
		triangles += Lint.triangle_count(part.mesh)
	var topology_policy: Dictionary = spec.topology_budget.duplicate(true)
	topology_policy.quality_profile = spec.quality_profile
	var topology := TopologyBudget.evaluate(spec.assembly.parts, topology_policy,
		int(spec.triangle_budget))
	for failure in topology.failures:
		failures.append("topology: " + failure)
	for warning in topology.warnings:
		warnings.append("topology: " + warning)
	if not spec.checks.is_empty():
		var semantic := Checks.evaluate(spec.assembly.parts, spec.checks)
		for failure in semantic.failures:
			failures.append(failure)
		measurements = semantic.measurements
	if bool(spec.noclip) and not bool(spec.loose):
		for failure in Checks.noclip(spec.assembly.parts):
			failures.append(failure)
	elif bool(spec.noclip) and bool(spec.loose):
		warnings.append("noclip skipped because recipe declares loose=true")
	var attachment_validation := Attachments.validate(spec.assembly, spec.attachments)
	for failure in attachment_validation.failures:
		failures.append(failure)
	for warning in attachment_validation.warnings:
		warnings.append(warning)
	for measurement in attachment_validation.measurements:
		measurements.append({"type": "attachment", "result": measurement})
	var surface_validation := SurfaceValidation.evaluate(spec.assembly.parts,
		bool(spec.require_surface_classification), bool(spec.require_part_classification))
	for failure in surface_validation.failures:
		failures.append("surface: " + failure)
	for warning in surface_validation.warnings:
		warnings.append("surface: " + warning)
	for measurement in surface_validation.measurements:
		measurements.append({"type": "surface", "result": measurement})
	var symmetry_validation := Symmetry.evaluate(spec.assembly, spec.symmetry)
	for failure in symmetry_validation.failures:
		failures.append("symmetry: " + failure)
	for measurement in symmetry_validation.measurements:
		measurements.append({"type": "symmetry", "result": measurement})
	var rig_validation := RigValidation.evaluate(spec.rig, spec.assembly)
	for failure in rig_validation.failures:
		failures.append("rig: " + failure)
	for warning in rig_validation.warnings:
		warnings.append("rig: " + warning)
	for measurement in rig_validation.measurements:
		measurements.append({"type": "rig", "result": measurement})
	var bounds := _bounds(spec.assembly.parts)
	var anchor_slack := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * 0.25
	for anchor_name in spec.anchors:
		var anchor = spec.anchors[anchor_name]
		if not anchor is Vector3 or not (
				is_finite(anchor.x) and is_finite(anchor.y) and is_finite(anchor.z)):
			failures.append("anchor %s must be a finite Vector3" % anchor_name)
		elif not bounds.grow(anchor_slack).has_point(anchor):
			warnings.append("anchor %s is outside the asset bounds; derive it from the geometry it describes" % anchor_name)
	return {
		"ok": failures.is_empty(),
		"failures": failures,
		"warnings": warnings,
		"measurements": measurements,
		"attachments": attachment_validation,
		"surfaces": surface_validation,
		"symmetry": symmetry_validation,
		"topology": topology,
		"rig": rig_validation,
		"triangles": triangles,
	}

static func validate_sweep(cases: Array) -> Dictionary:
	var records := []
	var failures := PackedStringArray()
	var warnings := PackedStringArray()
	var base_record := {}
	var base_spec := {}
	for test_case in cases:
		var spec: Dictionary = test_case.spec
		var checked := validate(spec)
		var bounds := _bounds(spec.assembly.parts)
		var record := {
			"label": test_case.label,
			"varied": test_case.get("varied", PackedStringArray()),
			"plan": test_case.get("plan", {}),
			"ok": checked.ok,
			"values": spec.parameters.get("values", {}),
			"triangles": checked.triangles,
			"bounds": {"position": bounds.position, "size": bounds.size},
			"failures": checked.failures,
			"warnings": checked.warnings,
		}
		records.append(record)
		if str(test_case.label) == "base":
			base_record = record
			base_spec = spec
			if bool(record.plan.get("truncated", false)):
				warnings.append("parameter sweep capped at %d of %d generated cases" % [
					int(record.plan.case_limit), int(record.plan.generated_cases)])
		else:
			for failure in checked.failures:
				failures.append("parameter sweep %s: %s" % [test_case.label, failure])
			for warning in checked.warnings:
				warnings.append("parameter sweep %s: %s" % [test_case.label, warning])
	if not base_record.is_empty():
		var base_values: Dictionary = base_record.values
		var parameter_schema: Dictionary = base_spec.parameters.get("schema", {})
		for record in records:
			if record.label == "base":
				continue
			for raw_name in parameter_schema:
				var name := str(raw_name)
				var entry: Dictionary = parameter_schema[raw_name]
				if not bool(entry.get("uniform_scale", false)) or \
						record.varied.size() != 1 or not record.varied.has(name):
					continue
				var base_value := float(base_values[name])
				var case_value := float(record.values[name])
				var expected := case_value / maxf(absf(base_value), 0.000000001)
				var tolerance := float(entry.get("scale_tolerance", 0.02))
				var base_size: Vector3 = base_record.bounds.size
				var case_size: Vector3 = record.bounds.size
				var base_axes := [base_size.x, base_size.y, base_size.z]
				var case_axes := [case_size.x, case_size.y, case_size.z]
				for axis in range(3):
					if base_axes[axis] <= 0.000000001:
						continue
					var actual: float = case_axes[axis] / base_axes[axis]
					if absf(actual - expected) > tolerance:
						var message := "%s did not uniformly scale axis %d: measured %.6f, expected %.6f ± %.6f" % [
							name, axis, actual, expected, tolerance]
						record.failures.append(message)
						record.ok = false
						failures.append("parameter sweep %s: %s" % [record.label, message])
	return {"ok": failures.is_empty(), "records": records,
		"failures": failures, "warnings": warnings}

static func _record_error(result: Dictionary, label: String, error: Error) -> void:
	if error != OK:
		result.validation.failures.append("%s failed with error %d" % [label, error])
		result.validation.ok = false
		result.export_ok = false

static func _apply_readability(validation: Dictionary, report: Dictionary,
		required: bool, label := "") -> void:
	var prefix := "play-size readability"
	if label != "":
		prefix = "parameter sweep %s readability" % label
	if not bool(report.get("available", false)):
		var reasons = report.get("issues", PackedStringArray())
		var reason := str(reasons[0]) if not reasons.is_empty() else "renderer unavailable"
		var message := "%s unavailable: %s" % [prefix, reason]
		if required:
			validation.failures.append(message)
		else:
			validation.warnings.append(message)
		return
	for issue in report.issues:
		var message := "%s: %s" % [prefix, issue]
		if required:
			validation.failures.append(message)
		else:
			validation.warnings.append(message)

static func _readability_policy(spec: Dictionary, options: Dictionary,
		for_sweep := false) -> Dictionary:
	var policy := Readability.normalize_policy(str(spec.category), spec.readability)
	var override := str(options.sweep_view_set if for_sweep else options.view_set)
	if override != "":
		policy.view_set = override
	return policy

static func run(tree: SceneTree, spec: Dictionary, supplied_options := {}) -> Dictionary:
	var options := default_options()
	for key in supplied_options:
		options[key] = supplied_options[key]
	assert(["preserve", "merge", "both"].has(options.mode),
		"PolyForge mode must be preserve, merge, or both")
	var validation := validate(spec)
	var sweep := validate_sweep(options.sweep_specs)
	validation.parameter_sweep = sweep.records
	for failure in sweep.failures:
		validation.failures.append(failure)
	for warning in sweep.warnings:
		validation.warnings.append(warning)
	validation.ok = validation.failures.is_empty()
	var result := {"ok": validation.ok, "export_ok": true, "validation": validation,
		"outputs": {}, "inspection": {}}
	if not validation.ok and not bool(options.force):
		return result
	var readability_policy := _readability_policy(spec, options)
	if bool(options.measure_readability) and bool(readability_policy.enabled):
		var readability_scene := GLTFExport.scene_from_parts(spec.name, spec.assembly.parts, spec.rig)
		var readability := await PreviewExport.measure_readability(
			tree, readability_scene, _bounds(spec.assembly.parts), readability_policy)
		validation.readability = readability
		_apply_readability(validation, readability, bool(readability_policy.required))
		if bool(readability.get("available", false)) and bool(options.measure_sweep_readability):
			for case_index in range(options.sweep_specs.size()):
				var test_case: Dictionary = options.sweep_specs[case_index]
				if str(test_case.label) == "base":
					validation.parameter_sweep[case_index].readability = readability
					continue
				var case_spec: Dictionary = test_case.spec
				var case_policy := _readability_policy(case_spec, options, true)
				var case_scene := GLTFExport.scene_from_parts(
					case_spec.name, case_spec.assembly.parts, case_spec.rig)
				var case_readability := await PreviewExport.measure_readability(
					tree, case_scene, _bounds(case_spec.assembly.parts), case_policy)
				validation.parameter_sweep[case_index].readability = case_readability
				_apply_readability(validation, case_readability,
					bool(case_policy.required), str(test_case.label))
				if not bool(case_readability.get("available", false)):
					break
	else:
		validation.readability = {"available": false, "enabled": false,
			"policy": readability_policy}
	validation.ok = validation.failures.is_empty()
	result.ok = validation.ok
	if not validation.ok and not bool(options.force):
		return result
	var dir_error := _ensure_directory(options.out_dir)
	if dir_error != OK:
		_record_error(result, "create output directory", dir_error)
		result.ok = false
		return result
	var base := _safe_name(str(spec.name))
	var merged = null
	if bool(options.write_glb):
		if options.mode == "preserve" or options.mode == "both":
			var preserved_path: String = str(options.out_dir).path_join(base + ".glb")
			var preserve_error := GLTFExport.write_preserved(
				spec.name, spec.assembly, preserved_path, spec.rig)
			_record_error(result, "preserved GLB export", preserve_error)
			if preserve_error == OK:
				result.outputs.glb = preserved_path
				var inspection := GLTFExport.inspect(preserved_path)
				result.inspection.preserved = inspection
				if not inspection.ok:
					result.validation.failures.append("Godot could not re-import preserved GLB")
					result.validation.ok = false
					result.export_ok = false
		if options.mode == "merge" or options.mode == "both":
			var merged_path: String = str(options.out_dir).path_join(
				base + ("_merged.glb" if options.mode == "both" else ".glb"))
			var merge_error := GLTFExport.write_merged(spec.name, spec.assembly, merged_path)
			_record_error(result, "merged GLB export", merge_error)
			if merge_error == OK:
				result.outputs.merged_glb = merged_path
				var inspection := GLTFExport.inspect(merged_path)
				result.inspection.merged = inspection
				if not inspection.ok:
					result.validation.failures.append("Godot could not re-import merged GLB")
					result.validation.ok = false
					result.export_ok = false
	if bool(options.write_viewer):
		merged = spec.assembly.merged_mesh()
		var viewer_json: String = str(options.out_dir).path_join(base + "_viewer.json")
		var viewer_html: String = str(options.out_dir).path_join(base + "_viewer.html")
		var viewer_error := ViewerExport.write_json(merged, viewer_json, spec.name)
		_record_error(result, "viewer JSON export", viewer_error)
		if viewer_error == OK:
			result.outputs.viewer_json = viewer_json
		viewer_error = ViewerExport.write_embedded_html(
			merged, options.viewer_template, viewer_html, spec.name)
		_record_error(result, "embedded viewer export", viewer_error)
		if viewer_error == OK:
			result.outputs.viewer_html = viewer_html
	if bool(options.write_preview):
		var preview_path: String = str(options.out_dir).path_join(base + "_turntable.png")
		var scene := GLTFExport.scene_from_parts(spec.name, spec.assembly.parts, spec.rig)
		var preview := await PreviewExport.render_contact_sheet(
			tree, scene, _bounds(spec.assembly.parts), preview_path,
			Vector2i(420, 500), str(readability_policy.view_set))
		if preview.ok:
			result.outputs.preview = preview_path
		else:
			result.validation.warnings.append(preview.get("message", "preview render unavailable"))
	var manifest_path: String = str(options.out_dir).path_join(base + ".manifest.json")
	result.validation.round_trip = result.inspection
	result.outputs.manifest = manifest_path
	var manifest_error := ManifestExport.write(spec, result.validation, result.outputs, manifest_path)
	_record_error(result, "manifest export", manifest_error)
	result.ok = bool(result.export_ok) and (validation.ok or bool(options.force))
	return result
