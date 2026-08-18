# PolyForge next-session implementation brief

## Purpose

This document is the handoff for the next PolyForge implementation session. It records the current repository state, the visual failure that must be corrected, the agreed architecture, and measurable completion criteria.

The next change should improve the vapor-derrick reference reconstruction while adding reusable triangle-budgeting and Godot-native rigging/animation capabilities inspired by WAM. It must keep PolyForge a standalone Godot asset-generation pipeline.

## Start here

1. Work in `nsb1014/godot-polyforge` from current `main`.
2. Confirm `main` contains merged PR #7, commit `4355fd4c5923b84b8923926e3a5761180ecef7f2` or a descendant.
3. Read PR #7 and inspect its workflow artifact before editing.
4. Ask the user to reattach the original vapor-derrick concept and the bad PR7 result if those images are not available in the new session. Do not claim reference fidelity from prose alone.
5. Use `examples/arcane_pumpjack_recipe.gd` as the visual regression target.
6. Use GitHub Actions with the pinned Godot version for authoritative build, render, GLB round-trip, and artifact testing when Godot is unavailable in the session environment.
7. Open a draft PR and keep it draft until the user has inspected the generated multi-view and animated artifact.

## Product boundary

PolyForge is a standalone, Godot-native procedural asset generator. The Aether Wars hex-tile/zone pipeline is not part of this work and must not influence the asset recipe or architecture. Do not introduce Node, browser, or game-runtime dependencies into asset generation. The output should remain ordinary Godot-importable GLB plus PolyForge metadata and previews.

`https://antics.gg/modelkit` is a conceptual reference for measurement ownership, reusable construction vocabulary, named parts, build-time generation, and portable GLB output. `https://github.com/elliottdehn/wam` is a reference for explicit bone frames, skeleton relationships, constraints, pose/clip authoring, and glTF animation export.

Implement the ideas independently in GDScript where practical. If source or algorithms are copied or closely adapted from WAM, preserve applicable notices, add a source-level attribution comment with the upstream URL, and update `NOTICE.md`. The repository owner has stated that permission to copy from WAM was obtained from WAM's owner, but credit is still required for direct copying.

## Current baseline after PR #7

PR #7 added useful generic infrastructure:

- reusable/nestable components with stable IDs and shared mesh resources;
- sockets and hierarchy paths;
- construction and semantic surface classifications;
- scoped component-pair symmetry contracts;
- opposite-view visibility balance checks;
- parameter interaction sweeps;
- manifest v5 component, socket, surface, and symmetry records;
- preserved-node and merged GLB export and round-trip checks.

Its verified vapor-derrick artifact reported:

- 160 named meshes;
- 8,860 rendered triangles;
- 43 component instances;
- 56 exported sockets;
- 19 parameter-interaction cases;
- zero animations and no bone structure.

Keep the generic component, socket, surface, sweep, and validation systems unless a focused correction is necessary. Do not revert PR #7 wholesale.

## What went wrong visually

The PR7 tests proved internal consistency, not reference fidelity. The rebuilt derrick became over-segmented and over-symmetrized. It passed structural and visibility metrics while its part language, proportions, negative spaces, and overall silhouette moved farther from the supplied concept.

The core mistake was treating symmetry as a scene-level visual objective. The intended rule is narrower:

> Reuse the same component definition for front/back or left/right members when those members are genuinely the same manufactured part. Do not force unrelated machinery, pipes, reservoirs, trim, or occlusion to become symmetric.

Symmetry is therefore a property of an explicitly declared component relationship, never an inferred requirement for the complete asset.

## Required construction model

Break every recipe into smaller authored units. Each unit must carry four independent classifications:

| Axis | Values | Purpose |
| --- | --- | --- |
| Construction | `prismatic`, `revolved`, `swept`, `profile`, `organic` | Select topology generation and sampling rules. |
| Role | `primary_silhouette`, `structural`, `interface`, `mechanism`, `conduit`, `trim`, `effect_anchor` | Select validation and visual importance. |
| Repetition | `unique`, `paired`, `radial_repeat`, `centered` | Permit reuse without accidental global symmetry. |
| Motion | `static`, `rigid`, `deformable` | Select no binding, single-bone binding, or blended skinning. |

These axes must remain orthogonal. A swept pipe can be unique and rigid; a profile plate can be paired and rigid; a centered revolved housing can be static.

For the vapor derrick, decompose at least the following units rather than building large monolithic assemblies:

- base slab, inner deck, perimeter curb, and repeated rim blocks;
- front and rear A-frame members, cross braces, pivot bearings, and fasteners;
- the two walking-beam rails, their spacers, pivot hub, and end blocks;
- front and rear horsehead plates plus their spacers and accent inserts;
- central pump body, end caps, mounts, wheel/gear, chimney, and effect anchor;
- reusable reservoir body, cap, base, and connector components, with independent placement;
- each pipe run as endpoints, bends, and fittings rather than one decorative loop;
- crank, crank pin, pitman, flywheel, polish rod, and pump shaft as separate moving rigid pieces.

