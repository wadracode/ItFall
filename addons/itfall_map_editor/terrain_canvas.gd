@tool
extends Control

signal edit_started()
signal edit_changed()
signal edit_finished()
signal undo_requested()
signal redo_requested()

const SKY := Color(0.56, 0.75, 0.81)
const GROUND := Color(0.22, 0.43, 0.30)
const GRASS := Color(0.60, 0.82, 0.43)
const GRID := Color(0.95, 0.99, 0.98, 0.18)
const ANCHOR := Color(0.98, 0.98, 0.99)
const SELECTED := Color(1.0, 0.79, 0.27)
const HANDLE := Color(0.99, 0.55, 0.35)
const HIT_RADIUS := 11.0

var data
var tool_mode := "Pen"
var show_grid := true
var selected_index := -1
var camera_position := Vector2(4000.0, 280.0)
var zoom := 0.3

var _panning := false
var _drag_mode := ""
var _drag_index := -1
var _mouse := Vector2.ZERO
var _mouse_over := false
var _alt_break_tangent := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_exited.connect(_on_mouse_exited)


func set_data(value, fit_view: bool = false) -> void:
	data = value
	selected_index = -1
	_drag_mode = ""
	_drag_index = -1
	if fit_view:
		call_deferred("fit_to_data")
	queue_redraw()


func fit_to_data() -> void:
	if data == null or size.x < 1.0:
		return
	zoom = clampf((size.x - 90.0) / maxf(1.0, float(data.width_px)), 0.045, 4.0)
	camera_position = Vector2(float(data.width_px) * 0.5, data.base_y + 120.0)
	queue_redraw()


func _to_screen(world: Vector2) -> Vector2:
	return (world - camera_position) * zoom + size * 0.5


func _to_world(screen: Vector2) -> Vector2:
	return (screen - size * 0.5) / zoom + camera_position


func _gui_input(event: InputEvent) -> void:
	if data == null:
		return
	if event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and not key.echo:
			if (key.ctrl_pressed or key.meta_pressed) and key.keycode == KEY_Z:
				if key.shift_pressed:
					redo_requested.emit()
				else:
					undo_requested.emit()
				accept_event()
			elif (key.ctrl_pressed or key.meta_pressed) and key.keycode == KEY_Y:
				redo_requested.emit()
				accept_event()
			elif key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE:
				delete_selected()
				accept_event()
		return

	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		_mouse = button.position
		_mouse_over = true
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom_at(1.16, button.position)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom_at(1.0 / 1.16, button.position)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_RIGHT or button.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = button.pressed
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				grab_focus()
				if tool_mode == "Pan":
					_panning = true
				else:
					_begin_edit(button.position, button.alt_pressed)
			else:
				if _drag_mode != "":
					edit_finished.emit()
				_drag_mode = ""
				_drag_index = -1
				if tool_mode == "Pan":
					_panning = false
			queue_redraw()
			accept_event()

	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		_mouse = motion.position
		_mouse_over = true
		if _panning:
			camera_position -= motion.relative / zoom
			accept_event()
		elif _drag_mode != "":
			_update_edit(motion.position, motion.alt_pressed)
			accept_event()
		queue_redraw()


func _begin_edit(screen: Vector2, alt_pressed: bool) -> void:
	var anchor_index: int = _hit_anchor(screen)
	var handle: String = _hit_selected_handle(screen)
	_alt_break_tangent = alt_pressed

	if tool_mode == "Pen":
		if anchor_index >= 0:
			selected_index = anchor_index
			_drag_index = anchor_index
			# Clicking an existing anchor and dragging adjusts its outgoing tangent.
			_drag_mode = "out" if anchor_index < data.anchors.size() - 1 else "in"
			edit_started.emit()
			return
		var world: Vector2 = _to_world(screen)
		if world.x <= 0.0 or world.x >= float(data.width_px):
			return
		edit_started.emit()
		var added: int = data.insert_anchor(world)
		if added < 0:
			edit_finished.emit()
			return
		selected_index = added
		_drag_index = added
		_drag_mode = "out"
		edit_changed.emit()
		return

	# Edit mode: drag an anchor to reposition, or drag one of its tangent handles.
	if handle != "":
		_drag_index = selected_index
		_drag_mode = handle
		edit_started.emit()
	elif anchor_index >= 0:
		selected_index = anchor_index
		_drag_index = anchor_index
		_drag_mode = "anchor"
		edit_started.emit()
	else:
		selected_index = -1


func _update_edit(screen: Vector2, alt_pressed: bool) -> void:
	if _drag_index < 0:
		return
	var world: Vector2 = _to_world(screen)
	match _drag_mode:
		"anchor":
			data.move_anchor(_drag_index, world)
		"in":
			data.set_handle(_drag_index, false, world, not (alt_pressed or _alt_break_tangent))
		"out":
			data.set_handle(_drag_index, true, world, not (alt_pressed or _alt_break_tangent))
	edit_changed.emit()


func _hit_anchor(screen: Vector2) -> int:
	# Screen-space radius remains usable across all zoom levels.
	for i in range(data.anchors.size()):
		if _to_screen(data.anchors[i]).distance_to(screen) <= HIT_RADIUS:
			return i
	return -1


