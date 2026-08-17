extends RefCounted
## Orthogonal surface semantics: how a surface is constructed and what it does.

const CONSTRUCTIONS := [
	"plate", "prismatic", "revolved", "swept", "lofted", "shell",
	"sculpted", "repeated", "field", "profile", "organic",
]
const ROLES := [
	"structural", "enclosure", "interface", "conduit", "contact",
	"silhouette", "trim", "deformable", "decorative", "primary_silhouette",
	"mechanism", "effect_anchor",
]
const REPETITIONS := ["unique", "paired", "radial_repeat", "centered"]
const MOTIONS := ["static", "rigid", "deformable"]

static func describe(construction: String, role: String, options := {}) -> Dictionary:
	var result := options.duplicate(true)
	result.construction = construction
	result.role = role
	return result

static func classify(construction: String, role: String, repetition: String,
		motion: String, options := {}) -> Dictionary:
	var result := describe(construction, role, options)
	result.repetition = repetition
	result.motion = motion
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
	if descriptor.has("repetition") and not REPETITIONS.has(str(descriptor.repetition)):
		failures.append("unknown repetition '%s'" % str(descriptor.repetition))
	if descriptor.has("motion") and not MOTIONS.has(str(descriptor.motion)):
		failures.append("unknown motion '%s'" % str(descriptor.motion))
	return failures

static func validate_extended(descriptor) -> PackedStringArray:
	var failures := validate(descriptor)
	if not descriptor is Dictionary:
		return failures
	if not descriptor.has("repetition"):
		failures.append("repetition classification is missing")
	if not descriptor.has("motion"):
		failures.append("motion classification is missing")
	return failures
