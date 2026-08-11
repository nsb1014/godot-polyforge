extends RefCounted
## Play-size image measurements for procedural assets.
##
## This independently implemented Godot image pass follows the ModelKit design principle
## that legibility should be measured at the size used in play, not inferred from mesh detail.

static func default_policy(category: String) -> Dictionary:
	var policy := {
		"enabled": true,
		"required": false,
		"target_pixels": 64,
		"supersample": 2,
		"minimum_regions": 2,
		"minimum_contrast": 0.08,
		"minimum_stroke_px": 1.5,
		"background_tolerance": 0.055,
		"view_set": "front",
		"critical_parts": {},
		"minimum_visible_fraction": 0.35,
	}
	match category:
		"plant":
			policy.minimum_regions = 2
			policy.minimum_stroke_px = 1.0
		"structure":
			policy.minimum_stroke_px = 1.25
		"terrain":
			policy.minimum_regions = 1
			policy.minimum_contrast = 0.035
			policy.minimum_stroke_px = 1.0
	return policy

static func normalize_policy(category: String, supplied := {}) -> Dictionary:
	var policy := default_policy(category)
	if supplied is Dictionary:
		for key in supplied:
			policy[key] = supplied[key]
	policy.target_pixels = maxi(16, int(policy.target_pixels))
	policy.supersample = clampi(int(policy.supersample), 1, 4)
	assert(str(policy.view_set) in ["front", "cardinal", "octants"],
		"readability view_set must be front, cardinal, or octants")
	return policy

