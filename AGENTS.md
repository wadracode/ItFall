# Repository Guidelines

## Project Structure & Module Organization

This is a Godot 4.7 project. `project.godot` defines the project and enables the main scene, `Terrain.tscn`. Game scenes and assets live at the project root or in appropriately named asset folders. Reusable code is under `addons/`: `rmsmartshape/` provides SmartShape2D shapes, materials, tools, examples, and documentation; `godot_ai/` provides the editor MCP plugin and runtime helpers. Keep addon-specific changes within their addon and avoid editing generated `.godot/` data.

## Build, Test, and Development Commands

Run these from the repository root with Godot 4.7 available on `PATH`:

- `godot --editor --path .` opens the project in the editor.
- `godot --path .` runs the configured main scene (`Terrain.tscn`).
- `godot --headless --editor --path . --quit` imports project resources and checks that the project opens headlessly.

There is no root-level build script or dedicated test suite. Use the Godot editor and targeted scene checks for gameplay or visual changes; addon test utilities live under `addons/godot_ai/testing/`.

## Coding Style & Naming Conventions

Follow `.editorconfig` for UTF-8 text. Use GDScript conventions: `snake_case` for files, functions, and variables; `PascalCase` for classes and node types; tabs for indentation. Keep scene and resource references as `res://` paths, and make scene/resource names descriptive. Match the surrounding addon style when changing vendored addon code.

## Testing Guidelines

For script or project setting changes, run the headless editor command above and inspect its output for parse or import errors. For scene, physics, rendering, or plugin changes, open the project in Godot and exercise the affected behavior; headless import does not validate visual results or live MCP connectivity. No repository-wide coverage requirement is configured.

## Commit & Pull Request Guidelines

The current Git history has no commits, so no established commit format can be inferred. Use short imperative commit subjects (for example, `Add terrain collision`) and keep unrelated changes separate. Pull requests should describe the user-visible change, list validation performed, link relevant issues when available, and include screenshots or recordings for visual changes.

## Configuration & Generated Files

Do not commit `.godot/`, `.venv/`, or Android build output; these are ignored by `.gitignore`. Keep local credentials and machine-specific settings out of the repository. The Godot AI addon may require `uv` and an MCP client for live integration work; document any setup needed to reproduce such changes.
