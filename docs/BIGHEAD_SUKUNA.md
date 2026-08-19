# Big-head Sukuna character

`examples/bighead_sukuna_recipe.gd` is a PolyForge hero-quality character recipe based on
the supplied collectible-toy reference. It keeps the +Z-facing portrait pose and the
oversized head, warm skin, rose spikes, crimson eyes, raised cursed markings, dark navy
uniform, red collar, and red boots as separate named parts.

The 60,000-triangle budget is used on smooth primary surfaces. The hands intentionally stay
as rounded mitten volumes; fingernails, finger segments, and other tiny surface extras are
not modeled.

## Build locally

The repository's CI pins Godot `4.4.1`. With that binary available as `.godot-bin/godot`:

```bash
.godot-bin/godot --headless --path . \
  --script res://addons/polyforge/cli/polyforge_cli.gd -- \
  build res://examples/bighead_sukuna_recipe.gd \
  --out res://dist/base --mode both --no-sweep
```

The generated base build contains:

- `bighead_sukuna.glb` — preserved named-part GLB for authoring and semantic access
- `bighead_sukuna_merged.glb` — material-batched runtime GLB
- `bighead_sukuna.manifest.json` — measurements, validation, and round-trip evidence
- `bighead_sukuna_viewer.html` / `bighead_sukuna_viewer.json` — self-contained review viewer

The validated base build is 59,812 rendered triangles and 59,812 unique triangles. Both GLB
variants pass Godot's importer round trip.

