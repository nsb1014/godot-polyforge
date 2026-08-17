# Godot PolyForge

Standalone procedural low-poly asset and environment generation for Godot 4.

PolyForge builds polygonal meshes in GDScript, paints them deterministically, validates
geometry and authored relationships, composes named assemblies, generates terrain/zones,
and compiles ordinary GLB assets through Godot itself. It has no Node, Three.js, game-specific
palette, catalog, asset naming scheme, or output path dependency.

`examples/arcane_pumpjack_recipe.gd` is the vapor-derrick reliability reference for reusable
components, four-axis part classification, adaptive topology, constraint-baked animation,
interaction sweeps, and eight-view rendering.

## Modules

| Path | Purpose |
|---|---|
| `core/mesh.gd` | Polygon container, lathe, extrusion, heightfield, sweep, transforms, merge, paint, and ArrayMesh emission |
| `core/sdf.gd` | SDF primitives, boolean operations, warp, and coarse surface-nets polygonization |
| `core/compose.gd` | Seeded ring, arc, border, and anchored-cluster placement |
| `core/density.gd` | Consumer-defined sampling profiles and triangle targets |
| `core/palette.gd` | OKLab palette and dimension-grid snapping |
| `core/assembly.gd` | Named subparts, reusable component instances, sockets, local frames, and merge |
| `core/component.gd` | Nestable local-space component definitions with shared meshes and sockets |
| `core/surface_types.gd` | Orthogonal construction, role, repetition, and motion taxonomy |
| `core/topology_budget.gd` | Play-size adaptive topology profiles and rendered/unique triangle accounting |
| `core/rig.gd` | Skeleton bones, skin bindings, clips, and validated motion reports |
| `core/animation.gd` | Deterministic named bone-transform animation clips |
| `core/mechanical_constraints.gd` | Four-bar solving, loop baking, and swept-link clearance checks |
| `core/asset_recipe.gd` | Project-owned recipe loading and normalized compiler contract |
| `core/parameters.gd` | Validated primary measurements, derived-dimension provenance, overrides, and sweeps |
| `core/attachments.gd` | Geometry-sampled surface frames, child bindings, provenance, and drift checks |
| `core/stock.gd` | Godot primitive and material factories for named recipes |
| `core/surface_attach.gd` | Closest-surface placement with normal-aligned frames and inset |
| `core/paint.gd` | Deterministic gradients, noise, streaks, bands, planks, bricks, and painted AO |
| `quality/lint_core.gd` | Bounds, indices, degeneracy, winding, manifold, budget, attribute, and determinism checks |
| `quality/checks.gd` | Named-part gap, intersection, burial, symmetry, ratio, and `noclip` checks |
| `quality/readability.gd` | Play-size foreground, color-region, contrast, thickness, and silhouette measurements |
| `quality/surface_validation.gd` | Surface-type-specific proportion and interface validation |
| `quality/symmetry.gd` | Scoped component-reuse and reflection contracts |
| `quality/rig_validation.gd` | Skeleton, skin, clip-loop, and mechanical report validation |
| `terrain/zone.gd` | Landforms, spline cuts, surface rules, and constrained deterministic scatter |
| `exporters/viewer_export.gd` | JSON and self-contained HTML export for the bundled WebGL viewer |
| `exporters/gltf_export.gd` | Preserved/merged GLB export and Godot round-trip inspection |
| `exporters/manifest_export.gd` | Bounds, anchors, materials, parts, validation, and output metadata |
| `exporters/preview_export.gd` | Godot-rendered multi-view contact sheets and play-size captures |
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

### Reusable components and scoped symmetry

Use `Component` for geometry that should remain identical wherever it is placed. Components can
contain named parts, sockets, and nested component instances. `Assembly.instance_component()`
flattens the hierarchy for ordinary Godot/GLB export while retaining component IDs, source-part
names, instance paths, shared mesh identity, and sockets in manifest version 6.

```gdscript
const Component := preload("res://addons/polyforge/core/component.gd")

var bent := Component.new("derrick_bent")
bent.add("left_leg", leg_mesh, left_leg_transform, leg_options)
bent.add("right_leg", leg_mesh, right_leg_transform, leg_options)

asset.instance_component("derrick_front", bent, front_transform)
asset.instance_component("derrick_back", bent, back_transform)

# Include only the relationship that is intended to be symmetric:
"symmetry": [{
	"name": "derrick front/back reuse",
	"first": "derrick_front",
	"second": "derrick_back",
	"axis": "z",
}]
```

