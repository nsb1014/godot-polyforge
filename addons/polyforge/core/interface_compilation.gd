extends "res://addons/polyforge/core/canonical_artifact.gd"
## Evidence emitted by interface compilation; records geometry hashes and measured overlap.

func _init(solved_assembly_hash := "", interface_plan_hash := "",
		base_geometry_hash := "", output_geometry_hash := "", connections := [],
		producer := "polyforge.rigid_interface_compiler.v1") -> void:
	super("interface_compilation", {
		"solved_assembly_hash": str(solved_assembly_hash),
		"interface_plan_hash": str(interface_plan_hash),
		"base_geometry_hash": str(base_geometry_hash),
		"output_geometry_hash": str(output_geometry_hash),
		"connections": connections,
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	for key in ["solved_assembly_hash", "interface_plan_hash", "base_geometry_hash",
			"output_geometry_hash"]:
		if str(payload.get(key, "")) == "":
			errors.append("interface compilation requires %s" % key)
	var ids := PackedStringArray()
	for connection in payload.get("connections", []):
		var id := str(connection.get("connection_id", ""))
		if id == "" or ids.has(id):
			errors.append("interface compilation requires unique connection evidence")
		else:
			ids.append(id)
		for endpoint in ["a_overlap", "b_overlap"]:
			var overlap := float(connection.get(endpoint, -1.0))
			if overlap < 0.0 or overlap > 1.0:
				errors.append("interface compilation %s has invalid %s" % [id, endpoint])
	return errors

static func from_canonical_dict(record: Dictionary):
	var source: Dictionary = record.get("payload", {})
	return load("res://addons/polyforge/core/interface_compilation.gd").new(
		str(source.get("solved_assembly_hash", "")),
		str(source.get("interface_plan_hash", "")),
		str(source.get("base_geometry_hash", "")),
		str(source.get("output_geometry_hash", "")), source.get("connections", []),
		str(record.get("producer_version", "")))
