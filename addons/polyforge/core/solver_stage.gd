extends RefCounted
## Minimal shared solver invocation contract. Domain mathematics stay specialized.

func descriptor() -> Dictionary:
	return {}

func supports(_problem: Dictionary) -> bool:
	return false

func solve(problem: Dictionary, _context := {}) -> Dictionary:
	if not supports(problem):
		return {"status": "unsupported", "solution": {}, "evidence": {},
			"diagnostics": [{"code": "SOLVER_UNSUPPORTED_PROBLEM",
				"severity": "error", "problem_type": problem.get("problem_type", "")}],
			"provenance": descriptor(), "statistics": {}}
	return {"status": "error", "solution": {}, "evidence": {},
		"diagnostics": [{"code": "SOLVER_NOT_IMPLEMENTED", "severity": "error"}],
		"provenance": descriptor(), "statistics": {}}
