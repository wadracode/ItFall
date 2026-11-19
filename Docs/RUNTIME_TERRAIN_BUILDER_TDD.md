# ItFall — Runtime Terrain Builder (TDD)

> Version 1.0 · 2026-11-19 · Godot 4.7 · Implementation design (not implemented yet)  
> Related: `Docs/GAME_VISION.md`, `AGENTS.md`  
> Purpose: build and test terrain **inside running gameplay**, instead of maintaining a separate Godot editor tool.

## 1. Decisions and purpose

Runtime Terrain Builder is a **developer gameplay construction mode**. The same terrain scene and data are edited in Edit Mode and played in Play Mode; no bake or scene restart should be required to test a change.

**Goals:** Photoshop-like Pen Tool, Bézier ground surface, immediate visualization, real collision, Edit ↔ Play switching, Save/Load, undo/redo, and a technology sandbox for rendering/physics experiments.

**Not in MVP:** procedural maps/seed, caves, overhangs, overlapping floors, world streaming, biome generation, multiplayer, player ownership/economy, full object editor. Future player-facing terrain building can reuse the core only after server-side validation and gameplay rules are designed.

**Architecture invariant:** Bézier source data is authoritative. Sampled points, polygons, mesh, physics shapes, material rendering and spawn positions are *derived outputs*. Terrain Core must not depend on UI, player controller, a Godot EditorPlugin, or SmartShape2D.

## 2. Existing project and migration boundaries

Repository inspection shows:
- `project.godot` currently runs `res://Terrain.tscn`, with Godot 4.7 GL Compatibility.
- `Terrain.tscn` currently has SmartShape2D flat ground.
- `addons/itfall_map_editor/` contains v0.3 Pen Tool with editable .tres data, Bézier handles, a window and SmartShape2D bake step.
- `addons/rmsmartshape/` is installed; `assets/terrain/grassland/` has fill/surface/flowers assets.
- `Docs/GAME_VISION.md` describes side-scrolling 2.5D, horizontal routes, and terrain extending below camera.

**Do not delete or rewrite these components.** Create an independent sandbox scene and runtime modules; leave `Terrain.tscn` as the main scene until the sandbox is approved. Reuse algorithms and schemas where useful, but do not call EditorPlugin/EditorWindow APIs at game runtime. Support old .tres data with an optional import/migration path without overwriting originals.

## 3. MVP user experience

1. Launch `RuntimeTerrainSandbox.tscn`; show a flat ground with two endpoint anchors.
2. Enter Edit Mode; Pen click adds an anchor, click-drag generates a smooth Bézier tangent.
3. Select and drag anchors; select and drag handles. Alt-drag decouples one handle. Insert a point on an existing segment without visibly changing its shape, remove interior anchors.
4. Pan, zoom around pointer, Fit Map; view ground/collision/debug overlays.
5. Press F1 to Play. Editing gizmos disappear; TestPlayer moves/jumps over the **same** terrain without baking or restarting the scene.
6. Press F1 again to Edit. Shape remains unchanged and is editable.
7. Save/Load a versioned map; restart the sandbox and reproduce the same ground.

**Input defaults (remappable):**

| Context | Input | Action |
| --- | --- | --- |
| Both | F1 | Toggle Edit/Play |
| Edit | P/E/H | Pen/Edit/Pan tool |
| Edit | Left click | Add/select anchor depending on tool |
| Edit | Left drag | Create tangent, move anchor/handle |
| Edit | Alt + handle drag | Break symmetric tangent link |
| Edit | Delete | Delete selected interior anchor |
| Edit | Ctrl+Z/Ctrl+Y | Undo/Redo |
| Edit | Middle/right drag | Camera pan |
| Edit | Mouse wheel | Zoom centered on pointer |
| Both | F2 / F3 | Collision overlay / performance HUD |
| Play | A/D, Space | TestPlayer movement and jump |

Esc cancels an active drag and restores its before-state. UI clicks cannot create points. Input routing must ensure Player actions never trigger in Edit and Terrain Tool actions never trigger in Play. On switching to Play, commit/cancel pending edits and flush collision rebuild safely.

**Coordinate handling:** use world-to-terrain-local conversions through actual transforms and Camera2D; hit radius is in **screen pixels** across zoom levels.

## 4. Suggested modules

```text
res://
├── Docs/RUNTIME_TERRAIN_BUILDER_TDD.md
├── terrain/
│   ├── core/
│   │   ├── terrain_document.gd
│   │   ├── terrain_geometry.gd
│   │   ├── terrain_session.gd
│   │   └── terrain_storage.gd
│   ├── render/terrain_polygon_renderer.gd
│   └── physics/terrain_physics.gd
├── runtime_builder/
│   ├── controllers/sandbox_mode_controller.gd
│   ├── controllers/terrain_tool_controller.gd
│   ├── tools/pen_tool.gd
│   ├── tools/edit_tool.gd
│   ├── tools/pan_tool.gd
│   ├── history/edit_history.gd
│   └── ui/
├── scenes/sandbox/RuntimeTerrainSandbox.tscn
└── tests/terrain/
```