static func view_angles(view_set: String) -> Array[float]:
	match view_set:
		"cardinal":
			return [0.0, 90.0, 180.0, 270.0]
		"octants":
			return [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
	return [0.0]

static func view_is_required(rule, yaw: float) -> bool:
	if not rule is Dictionary or not rule.has("views"):
		return true
	for value in rule.views:
		if is_equal_approx(fposmod(float(value), 360.0), fposmod(yaw, 360.0)):
			return true
	return false

static func aggregate_views(view_reports: Array, supplied_policy := {}) -> Dictionary:
	var policy := normalize_policy("default", supplied_policy)
	if view_reports.is_empty():
		return {"available": false, "ok": false, "views": [],
			"issues": PackedStringArray(["no readability views were rendered"]), "policy": policy}
	var available := true
	var issues := PackedStringArray()
	var sums := {"regions": 0.0, "contrast": 0.0, "stroke_px": 0.0,
		"width_px": 0.0, "height_px": 0.0, "solidity": 0.0}
	var worst_index := 0
	var worst_margin := INF
	for index in range(view_reports.size()):
		var view: Dictionary = view_reports[index]
		var report: Dictionary = view.get("readability", {})
		available = available and bool(report.get("available", false))
		var yaw := float(view.get("yaw", 0.0))
		for issue in view.get("issues", PackedStringArray()):
			issues.append("view %d°: %s" % [roundi(yaw), issue])
		for issue in report.get("issues", PackedStringArray()):
			issues.append("view %d°: %s" % [roundi(yaw), issue])
		for key in sums:
			sums[key] += float(report.get(key, 0.0))
		var margin := minf(
			float(report.get("regions", 0)) / maxf(float(policy.minimum_regions), 1.0),
			minf(float(report.get("contrast", 0.0)) / maxf(float(policy.minimum_contrast), 0.000001),
				float(report.get("stroke_px", 0.0)) / maxf(float(policy.minimum_stroke_px), 0.000001)))
		if margin < worst_margin:
			worst_margin = margin
			worst_index = index
	var divisor := maxf(float(view_reports.size()), 1.0)
	var averages := {}
	for key in sums:
		averages[key] = snappedf(float(sums[key]) / divisor, 0.001)
	var worst: Dictionary = view_reports[worst_index]
	var worst_readability: Dictionary = worst.get("readability", {})
	return {
		"available": available,
		"ok": available and issues.is_empty(),
		"view_set": policy.view_set,
		"views": view_reports,
		"worst_view": worst.get("yaw", 0.0),
		"averages": averages,
		"regions": worst_readability.get("regions", 0),
		"contrast": worst_readability.get("contrast", 0.0),
		"stroke_px": worst_readability.get("stroke_px", 0.0),
		"width_px": worst_readability.get("width_px", 0.0),
		"height_px": worst_readability.get("height_px", 0.0),
		"solidity": worst_readability.get("solidity", 0.0),
		"issues": issues,
		"policy": policy,
	}

static func _color_distance(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

static func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722

static func _edge_colors(image: Image) -> Array[Color]:
	var w := image.get_width()
	var h := image.get_height()
	return [
		image.get_pixel(0, 0), image.get_pixel(w - 1, 0),
		image.get_pixel(0, h - 1), image.get_pixel(w - 1, h - 1),
		image.get_pixel(w / 2, 0), image.get_pixel(w / 2, h - 1),
		image.get_pixel(0, h / 2), image.get_pixel(w - 1, h / 2),
	]

static func _matches_edge(color: Color, edge_colors: Array[Color], tolerance: float) -> bool:
	for edge_color in edge_colors:
		if _color_distance(color, edge_color) <= tolerance:
			return true
	return false

## State values: 0 unseen, 1 edge-connected background, 2 rejected foreground boundary.
static func _background_mask(image: Image, tolerance: float) -> PackedByteArray:
	var w := image.get_width()
	var h := image.get_height()
	var state := PackedByteArray()
	state.resize(w * h)
	var stack := PackedInt32Array()
	for x in range(w):
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in range(h):
		stack.append(y * w)
		stack.append(y * w + w - 1)
	var edge_colors := _edge_colors(image)
	while not stack.is_empty():
		var index := stack[-1]
		stack.resize(stack.size() - 1)
		if state[index] != 0:
			continue
		var x := index % w
		var y := index / w
		if not _matches_edge(image.get_pixel(x, y), edge_colors, tolerance):
			state[index] = 2
			continue
		state[index] = 1
		if x > 0:
			stack.append(index - 1)
		if x + 1 < w:
			stack.append(index + 1)
		if y > 0:
			stack.append(index - w)
		if y + 1 < h:
			stack.append(index + w)
	return state

static func _region_key(color: Color) -> int:
	var r := clampi(int(color.r * 5.0), 0, 4)
	var g := clampi(int(color.g * 5.0), 0, 4)
	var b := clampi(int(color.b * 5.0), 0, 4)
	return r * 25 + g * 5 + b

static func _subject(mask: PackedByteArray, width: int, x: int, y: int) -> bool:
	return mask[y * width + x] != 1

static func analyze(image: Image, supplied_policy := {}) -> Dictionary:
	var policy := normalize_policy("default", supplied_policy)
	if image == null or image.is_empty():
		return {"available": false, "ok": false,
			"issues": PackedStringArray(["renderer returned no image"]), "policy": policy}
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	var mask := _background_mask(image, float(policy.background_tolerance))
	var edge_colors := _edge_colors(image)
	var background_luminance := 0.0
	for color in edge_colors:
		background_luminance += _luminance(color)
	background_luminance /= maxf(float(edge_colors.size()), 1.0)
	var count := 0
	var contrast_sum := 0.0
	var minimum := Vector2i(width, height)
	var maximum := Vector2i(-1, -1)
	var bins := {}
	for y in range(height):
		for x in range(width):
			if not _subject(mask, width, x, y):
				continue
			var color := image.get_pixel(x, y)
			count += 1
			contrast_sum += absf(_luminance(color) - background_luminance)
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
			var key := _region_key(color)
			bins[key] = int(bins.get(key, 0)) + 1
	var issues := PackedStringArray()
	if count == 0:
		issues.append("asset produced no foreground pixels at play size")
		return {"available": true, "ok": false, "subject_pixels": 0,
			"width_px": 0.0, "height_px": 0.0, "regions": 0, "contrast": 0.0,
			"stroke_px": 0.0, "solidity": 0.0, "issues": issues, "policy": policy}
	var runs: Array[int] = []
	for y in range(minimum.y, maximum.y + 1):
		var run := 0
		for x in range(minimum.x, maximum.x + 1):
			if _subject(mask, width, x, y):
				run += 1
			elif run > 0:
				runs.append(run)
				run = 0
		if run > 0:
			runs.append(run)
	for x in range(minimum.x, maximum.x + 1):
		var run := 0
		for y in range(minimum.y, maximum.y + 1):
			if _subject(mask, width, x, y):
				run += 1
			elif run > 0:
				runs.append(run)
				run = 0
		if run > 0:
			runs.append(run)
	runs.sort()
	var supersample := float(policy.supersample)
	var measured_width := float(maximum.x - minimum.x + 1) / supersample
	var measured_height := float(maximum.y - minimum.y + 1) / supersample
	var stroke := float(runs[runs.size() / 2]) / supersample if not runs.is_empty() else 0.0
	var regions := 0
	for bin_count in bins.values():
		if float(bin_count) / float(count) >= 0.05:
			regions += 1
	var contrast := contrast_sum / float(count)
	var solidity := float(count) / float(
		(maximum.x - minimum.x + 1) * (maximum.y - minimum.y + 1))
	if regions < int(policy.minimum_regions):
		issues.append("only %d color regions survive; expected at least %d" % [
			regions, int(policy.minimum_regions)])
	if contrast < float(policy.minimum_contrast):
		issues.append("mean background contrast %.3f is below %.3f" % [
			contrast, float(policy.minimum_contrast)])
	if stroke < float(policy.minimum_stroke_px):
		issues.append("typical feature thickness %.2fpx is below %.2fpx" % [
			stroke, float(policy.minimum_stroke_px)])
	return {
		"available": true,
		"ok": issues.is_empty(),
		"subject_pixels": count,
		"width_px": snappedf(measured_width, 0.01),
		"height_px": snappedf(measured_height, 0.01),
		"regions": regions,
		"contrast": snappedf(contrast, 0.001),
		"stroke_px": snappedf(stroke, 0.01),
		"solidity": snappedf(solidity, 0.001),
		"issues": issues,
		"policy": policy,
	}
