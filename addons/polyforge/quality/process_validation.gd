extends RefCounted
## Verifies the stage ledger and cross-stage hash invariants without mutating artifacts.

const CanonicalArtifact := preload("res://addons/polyforge/core/canonical_artifact.gd")

const REQUIRED_STAGES := ["intent", "resolve_design", "compile_geometry",
	"compile_appearance"]

static func evaluate(spec: Dictionary) -> Dictionary:
	var failures := PackedStringArray()
	var process: Dictionary = spec.get("process", {})
	var contracts: Dictionary = spec.get("contracts", {})
	if process.is_empty():
		return {"ok": false, "failures": PackedStringArray([
			"PROCESS_MISSING_STAGE_LEDGER"]), "stages": 0}
	var stage_ids := PackedStringArray()
	for stage in process.get("stages", []):
		var stage_id := str(stage.get("stage_id", ""))
		if stage_id == "":
			failures.append("PROCESS_STAGE_WITHOUT_ID")
		elif stage_ids.has(stage_id):
			failures.append("PROCESS_DUPLICATE_STAGE: %s" % stage_id)
		else:
			stage_ids.append(stage_id)
		if str(stage.get("status", "")) != "completed":
			failures.append("PROCESS_INCOMPLETE_STAGE: %s" % stage_id)
		if str(stage.get("output_hash", "")) == "":
			failures.append("PROCESS_STAGE_WITHOUT_OUTPUT_HASH: %s" % stage_id)
	for required in REQUIRED_STAGES:
		if not stage_ids.has(required):
			failures.append("PROCESS_MISSING_STAGE: %s" % required)
	var has_motion := contracts.has("motion_contract")
	if has_motion:
		for required in ["solve_mechanism", "compile_rig"]:
			if not stage_ids.has(required):
				failures.append("PROCESS_MISSING_MOTION_STAGE: %s" % required)
	var has_rigid_plan := contracts.has("assembly_plan") or contracts.has("solved_assembly")
	if has_rigid_plan:
		for contract_name in ["assembly_plan", "solved_assembly"]:
			if not contracts.has(contract_name):
				failures.append("PROCESS_MISSING_RIGID_CONTRACT: %s" % contract_name)
		for required in ["plan_assembly", "solve_rigid"]:
			if not stage_ids.has(required):
				failures.append("PROCESS_MISSING_RIGID_STAGE: %s" % required)
	var unhashed := process.duplicate(true)
	var recorded_hash := str(unhashed.get("pipeline_hash", ""))
	unhashed.erase("pipeline_hash")
	if recorded_hash == "" or recorded_hash != CanonicalArtifact.hash_value(unhashed):
		failures.append("PROCESS_PIPELINE_HASH_MISMATCH")
	for contract_name in ["asset_intent", "resolved_design", "appearance_binding"]:
		if not contracts.has(contract_name):
			failures.append("PROCESS_MISSING_CONTRACT: %s" % contract_name)
	var style: Dictionary = spec.get("style_compilation", {})
	if not bool(style.get("ok", false)):
		failures.append("PROCESS_STYLE_COMPILATION_FAILED")
	if str(style.get("geometry_hash_before", "")) != \
			str(style.get("geometry_hash_after", "")):
		failures.append("PROCESS_STYLE_CHANGED_GEOMETRY")
	if has_motion:
		var rig_provenance: Dictionary = spec.rig.provenance \
			if spec.get("rig") != null else {}
		if str(rig_provenance.get("geometry_hash", "")) != \
				str(style.get("geometry_hash_after", "")):
			failures.append("PROCESS_RIG_GEOMETRY_HASH_MISMATCH")
		var motion_hash := CanonicalArtifact.hash_value(contracts.motion_contract)
		if str(rig_provenance.get("motion_contract_hash", "")) != motion_hash:
			failures.append("PROCESS_RIG_MOTION_HASH_MISMATCH")
	if has_rigid_plan and contracts.has("assembly_plan") and contracts.has("solved_assembly"):
		var plan_hash := CanonicalArtifact.hash_value(contracts.assembly_plan)
		var solved_hash := CanonicalArtifact.hash_value(contracts.solved_assembly)
		if str(contracts.solved_assembly.get("payload", {}).get("plan_hash", "")) != plan_hash:
			failures.append("PROCESS_SOLVED_PLAN_HASH_MISMATCH")
		var stages_by_id := {}
		for stage in process.get("stages", []):
			stages_by_id[str(stage.get("stage_id", ""))] = stage
		if str(stages_by_id.get("plan_assembly", {}).get("output_hash", "")) != plan_hash:
			failures.append("PROCESS_PLAN_STAGE_HASH_MISMATCH")
		if str(stages_by_id.get("solve_rigid", {}).get("output_hash", "")) != solved_hash:
			failures.append("PROCESS_RIGID_STAGE_HASH_MISMATCH")
		if str(stages_by_id.get("compile_geometry", {}).get("input_hashes", {}).get(
				"solved_assembly", "")) != solved_hash:
			failures.append("PROCESS_GEOMETRY_BYPASSED_SOLVED_ASSEMBLY")
	return {"ok": failures.is_empty(), "failures": failures,
		"stages": stage_ids.size(), "stage_ids": stage_ids,
		"pipeline_hash": recorded_hash}
