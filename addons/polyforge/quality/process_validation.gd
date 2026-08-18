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
	var has_candidates := contracts.has("candidate_set") or \
		contracts.has("candidate_repair_report") or contracts.has("candidate_selection")
	if has_candidates:
		if not has_rigid_plan:
			failures.append("PROCESS_CANDIDATES_REQUIRE_RIGID_CONTRACTS")
		for contract_name in ["candidate_set", "candidate_repair_report",
				"candidate_selection"]:
			if not contracts.has(contract_name):
				failures.append("PROCESS_MISSING_CANDIDATE_CONTRACT: %s" % contract_name)
		for required in ["propose_candidates", "repair_candidates", "select_candidate"]:
			if not stage_ids.has(required):
				failures.append("PROCESS_MISSING_CANDIDATE_STAGE: %s" % required)
		var candidate_order := ["intent", "resolve_design", "propose_candidates",
			"repair_candidates", "select_candidate", "plan_assembly", "solve_rigid",
			"compile_geometry", "compile_appearance"]
		var previous_index := -1
		for stage_id in candidate_order:
			var index := stage_ids.find(stage_id)
			if index < 0 or index <= previous_index:
				failures.append("PROCESS_CANDIDATE_STAGE_ORDER_INVALID")
				break
			previous_index = index
	var has_cohesion := contracts.has("design_brief") or \
		contracts.has("cohesion_contract") or contracts.has("interface_plan") or \
		contracts.has("interface_compilation")
	if has_cohesion:
		if not has_rigid_plan:
			failures.append("PROCESS_COHESION_REQUIRES_RIGID_CONTRACTS")
		for contract_name in ["design_brief", "cohesion_contract", "interface_plan",
				"interface_compilation"]:
			if not contracts.has(contract_name):
				failures.append("PROCESS_MISSING_COHESION_CONTRACT: %s" % contract_name)
		for required in ["resolve_brief", "plan_interfaces", "compile_interfaces"]:
			if not stage_ids.has(required):
				failures.append("PROCESS_MISSING_COHESION_STAGE: %s" % required)
		var cohesion_order := ["intent", "resolve_brief", "resolve_design",
			"plan_assembly", "solve_rigid", "plan_interfaces", "compile_geometry",
			"compile_interfaces", "compile_appearance"]
		var previous_cohesion_index := -1
		for stage_id in cohesion_order:
			var index := stage_ids.find(stage_id)
			if index < 0 or index <= previous_cohesion_index:
				failures.append("PROCESS_COHESION_STAGE_ORDER_INVALID")
				break
			previous_cohesion_index = index
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
		if has_candidates and contracts.has("candidate_set") and \
				contracts.has("candidate_repair_report") and \
				contracts.has("candidate_selection"):
			var candidate_hash := CanonicalArtifact.hash_value(contracts.candidate_set)
			var repair_hash := CanonicalArtifact.hash_value(contracts.candidate_repair_report)
			var selection_hash := CanonicalArtifact.hash_value(contracts.candidate_selection)
			if str(contracts.candidate_repair_report.get("payload", {}).get(
					"candidate_set_hash", "")) != candidate_hash:
				failures.append("PROCESS_REPAIR_CANDIDATE_HASH_MISMATCH")
			if str(contracts.candidate_selection.get("payload", {}).get(
					"repair_report_hash", "")) != repair_hash:
				failures.append("PROCESS_SELECTION_REPAIR_HASH_MISMATCH")
			if str(contracts.candidate_selection.get("payload", {}).get(
					"selected_plan_hash", "")) != plan_hash:
				failures.append("PROCESS_SELECTION_PLAN_HASH_MISMATCH")
			if str(stages_by_id.get("propose_candidates", {}).get(
					"output_hash", "")) != candidate_hash:
				failures.append("PROCESS_CANDIDATE_STAGE_HASH_MISMATCH")
			if str(stages_by_id.get("repair_candidates", {}).get(
					"input_hashes", {}).get("candidate_set", "")) != candidate_hash or \
					str(stages_by_id.get("repair_candidates", {}).get(
					"output_hash", "")) != repair_hash:
				failures.append("PROCESS_REPAIR_STAGE_HASH_MISMATCH")
			if str(stages_by_id.get("select_candidate", {}).get(
					"input_hashes", {}).get("repair_report", "")) != repair_hash or \
					str(stages_by_id.get("select_candidate", {}).get(
					"output_hash", "")) != selection_hash:
				failures.append("PROCESS_SELECTION_STAGE_HASH_MISMATCH")
			if str(stages_by_id.get("plan_assembly", {}).get(
					"input_hashes", {}).get("candidate_selection", "")) != selection_hash:
				failures.append("PROCESS_PLAN_BYPASSED_CANDIDATE_SELECTION")
		if has_cohesion and contracts.has("design_brief") and \
				contracts.has("cohesion_contract") and contracts.has("interface_plan") and \
				contracts.has("interface_compilation"):
			var intent_hash := CanonicalArtifact.hash_value(contracts.asset_intent)
			var brief_hash := CanonicalArtifact.hash_value(contracts.design_brief)
			var cohesion_hash := CanonicalArtifact.hash_value(contracts.cohesion_contract)
			var interface_plan_hash := CanonicalArtifact.hash_value(contracts.interface_plan)
			var interface_compilation_hash := CanonicalArtifact.hash_value(
				contracts.interface_compilation)
			if str(contracts.design_brief.get("payload", {}).get("intent_hash", "")) != \
					intent_hash:
				failures.append("PROCESS_BRIEF_INTENT_HASH_MISMATCH")
			if str(contracts.cohesion_contract.get("payload", {}).get(
					"design_brief_hash", "")) != brief_hash:
				failures.append("PROCESS_COHESION_BRIEF_HASH_MISMATCH")
			if str(contracts.interface_plan.get("payload", {}).get(
					"solved_assembly_hash", "")) != solved_hash or \
					str(contracts.interface_plan.get("payload", {}).get(
					"cohesion_contract_hash", "")) != cohesion_hash:
				failures.append("PROCESS_INTERFACE_PLAN_INPUT_HASH_MISMATCH")
			if str(contracts.interface_compilation.get("payload", {}).get(
					"solved_assembly_hash", "")) != solved_hash or \
					str(contracts.interface_compilation.get("payload", {}).get(
					"interface_plan_hash", "")) != interface_plan_hash:
				failures.append("PROCESS_INTERFACE_COMPILATION_INPUT_HASH_MISMATCH")
			if str(stages_by_id.get("resolve_brief", {}).get("output_hash", "")) != brief_hash or \
					str(stages_by_id.get("resolve_design", {}).get(
					"input_hashes", {}).get("design_brief", "")) != brief_hash:
				failures.append("PROCESS_BRIEF_STAGE_HASH_MISMATCH")
			if str(stages_by_id.get("plan_interfaces", {}).get(
					"output_hash", "")) != interface_plan_hash:
				failures.append("PROCESS_INTERFACE_PLAN_STAGE_HASH_MISMATCH")
			if str(stages_by_id.get("compile_interfaces", {}).get(
					"output_hash", "")) != interface_compilation_hash:
				failures.append("PROCESS_INTERFACE_COMPILATION_STAGE_HASH_MISMATCH")
			if str(stages_by_id.get("compile_appearance", {}).get(
					"input_hashes", {}).get("geometry", "")) != str(
					contracts.interface_compilation.get("payload", {}).get(
					"output_geometry_hash", "")):
				failures.append("PROCESS_STYLE_BYPASSED_INTERFACE_GEOMETRY")
	return {"ok": failures.is_empty(), "failures": failures,
		"stages": stage_ids.size(), "stage_ids": stage_ids,
		"pipeline_hash": recorded_hash}
