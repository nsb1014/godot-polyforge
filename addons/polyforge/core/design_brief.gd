extends "res://addons/polyforge/core/canonical_artifact.gd"
## Immutable semantic design decisions distilled from intent and optional references.

func _init(intent_hash := "", identity := {}, mass_hierarchy := [],
		signature_features := [], shape_vocabulary := [], reference_policy := {},
		producer := "polyforge.design_brief.v1") -> void:
	super("design_brief", {
		"intent_hash": str(intent_hash),
		"identity": identity,
		"mass_hierarchy": mass_hierarchy,
		"signature_features": signature_features,
		"shape_vocabulary": shape_vocabulary,
		"reference_policy": reference_policy,
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	if str(payload.get("intent_hash", "")) == "":
		errors.append("design brief requires an intent hash")
	if str(payload.get("identity", {}).get("archetype", "")) == "":
		errors.append("design brief requires an identity archetype")
	var ids := PackedStringArray()
	for group in payload.get("mass_hierarchy", []):
		var id := str(group.get("id", ""))
		if id == "" or ids.has(id):
			errors.append("design brief mass groups require unique stable IDs")
		else:
			ids.append(id)
		if not ["primary", "secondary", "tertiary"].has(str(group.get("tier", ""))):
			errors.append("design brief mass group %s has an invalid tier" % id)
	return errors

static func from_canonical_dict(record: Dictionary):
	var source: Dictionary = record.get("payload", {})
	return load("res://addons/polyforge/core/design_brief.gd").new(
		str(source.get("intent_hash", "")), source.get("identity", {}),
		source.get("mass_hierarchy", []), source.get("signature_features", []),
		source.get("shape_vocabulary", []), source.get("reference_policy", {}),
		str(record.get("producer_version", "")))
