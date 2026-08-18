extends "res://addons/polyforge/core/canonical_artifact.gd"
## Separately hashed construction and appearance intent in one authoring object.

func _init(construction := {}, appearance := {}, references := [],
		producer := "polyforge.asset_intent.v1") -> void:
	super("asset_intent", {
		"construction": construction,
		"appearance": appearance,
		"references": references,
	}, 1, producer)

func construction_hash() -> String:
	return hash_value(payload.get("construction", {}))

func appearance_hash() -> String:
	return hash_value(payload.get("appearance", {}))

static func from_canonical_dict(record: Dictionary):
	var source: Dictionary = record.get("payload", {})
	return load("res://addons/polyforge/core/asset_intent.gd").new(
		source.get("construction", {}), source.get("appearance", {}),
		source.get("references", []), str(record.get("producer_version", "")))