The A-frame pair, walking-beam rail pair, and horsehead plate pair should reuse component definitions. Reservoir placements, piping, chimney/effect, crank drive, and other process details may remain deliberately asymmetric when the reference calls for it.

## Reference-first visual correction

Correct the recipe before relying on new generic metrics. For every primary component, record a small set of reference-relative measurements under a common asset scale:

- center and bounding box in front, side, and top construction views;
- length, width/depth, and height owned by that component;
- pivot and attachment locations expressed in the parent component's local dimensions;
- silhouette profile and important negative spaces;
- whether the visible part is a pair, a centered part, or unique.

Dimensions should be derived from the nearest meaningful owning component. For example, a horsehead inset belongs to the horsehead profile, not the overall platform diameter. This prevents parameter changes from preserving one view while distorting the other views.

Use a custom low-vertex extruded profile for the horsehead and other distinctive plates. Do not approximate primary silhouettes with stacks of capsules or unrelated primitives merely because those primitives are available.

Automated scores are supporting evidence. The final visual gate is a human comparison of the generated eight-view sheet and orbitable model against the supplied concept.

## Triangle minimization

Triangle count must be planned during construction, not reduced indiscriminately after generation.

### Required behavior

- Add per-component and whole-asset triangle budgets.
- Report both rendered triangles and unique stored-mesh triangles. Reused mesh resources reduce unique geometry even though every visible instance contributes rendered triangles.
- Select the lowest tessellation that satisfies a projected silhouette/curvature error at the configured play-size render.
- For revolved parts, choose radial segments from projected radius and error tolerance.
- For swept conduits, choose cross-section sides from projected radius and longitudinal subdivisions from bend angle/curvature.
- For profile and prismatic parts, remove internal faces and subdivisions that do not affect silhouette, shading boundaries, sockets, or deformation.
- Preserve topology near pivots, attachment sockets, primary silhouettes, and deforming regions.
- Prefer component mesh reuse over duplicating identical geometry.
- Make quality profiles explicit (for example `preview`, `runtime`, and `hero`) rather than scattering segment constants through recipes.

Do not add a blind mesh-decimation pass as the primary solution. It can move sockets, damage hard-surface normals, and make parameter sweeps nondeterministic. A later optional simplifier is acceptable only after authored topology selection is working and protected regions are defined.

### Vapor-derrick target

The PR7 baseline is 8,860 rendered triangles. The correction must be lower than that. The implementation goal is at most 5,500 rendered triangles at the normal runtime quality, with a stretch goal near 4,500. Visual fidelity and connected motion take priority over hitting the stretch goal, but any result above 5,500 needs a per-component budget explanation in the PR.

## Godot-native rig and animation

Add a general rig data model rather than hard-coding animation into the vapor-derrick recipe.

### Rig concepts

- A bone has a stable name, parent, rest transform/frame, and optional motion limits.
- A socket is a named transform on a component and may be used as a joint or constraint endpoint.
- A rigid hard-surface component binds all of its vertices to one bone at weight `1.0`.
- A deformable component may use normalized blended weights with no more than four bone influences per vertex.
- A static component does not receive meaningless bones or weights.
- Mirrored bones may be declared from a shared definition, but mirroring is explicit and limited to a declared pair.
- Bone names, mesh/component names, sockets, and animation names must survive GLB export and Godot re-import.

Export a real `Skeleton3D`/skin when the asset declares bones. Do not merely animate anonymous scene nodes and call that a skeleton. Rigid mechanical pieces can still use single-bone skinning, which keeps their surfaces undeformed while producing conventional glTF joints and animation channels.

### Mechanical motion is constraint-baked

A pumpjack is a closed linkage, not a character-style open bone chain. A simple parent hierarchy cannot keep every joint connected.

Use a driver/constraint graph to compute the pose at each sample, then bake the resulting local bone transforms into a looping animation clip:

1. Drive the crank/flywheel angle through one revolution.
2. Compute the crank-pin position.
3. Solve the fixed-length pitman connection to the beam rear pin. A circle-circle/four-bar solution is appropriate; choose the continuous physical branch across samples.
4. Derive the walking-beam rotation about its fixed pivot.
5. Move the horsehead with the beam.
6. Derive the polish-rod/pump-shaft translation from the horsehead attachment.
7. Orient the pitman between its two solved sockets without changing its authored length.
8. Bake the transforms to a `pump_cycle` clip whose first and last poses match.

Suggested initial bone set:

- `root`
- `walking_beam`
- `horsehead`
- `crank`
- `flywheel`
- `pitman`
- `polish_rod`
- `pump_shaft`

Add or omit bones according to actual moving assemblies; do not create one bone per decorative mesh.

## Suggested implementation files

The next session should inspect existing APIs before fixing exact names, but the responsibility split should resemble:

