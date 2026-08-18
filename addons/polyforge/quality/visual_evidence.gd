extends RefCounted
## Normalized visual evidence. Cross-renderer checks compare measurements, never pixels.

const CanonicalArtifact := preload("res://addons/polyforge/core/canonical_artifact.gd")

static func compile(reference: Dictionary, readability: Dictionary) -> Dictionary:
	var semantic_views := []
	for view in readability.get("views", []):
		var report: Dictionary = view.get("readability", {})
		var visible := {}
		for part_name in view.get("part_visibility", {}):
			var part: Dictionary = view.part_visibility[part_name]
			visible[str(part_name)] = {
				"visible_fraction": part.get("visible_fraction", 0.0),
				"potential_pixels": part.get("potential_pixels", 0),
				"ok": part.get("ok", false),
			}
		semantic_views.append({
			"yaw": view.get("yaw", 0.0),
			"subject_width_px": report.get("width_px", 0.0),
			"subject_height_px": report.get("height_px", 0.0),
			"regions": report.get("regions", 0),
			"contrast": report.get("contrast", 0.0),
			"stroke_px": report.get("stroke_px", 0.0),
			"solidity": report.get("solidity", 0.0),
			"part_visibility": visible,
		})
	var reference_vector := []
	for measurement in reference.get("measurements", []):
		reference_vector.append(measurement)
	var evidence: Dictionary = CanonicalArtifact.canonicalize({
		"schema_version": 1,
		"renderer_policy": {
			"cross_renderer_pixel_comparison": false,
			"canonical_environment": "pinned Godot software-rendered CI",
			"compatibility_gate": "normalized semantic evidence",
			"beauty_baselines": "renderer_scoped",
		},
		"reference_image": reference.get("reference_image", {}),
		"reference_ok": reference.get("ok", true),
		"reference_vector": reference_vector,
		"semantic_render_available": readability.get("available", false),
		"semantic_render_ok": readability.get("ok", false),
		"semantic_views": semantic_views,
	})
	evidence["evidence_hash"] = CanonicalArtifact.hash_value(evidence)
	return evidence
