extends RefCounted
## Domain-agnostic immutable stage ledger. It records dependencies; it owns no build logic.

const CanonicalArtifact := preload("res://addons/polyforge/core/canonical_artifact.gd")

var pipeline_id: String
var records: Array[Dictionary] = []
var _ids := {}

func _init(id := "asset_pipeline") -> void:
	pipeline_id = str(id)

func record(stage_id: String, producer: String, input_hashes: Dictionary,
		output, diagnostics := []) -> Dictionary:
	assert(stage_id != "", "stage IDs must not be empty")
	assert(not _ids.has(stage_id), "duplicate stage ID: " + stage_id)
	var normalized_inputs := {}
	for name in input_hashes:
		var value := str(input_hashes[name])
		assert(value != "", "stage input hashes must not be empty")
		normalized_inputs[str(name)] = value
	var output_hash: String = output.content_hash() if output is Object and \
			output.has_method("content_hash") else CanonicalArtifact.hash_value(output)
	var stage: Dictionary = CanonicalArtifact.canonicalize({
		"stage_id": stage_id,
		"producer": producer,
		"input_hashes": normalized_inputs,
		"output_hash": output_hash,
		"diagnostics": diagnostics,
		"status": "completed",
	})
	records.append(stage)
	_ids[stage_id] = true
	return stage

func snapshot() -> Dictionary:
	var result: Dictionary = CanonicalArtifact.canonicalize({
		"pipeline_id": pipeline_id,
		"schema_version": 1,
		"stages": records,
	})
	result["pipeline_hash"] = CanonicalArtifact.hash_value(result)
	return result
