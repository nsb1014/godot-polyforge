extends RefCounted
## Validation helpers for typed rigid connection sockets.

static func validate(contract: Dictionary, label := "socket") -> PackedStringArray:
	var errors := PackedStringArray()
	if str(contract.get("type", "")) == "":
		errors.append("%s requires a type" % label)
	if contract.get("accepts", []).is_empty():
		errors.append("%s requires at least one accepted mate type" % label)
	if contract.get("allowed_twist_degrees", []).is_empty():
		errors.append("%s requires at least one allowed twist" % label)
	if int(contract.get("cardinality", 1)) < 1:
		errors.append("%s cardinality must be positive" % label)
	if float(contract.get("position_tolerance", 0.0001)) <= 0.0:
		errors.append("%s position tolerance must be positive" % label)
	if float(contract.get("rotation_tolerance_degrees", 0.01)) <= 0.0:
		errors.append("%s rotation tolerance must be positive" % label)
	if float(contract.get("clearance_radius", 0.0)) < 0.0:
		errors.append("%s clearance radius must not be negative" % label)
	return errors

static func compatible(a: Dictionary, b: Dictionary) -> bool:
	return a.get("accepts", []).has(str(b.get("type", ""))) and \
		b.get("accepts", []).has(str(a.get("type", "")))

static func twist_allowed(contract: Dictionary, degrees: float,
		tolerance := 0.0001) -> bool:
	for allowed in contract.get("allowed_twist_degrees", [0.0]):
		if absf(fposmod(float(allowed) - degrees + 180.0, 360.0) - 180.0) <= tolerance:
			return true
	return false

static func twist_transform(degrees: float) -> Transform3D:
	return Transform3D(Basis(Vector3.FORWARD, deg_to_rad(degrees)), Vector3.ZERO)
