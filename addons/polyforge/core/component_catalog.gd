extends RefCounted
## Runtime component resources paired with canonical, hashable capability descriptors.

const CanonicalArtifact := preload("res://addons/polyforge/core/canonical_artifact.gd")
const SocketContract := preload("res://addons/polyforge/core/socket_contract.gd")

var _components: Dictionary = {}
var _descriptors: Dictionary = {}

func register(id: String, version: String, component, clearance_volumes := [],
		capabilities := {}) -> void:
	assert(id != "" and version != "", "catalog entries require stable ID and version")
	assert(not _components.has(id), "duplicate catalog component: " + id)
	assert(component != null and component.get("component_id") != null,
		"catalog entries require a Component")
	var sockets := {}
	for socket_name in component.socket_contracts:
		var contract: Dictionary = component.socket_contracts[socket_name]
		var errors := SocketContract.validate(contract, "%s/%s" % [id, socket_name])
		assert(errors.is_empty(), "; ".join(errors))
		sockets[str(socket_name)] = {
			"transform": component.sockets[socket_name],
			"contract": contract,
		}
	for volume in clearance_volumes:
		assert(str(volume.get("id", "")) != "",
			"catalog clearance volumes require stable IDs")
		assert(volume.get("center") is Vector3,
			"catalog clearance volume centers must be Vector3")
		assert(float(volume.get("radius", 0.0)) > 0.0,
			"catalog clearance volume radii must be positive")
	_components[id] = component
	_descriptors[id] = {
		"id": id,
		"version": version,
		"sockets": sockets,
		"clearance_volumes": clearance_volumes,
		"capabilities": capabilities,
	}

func has(id: String) -> bool:
	return _components.has(id)

func component(id: String):
	return _components.get(id)

func descriptor(id: String) -> Dictionary:
	return _descriptors.get(id, {}).duplicate(true)

func socket(id: String, socket_name: String) -> Dictionary:
	return descriptor(id).get("sockets", {}).get(socket_name, {}).duplicate(true)

func snapshot() -> Dictionary:
	var ids := PackedStringArray(_descriptors.keys())
	ids.sort()
	var entries := []
	for id in ids:
		entries.append(_descriptors[id])
	return CanonicalArtifact.canonicalize({"schema_version": 1, "components": entries})

func content_hash() -> String:
	return CanonicalArtifact.hash_value(snapshot())
