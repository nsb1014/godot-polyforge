extends "res://addons/polyforge/core/canonical_artifact.gd"
## Connection-local geometry treatments bound to one immutable solved assembly.

const FAMILIES := ["rigid.box_collar", "rigid.cylinder_collar"]

func _init(solved_assembly_hash := "", cohesion_contract_hash := "",
		treatments := [], producer := "polyforge.rigid_interface_planner.v1") -> void:
	super("interface_plan", {
		"solved_assembly_hash": str(solved_assembly_hash),
		"cohesion_contract_hash": str(cohesion_contract_hash),
		"treatments": treatments,
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	if str(payload.get("solved_assembly_hash", "")) == "":
		errors.append("interface plan requires a solved assembly hash")
	if str(payload.get("cohesion_contract_hash", "")) == "":
		errors.append("interface plan requires a cohesion contract hash")
	var ids := PackedStringArray()
	for treatment in payload.get("treatments", []):
		var id := str(treatment.get("connection_id", ""))
		if id == "" or ids.has(id):
			errors.append("interface treatments require unique connection IDs")
		else:
			ids.append(id)
		if not FAMILIES.has(str(treatment.get("family", ""))):
			errors.append("interface treatment %s uses an unsupported family" % id)
		if str(treatment.get("profile_id", "")) == "":
			errors.append("interface treatment %s requires a profile ID" % id)
		if str(treatment.get("material_slot", "")) == "":
			errors.append("interface treatment %s requires a material slot" % id)
		if float(treatment.get("minimum_endpoint_overlap", 0.0)) <= 0.0:
			errors.append("interface treatment %s requires positive endpoint overlap" % id)
		match str(treatment.get("family", "")):
			"rigid.box_collar":
				if not treatment.get("size") is Vector3 or \
						(treatment.size as Vector3).x <= 0.0 or \
						(treatment.size as Vector3).y <= 0.0 or \
						(treatment.size as Vector3).z <= 0.0:
					errors.append("box collar %s requires a positive Vector3 size" % id)
			"rigid.cylinder_collar":
				if float(treatment.get("radius", 0.0)) <= 0.0 or \
						float(treatment.get("height", 0.0)) <= 0.0:
					errors.append("cylinder collar %s requires positive dimensions" % id)
	return errors

static func from_canonical_dict(record: Dictionary):
	var canonical := load("res://addons/polyforge/core/canonical_artifact.gd")
	var source: Dictionary = canonical.decanonicalize(record.get("payload", {}))
	return load("res://addons/polyforge/core/interface_plan.gd").new(
		str(source.get("solved_assembly_hash", "")),
		str(source.get("cohesion_contract_hash", "")), source.get("treatments", []),
		str(record.get("producer_version", "")))
