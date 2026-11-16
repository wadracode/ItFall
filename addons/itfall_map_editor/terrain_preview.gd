@tool
extends Control

var _terrain


func set_terrain(value) -> void:
	_terrain = value
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(0.74, 0.86, 0.88))
	if _terrain == null or _terrain.ground_points.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(10.0, size.y * 0.5), "Press Preview to generate terrain", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.16, 0.25, 0.26))
		return

	var points := PackedVector2Array()
	var min_y := INF
	var max_y := -INF
	for p in _terrain.ground_points:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	var vertical_scale := maxf((max_y - min_y) * 1.4, 180.0)
	var view_base := min_y - vertical_scale * 0.2
	for p in _terrain.ground_points:
		var x := lerpf(4.0, size.x - 4.0, p.x / float(_terrain.width_px))
		var y := lerpf(12.0, size.y - 18.0, (p.y - view_base) / vertical_scale)
		points.append(Vector2(x, y))
	if points.size() < 2:
		return

	var fill := points.duplicate()
	fill.append(Vector2(size.x - 4.0, size.y))
	fill.append(Vector2(4.0, size.y))
	draw_colored_polygon(fill, Color(0.20, 0.40, 0.23))
	draw_polyline(points, Color(0.33, 0.64, 0.34), 3.0, true)
	for p in _terrain.tree_points:
		var x := lerpf(4.0, size.x - 4.0, p.x / float(_terrain.width_px))
		var y := lerpf(12.0, size.y - 18.0, (p.y - view_base) / vertical_scale)
		draw_line(Vector2(x, y), Vector2(x, y - 12.0), Color(0.27, 0.20, 0.14), 2.0)
		draw_circle(Vector2(x, y - 14.0), 4.0, Color(0.12, 0.36, 0.16))

	var caption := "Seed %d  |  %d px  |  %d trees  |  %d rocks" % [
		_terrain.seed, _terrain.width_px, _terrain.tree_points.size(), _terrain.rock_points.size()
	]
	draw_string(ThemeDB.fallback_font, Vector2(8.0, 20.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.12, 0.20, 0.25))
