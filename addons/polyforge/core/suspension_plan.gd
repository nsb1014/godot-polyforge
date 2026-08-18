extends "res://addons/polyforge/core/canonical_artifact.gd"
## Tension members bound to immutable solved component transforms and geometry.

func _init(solved_assembly_hash := "", input_geometry_hash := "", members := [],
		producer := "polyforge.suspension_planner.v1") -> void:
	super("suspension_plan", {
		"solved_assembly_hash": str(solved_assembly_hash),
		"input_geometry_hash": str(input_geometry_hash),
		"members": members,
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	for key in ["solved_assembly_hash", "input_geometry_hash"]:
		if str(payload.get(key, "")) == "":
			errors.append("suspension plan requires %s" % key)
	var ids := PackedStringArray()
	for member in payload.get("members", []):
		var id := str(member.get("id", ""))
		if id == "" or ids.has(id):
			errors.append("suspension members require unique stable IDs")
		else:
			ids.append(id)
		for endpoint_name in ["a", "b"]:
			var endpoint: Dictionary = member.get(endpoint_name, {})
			if str(endpoint.get("instance", "")) == "" or \
					str(endpoint.get("socket", "")) == "":
				errors.append("suspension member %s requires endpoint %s" % [id,
					endpoint_name])
		if float(member.get("radius", 0.0)) <= 0.0:
			errors.append("suspension member %s requires a positive radius" % id)
		if float(member.get("minimum_length", 0.0)) <= 0.0:
			errors.append("suspension member %s requires a positive minimum length" % id)
		var maximum := float(member.get("maximum_length", 0.0))
		if maximum < float(member.get("minimum_length", 0.0)):
			errors.append("suspension member %s requires maximum length >= minimum length" % id)
		if str(member.get("material_slot", "")) == "":
			errors.append("suspension member %s requires a material slot" % id)
		if str(member.get("profile_id", "")) == "":
			errors.append("suspension member %s requires a profile ID" % id)
	for member in payload.get("members", []):
		var paired_with := str(member.get("paired_with", ""))
		if paired_with != "" and not ids.has(paired_with):
			errors.append("suspension member %s has an unknown pair" % str(
				member.get("id", "")))
	return errors

static func from_canonical_dict(record: Dictionary):
	var canonical := load("res://addons/polyforge/core/canonical_artifact.gd")
	var source: Dictionary = canonical.decanonicalize(record.get("payload", {}))
	return load("res://addons/polyforge/core/suspension_plan.gd").new(
		str(source.get("solved_assembly_hash", "")),
		str(source.get("input_geometry_hash", "")), source.get("members", []),
		str(record.get("producer_version", "")))
