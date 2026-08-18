extends "res://addons/polyforge/core/canonical_artifact.gd"
## Human-authored semantic evidence extracted from a specific reference image.

func _init(image := {}, semantic_groups := {}, anchors := {}, required_slots := [],
		proportions := [], producer := "polyforge.reference_profile.v1") -> void:
	super("reference_profile", {
		"image": image,
		"semantic_groups": semantic_groups,
		"anchors": anchors,
		"required_appearance_slots": required_slots,
		"proportions": proportions,
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	var image: Dictionary = payload.get("image", {})
	if str(image.get("sha256", "")) == "":
		errors.append("reference profile requires an image SHA-256")
	if payload.get("semantic_groups", {}).is_empty():
		errors.append("reference profile requires semantic groups")
	return errors
