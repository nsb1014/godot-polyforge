# Measured-shape minotaur study

This static character is the first trial of defining shape before tessellation.
The reference is the rightmost character in the user-supplied ensemble image,
SHA-256 `64f7a9ab586a343bc96efab38c149a99084cde31f1611665dc52ace09cd10543`.
The image itself is excluded from the repository.

## Scope and assumptions

- Default horn-tip height is approximately 3.6 m, an authoring assumption.
- Proportions and stations are hand-authored estimates from one perspective image.
- Depth, hidden surfaces, and the rear mane are inferred.
- This is a static, separately assembled character study. Animation skinning,
  deformation topology, texture baking, and automatic image fitting are future work.
- Armor, flesh, fur, and fingers intentionally overlap. This prototype does not
  claim to provide a watertight unified character or collision-free articulation.

## Implementation

`core/measured_shape.gd` adds elliptical station lofts, concave profile extrusion,
and cubic Bezier tubes. The minotaur recipe first records all source shapes,
freezes them in construction intent and resolved design, and then compiles meshes.
Appearance is bound afterward using the existing geometry fingerprint check.

Lofts interpolate between measured stations linearly. Radial samples are multiples
of four so X/Z extrema survive fidelity changes. Cubic centerlines are subdivided
with the bound `max |B''| / 8` on each normalized interval. This is a second-derivative
Taylor/interpolation error bound. Failure to meet tolerance within the subdivision
limit is reported explicitly. Tube caps use center fans to avoid thin tip triangles.

The reported bounds cover centerline chords and cross-section rings independently.
They do not establish a full swept-surface Hausdorff bound or reference-image accuracy.
Ellipsoid latitude sampling and decorative torus sections remain conventional stock
geometry. There is no parameter-fitting optimizer in this first implementation.

Height changes uniformly scale the authoring frame. The `detail` parameter changes
tessellation without changing the recorded source shapes. Default detail is 1.0,
with 0.6 and 1.8 used for coarse and fine comparisons. Model triangle budgets are
32,000, including the highest supported detail setting.

## Reproduce

Use the repository's pinned Godot 4.4.1.

```sh
godot --headless --path . --script res://tests/test_polyforge.gd
godot --headless --path . --script res://tests/test_measured_shape.gd
godot --headless --path . --script res://addons/polyforge/cli/polyforge_cli.gd -- \
  build res://examples/minotaur_recipe.gd --out res://out/minotaur --mode both \
  --no-preview --no-readability --no-sweep-readability
```

The last command retains the full default pairwise parameter sweep and performs
Godot GLB round-trip checks. The three disabled options require a working rendering
display. On a configured Godot desktop, omit them to collect native previews and
play-size readability evidence.

An optional offline Blender render script imports the actual GLB and produces eight
views plus a larger preview. Its images are visual review evidence, separate from
Godot's native readability measurements.

```sh
blender -b --python examples/render_minotaur.py -- out/minotaur
```

## Validation

Focused tests cover dense independent curve-error sampling, preserved endpoints,
subdivision limits, invalid controls and radii, collapsed paths and reversing cusps,
closed and consistently oriented meshes, concave extrusion in both winding orders,
measured loft extrema, deterministic rebuilds, and fidelity-independent definitions.
The normal build additionally checks named torso/head/tabard dimensions, required
reference features, stage provenance, appearance isolation, mesh structure, triangle
budgets, uniform scaling, and height/detail boundary interactions.

The local environment supports headless Godot export and offline Blender CPU renders.
Godot display-backed preview/readability checks and the interactive browser viewer
could not be run here. Visual review is required before treating this study as a
finished likeness of the supplied reference.

## Grip and armor-fit revision

The hands use four continuous curled finger tubes and an opposing thumb around a
frame derived from the axe axis and elbow. Palm dimensions are scaled in their
local frame before rotation. The forearm ends at the wrist behind the handle.

Bracers, greaves, and the breastplate derive their sections from the exact underlying
body loft, including every taper station in the covered interval. Their rims use
those same elliptical sections. The leather harness conforms to the breastplate.
The hidden upper-arm volume beneath the shoulder plates is trimmed back to prevent
it from appearing between the overlapping layers in this static pose.

Seventeen mandatory semantic fit checks run through the normal build and parameter
sweeps. Five armor pairs use independent ray intersections against emitted triangles
at 32 angles, nine heights, and additional mesh station heights. Twelve hand parts
use the minimum distance of each projected triangle to the handle axis, detecting
penetration even when triangle vertices lie outside the cylinder. Maximum grip gaps
also reject floating hands. The handle envelope includes the leather wraps.

These checks establish the declared static fits. Armor clearance is sampled, and
the system does not claim exhaustive collision freedom for every decorative pair
or for future animated poses. The regression suite includes intentionally reversed
armor layers and a triangle that crosses a handle despite exterior vertices.
