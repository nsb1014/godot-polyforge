extends "res://addons/polyforge/core/canonical_artifact.gd"
## Shared upstream contract consumed by rigid geometry and rig compilation.

func _init(design_hash := "", solver := {}, bodies := [], joints := [],
		envelopes := [], requirements := {}, producer := "polyforge.motion_contract.v1") -> void:
	super("motion_contract", {
		"design_hash": str(design_hash),
		"domain": "rigid_mechanism",
		"solver": solver,
		"bodies": bodies,
		"joints": joints,
		"motion_envelopes": envelopes,
		"requirements": requirements,
	}, 1, producer)

func validate() -> PackedStringArray:
	var errors := super()
	if str(payload.get("design_hash", "")) == "":
		errors.append("motion contract requires a resolved design hash")
	var solver: Dictionary = payload.get("solver", {})
	if str(solver.get("id", "")) == "" or str(solver.get("version", "")) == "":
		errors.append("motion contract requires a pinned solver ID and version")
	return errors
