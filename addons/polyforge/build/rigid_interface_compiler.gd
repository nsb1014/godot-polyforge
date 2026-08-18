extends RefCounted
## Adds connection-local rigid transition geometry without changing solved transforms.

const AssemblyCompiler := preload("res://addons/polyforge/build/assembly_compiler.gd")
const GeometryFingerprint := preload("res://addons/polyforge/core/geometry_fingerprint.gd")
const InterfaceCompilation := preload("res://addons/polyforge/core/interface_compilation.gd")
const Stock := preload("res://addons/polyforge/core/stock.gd")
const StyleCompiler := preload("res://addons/polyforge/build/style_compiler.gd")
const SurfaceTypes := preload("res://addons/polyforge/core/surface_types.gd")
const Checks := preload("res://addons/polyforge/quality/checks.gd")

static func descriptor() -> Dictionary:
	return {"id": "polyforge.rigid_interface_compiler", "version": "1.0.0",
		"deterministic": true, "mutates_solved_transforms": false}

static func _connection(solved, id: String) -> Dictionary:
	for connection in solved.payload.connections:
		if str(connection.get("id", "")) == id:
			return connection
	return {}

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

static func _instance_bounds(assembly, instance_id: String) -> AABB:
	var bounds := AABB()
	var initialized := false
	for part in assembly.parts:
		if str(part.get("instance_path", "")) != instance_id:
			continue
		var geometry := Checks.geometry(part)
		if geometry.vertices.is_empty():
			continue
		bounds = geometry.aabb if not initialized else bounds.merge(geometry.aabb)
		initialized = true
	return bounds

static func _overlap_ratio(interface_bounds: AABB, endpoint_bounds: AABB) -> float:
	if interface_bounds.get_volume() <= 0.0 or endpoint_bounds.get_volume() <= 0.0 or \
			not interface_bounds.intersects(endpoint_bounds):
		return 0.0
	var overlap := interface_bounds.intersection(endpoint_bounds)
	return clampf(overlap.get_volume() / interface_bounds.get_volume(), 0.0, 1.0)

static func _mesh(treatment: Dictionary):
	match str(treatment.family):
		"rigid.box_collar":
			return Stock.box(treatment.size)
		"rigid.cylinder_collar":
			return Stock.cylinder(float(treatment.radius), float(treatment.radius),
				float(treatment.height), int(treatment.get("segments", 10)))
	return null

static func compile(catalog, solved, interface_plan) -> Dictionary:
	var failures := PackedStringArray()
	if solved == null or interface_plan == null:
		return {"ok": false, "failures": PackedStringArray([
			"INTERFACE_COMPILATION_INPUT_REQUIRED"]), "assembly": null, "artifact": null}
	for error in solved.validate():
		failures.append("INVALID_SOLVED_ASSEMBLY: " + error)
	for error in interface_plan.validate():
		failures.append("INVALID_INTERFACE_PLAN: " + error)
	if str(interface_plan.payload.solved_assembly_hash) != solved.content_hash():
		failures.append("INTERFACE_PLAN_SOLVED_HASH_MISMATCH")
	if not failures.is_empty():
		return {"ok": false, "failures": failures, "assembly": null, "artifact": null}
	var base := AssemblyCompiler.compile(catalog, solved)
	if not base.ok:
		return {"ok": false, "failures": base.failures, "assembly": null,
			"artifact": null}
	var assembly = base.assembly
	var base_hash := GeometryFingerprint.assembly_hash(assembly)
	var records := []
	var treatments: Array = interface_plan.payload.treatments.duplicate(true)
	treatments.sort_custom(func(a, b):
		return str(a.get("connection_id", "")) < str(b.get("connection_id", "")))
	for treatment in treatments:
		var connection_id := str(treatment.connection_id)
		var connection := _connection(solved, connection_id)
		if connection.is_empty():
			failures.append("INTERFACE_UNKNOWN_CONNECTION: " + connection_id)
			continue
		var mesh = _mesh(treatment)
		if mesh == null:
			failures.append("INTERFACE_UNSUPPORTED_FAMILY: " + str(treatment.family))
			continue
		var frame := _socket_frame(catalog, solved, connection.a)
		var offset: Vector3 = treatment.get("offset", Vector3.ZERO)
		var transform := frame * Transform3D(Basis.IDENTITY, offset)
		var material := StyleCompiler.slot(str(treatment.material_slot))
		mesh = Stock.with_material(mesh, material)
		var name := "interface__%s__%s" % [connection_id.to_snake_case(),
			str(treatment.family).trim_prefix("rigid.")]
		var surface_options := {"socket": connection_id}
		if str(treatment.family) == "rigid.box_collar":
			surface_options["minimum_slenderness"] = 1.0
		else:
			surface_options["axis"] = "y"
		var part: Dictionary = assembly.add(name, mesh, transform, {
			"tags": PackedStringArray(["interface", "cohesion", connection_id,
				str(treatment.profile_id)]),
			"surface": SurfaceTypes.classify("prismatic" if
				str(treatment.family) == "rigid.box_collar" else "revolved",
				"interface", "unique", "static", surface_options),
			"component_id": "polyforge.generated_interface",
			"source_part": connection_id,
			"component_path": "interfaces/%s" % connection_id,
			"instance_path": "interfaces",
		})
		var interface_bounds: AABB = Checks.geometry(part).aabb
		var a_id := str(connection.a.instance)
		var b_id := str(connection.b.instance)
		var a_overlap := _overlap_ratio(interface_bounds,
			_instance_bounds(assembly, a_id))
		var b_overlap := _overlap_ratio(interface_bounds,
			_instance_bounds(assembly, b_id))
		records.append({"connection_id": connection_id, "part_name": name,
			"family": str(treatment.family), "profile_id": str(treatment.profile_id),
			"a_instance": a_id, "b_instance": b_id,
			"a_overlap": snappedf(a_overlap, 0.000001),
			"b_overlap": snappedf(b_overlap, 0.000001),
			"minimum_endpoint_overlap": float(treatment.minimum_endpoint_overlap)})
	var output_hash := GeometryFingerprint.assembly_hash(assembly)
	var compiler := descriptor()
	var artifact := InterfaceCompilation.new(solved.content_hash(),
		interface_plan.content_hash(), base_hash, output_hash, records,
		"%s@%s" % [compiler.id, compiler.version])
	for error in artifact.validate():
		failures.append("INVALID_INTERFACE_COMPILATION: " + error)
	return {"ok": failures.is_empty(), "failures": failures, "assembly": assembly,
		"artifact": artifact, "base_geometry_hash": base_hash,
		"output_geometry_hash": output_hash}
