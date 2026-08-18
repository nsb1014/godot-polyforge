extends RefCounted
## Reusable, nestable authored geometry. A component is a local-space definition;
## assemblies place rigid instances of it without duplicating mesh resources.

var component_id: String
var parts: Array[Dictionary] = []
var sockets: Dictionary = {}
var socket_contracts: Dictionary = {}
var instances: Array[Dictionary] = []

func _init(id := "component") -> void:
	component_id = str(id)
	assert(component_id != "", "components require a stable component_id")

func add(name: String, mesh: Mesh, local_transform := Transform3D.IDENTITY,
		options := {}) -> Dictionary:
	assert(name != "", "component parts require a non-empty name")
	assert(mesh != null, "component parts require a mesh")
	for part in parts:
		assert(str(part.name) != name, "duplicate component part name: " + name)
	var record := {
		"name": name,
		"mesh": mesh,
		"transform": local_transform,
		"intentional_overlaps": PackedStringArray(options.get("intentional_overlaps", [])),
		"tags": PackedStringArray(options.get("tags", [])),
		"surface": options.get("surface", {}),
	}
	parts.append(record)
	return record

func define_socket(name: String, local_transform: Transform3D) -> void:
	assert(name != "", "component sockets require a non-empty name")
	sockets[name] = local_transform

func define_typed_socket(name: String, local_transform: Transform3D,
		contract: Dictionary) -> void:
	define_socket(name, local_transform)
	assert(str(contract.get("type", "")) != "", "typed sockets require a type")
	var normalized := contract.duplicate(true)
	normalized["type"] = str(normalized.type)
	normalized["accepts"] = PackedStringArray(normalized.get("accepts", []))
	normalized["allowed_twist_degrees"] = PackedFloat32Array(
		normalized.get("allowed_twist_degrees", [0.0]))
	normalized["cardinality"] = int(normalized.get("cardinality", 1))
	normalized["position_tolerance"] = float(normalized.get("position_tolerance", 0.0001))
	normalized["rotation_tolerance_degrees"] = float(
		normalized.get("rotation_tolerance_degrees", 0.01))
	normalized["clearance_radius"] = float(normalized.get("clearance_radius", 0.0))
	socket_contracts[name] = normalized

func socket(name: String) -> Transform3D:
	assert(sockets.has(name), "unknown component socket: " + name)
	return sockets[name]

func instance(name: String, child, local_transform := Transform3D.IDENTITY,
		options := {}) -> void:
	assert(name != "", "nested component instances require a non-empty name")
	assert(child != null and child.get("component_id") != null,
		"nested component instance requires a Component")
	instances.append({
		"name": name,
		"component": child,
		"transform": local_transform,
		"tags": PackedStringArray(options.get("tags", [])),
	})

func flattened(instance_path: String, root_transform := Transform3D.IDENTITY) -> Dictionary:
	var emitted_parts: Array[Dictionary] = []
	var emitted_instances: Array[Dictionary] = []
	var emitted_sockets := {}
	var emitted_socket_contracts := {}
	_flatten_into(instance_path, root_transform, emitted_parts, emitted_instances,
		emitted_sockets, emitted_socket_contracts)
	return {"parts": emitted_parts, "instances": emitted_instances,
		"sockets": emitted_sockets, "socket_contracts": emitted_socket_contracts}

func _flatten_into(instance_path: String, root_transform: Transform3D,
		emitted_parts: Array[Dictionary], emitted_instances: Array[Dictionary],
		emitted_sockets: Dictionary, emitted_socket_contracts: Dictionary) -> void:
	emitted_instances.append({
		"instance_path": instance_path,
		"component_id": component_id,
		"transform": root_transform,
	})
	for socket_name in sockets:
		var emitted_name := instance_path + "/" + str(socket_name)
		emitted_sockets[emitted_name] = root_transform * sockets[socket_name]
		if socket_contracts.has(socket_name):
			emitted_socket_contracts[emitted_name] = socket_contracts[socket_name].duplicate(true)
	for part in parts:
		emitted_parts.append({
			"source_part": str(part.name),
			"component_id": component_id,
			"component_path": instance_path,
			"mesh": part.mesh,
			"transform": root_transform * part.transform,
			"intentional_overlaps": part.intentional_overlaps,
			"tags": part.tags,
			"surface": part.get("surface", {}),
		})
	for nested in instances:
		var child_path := instance_path + "/" + str(nested.name)
		nested.component._flatten_into(child_path,
			root_transform * nested.transform, emitted_parts, emitted_instances,
			emitted_sockets, emitted_socket_contracts)
