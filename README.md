# Godot PolyForge

Standalone procedural low-poly asset and environment generation for Godot 4.

PolyForge builds polygonal meshes in GDScript, paints them deterministically, validates
geometry and authored relationships, composes named assemblies, generates terrain/zones,
and exports meshes for Godot or the bundled browser viewer. It has no game-specific palette,
catalog, asset naming scheme, or output path.

## Modules

| Path | Purpose |
|---|---|
| `core/mesh.gd` | Polygon container, lathe, extrusion, heightfield, sweep, transforms, merge, paint, and ArrayMesh emission |
| `core/sdf.gd` | SDF primitives, boolean operations, warp, and coarse surface-nets polygonization |
| `core/compose.gd` | Seeded ring, arc, border, and anchored-cluster placement |
| `core/density.gd` | Consumer-defined sampling profiles and triangle targets |
| `core/palette.gd` | OKLab palette and dimension-grid snapping |
| `core/assembly.gd` | Named subparts, local frames, intentional-overlap metadata, merge, and mirroring |
| `core/surface_attach.gd` | Closest-surface placement with normal-aligned frames and inset |
| `core/paint.gd` | Deterministic gradients, noise, streaks, bands, planks, bricks, and painted AO |
| `quality/lint_core.gd` | Bounds, indices, degeneracy, winding, manifold, budget, attribute, and determinism checks |
| `quality/checks.gd` | Named-part gap, intersection, burial, symmetry, ratio, and `noclip` checks |
| `terrain/zone.gd` | Landforms, spline cuts, surface rules, and constrained deterministic scatter |
| `exporters/viewer_export.gd` | JSON and self-contained HTML export for the bundled WebGL viewer |

## Install

Copy `addons/polyforge` into any Godot 4 project. Modules use relative preloads and do not
register global `class_name` symbols.

```gdscript
const PolyMesh := preload("res://addons/polyforge/core/mesh.gd")
const Paint := preload("res://addons/polyforge/core/paint.gd")
const Lint := preload("res://addons/polyforge/quality/lint_core.gd")

var body = PolyMesh.lathe([
    Vector2(0.0, -1.0),
    Vector2(0.8, -0.8),
    Vector2(1.0, 0.2),
    Vector2(0.2, 1.0),
], 12, 0.04, 42)

Paint.apply(body, [
    Paint.height_gradient(Color("553b2c"), Color("a98b62"), -1.0, 1.0),
    Paint.noise(0.4, 0.08),
], 42)

for failure in Lint.check_polymesh(body, 2000, true):
    push_error(failure)
```

## Named assemblies and semantic checks

```gdscript
const Assembly := preload("res://addons/polyforge/core/assembly.gd")
const Checks := preload("res://addons/polyforge/quality/checks.gd")

var asset := Assembly.new()
asset.add("body", body_mesh)
asset.add("chimney", chimney_mesh, chimney_transform)

var result := Checks.evaluate(asset.parts, [
    Checks.require_no_intersection("chimney", "body"),
    Checks.require_gap("chimney", "body", 0.01),
    Checks.require_symmetric("body", 0.005),
])
```

Intentional construction overlaps can be declared with
`asset.allow_overlap("chimney", "body")` before running `Checks.noclip(asset.parts)`.

## Terrain and zones

`terrain/zone.gd` produces a project-neutral PolyMesh and placement records. Projects decide
whether placements become nodes, `MultiMeshInstance3D`, packed scenes, or another format.
See `examples/generate_zone.gd`.

## Browser viewer

Open `viewer/template.html` and drop a generated `*_viewer.json`, or use
`ViewerExport.write_embedded_html()` to create a self-contained review page.

## Validation

With Godot 4 available:

```bash
godot --headless --path . --script res://tests/test_polyforge.gd
```

## Credit and licensing

See [`NOTICE.md`](NOTICE.md) for the WAM-derived modules and pinned source commits. No
repository-wide license has been selected yet; add one before offering downstream reuse.
