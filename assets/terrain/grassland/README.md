# ItFall — Grassland terrain texture pack (first pass)

Godot 4.7 compatible **SVG textures** designed for ItFall's 2.5D side-scrolling terrain.

These are **editable vector game textures**, not exports from the concept-art presentation. They can be opened in Inkscape, Illustrator or a text editor; Godot imports them as Texture2D. The source SVGs are in this folder.

| File | Size | Purpose |
| --- | --- | --- |
| `grassland_fill.svg` | 256 × 256 | Seamless meadow-green ground fill; **no exposed dirt cross-section** |
| `grassland_surface_edge.svg` | 256 × 96 | Grass lip that follows the curved surface; repeat horizontally |
| `grassland_flowers_overlay.svg` | 256 × 256 | Transparent tile of clover/flowers for future ground decoration |

## Integration

The current `addons/itfall_map_editor/map_baker.gd` **automatically uses** `grassland_fill.svg` and `grassland_surface_edge.svg` when it bakes a terrain scene. It falls back to the original procedural fill if Godot has not imported the SVG.

You **do not need to manually create SmartShape materials** for the default grassland. Use ItFall Map Editor → Bake. The generated scene still uses SmartShape2D under the hood.

The flowers overlay is provided as a separate asset and **is not automatically scattered or layered yet**.

## Direction of art

- Ground is fully grass-covered into the bottom of the camera, to create a side-view **2.5D grass surface**, not a Terraria-like exposed soil cross-section.
- Organic meadow greens, small blades, natural mottling and restrained flowers.
- These are **foundation assets**, not final art. The generated reference illustration is a style exploration, not a texture atlas; it should not be imported as a repeating material.
- This v1 pack is **vector/stylized**. Seam visibility, scale, blur, SmartShape edge orientation and art direction must be evaluated inside Godot before production use.

## Next steps

- Map Editor controls for custom user-selected Fill/Edge texture paths.
- True material preset and biome switching.
- Live SmartShape preview with imported assets.
- Visual QA and hand-painting refinements after in-engine testing.
