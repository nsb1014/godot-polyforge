extends "res://addons/polyforge/core/solver_stage.gd"
## Specialized closed-form four-bar solver behind the shared solver-stage contract.

const MechanicalConstraints := preload("res://addons/polyforge/core/mechanical_constraints.gd")

func descriptor() -> Dictionary:
	return {
		"id": "polyforge.mechanism.four_bar",
		"version": "1.0.0",
		"problem_types": ["mechanism.four_bar"],
		"constraint_kinds": ["mechanism.loop_closure", "mechanism.fixed_length"],
		"deterministic": true,
		"exact": true,
	}

func supports(problem: Dictionary) -> bool:
	if str(problem.get("problem_type", "")) != "mechanism.four_bar":
		return false
	for constraint in problem.get("constraints", []):
		if not descriptor().constraint_kinds.has(str(constraint.get("kind", ""))):
			return false
	return problem.get("parameters", {}) is Dictionary

func solve(problem: Dictionary, context := {}) -> Dictionary:
	if not supports(problem):
		return super(problem, context)
	var samples := int(context.get("samples", 64))
	if samples < 4:
		return {"status": "error", "solution": {}, "evidence": {},
			"diagnostics": [{"code": "SOLVER_INVALID_SAMPLE_BUDGET",
				"severity": "error", "measured": samples, "required": 4}],
			"provenance": descriptor(), "statistics": {"samples": samples}}
	var result := MechanicalConstraints.solve_four_bar(problem.parameters, samples)
	if not bool(result.get("ok", false)):
		return {"status": "unsatisfiable", "solution": result, "evidence": {},
			"diagnostics": [{"code": "MECHANISM_FOUR_BAR_UNSATISFIABLE",
				"severity": "error", "message": result.get("error", "solve failed")}],
			"provenance": descriptor(), "statistics": {"samples": samples}}
	return {
		"status": "solved",
		"solution": result,
		"evidence": {
			"maximum_fixed_length_error": result.maximum_fixed_length_error,
			"loop_closure_error": result.loop_closure_error,
			"sample_count": result.samples.size(),
		},
		"diagnostics": [],
		"provenance": descriptor(),
		"statistics": {"samples": samples, "iterations": 1},
	}