This is a **target structure**, not an assertion these files already exist.

**Responsibility boundaries:**

| Component | Responsibility |
| --- | --- |
| TerrainDocument | Versioned authoritative anchor/handle/metadata |
| TerrainGeometry | Validate monotonic X; sample cubic Bézier; ground-height query |
| TerrainRenderer | Generate visible fill and surface, initial Polygon2D adapter |
| TerrainPhysics | Rebuild matching collision safely, based on geometry |
| TerrainSession | Edit commands, revisions, dirty regions, refresh orchestration |
| TerrainToolController | Convert mouse/keyboard actions into edit commands |
| EditHistory | Transaction-level undo/redo snapshots |
| TerrainStorage | Validate, save, load, migrate |
| SandboxModeController | Switch game/edit inputs, camera, overlays and TestPlayer |

**Update flow:**
```text
Input → Tool → Edit Command → TerrainDocument → Validate → TerrainGeometry
                                                   ├→ TerrainRenderer
                                                   └→ TerrainPhysics
```
Rendering and collision must match the same **committed revision** before entering Play.

## 5. Terrain data contract

Minimum proposed fields:
- `format_version`, `map_id`, `map_name`
- `width_px`, `base_y`, `fill_depth_px`, `material_id`
- Ordered anchors with **stable IDs**, positions, relative `handle_in` and `handle_out`, and `handle_mode` (smooth/broken/corner)
- Optional map entrance metadata.

Godot 2D convention: X right, Y down; source coordinates in **terrain-local space**.

**Geometry constraints:**
- Two boundary anchors are mandatory; endpoint X locked at 0 and `width_px` (endpoint Y editable).
- Interior X values strictly increase and remain separated by a configurable minimum, initially 24 world pixels.
- Cubic control-point X must be constrained so X remains nondecreasing (one height per X). Reject invalid coordinate values, NaN, Infinity and segment self-intersections.
- Give slope warnings where gameplay movement becomes impractical; do not silently flatten authored shapes.
- Insert point on curve using **De Casteljau split**, maintaining visual curve shape.
- Store only source anchors/handles, not required cached samples, physics shapes or mesh data.

Caves, bridges and multilayer platforms are future separate geometry types; do not force them into the surface heightfield.

## 6. Terrain geometry, visual and physics

**Geometry:** sample each cubic Bézier segment in X order. Prototype sampling roughly 8–16 world px (tune by curve error). Preserve exact endpoints, remove consecutive duplicates, maintain deterministic output. Expose `surface_y_at(x)` without full-array scans in hot gameplay paths.

**Visual:** start with simple `Polygon2D` ground fill and a separate ground-edge visual. Close surface polygon with bottom corners below all surface Ys and below expected visible camera depth. Do not make geometry depend on camera every frame. Try existing grassland textures where compatible; fallback to flat color before adding advanced UV mapping. SmartShape2D and custom meshes can be **replaceable renderer adapters**, never sources of truth.

**Physics:** build `StaticBody2D` collision from the same surface samples. Start with validated solid terrain `CollisionPolygon2D` or an equivalent surface collision method; check collider semantics explicitly. The collision must match rendered ground within an agreed tolerance. While dragging, visuals refresh immediately; physics can rebuild on drag release or at throttled intervals. Do not mutate physics shapes unsafely from physics callbacks. On Play entry, apply the latest physics revision before enabling the player.

**Scaling:** MVP may rebuild a short map. Once measured, segment terrain into X-based chunks and update only chunks touched by modified curve segments. Ensure contiguous seams for rendering/collision. Do not prematurely add streaming/LOD.

## 7. Edit transactions and state

```text
EDIT_IDLE → EDIT_DRAG → EDIT_IDLE ↔ PLAY
```

A drag begins one transaction with a before-state, continuously previews changes, and commits one undo entry on mouse release. Escape rolls back; redo reapplies the after-state. Do not push one history state per frame or store mesh/node snapshots. Default cap ~100 transactions (configurable).

Loading a different map resets per-map history. Switching between modes **does not** reset the terrain or edit history. Switching to Play hides gizmos, freezes editing input, spawns/resets a basic CharacterBody2D test player at a valid surface location and changes camera behavior. Return to Edit restores the free camera.

## 8. Save/Load and legacy import

Runtime saves should go to **`user://maps/`**, not `res://` (which may be read-only in exported builds). Use a **versioned JSON document** for the prototype with a validator and explicit migration path. Save through temp-file + safe replacement where supported; on failure preserve dirty flag and existing file. New/Open/Quit with unsaved changes offers Save/Discard/Cancel.

