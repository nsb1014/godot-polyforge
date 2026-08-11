# Godot PolyForge

Standalone procedural low-poly asset and environment generation for Godot 4.

PolyForge builds polygonal meshes in GDScript, paints them deterministically, validates
geometry and authored relationships, composes named assemblies, generates terrain/zones,
and compiles ordinary GLB assets through Godot itself. It has no Node, Three.js, game-specific
palette, catalog, asset naming scheme, or output path dependency.

## Modules

| Path | Purpose |
|---|---|
| `core/mesh.gd` | Polygon container, lathe, extrusion, heightfield, sweep, transforms, merge, paint, and ArrayMesh emission |
| `core/sdf.gd` | SDF primitives, boolean operations, warp, and coarse surface-nets polygonization |
| `core/compose.gd` | Seeded ring, arc, border, and anchored-cluster placement |
| `core/density.gd` | Consumer-defined sampling profiles and triangle targets |
| `core/palette.gd` | OKLab palette and dimension-grid snapping |
| `core/assembly.gd` | Named subparts, local frames, intentional-overlap metadata, merge, and mirroring |
| `core/asset_recipe.gd` | Project-owned recipe loading and normalized compiler contract |
| `core/parameters.gd` | Validated primary measurements, derived-dimension provenance, overrides, and sweeps |
| `core/stock.gd` | Godot primitive and material factories for named recipes |
| `core/surface_attach.gd` | Closest-surface placement with normal-aligned frames and inset |
| `core/paint.gd` | Deterministic gradients, noise, streaks, bands, planks, bricks, and painted AO |
| `quality/lint_core.gd` | Bounds, indices, degeneracy, winding, manifold, budget, attribute, and determinism checks |
| `quality/checks.gd` | Named-part gap, intersection, burial, symmetry, ratio, and `noclip` checks |
| `terrain/zone.gd` | Landforms, spline cuts, surface rules, and constrained deterministic scatter |
| `exporters/viewer_export.gd` | JSON and self-contained HTML export for the bundled WebGL viewer |
| `exporters/gltf_export.gd` | Preserved/merged GLB export and Godot round-trip inspection |
| `exporters/manifest_export.gd` | Bounds, anchors, materials, parts, validation, and output metadata |
| `exporters/preview_export.gd` | Godot-rendered four-view contact sheets |
| `build/build_pipeline.gd` | Validation gate and coordinated production output |
| `cli/polyforge_cli.gd` | Headless `build` and `inspect` commands |

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

## Compile assets offline

PolyForge is a development-time dependency. Your recipe and the addon run during the build;
the resulting GLB imports into a game like any other asset. Nothing from PolyForge needs to
execute at game startup.

```bash
godot --path . --script res://addons/polyforge/cli/polyforge_cli.gd -- \
  build res://examples/bronze_guardian_recipe.gd \
  --param height=4.2 --param bulk=1.1 --out res://dist --mode both
```

The build produces:

```text
dist/bronze_guardian.glb                 named MeshInstance3D nodes
dist/bronze_guardian_merged.glb          one material-batched mesh
dist/bronze_guardian.manifest.json       parts, bounds, anchors and validation
dist/bronze_guardian_viewer.json         browser viewer payload
dist/bronze_guardian_viewer.html         self-contained interactive review
dist/bronze_guardian_turntable.png       four views when rendering is available
```

Every emitted GLB is immediately imported again using Godot's `GLTFDocument`. A build fails
if Godot cannot consume its own output. `inspect` applies the same importer to any GLB and
reports mesh names, triangle counts, surfaces, and glTF extensions:

```bash
godot --path . --script res://addons/polyforge/cli/polyforge_cli.gd -- \
  inspect res://dist/bronze_guardian.glb
```

### Recipe contract

A project-owned recipe exposes `build()` and returns a named assembly plus optional policy:

```gdscript
extends RefCounted

const Assembly := preload("res://addons/polyforge/core/assembly.gd")
const Parameters := preload("res://addons/polyforge/core/parameters.gd")
const Stock := preload("res://addons/polyforge/core/stock.gd")

func parameters() -> Dictionary:
	return {
		"width": Parameters.scale(0.6, 0.3, 1.2, "m", "Canonical crate width"),
	}

func build(p) -> Dictionary:
	var width := p.value("width")
	var plank := p.derive("body.plank", "width", 0.08)
	var asset := Assembly.new()
	var steel := Stock.material("steel", Color("68635f"), 0.6, 0.7)
	asset.add("body", Stock.with_material(Stock.box(Vector3(width, width, width)), steel))
	return {
        "name": "crate",
        "category": "prop",
        "assembly": asset,
        "triangle_budget": 1000,
        "checks": [],
		"anchors": {"top": Vector3(0, width * 0.5, 0)},
		"metadata": {"plank_thickness": plank},
		"front": "+Z",
	}
```

See `examples/bronze_guardian_recipe.gd` for a multi-part model and `llms.txt` for the compact
agent authoring contract.

### Variable measurements

Recipes may expose `parameters()` and accept the resulting measurement context in `build(p)`.
Primary measurements have defaults and bounds. Use `Parameters.scale()` for a canonical
measurement expected to resize all three asset axes uniformly; the sweep verifies the measured
bounds follow it. Derived measurements name the value they scale
from, so the manifest can explain relationships such as `head.radius <- torso.height` rather
than preserving only the final anonymous number.

```gdscript
var height := p.value("height")
var torso_height := p.derive("torso.height", "height", 0.46)
var head_size := p.derive("head.size", "torso.height", 0.34)
var visor_width := p.derive("head.visor_width", "head.size", 1.15)
```

`p.computed()` records arbitrary relationships involving more than one source. Use it when a
dimension depends on both a local measurement and a dimensionless style parameter:

```gdscript
var width := p.computed("torso.width", torso_height * p.value("bulk") * 0.8,
	["torso.height", "bulk"], "torso.height * bulk * 0.8")
```

The compiler automatically rebuilds and validates the base recipe plus the minimum and maximum
of every declared primary measurement. This one-at-a-time sweep catches hard-coded placements,
budget overruns, broken proportions, and geometry failures away from the default size. Use
`--sweep-param height` to restrict the sweep or `--no-sweep` while iterating. Sweep measurements,
bounds, triangle counts, warnings, and failures are written into the manifest.

Use `Checks.require_axis_size()` to compare emitted geometry with the dimension that claims to
control it. This catches a parameter that is recorded correctly but was not actually applied to
the mesh. Anchors are also checked against final asset bounds; outlying anchors report a warning.

### Preserved versus merged GLB

- `--mode preserve` keeps one named node per `Assembly` part. Use this when a game needs to
  find a door, turret, hand, socket, or other movable semantic component.
- `--mode merge` batches all parts by material into one mesh for static runtime assets.
- `--mode both` writes both versions so authoring and deployment can choose independently.

Builds stop before export on malformed geometry, budget overruns, failed semantic rules, or
requested `noclip` failures. `--force` writes diagnostic artifacts while keeping failures in
the manifest. A renderer running in dummy headless mode may not support PNG output; this is
reported as a warning because the self-contained viewer still provides interactive review.

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

Open `addons/polyforge/viewer/template.html` and drop a generated `*_viewer.json`, or use
`ViewerExport.write_embedded_html()` to create a self-contained review page.

## Validation

With Godot 4 available:

```bash
godot --headless --path . --script res://tests/test_polyforge.gd
```

## Credit and licensing

See [`NOTICE.md`](NOTICE.md) for the WAM-derived modules, permission record, and pinned
source commits. This repository is distributed under the MIT License; see [`LICENSE`](LICENSE).
