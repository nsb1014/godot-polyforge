# Provenance and third-party credit

Godot PolyForge was extracted from the portable PolyForge modules in
[`nsb1014/aether_wars_rts`](https://github.com/nsb1014/aether_wars_rts) at commit
`3f726295163e7047ec4959cc2399aef284921d6b`. Aether Wars-specific palettes,
catalogs, asset names, providers, paths, and gameplay contracts are intentionally excluded.

Several capabilities were copied or adapted with permission from Elliott Dehn's
[`elliottdehn/wam`](https://github.com/elliottdehn/wam) at commit
`0ac32d599fd8d7c954812136292a19bb0be1a965`:

- `viewer/template.html` is a directly adapted copy of WAM's standalone viewer.
- `addons/polyforge/quality/checks.gd` adapts WAM's named-part measurement,
  proximity, intersection, containment, symmetry, and regression-check concepts.
- `addons/polyforge/core/surface_attach.gd` adapts WAM's surface-aware `on=` placement.
- `addons/polyforge/core/paint.gd` adapts WAM's deterministic procedural paint operators.
- `addons/polyforge/terrain/zone.gd` adapts WAM's landform, terrain-surface,
  spline-feature, and constrained-scatter architecture.
- `addons/polyforge/exporters/viewer_export.gd` implements WAM's viewer JSON contract.

Credit: **Elliott Dehn — WAM (WoW-ish Art Model language)**.

The repository owner has represented that permission was granted by WAM's owner to copy,
modify, and use these materials. No upstream WAM license file was present at the pinned
commit. This notice records provenance and credit; it is not itself a software license.