Strict pairs must use the same component and mesh resources, remain rigidly transformed, and sit
at reflected origins. Tanks, pipes, damage, controls, and other deliberately asymmetric systems
can remain outside the contract.

### Surface classification

Parts may declare four independent fields: `construction`, `role`, `repetition`, and `motion`.
Use `SurfaceTypes.classify()` and set `require_part_classification` to enforce the complete
taxonomy. The legacy `require_surface_classification` gate remains compatible with existing
two-axis recipes. PolyForge selects relevant checks—for example profile thickness,
prismatic slenderness, conduit radius, revolved axis, or interface-socket metadata—without
assuming that every asset genre has the same topology or motion model.

### Adaptive topology and rigging

`TopologyBudget` chooses radial and bend segmentation from projected play-size error. A recipe
can separately cap rendered triangles, unique mesh-resource triangles, and named component
groups. Manifest v6 records the resulting policy and measurements instead of reducing repeated
component instances to one ambiguous triangle count.

Recipes may return a `Rig` containing Godot skeleton rests, rigid or deformable skin bindings,
named `AnimationClip` tracks, and motion validation reports. Preserved GLB export emits a real
`Skeleton3D`, `Skin`, and `AnimationPlayer`; the bundled viewer exposes play, pause, and reset for
the same clips. `MechanicalConstraints.solve_four_bar()` produces deterministic samples and
`validate_clearance()` checks moving link lanes against authored static keepouts.

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

The compiler automatically rebuilds and validates the base recipe, each individual minimum and
maximum, and all pairwise boundary combinations. Pairwise coverage catches failures such as a
wide body whose minimum-height limbs now collide without paying the exponential cost of every
possible combination. Use `--sweep-mode single` for the earlier one-at-a-time behavior,
`--sweep-param height` to restrict the parameter set, `--sweep-limit 64` to cap work, or
`--no-sweep` while iterating. Varied parameters, measurements, bounds, triangle counts, warnings,
and failures are written into the manifest. A capped plan reports how many generated cases were
not run; it never becomes silently quieter.

Use `Checks.require_axis_size()` to compare emitted geometry with the dimension that claims to
control it. This catches a parameter that is recorded correctly but was not actually applied to
the mesh. Anchors are also checked against final asset bounds; outlying anchors report a warning.

### Geometry-sampled attachments

Use `Attachments.surface()` when one part must meet another part's emitted surface. The query is
an authoring hint; PolyForge samples the closest triangle and returns a frame whose local +Y is
the surface normal. The manifest retains the host, triangle, sampled position, normal, and query
distance. Validation resamples the finished host and verifies both the surface and named child
still agree with that frame.

```gdscript
const Attachments := preload("res://addons/polyforge/core/attachments.gd")

var mounts := Attachments.new(asset)
var sign_frame := mounts.surface("sign_mount", "wall", approximate_sign_position, {
	"child": "sign",
	"inset": wall_thickness * 0.1,
	"max_hint_distance": wall_thickness * 4.0,
})
asset.add("sign", sign_mesh, sign_frame)

# Include this in the recipe result:
# "attachments": mounts.snapshot()
```

This avoids storing a second hand-typed coordinate for a relationship the wall geometry already
defines. `examples/bronze_guardian_recipe.gd` now samples the chest badge from the torso mesh.

### Play-size readability

Every build renders a neutral front view sized to the asset's declared play-size pixel target,
then repeats the measurement for enabled parameter-sweep cases so boundary interactions are
judged from their rendered output as well as their geometry.
The image pass measures surviving color regions, mean separation from the background, typical
foreground thickness, subject size, and silhouette solidity. Results are advisory by default and
are recorded under `validation.readability`; set `"required": true` in the recipe policy to make
failed measurements—or an unavailable renderer—a build failure.

```gdscript
"readability": {
	"target_pixels": 64,
	"minimum_regions": 3,
	"minimum_contrast": 0.07,
	"minimum_stroke_px": 1.5,
	"view_set": "octants",
	"critical_parts": {},
	"visibility_pairs": [],
	"required": false,
}
```

Use `--no-sweep-readability` to keep the base measurement while skipping variant renders, or
`--no-readability` only for iteration. Octant policies render all eight horizontal directions.
`critical_parts` measures semantic ID masks, while `visibility_pairs` compares reusable front/back
groups at paired angles and rejects excessive occlusion imbalance. The eight-view contact sheet
remains a separate human review aid.

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
