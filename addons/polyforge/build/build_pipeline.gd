extends RefCounted
## Godot-native PolyForge build pipeline.

const Checks := preload("res://addons/polyforge/quality/checks.gd")
const Lint := preload("res://addons/polyforge/quality/lint_core.gd")
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
	if int(spec.triangle_budget) > 0 and triangles > int(spec.triangle_budget):
		failures.append("triangle budget: %d triangles > %d" % [triangles, spec.triangle_budget])
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
				if not bool(entry.get("uniform_scale", false)) or not str(record.label).begins_with(name + "="):
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
			var preserve_error := GLTFExport.write_preserved(spec.name, spec.assembly, preserved_path)
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
		var scene := GLTFExport.scene_from_parts(spec.name, spec.assembly.parts)
		var preview := await PreviewExport.render_contact_sheet(
			tree, scene, _bounds(spec.assembly.parts), preview_path)
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