func _hit_selected_handle(screen: Vector2) -> String:
	if selected_index < 0 or selected_index >= data.anchors.size():
		return ""
	var anchor: Vector2 = data.anchors[selected_index]
	if selected_index > 0 and data.handles_in[selected_index].length() > 0.01:
		if _to_screen(anchor + data.handles_in[selected_index]).distance_to(screen) <= HIT_RADIUS:
			return "in"
	if selected_index < data.anchors.size() - 1 and data.handles_out[selected_index].length() > 0.01:
		if _to_screen(anchor + data.handles_out[selected_index]).distance_to(screen) <= HIT_RADIUS:
			return "out"
	return ""


func delete_selected() -> void:
	if data == null or selected_index <= 0 or selected_index >= data.anchors.size() - 1:
		return
	edit_started.emit()
	if data.delete_anchor(selected_index):
		selected_index = -1
		edit_changed.emit()
		edit_finished.emit()
		queue_redraw()


func _on_mouse_exited() -> void:
	_mouse_over = false
	queue_redraw()


func _zoom_at(factor: float, screen: Vector2) -> void:
	var world: Vector2 = _to_world(screen)
	zoom = clampf(zoom * factor, 0.045, 4.0)
	camera_position = world - (screen - size * 0.5) / zoom
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SKY)
	if data == null or data.ground_points.size() < 2:
		_caption("No terrain. Choose New Flat Map.")
		return
	_draw_grid()
	_draw_ground()
	_draw_markers()
	_draw_anchors()
	_caption("%s  |  %d px  |  %d anchors  |  %.2fx  |  %s" % [
		data.map_name, data.width_px, data.anchors.size(), zoom, tool_mode
	])


func _draw_grid() -> void:
	if not show_grid:
		return
	var top_left: Vector2 = _to_world(Vector2.ZERO)
	var bottom_right: Vector2 = _to_world(size)
	for axis in range(2):
		var start: float = top_left.x if axis == 0 else top_left.y
		var stop: float = bottom_right.x if axis == 0 else bottom_right.y
		var first: float = floorf(start / 500.0) * 500.0
		var v := first
		var loops := 0
		while v <= stop and loops < 150:
			var p: Vector2 = _to_screen(Vector2(v, 0.0)) if axis == 0 else _to_screen(Vector2(0.0, v))
			if axis == 0:
				draw_line(Vector2(p.x, 0.0), Vector2(p.x, size.y), GRID, 1.0)
			else:
				draw_line(Vector2(0.0, p.y), Vector2(size.x, p.y), GRID, 1.0)
			v += 500.0
			loops += 1


func _draw_ground() -> void:
	var outline := PackedVector2Array()
	for point in data.ground_points:
		outline.append(_to_screen(point))
	var polygon := outline.duplicate()
	var bottom: float = maxf(size.y + 24.0, _to_screen(Vector2(0.0, data.base_y + data.fill_depth_px)).y)
	polygon.append(Vector2(outline[-1].x, bottom))
	polygon.append(Vector2(outline[0].x, bottom))
	draw_colored_polygon(polygon, GROUND)
	draw_polyline(outline, GRASS, clampf(5.5 * zoom, 2.0, 7.0), true)


func _draw_markers() -> void:
	var a: Vector2 = _to_screen(data.anchors[0])
	var b: Vector2 = _to_screen(data.anchors[-1])
	draw_circle(a, 6.0, Color(0.23, 0.74, 1.0))
	draw_circle(b, 6.0, Color(1.0, 0.71, 0.28))
	if zoom > 0.15:
		draw_string(ThemeDB.fallback_font, a + Vector2(8, -12), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		draw_string(ThemeDB.fallback_font, b + Vector2(8, -12), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _draw_anchors() -> void:
	if tool_mode == "Pan":
		return
	for i in range(data.anchors.size()):
		var location: Vector2 = _to_screen(data.anchors[i])
		if location.x < -15.0 or location.x > size.x + 15.0 or location.y < -15.0 or location.y > size.y + 15.0:
			continue
		draw_circle(location, 6.5 if i == selected_index else 4.8, SELECTED if i == selected_index else ANCHOR)
		draw_arc(location, 8.5 if i == selected_index else 6.6, 0, TAU, 24, Color(0.12, 0.23, 0.25), 1.3, true)

	if selected_index < 0 or selected_index >= data.anchors.size():
		return
	var anchor: Vector2 = data.anchors[selected_index]
	var a: Vector2 = _to_screen(anchor)
	if selected_index > 0:
		_draw_handle(a, _to_screen(anchor + data.handles_in[selected_index]))
	if selected_index < data.anchors.size() - 1:
		_draw_handle(a, _to_screen(anchor + data.handles_out[selected_index]))


func _draw_handle(anchor: Vector2, endpoint: Vector2) -> void:
	if anchor.distance_to(endpoint) < 2.0:
		return
	draw_line(anchor, endpoint, HANDLE, 1.7, true)
	draw_rect(Rect2(endpoint - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), HANDLE, true)


func _caption(message: String) -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, 29.0), Color(0.07, 0.16, 0.20, 0.82))
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 20.0), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
