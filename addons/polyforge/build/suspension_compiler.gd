extends RefCounted
## Emits straight tension members between sockets without moving solved components.

const GeometryFingerprint := preload("res://addons/polyforge/core/geometry_fingerprint.gd")
const SuspensionCompilation := preload("res://addons/polyforge/core/suspension_compilation.gd")
const Stock := preload("res://addons/polyforge/core/stock.gd")
const StyleCompiler := preload("res://addons/polyforge/build/style_compiler.gd")
const SurfaceTypes := preload("res://addons/polyforge/core/surface_types.gd")

static func descriptor() -> Dictionary:
	return {"id": "polyforge.suspension_compiler", "version": "1.0.0",
		"deterministic": true, "mutates_solved_transforms": false}

static func _instance(solved, id: String) -> Dictionary:
	for instance in solved.payload.instances:
		if str(instance.get("id", "")) == id:
			return instance
	return {}

static func _socket_frame(catalog, solved, endpoint: Dictionary) -> Transform3D:
	var instance_id := str(endpoint.get("instance", ""))
	var instance := _instance(solved, instance_id)
	var socket: Dictionary = catalog.socket(str(instance.get("component_id", "")),
		str(endpoint.get("socket", "")))
	return solved.payload.transforms[instance_id] * socket.transform

static func _endpoint_error(catalog, solved, endpoint: Dictionary) -> String:
	var instance_id := str(endpoint.get("instance", ""))
	var instance := _instance(solved, instance_id)
	if instance.is_empty() or not solved.payload.transforms.has(instance_id):
		return "unknown instance %s" % instance_id
	var socket_name := str(endpoint.get("socket", ""))
	if catalog.socket(str(instance.get("component_id", "")), socket_name).is_empty():
		return "unknown socket %s/%s" % [instance_id, socket_name]
	return ""

static func _between_y(a: Vector3, b: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var guide := Vector3.FORWARD
	if absf(y.dot(guide)) > 0.95:
		guide = Vector3.RIGHT
	var x := y.cross(guide).normalized()
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x, y, z), (a + b) * 0.5)

static func compile(catalog, solved, assembly, suspension_plan) -> Dictionary:
	var failures := PackedStringArray()
	if solved == null or assembly == null or suspension_plan == null:
		return {"ok": false, "failures": PackedStringArray([
			"SUSPENSION_COMPILATION_INPUT_REQUIRED"]), "assembly": assembly,
			"artifact": null}
	for error in solved.validate():
		failures.append("INVALID_SOLVED_ASSEMBLY: " + error)
	for error in suspension_plan.validate():
		failures.append("INVALID_SUSPENSION_PLAN: " + error)
	if str(suspension_plan.payload.solved_assembly_hash) != solved.content_hash():
		failures.append("SUSPENSION_PLAN_SOLVED_HASH_MISMATCH")
	var input_hash := GeometryFingerprint.assembly_hash(assembly)
	if str(suspension_plan.payload.input_geometry_hash) != input_hash:
		failures.append("SUSPENSION_PLAN_GEOMETRY_HASH_MISMATCH")
	if not failures.is_empty():
		return {"ok": false, "failures": failures, "assembly": assembly,
			"artifact": null}
	var members: Array = suspension_plan.payload.members.duplicate(true)
	members.sort_custom(func(a, b): return str(a.id) < str(b.id))
	var prepared := []
	for member in members:
		for endpoint_name in ["a", "b"]:
			var endpoint_error := _endpoint_error(catalog, solved, member[endpoint_name])
			if endpoint_error != "":
				failures.append("SUSPENSION_UNKNOWN_ENDPOINT: %s %s" % [member.id,
					endpoint_error])
		if not failures.is_empty():
			continue
		var a: Vector3 = _socket_frame(catalog, solved, member.a).origin
		var b: Vector3 = _socket_frame(catalog, solved, member.b).origin
		var length := a.distance_to(b)
		var minimum := float(member.minimum_length)
		var maximum := float(member.maximum_length)
		if length < minimum or length > maximum:
			failures.append("SUSPENSION_LENGTH_OUT_OF_RANGE: %s measured %.4f required %.4f..%.4f" % [
				member.id, length, minimum, maximum])
		else:
			prepared.append({"member": member, "a": a, "b": b, "length": length,
				"minimum": minimum, "maximum": maximum})
	if not failures.is_empty():
		return {"ok": false, "failures": failures, "assembly": assembly,
			"artifact": null}
	var records := []
	for prepared_member in prepared:
		var member: Dictionary = prepared_member.member
		var a: Vector3 = prepared_member.a
		var b: Vector3 = prepared_member.b
		var length: float = prepared_member.length
		var minimum: float = prepared_member.minimum
		var maximum: float = prepared_member.maximum
		var material := StyleCompiler.slot(str(member.material_slot))
		var mesh := Stock.with_material(Stock.cylinder(float(member.radius),
			float(member.radius), length, int(member.get("segments", 8))), material)
		var name := "suspension__%s" % str(member.id).to_snake_case()
		assembly.add(name, mesh, _between_y(a, b), {
			"tags": PackedStringArray(["suspension", "tension_member",
				str(member.profile_id)]),
			"surface": SurfaceTypes.classify("swept", "structural", "paired",
				"static", {"radius": float(member.radius)}),
			"component_id": "polyforge.generated_suspension",
			"source_part": str(member.id), "component_path": "suspension",
			"instance_path": "suspension",
		})
		records.append({"id": str(member.id), "part_name": name,
			"profile_id": str(member.profile_id), "a": a, "b": b,
			"length": snappedf(length, 0.000001), "minimum_length": minimum,
			"maximum_length": maximum, "paired_with": str(member.get("paired_with", "")),
			"pair_tolerance": float(member.get("pair_tolerance", 0.0))})
	var output_hash := GeometryFingerprint.assembly_hash(assembly)
	var artifact := SuspensionCompilation.new(solved.content_hash(),
		suspension_plan.content_hash(), input_hash, output_hash, records)
	for error in artifact.validate():
		failures.append("INVALID_SUSPENSION_COMPILATION: " + error)
	return {"ok": failures.is_empty(), "failures": failures, "assembly": assembly,
		"artifact": artifact, "input_geometry_hash": input_hash,
		"output_geometry_hash": output_hash}
