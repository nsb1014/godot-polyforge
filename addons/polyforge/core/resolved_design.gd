extends "res://addons/polyforge/core/canonical_artifact.gd"
## Deterministic construction decisions resolved independently of appearance.

func _init(construction_input_hash := "", design := {},
		producer := "polyforge.design_resolver.v1") -> void:
	super("resolved_design", {
		"construction_input_hash": str(construction_input_hash),
		"design": design,
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	if str(payload.get("construction_input_hash", "")) == "":
		errors.append("resolved design requires a construction input hash")
	return errors

static func from_canonical_dict(record: Dictionary):
	var source: Dictionary = record.get("payload", {})
	return load("res://addons/polyforge/core/resolved_design.gd").new(
		str(source.get("construction_input_hash", "")), source.get("design", {}),
		str(record.get("producer_version", "")))
