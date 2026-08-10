extends RefCounted
## PolyForge palette + grid snapping — generic, project-agnostic.
##
## Snap authored colours to a project-supplied palette and authored dimensions to a
## project-supplied grid step. The engine ships the MECHANISM only: it holds NO palette
## and NO grid of its own. Pass your palette/step in, or leave them empty and every snap
## is an identity no-op — so PolyForge runs unchanged in a project that wants neither.
##
## Colour nearest-match is perceptual (OKLab), not raw RGB: two colours that look equally
## close to the eye are equally close here, which is what makes palette-snapping read well.
## Alpha is passed through untouched so consumers can keep masks or other shader data in
## COLOR.a without palette snapping disturbing that separate channel.
##
## All methods are static; nothing to instantiate. Preload and call:
##   const Palette := preload("res://addons/polyforge/core/palette.gd")
##   var mat_colour := Palette.snap_color(raw, my_palette)   # my_palette: Array[Color]
##   var size       := Palette.snapv(raw_size, my_step)      # my_step: float

# ---- sRGB -> linear -> OKLab (Björn Ottosson's transform) ----

static func _srgb_to_linear(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)

## Perceptual coordinates for a colour. Distances in this space approximate perceived
## colour difference, so nearest-swatch matching lands on the swatch that looks closest.
static func to_oklab(c: Color) -> Vector3:
	var r := _srgb_to_linear(c.r)
	var g := _srgb_to_linear(c.g)
	var b := _srgb_to_linear(c.b)
	var l := pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m := pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s := pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	return Vector3(
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)

## Perceptual distance between two colours (OKLab Euclidean). Handy for a project lint
## that wants to report how far an authored colour sits from its nearest palette swatch.
static func oklab_distance(a: Color, b: Color) -> float:
	return to_oklab(a).distance_to(to_oklab(b))

## Index of the nearest palette swatch to `c` in OKLab, or -1 for an empty palette.
static func nearest_index(c: Color, palette: Array) -> int:
	var best := -1
	var best_d := INF
	var lab := to_oklab(c)
	for i in range(palette.size()):
		var d := lab.distance_squared_to(to_oklab(palette[i]))
		if d < best_d:
			best_d = d
			best = i
	return best

## Snap `c` to the nearest palette swatch (perceptual). Empty palette -> `c` unchanged.
## The source alpha is preserved (only rgb moves), never the swatch's alpha.
static func snap_color(c: Color, palette: Array) -> Color:
	var i := nearest_index(c, palette)
	if i < 0:
		return c
	var sw: Color = palette[i]
	return Color(sw.r, sw.g, sw.b, c.a)

# ---- dimension grid snap ----

## Snap a scalar to the nearest multiple of `step`. step <= 0 -> `x` unchanged.
static func snapf(x: float, step: float) -> float:
	return x if step <= 0.0 else round(x / step) * step

## Snap each component of a Vector3 to the grid. step <= 0 -> `v` unchanged.
static func snapv(v: Vector3, step: float) -> Vector3:
	return Vector3(snapf(v.x, step), snapf(v.y, step), snapf(v.z, step))
