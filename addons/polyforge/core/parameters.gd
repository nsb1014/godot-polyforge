extends RefCounted
## Named primary and derived measurements for procedural asset recipes.
##
## Primary values are declared by the recipe and may be overridden by the CLI.
## Derived values record which local measurement they came from, making scale
## relationships visible in the manifest instead of leaving them as anonymous numbers.

var schema: Dictionary = {}
var values: Dictionary = {}
var overrides: Dictionary = {}
var derived: Dictionary = {}
var errors := PackedStringArray()

static func number(default_value: float, minimum: float, maximum: float,
		unit := "m", description := "") -> Dictionary:
	return {
		"default": default_value,
		"minimum": minimum,
		"maximum": maximum,
		"unit": unit,
		"description": description,
	}

static func scale(default_value: float, minimum: float, maximum: float,
		unit := "m", description := "", tolerance := 0.02) -> Dictionary:
	var result := number(default_value, minimum, maximum, unit, description)
	result["uniform_scale"] = true
	result["scale_tolerance"] = tolerance
	return result

static func _finite_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _normalized_entry(name: String, raw) -> Dictionary:
	var entry: Dictionary = raw.duplicate(true) if raw is Dictionary else {"default": raw}
	entry["name"] = name
	entry["unit"] = str(entry.get("unit", ""))
	entry["description"] = str(entry.get("description", ""))
	return entry

func _init(raw_schema := {}, supplied_overrides := {}) -> void:
	if not raw_schema is Dictionary:
		errors.append("parameter schema must be a Dictionary")
		return
	for raw_name in raw_schema:
		var name := str(raw_name)
		var entry := _normalized_entry(name, raw_schema[raw_name])
		schema[name] = entry
		if not entry.has("default") or not _finite_number(entry.default):
			errors.append("parameter %s needs a finite numeric default" % name)
			continue
		if entry.has("minimum") and not _finite_number(entry.minimum):
			errors.append("parameter %s minimum must be finite" % name)
		if entry.has("maximum") and not _finite_number(entry.maximum):
			errors.append("parameter %s maximum must be finite" % name)
		if entry.has("minimum") and entry.has("maximum") and \
				_finite_number(entry.minimum) and _finite_number(entry.maximum) and \
				float(entry.minimum) > float(entry.maximum):
			errors.append("parameter %s minimum exceeds its maximum" % name)
		var supplied = supplied_overrides.get(name, entry.default)
		if not _finite_number(supplied):
			errors.append("parameter %s override must be a finite number" % name)
			supplied = entry.default
		var value: float = float(supplied)
		values[name] = value
		if supplied_overrides.has(name):
			overrides[name] = value
		if entry.has("minimum") and _finite_number(entry.minimum) and value < float(entry.minimum):
			errors.append("parameter %s %.6f is below minimum %.6f" % [
				name, value, float(entry.minimum)])
		if entry.has("maximum") and _finite_number(entry.maximum) and value > float(entry.maximum):
			errors.append("parameter %s %.6f is above maximum %.6f" % [
				name, value, float(entry.maximum)])
	for raw_name in supplied_overrides:
		var name := str(raw_name)
		if not schema.has(name):
			errors.append("unknown recipe parameter: " + name)

func value(name: String) -> float:
	assert(values.has(name), "unknown PolyForge parameter: " + name)
	return float(values[name])

func computed(name: String, result: float, sources := PackedStringArray(),
		expression := "") -> float:
	assert(not values.has(name) and not derived.has(name),
		"duplicate PolyForge measurement: " + name)
	var source_names := PackedStringArray(sources)
	for source in source_names:
		assert(values.has(source) or derived.has(source),
			"derived measurement %s has unknown source %s" % [name, source])
	if not is_finite(result):
		errors.append("derived measurement %s is not finite" % name)
	derived[name] = {
		"value": result,
		"sources": source_names,
		"expression": expression,
	}
	return result

func derive(name: String, source: String, factor := 1.0, offset := 0.0) -> float:
	var source_value: float
	if values.has(source):
		source_value = float(values[source])
	else:
		assert(derived.has(source), "unknown PolyForge measurement: " + source)
		source_value = float(derived[source].value)
	return computed(name, source_value * float(factor) + float(offset),
		PackedStringArray([source]), "%s * %.8f + %.8f" % [source, factor, offset])

func measurement(name: String) -> float:
	if values.has(name):
		return float(values[name])
	assert(derived.has(name), "unknown PolyForge measurement: " + name)
	return float(derived[name].value)

func snapshot() -> Dictionary:
	return {
		"schema": schema.duplicate(true),
		"values": values.duplicate(true),
		"overrides": overrides.duplicate(true),
		"derived": derived.duplicate(true),
		"errors": errors.duplicate(),
	}

static func sweep_cases(raw_schema: Dictionary, base_overrides := {},
		selected := PackedStringArray()) -> Array[Dictionary]:
	var cases: Array[Dictionary] = [{"label": "base", "overrides": base_overrides.duplicate(true)}]
	var names := PackedStringArray()
	if selected.is_empty():
		for raw_name in raw_schema:
			names.append(str(raw_name))
	else:
		names = selected.duplicate()
	for name in names:
		if not raw_schema.has(name):
			cases.append({"label": name + "=unknown", "overrides": {name: NAN}})
			continue
		var entry := _normalized_entry(name, raw_schema[name])
		for bound in ["minimum", "maximum"]:
			if not entry.has(bound) or not _finite_number(entry[bound]):
				continue
			var candidate := base_overrides.duplicate(true)
			candidate[name] = float(entry[bound])
			cases.append({"label": "%s=%s" % [name, bound], "overrides": candidate})
	return cases
