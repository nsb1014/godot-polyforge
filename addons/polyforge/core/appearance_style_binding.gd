extends "res://addons/polyforge/core/canonical_artifact.gd"
## Appearance-only bindings. Slot specs cannot carry geometry-affecting capabilities.

func _init(appearance_input_hash := "", slots := {},
		producer := "polyforge.appearance_binding.v1") -> void:
	super("appearance_style_binding", {
		"appearance_input_hash": str(appearance_input_hash),
		"slots": slots,
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	if str(payload.get("appearance_input_hash", "")) == "":
		errors.append("appearance binding requires an appearance input hash")
	var slots: Dictionary = payload.get("slots", {})
	for slot_id in slots:
		var spec = slots[slot_id]
		if str(slot_id) == "":
			errors.append("appearance slot IDs must not be empty")
		if not spec is Dictionary:
			errors.append("appearance slot %s must be a dictionary" % slot_id)
		elif bool(spec.get("affects_geometry", false)):
			errors.append("appearance slot %s declares geometry-affecting behavior" % slot_id)
	return errors

func slots() -> Dictionary:
	return payload.get("slots", {})

static func from_canonical_dict(record: Dictionary):
	var source: Dictionary = record.get("payload", {})
	return load("res://addons/polyforge/core/appearance_style_binding.gd").new(
		str(source.get("appearance_input_hash", "")), source.get("slots", {}),
		str(record.get("producer_version", "")))
