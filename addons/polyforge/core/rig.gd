extends RefCounted
## Godot-native skeleton, skin binding, and clip authoring data.

var bones: Array[Dictionary] = []
var bindings: Dictionary = {}
var clips: Array = []
var motion_reports: Array[Dictionary] = []
var provenance: Dictionary = {}

func bone_index(name: String) -> int:
	for index in range(bones.size()):
		if str(bones[index].name) == name:
			return index
	return -1

func add_bone(name: String, parent := "", rest := Transform3D.IDENTITY,
		limits := {}) -> int:
	assert(name != "", "bones require a stable name")
	assert(bone_index(name) < 0, "duplicate bone name: " + name)
	var parent_name := str(parent)
	assert(parent_name == "" or bone_index(parent_name) >= 0,
		"bone parent must be added before its child: " + parent_name)
	bones.append({"name": name, "parent": parent_name, "rest": rest,
		"limits": limits.duplicate(true)})
	return bones.size() - 1

func bind_rigid(part_name: String, bone_name: String) -> void:
	assert(part_name != "", "rigid bindings require a part name")
	assert(bone_index(bone_name) >= 0, "unknown rigid binding bone: " + bone_name)
	bindings[part_name] = {"mode": "rigid", "influences": [
		{"bone": bone_name, "weight": 1.0}]}

func bind_deformable(part_name: String, influences: Array) -> void:
	assert(part_name != "", "deformable bindings require a part name")
	bindings[part_name] = {"mode": "deformable", "influences": influences.duplicate(true)}

func add_clip(clip) -> void:
	assert(clip != null and clip.get("name") != null,
		"rig clips require an Animation clip")
	for existing in clips:
		assert(str(existing.name) != str(clip.name), "duplicate animation clip: " + str(clip.name))
	clips.append(clip)

func add_motion_report(name: String, report: Dictionary, tolerances := {}) -> void:
	assert(name != "", "motion reports require a stable name")
	motion_reports.append({"name": name, "report": report,
		"tolerances": tolerances.duplicate(true)})

func bind_contract(geometry_hash: String, motion_contract_hash: String,
		producer := "polyforge.rig_compiler.v1") -> void:
	assert(geometry_hash != "", "rig provenance requires a geometry hash")
	assert(motion_contract_hash != "", "rig provenance requires a motion contract hash")
	provenance = {
		"geometry_hash": geometry_hash,
		"motion_contract_hash": motion_contract_hash,
		"producer": str(producer),
	}

func snapshot() -> Dictionary:
	var clip_records := []
	for clip in clips:
		clip_records.append(clip.snapshot())
	return {"bones": bones, "bindings": bindings, "clips": clip_records,
		"motion_reports": motion_reports, "provenance": provenance}
