# Godot PolyForge

Godot PolyForge is a standalone procedural low-poly asset generation toolkit for Godot 4.
It builds deterministic meshes and named assemblies in GDScript, validates geometry and authored
relationships, and exports ordinary Godot-importable GLB files plus optional metadata and previews.

PolyForge is a development-time dependency. Generated assets can be imported by a game or tool
without running PolyForge at application startup.

## Scope

PolyForge provides reusable infrastructure for:

- procedural polygon meshes, primitive assemblies, sweeps, lathes, heightfields, and SDF surfaces;
- deterministic material assignment and vertex-color painting;
- parameter schemas, derived measurements, and boundary sweeps;
- named components, typed sockets, rigid assembly solving, and bounded repair;
- surface attachment, interface geometry, suspension members, rigs, and animation clips;
- structural, topology, readability, provenance, and relationship validation;
- preserved and merged GLB export, manifests, and optional review output.

Asset catalogs, palettes, naming schemes, reference material, and output locations belong to the
project using PolyForge. This repository contains the reusable addon and synthetic tests, not a
catalog of finished or reference-derived models.

## Installation

Copy the addon into a Godot project:

```text
res://addons/polyforge/
```

The command-line entry point is:

```text
res://addons/polyforge/cli/polyforge_cli.gd
```

No Node or browser runtime is required for asset construction.

## Minimal project-owned recipe

Recipes belong in the consuming project rather than this repository.

```gdscript
extends RefCounted

const Assembly := preload("res://addons/polyforge/core/assembly.gd")
const Parameters := preload("res://addons/polyforge/core/parameters.gd")
const Stock := preload("res://addons/polyforge/core/stock.gd")

func parameters() -> Dictionary:
	return {
		"size": Parameters.scale(1.0, 0.5, 2.0, "m", "Overall fixture size."),
	}

func build(p) -> Dictionary:
	var size: float = p.value("size")
	var material := Stock.material("primary", Color("6f86a6"), 0.0, 0.75)
	var assembly := Assembly.new()
	assembly.add("root", Stock.with_material(
		Stock.box(Vector3.ONE * size), material))
	return {
		"name": "project_asset",
		"category": "prop",
		"assembly": assembly,
		"triangle_budget": 500,
		"anchors": {"origin": Vector3.ZERO},
		"front": "+Z",
	}
```

A recipe may also return checks, topology policy, surface classifications, a rig, animation clips,
typed contracts, reference policy, and readability requirements. These are optional and should be
owned by the consuming project.

## Build assets offline

```bash
godot --path . --script res://addons/polyforge/cli/polyforge_cli.gd -- \
  build res://path/to/project_recipe.gd \
  --param size=1.25 --out res://out --mode both
```

A build can produce:

```text
out/project_asset.glb
out/project_asset_merged.glb
out/project_asset.manifest.json
out/project_asset_viewer.json
out/project_asset_viewer.html
out/project_asset_turntable.png
```

Every emitted GLB is imported again through Godot's `GLTFDocument`. A build fails if Godot cannot
consume its own output. Inspect an existing GLB with:

```bash
godot --path . --script res://addons/polyforge/cli/polyforge_cli.gd -- \
  inspect res://out/project_asset.glb
```

Use `--no-glb`, `--no-viewer`, `--no-preview`, or `--no-readability` when a build only needs
the corresponding validation stages.

## Core concepts

### Deterministic geometry

`core/mesh.gd` stores indexed polygons and emits Godot meshes. Construction operations preserve
stable ordering so repeated builds from the same inputs can be compared byte-for-byte or through
geometry fingerprints.

### Named assemblies and components

`core/assembly.gd` keeps semantic part names through export. `core/component.gd` provides reusable
local-space geometry and sockets. `core/component_catalog.gd`, `core/assembly_plan.gd`, and
`core/rigid_assembly_solver.gd` support geometry-free planning followed by deterministic placement.

### Parameters and sweeps

