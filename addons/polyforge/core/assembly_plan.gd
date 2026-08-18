extends "res://addons/polyforge/core/canonical_artifact.gd"
## Geometry-free rigid component graph and connection constraints.

func _init(design_hash := "", catalog_hash := "", root_instance := "",
		instances := [], connections := [], keepouts := [],
		producer := "polyforge.assembly_planner.v1", locks := []) -> void:
	super("assembly_plan", {
		"design_hash": str(design_hash),
		"catalog_hash": str(catalog_hash),
		"root_instance": str(root_instance),
		"instances": instances,
		"connections": connections,
		"keepouts": keepouts,
		"locks": PackedStringArray(locks),
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	if str(payload.get("design_hash", "")) == "":
		errors.append("assembly plan requires a design hash")
	if str(payload.get("catalog_hash", "")) == "":
		errors.append("assembly plan requires a catalog hash")
	var ids := PackedStringArray()
	for instance in payload.get("instances", []):
		var id := str(instance.get("id", ""))
		if id == "":
			errors.append("assembly instances require stable IDs")
		elif ids.has(id):
			errors.append("duplicate assembly instance: %s" % id)
		else:
			ids.append(id)
		if str(instance.get("component_id", "")) == "":
			errors.append("assembly instance %s requires a component ID" % id)
		if instance.has("fixed_transform") and not instance.fixed_transform is Transform3D:
			errors.append("assembly instance %s fixed transform must be Transform3D" % id)
	if not ids.has(str(payload.get("root_instance", ""))):
		errors.append("assembly root instance must exist")
	var connection_ids := PackedStringArray()
	for connection in payload.get("connections", []):
		var id := str(connection.get("id", ""))
		if id == "" or connection_ids.has(id):
			errors.append("assembly connections require unique stable IDs")
		else:
			connection_ids.append(id)
		for endpoint_name in ["a", "b"]:
			var endpoint: Dictionary = connection.get(endpoint_name, {})
			if not ids.has(str(endpoint.get("instance", ""))):
				errors.append("connection %s references unknown instance at %s" % [
					id, endpoint_name])
			if str(endpoint.get("socket", "")) == "":
				errors.append("connection %s requires a socket at %s" % [id, endpoint_name])
	for keepout in payload.get("keepouts", []):
		var id := str(keepout.get("id", ""))
		if id == "":
			errors.append("assembly keepouts require stable IDs")
		if not keepout.get("center") is Vector3:
			errors.append("assembly keepout %s center must be Vector3" % id)
		if float(keepout.get("radius", 0.0)) <= 0.0:
			errors.append("assembly keepout %s radius must be positive" % id)
	var locks_seen := {}
	for lock in payload.get("locks", []):
		var key := str(lock)
		if key == "" or locks_seen.has(key):
			errors.append("assembly locks must be unique non-empty paths")
		locks_seen[key] = true
		if not key.begins_with("connection:"):
			errors.append("unsupported assembly lock path: %s" % key)
			continue
		var target := key.trim_prefix("connection:").trim_suffix(".twist_degrees")
		if not connection_ids.has(target) or not ["connection:%s" % target,
				"connection:%s.twist_degrees" % target].has(key):
			errors.append("assembly lock references an unsupported target: %s" % key)
	return errors

static func from_canonical_dict(record: Dictionary):
	var canonical := load("res://addons/polyforge/core/canonical_artifact.gd")
	var source: Dictionary = canonical.decanonicalize(record.get("payload", {}))
	return load("res://addons/polyforge/core/assembly_plan.gd").new(
		str(source.get("design_hash", "")), str(source.get("catalog_hash", "")),
		str(source.get("root_instance", "")), source.get("instances", []),
		source.get("connections", []), source.get("keepouts", []),
		str(record.get("producer_version", "")), source.get("locks", []))
