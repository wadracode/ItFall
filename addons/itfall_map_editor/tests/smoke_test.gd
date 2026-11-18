extends SceneTree

# Run in Godot 4.7 after importing assets:
# godot --headless --editor --path . --quit
# godot --headless --path . --script res://addons/itfall_map_editor/tests/smoke_test.gd

const DataScript = preload("res://addons/itfall_map_editor/terrain_data.gd")
const Baker = preload("res://addons/itfall_map_editor/map_baker.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data = DataScript.new()
	data.map_name = "_pen_tool_test"
	data.create_flat(1024, 280.0)
	if data.anchors.size() != 2 or data.ground_points.size() < 3:
		_failed("New flat map must have two anchors and a sampled level surface.")
		return
	if not is_equal_approx(data.ground_y_at(300.0), 280.0):
		_failed("The default surface must be flat.")
		return

	var anchor: int = data.insert_anchor(Vector2(500.0, 170.0))
	if anchor != 1 or data.anchors.size() != 3:
		_failed("Pen tool must insert an anchor in horizontal order.")
		return
	data.set_handle(anchor, true, Vector2(680.0, 170.0))
	if data.handles_out[anchor].x <= 0.0 or data.handles_in[anchor] != -data.handles_out[anchor]:
		_failed("Dragging a tangent must generate mirrored Bezier handles.")
		return
	if not is_equal_approx(data.ground_y_at(500.0), 170.0):
		_failed("The rendered surface must pass through the anchor.")
		return

	var prev_x := -INF
	for point in data.ground_points:
		if point.x <= prev_x:
			_failed("Bezier samples must have strictly increasing X for collision.")
			return
		prev_x = point.x

	data.move_anchor(anchor, Vector2(540.0, 110.0))
	if not is_equal_approx(data.ground_y_at(540.0), 110.0):
		_failed("Moving an anchor must update the terrain.")
		return

	var baked: Dictionary = Baker.bake(data)
	if not baked.get("ok", false):
		_failed("Bake failed: " + str(baked.get("message", "Unknown error")))
		return
	var source_path: String = baked["data"]
	var scene_path: String = baked["scene"]
	var saved = ResourceLoader.load(source_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var scene: PackedScene = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if saved == null or scene == null:
		_failed("Editable .tres and baked .tscn must reload.")
		return
	if saved.anchors != data.anchors or saved.handles_out != data.handles_out or saved.handles_in != data.handles_in:
		_failed("Control points and tangent handles must persist in the .tres.")
		return
	var instance: Node = scene.instantiate()
	if instance.get_node_or_null("SmartShapeGround") == null:
		instance.free()
		_failed("Baked scene must contain SmartShape2D.")
		return
	var collider := instance.get_node_or_null("GroundCollision/SolidGround") as CollisionPolygon2D
	if collider == null or collider.polygon.size() <= 4:
		instance.free()
		_failed("Baked scene must have a polygon following the Bezier terrain.")
		return
	if instance.get_node_or_null("SpawnPoints/Entrance_A") == null or instance.get_node_or_null("SpawnPoints/Entrance_B") == null:
		instance.free()
		_failed("Baked scene must include the A/B entrances.")
		return
	instance.free()

	var next: Dictionary = Baker.bake(data, source_path)
	if not next.get("ok", false) or next["scene"] == scene_path:
		_failed("Re-baking must not overwrite an existing scene.")
		return

	if not data.delete_anchor(anchor) or data.anchors.size() != 2:
		_failed("Deleting an intermediate anchor must preserve the two endpoints.")
		return
	if data.delete_anchor(0) or data.delete_anchor(1):
		_failed("Endpoint anchors must not be deletable.")
		return

	var legacy = DataScript.new()
	legacy.width_px = 1024
	legacy.ground_points = PackedVector2Array([Vector2(0, 280), Vector2(400, 220), Vector2(1024, 280)])
	legacy.ensure_editable()
	if legacy.anchors.size() != 3 or legacy.handles_out.size() != 3:
		_failed("Existing sampled terrain must be convertible to editable corner anchors.")
		return

	_cleanup(str(next["scene"]))
	_cleanup(scene_path)
	_cleanup(source_path)
	print("ItFall Map Editor v0.3 Pen Tool smoke test passed.")
	quit(0)


func _cleanup(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _failed(message: String) -> void:
	push_error("ItFall Map Editor v0.3 smoke test FAILED: " + message)
	quit(1)
