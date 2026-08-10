extends RefCounted
## PolyForge composition grammar — DELIBERATE placement, not scatter.
## Anchors/counts are hand-chosen by the author; seeded jitter only wobbles within
## a hard bound. Silhouette-defining detail should never depend on unconstrained scatter.
## Every `place` callable receives (pos: Vector3, rot_y: float, i: int).

static func ring(center: Vector3, radius: float, count: int, seed_val: int, jitter: float, place: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for i in range(count):
		var a := TAU * i / count + (rng.randf_range(-jitter, jitter) / maxf(radius, 0.001))
		var r := radius + rng.randf_range(-jitter, jitter)
		place.call(center + Vector3(cos(a) * r, 0.0, sin(a) * r), a, i)

static func arc(center: Vector3, radius: float, from_deg: float, to_deg: float, count: int,
		seed_val: int, jitter: float, place: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for i in range(count):
		var t := float(i) / maxf(count - 1, 1.0)
		var a := deg_to_rad(lerpf(from_deg, to_deg, t)) + (rng.randf_range(-jitter, jitter) / maxf(radius, 0.001))
		var r := radius + rng.randf_range(-jitter, jitter)
		place.call(center + Vector3(cos(a) * r, 0.0, sin(a) * r), a, i)

## Walk the hexagon perimeter at (hex_r - inset). rot_y = edge tangent angle, so
## placed detail can align with the rim. corner_phase_deg rotates the hexagon to
## match a consumer's radial segment phase (calibrate visually once).
static func border_band(center: Vector3, hex_r: float, inset: float, count: int, seed_val: int,
		jitter: float, place: Callable, corner_phase_deg := 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var corners: Array = []
	for e in range(6):
		var a := TAU * e / 6.0 + deg_to_rad(corner_phase_deg)
		corners.append(Vector3(cos(a), 0.0, sin(a)) * (hex_r - inset))
	for i in range(count):
		var t := float(i) / count * 6.0
		var e2 := int(t) % 6
		var frac := t - int(t)
		var ca: Vector3 = corners[e2]
		var cb: Vector3 = corners[(e2 + 1) % 6]
		var pos := center + ca.lerp(cb, frac)
		pos += Vector3(rng.randf_range(-jitter, jitter), 0.0, rng.randf_range(-jitter, jitter))
		var tangent := cb - ca
		place.call(pos, atan2(-tangent.z, tangent.x), i)

static func cluster_at(anchors: Array, seed_val: int, jitter: float, place: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for i in range(anchors.size()):
		var a: Vector3 = anchors[i]
		var pos := a + Vector3(rng.randf_range(-jitter, jitter), 0.0, rng.randf_range(-jitter, jitter))
		place.call(pos, rng.randf_range(0.0, TAU), i)
