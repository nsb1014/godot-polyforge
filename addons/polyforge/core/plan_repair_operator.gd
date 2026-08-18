extends RefCounted
## Minimal domain-specific repair contract. Implementations return PlanPatch artifacts.

func descriptor() -> Dictionary:
	return {"id": "polyforge.repair.unsupported", "version": "1.0.0",
		"diagnostic_codes": [], "operation_kinds": [], "deterministic": true}

func supports(_plan, diagnostic: Dictionary) -> bool:
	return descriptor().diagnostic_codes.has(str(diagnostic.get("code", "")))

func propose(_plan, _diagnostic: Dictionary, _attempt: int) -> Dictionary:
	return {"ok": false, "diagnostics": [{"code": "REPAIR_UNSUPPORTED",
		"severity": "error", "message": "repair operator cannot handle diagnostic",
		"entities": []}]}