Legacy v0.3 uses `anchors`, `handles_in`, `handles_out`, `ground_points`, `width_px`, `base_y`, `fill_depth_px` in `addons/itfall_map_editor/terrain_data.gd`. A later importer may read compatible legacy .tres, convert into new schema and **save separately**. If only sampled polyline exists, do not claim perfect Bézier reconstruction. Old files and scenes stay untouched.

## 9. Sandbox diagnostics

Show FPS/frame time, counts of anchors/samples/chunks/colliders, visual and collision rebuild times (ms), source/visual/physics revisions and dirty status. Include overlays for anchors, tangent handles, ground samples and collision.

Suggested test sizes: 2k, 8k and 30k world px; 2, 20 and 200 anchors; zoom in/out and drag continuously. Record observations on the same test machine instead of claiming an FPS target without measurement.

## 10. Implementation phases for Codex

### Phase 0 — Audit, isolated sandbox
- Review `AGENTS.md`, `project.godot`, `Terrain.tscn`, current editor v0.3 and terrain asset paths.
- Create sandbox scene; do not change main scene or addons.
- Establish TerrainDocument schema and tests.
- **Exit:** sandbox launches independently; existing project still works.

### Phase 1 — Terrain Core, flat ground, physics
- Create a valid two-anchor flat map; implement Bézier sampling and fill rendering.
- Build collision and a minimal TestPlayer.
- **Exit:** player stands on the rendered flat ground; source change can rebuild geometry/physics.

### Phase 2 — Interactive Runtime Pen Tool
- Implement click/drag points and handles, move/select/delete, De Casteljau split.
- Enforce monotonic X, anchor boundaries and minimum spacing.
- Add camera zoom/pan, screen-space hit tests, overlays, Undo/Redo and cancel.
- **Exit:** draw smooth hills/valleys interactively without broken curves.

### Phase 3 — Instant Edit / Play
- Central mode/input switch; free edit camera versus test-player camera.
- Edit → Play → Edit on the same map with synchronized physics.
- **Exit:** character can traverse newly drawn terrain without bake/reload.

### Phase 4 — Persistence and compatibility
- Save/Load/New/Save As, versioning, validation, unsaved warnings.
- Optional legacy import into a separate map.
- **Exit:** restart sandbox and recover visually/physically equivalent terrain.

### Phase 5 — Benchmark and architecture decision
- Stress test long terrain, dense anchors and camera movement.
- Compare Polygon2D with mesh/SmartShape adapter **only if required**.
- Measure updates; chunk/cull only if justified; document final renderer/physics tradeoffs.
- **Exit:** repeatable benchmark and architecture decision record.

For each phase report: touched files, how to launch, automated/manual tests, screenshots for visual changes, known limitations and the next phase.

## 11. Acceptance checklist

| ID | Scenario | Required result |
| --- | --- | --- |
| RTB-01 | Open sandbox | Flat map and no startup error |
| RTB-02 | Pen click, click-drag | Ordered anchors and smooth curve |
| RTB-03 | Edit handle / Alt-drag | Linked vs independent tangent |
| RTB-04 | Insert/delete anchor | Preserves validity; cannot delete endpoints |
| RTB-05 | Undo/Redo 1 drag | Exactly one history transaction |
| RTB-06 | Pan/zoom | Stable world-space editing and screen-space selection |
| RTB-07 | F1 to Play | Same terrain, matching collision, functioning player |
| RTB-08 | F1 to Edit | Same terrain persists; editing resumes |
| RTB-09 | Save, restart, load | Source and regenerated outputs match |
| RTB-10 | Invalid/corrupt map | Friendly error, old session survives |
| RTB-11 | Invalid X handles | Clamp/reject; no loop or self-intersection |
| RTB-12 | Existing main scene | `Terrain.tscn` and old plugin not broken |
| RTB-13 | Long/dense terrain | Measurements available; no silent corruption |
| RTB-14 | Latest edit then Play | Physics revision current before player enabled |

**Validation:** follow `AGENTS.md` for Godot 4.7 headless import/parse and exercise sandbox in interactive editor. Headless success does not prove visuals, collision or mouse gestures behave correctly.

## 12. Deferred questions

- Production renderer: Polygon2D, custom mesh or SmartShape2D.
- Solid ground vs surface-only collision, and how to handle special terrain.
- Chunk length, LOD, camera zoom and streaming policy.
- Final map asset format and content pipeline from `user://` into repository.
- Whether players may permanently deform land, and any multiplayer/server ownership model.

**Definition of Done (initial):** a developer launches the sandbox, uses Pen/handles to build a Bézier terrain inside running gameplay, switches to a controllable test player on that exact terrain, switches back to edit, can undo/redo and save/load, and never needs the legacy editor window or baked .tscn.