`core/parameters.gd` separates primary measurements from derived values and records dependency
provenance. Sweep cases cover individual bounds and pairwise boundary interactions without changing
the recipe source.

### Construction and appearance ownership

Construction creates geometry. Appearance binds project-owned material slots afterward.
`build/style_compiler.gd` verifies that appearance changes do not mutate the geometry fingerprint.

### Validation

Validation is observational and does not silently repair geometry. Available checks include:

- mesh indices, winding, degeneracy, manifold structure, attributes, and triangle budgets;
- part gaps, intersections, burial, symmetry, proportions, and attachment drift;
- socket residuals, clearances, interface overlap, and causal support paths;
- rig bindings, animation loops, surface classifications, and multi-view readability;
- stage-ledger and cross-stage hash consistency.

Repairs, when enabled, are explicit bounded plan patches with recorded diagnostics and provenance.

### Export

The GLB exporter supports preserved named parts and material-batched merged output. The manifest
records bounds, anchors, part names, materials, validation results, parameters, and contract hashes.
Viewer and preview output are optional review aids and are never required at application runtime.

## Module map

| Path | Purpose |
|---|---|
| `core/mesh.gd` | Polygon storage, construction helpers, transforms, and ArrayMesh emission |
| `core/stock.gd` | Godot primitive and material factories |
| `core/assembly.gd` | Named parts, component instances, metadata, and merging |
| `core/component.gd` | Reusable local-space components and sockets |
| `core/parameters.gd` | Parameter schemas, derived measurements, overrides, and sweeps |
| `core/attachments.gd` | Geometry-sampled attachment frames and drift checks |
| `core/surface_attach.gd` | Closest-surface queries and normal-aligned placement |
| `core/surface_types.gd` | Construction, role, repetition, and motion classification |
| `core/topology_budget.gd` | Projected-size topology profiles and budgets |
| `core/rig.gd` | Bones, skin bindings, and animation clip data |
| `core/canonical_artifact.gd` | Canonical dictionaries and stable content hashes |
| `core/assembly_plan.gd` | Geometry-free component graph and connection constraints |
| `core/solved_assembly.gd` | Solved transforms, residuals, and clearance evidence |
| `core/rigid_assembly_solver.gd` | Typed-socket rigid placement |
| `build/build_pipeline.gd` | Validation gate and coordinated output |
| `build/stage_runner.gd` | Deterministic stage ledger and provenance |
| `build/style_compiler.gd` | Non-geometric appearance binding |
| `quality/lint_core.gd` | Structural mesh validation |
| `quality/checks.gd` | Named-part relationship checks |
| `quality/readability.gd` | Play-size and multi-view readability metrics |
| `quality/process_validation.gd` | Stage-order and cross-stage hash validation |
| `exporters/gltf_export.gd` | Preserved and merged GLB export and inspection |
| `exporters/manifest_export.gd` | Machine-readable build metadata |
| `exporters/preview_export.gd` | Optional multi-view PNG output |
| `exporters/viewer_export.gd` | Optional self-contained review viewer |

## Testing PolyForge itself

Run the synthetic test suite:

```bash
godot --headless --path . --script res://tests/test_polyforge.gd
```

Repository tests use neutral geometry and contract fixtures. Temporary recipes and all generated
outputs must be created beneath `out/`; they must not be committed.

The generic GitHub Actions workflow runs structural tests, a parameter sweep, GLB round-trip
inspection, determinism checks, and repository-hygiene checks. It does not publish generated models
as repository content.

## Repository hygiene

This repository intentionally excludes finished assets, subject-specific recipes, reference
recreations, renders, GLBs, manifests, viewers, contact sheets, and generated model evidence.
Framework development may generate those files temporarily under `out/`, which is ignored.

Instructions for AI-assisted consumers and contributors are in [`llms.txt`](llms.txt).

## License

PolyForge is distributed under the MIT License. See [`LICENSE`](LICENSE) and [`NOTICE.md`](NOTICE.md).
