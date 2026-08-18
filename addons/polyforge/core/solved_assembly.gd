extends "res://addons/polyforge/core/canonical_artifact.gd"
## Authoritative rigid transforms and independently inspectable solver evidence.

func _init(plan_hash := "", catalog_hash := "", instances := [], transforms := {},
		connections := [], residuals := [], clearance := [], solver := {},
		producer := "polyforge.rigid_assembly_solver.v1") -> void:
	super("solved_assembly", {
		"plan_hash": str(plan_hash),
		"catalog_hash": str(catalog_hash),
		"instances": instances,
		"transforms": transforms,
		"connections": connections,
		"residuals": residuals,
		"clearance": clearance,
		"solver": solver,
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	if str(payload.get("plan_hash", "")) == "":
		errors.append("solved assembly requires a plan hash")
	if str(payload.get("catalog_hash", "")) == "":
		errors.append("solved assembly requires a catalog hash")
	for instance in payload.get("instances", []):
		var id := str(instance.get("id", ""))
		if not payload.get("transforms", {}).has(id):
			errors.append("solved assembly has no transform for %s" % id)
		elif not payload.transforms[id] is Transform3D:
			errors.append("solved assembly transform for %s must be Transform3D" % id)
	return errors

static func from_canonical_dict(record: Dictionary):
	var canonical := load("res://addons/polyforge/core/canonical_artifact.gd")
	var source: Dictionary = canonical.decanonicalize(record.get("payload", {}))
	return load("res://addons/polyforge/core/solved_assembly.gd").new(
		str(source.get("plan_hash", "")), str(source.get("catalog_hash", "")),
		source.get("instances", []), source.get("transforms", {}),
		source.get("connections", []), source.get("residuals", []),
		source.get("clearance", []), source.get("solver", {}),
		str(record.get("producer_version", "")))
