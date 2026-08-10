extends RefCounted
## Configurable polygon-density profiles for PolyForge authoring.
##
## Projects inject every value; this portable module owns no usage names, quality levels,
## or budgets. Profiles coordinate generator sampling with a final triangle ceiling. They
## do not decimate finished meshes because automatic decimation can destroy silhouettes,
## material tags, attachment datums, and intentionally flat surfaces.

const REQUIRED_FIELDS := [
	"triangle_target",
	"radial_segments",
	"curve_points",
	"heightfield_long_axis",
	"sdf_long_axis",
	"sdf_min_axis_cells",
	"detail_scale",
]

class Profile extends RefCounted:
	var triangle_target: int
	var radial_segments: int
	var curve_points: int
	var heightfield_long_axis: int
	var sdf_long_axis: int
	var sdf_min_axis_cells: int
	var detail_scale: float

	func _init(values: Dictionary) -> void:
		triangle_target = int(values.triangle_target)
		radial_segments = int(values.radial_segments)
		curve_points = int(values.curve_points)
		heightfield_long_axis = int(values.heightfield_long_axis)
		sdf_long_axis = int(values.sdf_long_axis)
		sdf_min_axis_cells = int(values.sdf_min_axis_cells)
		detail_scale = float(values.detail_scale)
		assert(triangle_target > 0, "triangle_target must be positive")
		assert(radial_segments >= 3, "radial_segments must be at least 3")
		assert(curve_points >= 2, "curve_points must be at least 2")
		assert(heightfield_long_axis >= 1, "heightfield_long_axis must be positive")
		assert(sdf_long_axis >= 2, "sdf_long_axis must be at least 2")
		assert(sdf_min_axis_cells >= 1, "sdf_min_axis_cells must be positive")
		assert(detail_scale >= 0.0, "detail_scale cannot be negative")

	## Angular sampling for lathes, cylinders, rings, and circular cross-sections.
	func radial(multiplier := 1.0, minimum := 3, maximum := -1) -> int:
		var value := maxi(minimum, roundi(radial_segments * multiplier))
		return mini(value, maximum) if maximum >= minimum else value

	## Sampling count for authored curves or paths. This does not resample a path itself.
	func curve(multiplier := 1.0, minimum := 2, maximum := -1) -> int:
		var value := maxi(minimum, roundi(curve_points * multiplier))
		return mini(value, maximum) if maximum >= minimum else value

	## Scale optional repeated detail while preserving an author-declared minimum.
	func detail_count(authored_count: int, minimum := 0) -> int:
		return maxi(minimum, roundi(authored_count * detail_scale))

	## Aspect-preserving heightfield grid. `size` is the authored X/Z extent.
	func heightfield_resolution(size: Vector2) -> Vector2i:
		var longest: float = maxf(absf(size.x), absf(size.y))
		if longest <= 0.000001:
			return Vector2i.ONE
		return Vector2i(
			maxi(1, roundi(heightfield_long_axis * absf(size.x) / longest)),
			maxi(1, roundi(heightfield_long_axis * absf(size.y) / longest)))

	## Surface-nets cell size derived from the longest bound while guaranteeing a minimum
	## number of cells through the thinnest non-zero axis. `smallest_feature` optionally
	## requests at least two samples across a feature the author must preserve.
	func sdf_cell(bounds: AABB, smallest_feature := 0.0) -> float:
		var dims := [absf(bounds.size.x), absf(bounds.size.y), absf(bounds.size.z)]
		var longest: float = maxf(dims[0], maxf(dims[1], dims[2]))
		assert(longest > 0.000001, "SDF bounds must have non-zero size")
		var shortest := INF
		for dim in dims:
			if dim > 0.000001:
				shortest = minf(shortest, dim)
		var cell: float = minf(longest / float(sdf_long_axis),
			shortest / float(sdf_min_axis_cells))
		if smallest_feature > 0.0:
			cell = minf(cell, smallest_feature * 0.5)
		return cell

## Build a profile from project-owned configuration and optional per-asset overrides.
## Missing required fields and unknown override fields fail loudly.
static func make(config: Dictionary, overrides := {}) -> Profile:
	for field in REQUIRED_FIELDS:
		assert(config.has(field), "missing PolyForge density field: " + field)
	var values: Dictionary = config.duplicate(true)
	for key in overrides:
		assert(REQUIRED_FIELDS.has(key), "unknown PolyForge density override: " + str(key))
		values[key] = overrides[key]
	return Profile.new(values)

