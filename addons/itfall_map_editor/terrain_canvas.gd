@tool
extends Control

signal stroke_started(world_position: Vector2)
signal stroke_moved(world_position: Vector2)
signal stroke_finished()

const COLORS := {
	"sky": Color(0.52, 0.73, 0.80),
	"hill": Color(0.31, 0.53, 0.40),
	"ground": Color(0.20, 0.41, 0.27),
	"grass": Color(0.47, 0.75, 0.40),
	"grid": Color(0.90, 0.98, 0.94, 0.13)
}

var data
var tool_mode: String = "Pan"
var brush_radius: float = 190.0
var show_grid: bool = true

var camera_position: Vector2 = Vector2(4000.0, 280.0)
var zoom: float = 0.3
var _panning := false
var _painting := false
var _mouse := Vector2.ZERO
var _mouse_over := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_exited.connect(_on_mouse_exited)


func set_data(value, fit_view: bool = false) -> void:
	data = value
	if fit_view:
		call_deferred("fit_to_data")
	queue_redraw()


func fit_to_data() -> void:
	if data == null or size.x < 1.0:
		return
	zoom = clampf((size.x - 90.0) / float(data.width_px), 0.045, 3.0)
	camera_position = Vector2(float(data.width_px) * 0.5, data.base_y + 110.0)
	queue_redraw()


func _to_screen(world: Vector2) -> Vector2:
	return (world - camera_position) * zoom + size * 0.5


func _to_world(screen: Vector2) -> Vector2:
	return (screen - size * 0.5) / zoom + camera_position


func _gui_input(event: InputEvent) -> void:
	if data == null:
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		_mouse = mouse_button.position
		_mouse_over = true
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_zoom_at(1.16, mouse_button.position)
			accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_zoom_at(1.0 / 1.16, mouse_button.position)
			accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			_panning = mouse_button.pressed
			accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				if tool_mode == "Pan":
					_panning = true
				else:
					_painting = true
					stroke_started.emit(_to_world(mouse_button.position))
			else:
				if _painting:
					stroke_finished.emit()
				_painting = false
				_panning = false
			accept_event()
	elif event is InputEventMouseMotion:
		var movement: InputEventMouseMotion = event
		_mouse = movement.position
		_mouse_over = true
		if _panning:
			camera_position -= movement.relative / zoom
		elif _painting:
			stroke_moved.emit(_to_world(movement.position))
		queue_redraw()
		if _painting or _panning:
			accept_event()


func _on_mouse_exited() -> void:
	_mouse_over = false
	queue_redraw()


func _zoom_at(factor: float, screen_position: Vector2) -> void:
	var anchor: Vector2 = _to_world(screen_position)
	zoom = clampf(zoom * factor, 0.045, 3.0)
	camera_position = anchor - (screen_position - size * 0.5) / zoom
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLORS["sky"])
	if data == null or data.ground_points.size() < 2:
		_caption("No map loaded. Press Generate.")
		return
	_draw_grid()
	_draw_terrain()
	_draw_decorations()
	_draw_markers()
	_draw_brush()
	_caption("%s | Seed %d | %d px | %0.2fx" % [data.map_name, data.seed, data.width_px, zoom])


func _draw_grid() -> void:
	if not show_grid:
		return
	var min_world: Vector2 = _to_world(Vector2.ZERO)
	var max_world: Vector2 = _to_world(size)
	var grid_spacing := 500.0
	var first_x := floorf(min_world.x / grid_spacing) * grid_spacing
	var x := first_x
	var loops := 0
	while x <= max_world.x and loops < 140:
		var screen_x: float = _to_screen(Vector2(x, 0.0)).x
		draw_line(Vector2(screen_x, 0.0), Vector2(screen_x, size.y), COLORS["grid"], 1.0)
		x += grid_spacing
		loops += 1
	var first_y := floorf(min_world.y / grid_spacing) * grid_spacing
	var y := first_y
	loops = 0
	while y <= max_world.y and loops < 140:
		var screen_y: float = _to_screen(Vector2(0.0, y)).y
		draw_line(Vector2(0.0, screen_y), Vector2(size.x, screen_y), COLORS["grid"], 1.0)
		y += grid_spacing
		loops += 1


func _draw_terrain() -> void:
	var visible := PackedVector2Array()
	for point in data.ground_points:
		visible.append(_to_screen(point))
	if visible.size() < 2:
		return
	var fill := visible.duplicate()
	var bottom := maxf(size.y + 32.0, _to_screen(Vector2(0.0, data.base_y + data.fill_depth_px)).y)
	fill.append(Vector2(visible[-1].x, bottom))
	fill.append(Vector2(visible[0].x, bottom))
	draw_colored_polygon(fill, COLORS["ground"])
	draw_polyline(visible, COLORS["grass"], clampf(7.0 * zoom, 2.0, 9.0), true)


func _draw_decorations() -> void:
	for point in data.tree_points:
		var root: Vector2 = _to_screen(point)
		if root.x < -60.0 or root.x > size.x + 60.0:
			continue
		var height: float = clampf(120.0 * zoom, 6.0, 260.0)
		draw_line(root, root + Vector2(0, -height), Color(0.31, 0.25, 0.17), maxf(2.0, 13.0 * zoom))
		draw_circle(root + Vector2(0.0, -height), maxf(3.0, 38.0 * zoom), Color(0.10, 0.33, 0.22))
	for point in data.rock_points:
		var p: Vector2 = _to_screen(point)
		if p.x < -20.0 or p.x > size.x + 20.0:
			continue
		draw_circle(p - Vector2(0, maxf(2.0, 10.0 * zoom)), maxf(2.0, 15.0 * zoom), Color(0.45, 0.51, 0.49))


func _draw_markers() -> void:
	var a := _to_screen(Vector2(100.0, data.ground_y_at(100.0)))
	var b := _to_screen(Vector2(float(data.width_px) - 100.0, data.ground_y_at(float(data.width_px) - 100.0)))
	draw_circle(a, 6.0, Color(0.20, 0.70, 0.96))
	draw_circle(b, 6.0, Color(0.96, 0.69, 0.19))
	if zoom >= 0.15:
		draw_string(ThemeDB.fallback_font, a + Vector2(7, -12), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		draw_string(ThemeDB.fallback_font, b + Vector2(7, -12), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _draw_brush() -> void:
	if not _mouse_over or tool_mode == "Pan":
		return
	draw_arc(_mouse, brush_radius * zoom, 0.0, TAU, 40, Color(0.98, 0.90, 0.42, 0.85), 2.0, true)


func _caption(value: String) -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, 27.0), Color(0.09, 0.17, 0.20, 0.78))
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 19.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
