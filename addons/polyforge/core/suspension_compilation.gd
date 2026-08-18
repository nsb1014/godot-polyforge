extends "res://addons/polyforge/core/canonical_artifact.gd"
## Evidence emitted by the suspension compiler.

func _init(solved_assembly_hash := "", suspension_plan_hash := "",
		input_geometry_hash := "", output_geometry_hash := "", members := [],
		producer := "polyforge.suspension_compiler@1.0.0") -> void:
	super("suspension_compilation", {
		"solved_assembly_hash": str(solved_assembly_hash),
		"suspension_plan_hash": str(suspension_plan_hash),
		"input_geometry_hash": str(input_geometry_hash),
		"output_geometry_hash": str(output_geometry_hash),
		"members": members,
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	for key in ["solved_assembly_hash", "suspension_plan_hash", "input_geometry_hash",
			"output_geometry_hash"]:
		if str(payload.get(key, "")) == "":
			errors.append("suspension compilation requires %s" % key)
	var ids := PackedStringArray()
	for member in payload.get("members", []):
		var id := str(member.get("id", ""))
		if id == "" or ids.has(id):
			errors.append("suspension compilation requires unique member evidence")
		else:
			ids.append(id)
		if float(member.get("length", 0.0)) <= 0.0:
			errors.append("suspension member %s has invalid length evidence" % id)
	return errors

static func from_canonical_dict(record: Dictionary):
	var canonical := load("res://addons/polyforge/core/canonical_artifact.gd")
	var source: Dictionary = canonical.decanonicalize(record.get("payload", {}))
	return load("res://addons/polyforge/core/suspension_compilation.gd").new(
		str(source.get("solved_assembly_hash", "")),
		str(source.get("suspension_plan_hash", "")),
		str(source.get("input_geometry_hash", "")),
		str(source.get("output_geometry_hash", "")), source.get("members", []),
		str(record.get("producer_version", "")))
