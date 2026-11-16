extends SceneTree

# Run after initial imports:
# godot --headless --editor --path . --quit
# godot --headless --path . --script res://addons/itfall_map_editor/tests/smoke_test.gd

const Generator = preload("res://addons/itfall_map_editor/terrain_generator.gd")
const Baker = preload("res://addons/itfall_map_editor/map_baker.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings := {
		"map_name": "_v2_smoke_test",
		"seed": 48251,
		"width_px": 1024,
		"sample_step_px": 64,
		"trees_per_km": 2.0,
		"rocks_per_km": 2.0
	}
	var first = Generator.create(settings)
	var second = Generator.create(settings)
	if first.ground_points != second.ground_points or first.tree_points != second.tree_points:
		_failed("Same seed must generate exactly the same geometry and props.")
		return
	settings["seed"] = 48252
	var different = Generator.create(settings)
	if first.ground_points == different.ground_points:
		_failed("Different seeds must produce different terrain.")
		return

	var edited := first.ground_points.duplicate()
	var original_height: float = edited[5].y
	edited[5] = Vector2(edited[5].x, original_height - 100.0)
	first.ground_points = edited
	Generator.regenerate_props(first)
	if not is_equal_approx(first.ground_points[5].y, original_height - 100.0):
		_failed("Redistribution must not erase terrain edits.")
		return

	var baked: Dictionary = Baker.bake(first)
	if not baked.get("ok", false):
		_failed("Bake failed: " + str(baked.get("message", "Unknown error")))
		return

	var source_path: String = baked["data"]
	var scene_path: String = baked["scene"]
	var saved = ResourceLoader.load(source_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var scene: PackedScene = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if saved == null or scene == null:
		_failed("Source data and PackedScene must both reload successfully.")
		return
	if saved.ground_points != first.ground_points:
		_failed("Edited terrain should persist through .tres save/load.")
		return
	var instance: Node = scene.instantiate()
	if instance.get_node_or_null("SmartShapeGround") == null:
		_failed("Baked scene must contain a SmartShape2D node.")
		instance.free()
		return
	var collider := instance.get_node_or_null("GroundCollision/SolidGround") as CollisionPolygon2D
	if collider == null or collider.polygon.size() < 4:
		_failed("Baked scene must contain solid terrain collision.")
		instance.free()
		return
	if instance.get_node_or_null("SpawnPoints/Entrance_A") == null or instance.get_node_or_null("SpawnPoints/Entrance_B") == null:
		_failed("Baked scene must include both entrance markers.")
		instance.free()
		return
	instance.free()

	var second_bake: Dictionary = Baker.bake(first, source_path)
	if not second_bake.get("ok", false) or second_bake["scene"] == scene_path:
		_failed("Re-baking must not overwrite the previous scene.")
		return

	print("ItFall Map Editor v2 smoke test passed.")
	_cleanup(str(second_bake["scene"]))
	_cleanup(scene_path)
	_cleanup(source_path)
	quit(0)


func _cleanup(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _failed(reason: String) -> void:
	push_error("ItFall Map Editor v2 smoke test FAILED: " + reason)
	quit(1)
