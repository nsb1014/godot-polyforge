extends RefCounted
## Orthogonal surface semantics: how a surface is constructed and what it does.

const CONSTRUCTIONS := [
	"plate", "prismatic", "revolved", "swept", "lofted", "shell",
	"sculpted", "repeated", "field",
]
const ROLES := [
	"structural", "enclosure", "interface", "conduit", "contact",
	"silhouette", "trim", "deformable", "decorative",
]

static func describe(construction: String, role: String, options := {}) -> Dictionary:
	var result := options.duplicate(true)
	result.construction = construction
	result.role = role
	return result

static func validate(descriptor) -> PackedStringArray:
	var failures := PackedStringArray()
	if not descriptor is Dictionary or descriptor.is_empty():
		failures.append("surface classification is missing")
		return failures
	var construction := str(descriptor.get("construction", ""))
	var role := str(descriptor.get("role", ""))
	if not CONSTRUCTIONS.has(construction):
		failures.append("unknown surface construction '%s'" % construction)
	if not ROLES.has(role):
		failures.append("unknown surface role '%s'" % role)
	return failures
