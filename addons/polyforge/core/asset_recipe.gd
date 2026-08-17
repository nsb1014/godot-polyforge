extends RefCounted
## Loader and normalizer for project-owned PolyForge asset recipes.
##
## A recipe script exposes `build()` and returns a Dictionary containing at least an
## `assembly`. The compiler owns the output contract; projects own all geometry and style.

const Parameters := preload("parameters.gd")

static func defaults() -> Dictionary:
	return {
		"name": "asset",
		"category": "prop",
		"assembly": null,
		"triangle_budget": -1,
		"topology_budget": {},
		"quality_profile": "runtime",
		"checks": [],
		"noclip": false,
		"anchors": {},
		"attachments": {},
		"metadata": {},
		"parameters": {},
		"readability": {},
		"symmetry": [],
		"require_surface_classification": false,
		"require_part_classification": false,
		"rig": null,
		"front": "",
		"loose": false,
	}

static func normalize(raw, source_path := "") -> Dictionary:
	var spec := defaults()
	if raw is Dictionary:
		for key in raw:
			spec[key] = raw[key]
	else:
		spec.assembly = raw
	if spec.name == "asset" and source_path != "":
		spec.name = source_path.get_file().get_basename()
	assert(str(spec.name) != "", "PolyForge recipe needs a non-empty name")
	assert(spec.assembly != null, "PolyForge recipe needs an assembly")
	assert(spec.assembly.get("parts") != null, "recipe assembly must expose named parts")
	assert(spec.checks is Array, "recipe checks must be an Array")
	assert(spec.anchors is Dictionary, "recipe anchors must be a Dictionary")
	assert(spec.attachments is Dictionary, "recipe attachments must be a Dictionary")
	assert(spec.metadata is Dictionary, "recipe metadata must be a Dictionary")
	assert(spec.parameters is Dictionary, "recipe parameters must be a Dictionary")
	assert(spec.readability is Dictionary, "recipe readability policy must be a Dictionary")
	assert(spec.symmetry is Array, "recipe symmetry contracts must be an Array")
	assert(spec.topology_budget is Dictionary, "recipe topology budget must be a Dictionary")
	assert(str(spec.quality_profile) in ["preview", "runtime", "hero"],
		"recipe quality_profile must be preview, runtime, or hero")
	return spec

static func _method_argument_count(provider, method_name: String) -> int:
	for method in provider.get_method_list():
		if str(method.name) == method_name:
			return method.args.size()
	return -1

static func _provider(path: String):
	var script = load(path)
	assert(script != null, "cannot load PolyForge recipe: " + path)
	var provider = script.new()
	assert(provider.has_method("build"), "PolyForge recipe must implement build(): " + path)
	return provider

static func parameter_schema(path: String) -> Dictionary:
	var provider = _provider(path)
	if not provider.has_method("parameters"):
		return {}
	var result = provider.call("parameters")
	assert(result is Dictionary, "recipe parameters() must return a Dictionary: " + path)
	return result

static func load_file(path: String, overrides := {}) -> Dictionary:
	var provider = _provider(path)
	var schema := {}
	if provider.has_method("parameters"):
		schema = provider.call("parameters")
		assert(schema is Dictionary, "recipe parameters() must return a Dictionary: " + path)
	var parameters := Parameters.new(schema, overrides)
	var argument_count := _method_argument_count(provider, "build")
	var raw = provider.call("build", parameters) if argument_count > 0 else provider.call("build")
	var spec := normalize(raw, path)
	spec.parameters = parameters.snapshot()
	return spec

static func load_sweep(path: String, base_overrides := {},
		selected := PackedStringArray(), include_interactions := true,
		max_cases := 128) -> Array[Dictionary]:
	var schema := parameter_schema(path)
	if schema.is_empty():
		return []
	var specs: Array[Dictionary] = []
	for test_case in Parameters.sweep_cases(
			schema, base_overrides, selected, include_interactions, max_cases):
		specs.append({
			"label": test_case.label,
			"varied": test_case.varied,
			"plan": test_case.get("plan", {}),
			"spec": load_file(path, test_case.overrides),
		})
	return specs
