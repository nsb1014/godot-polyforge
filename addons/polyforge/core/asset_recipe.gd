extends RefCounted
## Loader and normalizer for project-owned PolyForge asset recipes.
##
## A recipe script exposes `build()` and returns a Dictionary containing at least an
## `assembly`. The compiler owns the output contract; projects own all geometry and style.

static func defaults() -> Dictionary:
	return {
		"name": "asset",
		"category": "prop",
		"assembly": null,
		"triangle_budget": -1,
		"checks": [],
		"noclip": false,
		"anchors": {},
		"metadata": {},
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
	assert(spec.metadata is Dictionary, "recipe metadata must be a Dictionary")
	return spec

static func load_file(path: String) -> Dictionary:
	var script = load(path)
	assert(script != null, "cannot load PolyForge recipe: " + path)
	var provider = script.new()
	assert(provider.has_method("build"), "PolyForge recipe must implement build(): " + path)
	return normalize(provider.build(), path)
