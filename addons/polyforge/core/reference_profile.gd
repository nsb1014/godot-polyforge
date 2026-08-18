extends "res://addons/polyforge/core/canonical_artifact.gd"
## Human-authored semantic evidence extracted from a specific reference image.

func _init(image := {}, semantic_groups := {}, anchors := {}, required_slots := [],
		proportions := [], producer := "polyforge.reference_profile.v2",
		policies := {}) -> void:
	super("reference_profile", {
		"image": image,
		"semantic_groups": semantic_groups,
		"anchors": anchors,
		"required_appearance_slots": required_slots,
		"proportions": proportions,
		"policies": {
			"semantic_groups": str(policies.get("semantic_groups", "required")),
			"anchors": str(policies.get("anchors", "preferred")),
			"appearance_slots": str(policies.get("appearance_slots", "informational")),
			"proportions": str(policies.get("proportions", "preferred")),
		},
	}, 2, producer)

func validate() -> PackedStringArray:
	var errors := super()
	var image: Dictionary = payload.get("image", {})
	if str(image.get("sha256", "")) == "":
		errors.append("reference profile requires an image SHA-256")
	if payload.get("semantic_groups", {}).is_empty():
		errors.append("reference profile requires semantic groups")
	for policy in payload.get("policies", {}).values():
		if not ["required", "preferred", "informational"].has(str(policy)):
			errors.append("reference profile policies must be required, preferred, or informational")
	return errors
