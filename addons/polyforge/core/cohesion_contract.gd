extends "res://addons/polyforge/core/canonical_artifact.gd"
## Asset-specific cohesion rules. Universal code measures; recipes declare targets.

func _init(design_brief_hash := "", backbone_instances := [],
		backbone_connections := [], interface_grammar := {}, mass_groups := [],
		dominance_rules := [], visual_required := false,
		producer := "polyforge.cohesion_contract.v1") -> void:
	super("cohesion_contract", {
		"design_brief_hash": str(design_brief_hash),
		"backbone_instances": PackedStringArray(backbone_instances),
		"backbone_connections": PackedStringArray(backbone_connections),
		"interface_grammar": interface_grammar,
		"mass_groups": mass_groups,
		"dominance_rules": dominance_rules,
		"visual_required": bool(visual_required),
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	if str(payload.get("design_brief_hash", "")) == "":
		errors.append("cohesion contract requires a design brief hash")
	if payload.get("backbone_instances", []).is_empty():
		errors.append("cohesion contract requires backbone instances")
	if payload.get("backbone_connections", []).is_empty():
		errors.append("cohesion contract requires backbone connections")
	var family := str(payload.get("interface_grammar", {}).get("profile_id", ""))
	if family == "":
		errors.append("cohesion contract requires an interface profile ID")
	var group_ids := PackedStringArray()
	var target_total := 0.0
	for group in payload.get("mass_groups", []):
		var id := str(group.get("id", ""))
		if id == "" or group_ids.has(id):
			errors.append("cohesion mass groups require unique stable IDs")
		else:
			group_ids.append(id)
		var minimum := float(group.get("minimum_share", 0.0))
		var maximum := float(group.get("maximum_share", 1.0))
		if minimum < 0.0 or maximum > 1.0 or minimum > maximum:
			errors.append("cohesion mass group %s has an invalid share band" % id)
		var target := float(group.get("target_share", (minimum + maximum) * 0.5))
		target_total += target
		if target < minimum or target > maximum:
			errors.append("cohesion mass group %s target must be inside its share band" % id)
	if bool(payload.get("visual_required", false)) and group_ids.is_empty():
		errors.append("visual cohesion requires mass groups")
	if not group_ids.is_empty() and not is_equal_approx(target_total, 1.0):
		errors.append("cohesion mass group targets must sum to one")
	for rule in payload.get("dominance_rules", []):
		if not group_ids.has(str(rule.get("higher", ""))) or \
				not group_ids.has(str(rule.get("lower", ""))):
			errors.append("cohesion dominance rules must reference declared mass groups")
		if float(rule.get("minimum_ratio", 1.0)) < 1.0:
			errors.append("cohesion dominance ratios must be at least one")
		if float(rule.get("target_ratio", rule.get("minimum_ratio", 1.0))) < \
				float(rule.get("minimum_ratio", 1.0)):
			errors.append("cohesion dominance target ratios must meet their minimum")
	return errors

static func from_canonical_dict(record: Dictionary):
	var source: Dictionary = record.get("payload", {})
	return load("res://addons/polyforge/core/cohesion_contract.gd").new(
		str(source.get("design_brief_hash", "")),
		source.get("backbone_instances", []), source.get("backbone_connections", []),
		source.get("interface_grammar", {}), source.get("mass_groups", []),
		source.get("dominance_rules", []), bool(source.get("visual_required", false)),
		str(record.get("producer_version", "")))
