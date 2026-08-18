extends Resource
## Typed in-memory artifact with one deterministic dictionary wire representation.

var artifact_type: String = ""
var artifact_schema_version: int = 1
var producer_version: String = ""
var payload: Dictionary = {}

func _init(p_type := "", p_payload := {}, p_schema_version := 1,
		p_producer_version := "polyforge-dev") -> void:
	artifact_type = str(p_type)
	artifact_schema_version = int(p_schema_version)
	producer_version = str(p_producer_version)
	payload = p_payload.duplicate(true) if p_payload is Dictionary else {}

func schema_version() -> int:
	return artifact_schema_version

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if artifact_type == "":
		errors.append("artifact_type must not be empty")
	if artifact_schema_version < 1:
		errors.append("schema_version must be positive")
	_validate_value(payload, "payload", errors)
	return errors

func to_canonical_dict() -> Dictionary:
	return canonicalize({
		"artifact_type": artifact_type,
		"schema_version": artifact_schema_version,
		"producer_version": producer_version,
		"payload": payload,
	})

func content_hash() -> String:
	var errors := validate()
	assert(errors.is_empty(), "invalid canonical artifact: " + "; ".join(errors))
	return hash_value(to_canonical_dict())

static func hash_value(value) -> String:
	var serialized := JSON.stringify(canonicalize(value))
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(serialized.to_utf8_buffer())
	return context.finish().hex_encode()

static func canonicalize(value):
	if value is Dictionary:
		var keyed := {}
		var names := PackedStringArray()
		for raw_key in value:
			var key := str(raw_key)
			assert(not keyed.has(key), "canonical dictionaries require unique string keys")
			keyed[key] = value[raw_key]
			names.append(key)
		names.sort()
		var result := {}
		for key in names:
			result[key] = canonicalize(keyed[key])
		return result
	if value is Array or value is PackedStringArray or value is PackedInt32Array or \
			value is PackedInt64Array or value is PackedFloat32Array or \
			value is PackedFloat64Array or value is PackedVector2Array or \
			value is PackedVector3Array or value is PackedColorArray or \
			value is PackedByteArray:
		var result := []
		for item in value:
			result.append(canonicalize(item))
		return result
	if value is Vector2:
		return {"$type": "Vector2", "value": [_normalized_float(value.x),
			_normalized_float(value.y)]}
	if value is Vector2i:
		return {"$type": "Vector2i", "value": [value.x, value.y]}
	if value is Vector3:
		return {"$type": "Vector3", "value": [_normalized_float(value.x),
			_normalized_float(value.y), _normalized_float(value.z)]}
	if value is Vector3i:
		return {"$type": "Vector3i", "value": [value.x, value.y, value.z]}
	if value is Color:
		return {"$type": "Color", "value": [_normalized_float(value.r),
			_normalized_float(value.g), _normalized_float(value.b),
			_normalized_float(value.a)]}
	if value is Basis:
		return {"$type": "Basis", "value": [canonicalize(value.x),
			canonicalize(value.y), canonicalize(value.z)]}
	if value is Transform3D:
		return {"$type": "Transform3D", "basis": canonicalize(value.basis),
			"origin": canonicalize(value.origin)}
	if value is AABB:
		return {"$type": "AABB", "position": canonicalize(value.position),
			"size": canonicalize(value.size)}
	if value is float:
		assert(is_finite(value), "canonical artifacts reject non-finite floats")
		return _normalized_float(value)
	assert(not value is Object and not value is Callable,
		"canonical artifacts reject runtime objects and callables")
	return value

static func _normalized_float(value: float) -> float:
	assert(is_finite(value), "canonical artifacts reject non-finite floats")
	var normalized := snappedf(value, 0.000000001)
	return 0.0 if is_zero_approx(normalized) else normalized

static func _validate_value(value, path: String, errors: PackedStringArray) -> void:
	if value is float and not is_finite(value):
		errors.append("%s contains a non-finite float" % path)
		return
	if value is Object or value is Callable:
		errors.append("%s contains a runtime object or callable" % path)
		return
	if value is Dictionary:
		var normalized_keys := {}
		for raw_key in value:
			var key := str(raw_key)
			if normalized_keys.has(key):
				errors.append("%s has duplicate normalized key %s" % [path, key])
			normalized_keys[key] = true
			_validate_value(value[raw_key], "%s.%s" % [path, key], errors)
	elif value is Array or value is PackedStringArray or value is PackedInt32Array or \
			value is PackedInt64Array or value is PackedFloat32Array or \
			value is PackedFloat64Array or value is PackedVector2Array or \
			value is PackedVector3Array or value is PackedColorArray or \
			value is PackedByteArray:
		for index in range(value.size()):
			_validate_value(value[index], "%s[%d]" % [path, index], errors)
