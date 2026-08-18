extends "res://addons/polyforge/core/plan_repair_operator.gd"
## Repairs only unsupported discrete socket twist choices.

const PlanPatch := preload("res://addons/polyforge/core/plan_patch.gd")

var catalog

func _init(p_catalog = null) -> void:
	catalog = p_catalog

func descriptor() -> Dictionary:
	return {"id": "polyforge.rigid.allowed_twist_repair", "version": "1.0.0",
		"diagnostic_codes": ["RIGID_ORIENTATION_UNSUPPORTED"],
		"operation_kinds": ["set_connection_twist"], "deterministic": true}

func _instance(plan, id: String) -> Dictionary:
	for instance in plan.payload.instances:
		if str(instance.id) == id:
			return instance
	return {}

func _connection(plan, id: String) -> Dictionary:
	for connection in plan.payload.connections:
		if str(connection.id) == id:
			return connection
	return {}

func _distance(a: float, b: float) -> float:
	return absf(fposmod(a - b + 180.0, 360.0) - 180.0)

func propose(plan, diagnostic: Dictionary, attempt: int) -> Dictionary:
	if not supports(plan, diagnostic) or catalog == null:
		return super(plan, diagnostic, attempt)
	var entities: Array = diagnostic.get("entities", [])
	var connection_id := str(entities[0]) if not entities.is_empty() else ""
	var connection := _connection(plan, connection_id)
	if connection.is_empty():
		return {"ok": false, "diagnostics": [{"code": "REPAIR_TARGET_MISSING",
			"severity": "error", "message": "twist repair connection is missing",
			"entities": [connection_id]}]}
	var a_instance := _instance(plan, str(connection.a.instance))
	var b_instance := _instance(plan, str(connection.b.instance))
	var a_socket: Dictionary = catalog.socket(str(a_instance.component_id),
		str(connection.a.socket))
	var b_socket: Dictionary = catalog.socket(str(b_instance.component_id),
		str(connection.b.socket))
	if a_socket.is_empty() or b_socket.is_empty():
		return {"ok": false, "diagnostics": [{"code": "REPAIR_SOCKET_MISSING",
			"severity": "error", "message": "twist repair socket is missing",
			"entities": [connection_id]}]}
	var shared := []
	for raw in a_socket.contract.get("allowed_twist_degrees", []):
		var angle := float(raw)
		for other in b_socket.contract.get("allowed_twist_degrees", []):
			if _distance(angle, float(other)) <= 0.0001 and not shared.has(angle):
				shared.append(angle)
	shared.sort()
	if shared.is_empty():
		return {"ok": false, "diagnostics": [{"code": "REPAIR_NO_SHARED_TWIST",
			"severity": "error", "message": "sockets have no shared allowed twist",
			"entities": [connection_id]}]}
	var requested := float(connection.get("twist_degrees", 0.0))
	var selected: float = shared[0]
	for angle in shared:
		if _distance(float(angle), requested) < _distance(selected, requested):
			selected = float(angle)
	var patch := PlanPatch.new(plan.content_hash(), descriptor(),
		[diagnostic.code], [{"id": "set_twist:%s" % connection_id,
			"kind": "set_connection_twist", "connection_id": connection_id,
			"twist_degrees": selected}], attempt)
	return {"ok": patch.validate().is_empty(), "patch": patch, "diagnostics": []}