- `addons/polyforge/core/topology_budget.gd`: quality profile, per-component budgets, adaptive segment selection, and statistics;
- `addons/polyforge/core/rig.gd`: bones, rest frames, hierarchy, bindings, sockets, and limits;
- `addons/polyforge/core/animation.gd`: clips, pose samples, channels, interpolation, and loop metadata;
- `addons/polyforge/core/mechanical_constraints.gd`: linkage and socket solvers reusable across mechanical assets;
- `addons/polyforge/quality/rig_validation.gd`: hierarchy, binding, loop, constraint, and sampled-motion validation;
- `addons/polyforge/exporters/gltf_export.gd`: `Skeleton3D`, skin, and animation export;
- `addons/polyforge/exporters/manifest_export.gd`: manifest v6 rig, clip, topology, and budget records;
- `addons/polyforge/viewer/template.html` and `viewer/template.html`: clip selection/playback plus current orbit/turntable controls;
- `examples/arcane_pumpjack_recipe.gd`: corrected reference-first recipe and `pump_cycle` setup;
- `tests/test_polyforge.gd`: deterministic topology, rig, binding, and constraint tests;
- `.github/workflows/arcane-pumpjack-test.yml`: animated GLB round-trip and artifact checks.

Keep the two viewer templates synchronized or consolidate them only if that can be done without breaking existing exports.

## Manifest and validation requirements

Advance the manifest format only when the exporter and tests are updated together. The next manifest should include:

- unique and rendered triangle totals;
- triangle totals by component, construction type, role, and quality profile;
- bone names, parent indices, and rest transforms;
- mesh/component-to-bone bindings and weight statistics;
- clips, duration, loop flag, sample rate, and animated bone list;
- maximum socket separation and fixed-length error across sampled animation;
- loop closure error;
- existing component, socket, surface, symmetry, sweep, and readability results.

Validation must reject:

- cyclic or missing-parent bone hierarchies;
- non-finite or non-invertible rest transforms;
- missing/invalid bone indices;
- weights that are negative, unnormalized, or exceed four influences;
- non-single weights on surfaces classified as rigid;
- animated components without a declared binding;
- constraint endpoints that separate beyond tolerance;
- fixed-length links that stretch beyond tolerance;
- discontinuous linkage branch flips;
- animation loops whose endpoints do not close;
- triangle budget overruns without an explicit waiver/reason.

Sample the complete animation, not just keyed endpoints. Use enough uniformly spaced samples to catch mid-cycle separation or collision; 64 samples per pump revolution is a reasonable initial floor.

## Test and artifact acceptance

The draft PR is ready for user review only when GitHub Actions produces an artifact containing:

- preserved-node and merged GLBs where applicable;
- a rigged GLB containing named bones and a looping `pump_cycle` animation;
- a manifest with topology, rig, binding, and animation statistics;
- an orbitable viewer that can play/pause/reset the clip;
- a labeled eight-view contact sheet at the agreed play size;
- triangle totals per component and unique-versus-rendered totals;
- parameter sweep results that include motion validation for every tested configuration.

Required automated checks:

- existing PolyForge runtime tests continue to pass;
- adaptive segment selection is deterministic and monotonic across quality profiles;
- shared component instances retain shared geometry identity;
- all rigid mesh vertices have exactly one valid bone weight of `1.0`;
- GLB round-trip through pinned Godot preserves skeleton, bone names, skin bindings, clip name, duration, and loop endpoints;
- the `pump_cycle` passes socket-distance, link-length, continuity, collision, and loop-closure tolerances at every sample;
- normal-runtime vapor derrick is below 5,500 rendered triangles or documents a justified exception;
- the eight-view artifact is generated even if every numeric gate passes.

Do not treat a green workflow as proof that the reference match is good. The PR should remain draft until the user approves the visible model.

## Commit sequence

Keep the work reviewable in this order:

1. Add topology budgets/adaptive primitive detail and their unit tests.
2. Add rig, binding, clip, and validation data models without changing the example's appearance.
3. Add Skeleton3D/skin/animation export and GLB round-trip tests.
4. Add the mechanical linkage solver and animated viewer support.
5. Rebuild the vapor derrick recipe from measured, smaller parts and add `pump_cycle`.
6. Run the full multi-parameter, multi-view, motion, and budget workflow; make visual corrections without weakening gates.
7. Update README, `llms.txt`, and attribution notices.

Do not combine all architectural work and visual recipe changes into one opaque commit.

## Copy/paste prompt for a new session

> Work on `nsb1014/godot-polyforge` from current `main`. Read `docs/NEXT_SESSION_IMPLEMENTATION_BRIEF.md`, merged PR #7, and the current arcane pumpjack workflow before editing. Implement the brief in reviewable commits on a new branch and open a draft PR. Keep PolyForge standalone and Godot-native; Aether Wars terrain/zone code is out of scope. Ask me to reattach the original vapor-derrick reference if it is unavailable. Preserve PR7's reusable component/socket/surface infrastructure, but correct its over-symmetrized, over-segmented recipe. Add adaptive triangle budgeting, a real Skeleton3D/skin, constraint-baked pump linkage animation, manifest/validator support, viewer playback, and GitHub Actions verification. Credit any WAM code copied or closely adapted. Do not mark the PR ready until I have inspected its multi-view animated artifact.

