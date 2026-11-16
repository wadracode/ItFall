# ItFall Map Editor — Prototype v0.1

This addon generates a small deterministic side-scrolling **grassland** map using **SmartShape2D 3.3.2** from `addons/rmsmartshape/`.

> This is an editor-time map authoring tool, **not** a runtime world streamer or MMO server. Generated terrain is intentionally kept separate from procedural source data.

## Requirements

- Godot **4.7** (the version configured in `project.godot`).
- `addons/rmsmartshape/` available and the **SmartShape2D** editor plugin enabled.
- `addons/itfall_map_editor/` installed (this folder).

## Start

1. Open the ItFall project in Godot 4.7.
2. Go to **Project → Project Settings → Plugins**.
3. Enable **ItFall Map Editor**. Keep **SmartShape2D** enabled.
4. Find the **ItFall Maps** dock (right-bottom side, or wherever you move it).
5. Change **Seed**, **Length**, **Hill height**, **Hill scale**, **Trees** and **Rocks**.
6. Click **1. Generate preview**. This shows a *schematic terrain profile*, not the final art.
7. Click **2. Bake + open SmartShape scene**.
8. The generated map is opened as a Godot scene. Explore its `SmartShapeGround` node using SmartShape's editor point controls.

The baker stores **two files** in `res://generated_maps/`:

- `<map_name>_<seed>.tres`: the source terrain data and object positions.
- `<map_name>_<seed>.tscn`: the baked scene containing the SmartShape terrain, solid collision, marker nodes and decorative objects.

If the name exists, the baker adds a numeric suffix instead of overwriting it. This protects **hand-edited maps**.

## What is included

- Seeded deterministic height profile (smooth hills + detail noise; flat ends).
- SmartShape2D closed polygon with noise-based grassy fill, extending well below the camera.
- SmartShape2D edge material using the installed addon grass texture.
- `StaticBody2D / CollisionPolygon2D` for the ground surface.
- Basic procedural trees and rocks made from editable `Polygon2D` nodes.
- `Entrance_A` and `Entrance_B` markers, ready for future world route transitions.
- A full .tscn scene for inspection and manual changes. The existing `Terrain.tscn` is **not modified**.

## Useful boundaries

- `Generate preview` does **not** modify the current scene.
- `Bake` creates new files; it does **not** overwrite previous maps.
- Trees/rocks are **visual placeholders**, not yet harvestable gameplay resources.
- No player/controller, water shader, chunk streaming, save game or multiplayer is installed by this addon.
- 2.5D is a rendering illusion: the grassy shape fills down the screen, but collision follows the 2D terrain boundary.
- SmartShape control points can be edited after baking; changing saved terrain points manually does not automatically rewrite the source .tres. Treat the baked scene as the handcrafted version.
- Rendering a single 8k px map does not prove scalability; benchmark large scenes and future chunk systems separately.

## Example acceptance test

1. Generate preview at seed **12345**.
2. Bake and open map A. Check that the ground is green all the way below the screen and has no cutaway soil layers.
3. Find `SmartShapeGround`, `GroundCollision/SolidGround`, and `SpawnPoints/Entrance_A` / `Entrance_B` in the scene tree.
4. Bake again with the same seed. The new files have a suffix; original files are preserved. Geometry and spawn positions should match.
5. Change seed to **12346**, preview and bake; terrain/profile and decoration positions should change.
6. Run `godot --headless --editor --path . --quit` from the repository root to check for parser/import errors (in addition to GUI testing).

## Planned extensions (not implemented yet)

- User-provided fill and edge materials for each biome.
- Optional resource-bearing trees, rocks and harvestable entities.
- Heightmap/SmartShape point edits with explicit round-trip import/export.
- Authoring landmarks and reserved flat areas for player buildings.
- Chunk baking and streaming, including collision edge continuity.
- More detailed 2.5D dressing: lighting, distant layers, weather, shoreline and water.

Keep procedural generation rules separate from rendering; the renderer can be swapped later without changing the map seed/data format.
