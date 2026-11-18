@tool
extends Window

const Baker = preload("res://addons/itfall_map_editor/map_baker.gd")
const DataScript = preload("res://addons/itfall_map_editor/terrain_data.gd")
const TerrainCanvas = preload("res://addons/itfall_map_editor/terrain_canvas.gd")

var _data
var _source_path := ""
var _last_scene := ""
var _dirty := false
var _syncing := false
var _pending_action := ""
var _pending_path := ""

var _map_name: LineEdit
var _width: SpinBox
var _base_y: SpinBox
var _fill_depth: SpinBox
var _canvas
var _tool_selector: OptionButton
var _info: Label
var _status: Label
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []

var _open_dialog: EditorFileDialog
var _save_dialog: EditorFileDialog
var _confirmation: ConfirmationDialog


func _init() -> void:
	title = "ItFall Map Editor v0.3  |  Pen Tool Terrain"
	min_size = Vector2i(980, 620)
	size = Vector2i(1380, 820)
	transient = false
	unresizable = false
	close_requested.connect(_request_close)


func _ready() -> void:
	_create_dialogs()
	_create_ui()
	_new_map_now()


func _create_dialogs() -> void:
	_open_dialog = EditorFileDialog.new()
	_open_dialog.title = "Open editable ItFall terrain"
	_open_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_open_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.add_filter("*.tres", "Terrain data")
	add_child(_open_dialog)
	_open_dialog.file_selected.connect(_open_selected)

	_save_dialog = EditorFileDialog.new()
	_save_dialog.title = "Save editable ItFall terrain"
	_save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.add_filter("*.tres", "Terrain data")
	add_child(_save_dialog)
	_save_dialog.file_selected.connect(_save_selected)

	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "Discard unsaved terrain?"
	_confirmation.dialog_text = "You have unsaved changes. Continue and discard them?"
	_confirmation.confirmed.connect(_confirm_action)
	add_child(_confirmation)


func _create_ui() -> void:
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 10)
	frame.add_theme_constant_override("margin_right", 10)
	frame.add_theme_constant_override("margin_top", 10)
	frame.add_theme_constant_override("margin_bottom", 10)
	add_child(frame)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	frame.add_child(root)

	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)
	_add_button(toolbar, "New Flat Map", _new_map)
	_add_button(toolbar, "Open .tres", _open_file)
	_add_button(toolbar, "Save", _save)
	_add_button(toolbar, "Save As...", _save_as)
	_add_button(toolbar, "Bake SmartShape", _bake)
	_add_button(toolbar, "Open Baked", _open_baked)
	toolbar.add_spacer(false)
	_add_button(toolbar, "Fit", _fit)

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(260.0, 0.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(scroll)
	var sidebar := VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 9)
	scroll.add_child(sidebar)

	_heading(sidebar, "FLAT MAP SETUP")
	_map_name = LineEdit.new()
	_map_name.text = "Grassland_AB"
	_map_name.placeholder_text = "Map name"
	sidebar.add_child(_map_name)
	_map_name.text_changed.connect(_on_name_changed)
	_width = _spin(sidebar, "Length (px)", 8000.0, 512.0, 100000.0, 256.0)
	_base_y = _spin(sidebar, "Ground Y", 280.0, -2000.0, 5000.0, 20.0)
	_fill_depth = _spin(sidebar, "Fill depth", 1800.0, 600.0, 10000.0, 100.0)
	_fill_depth.value_changed.connect(_on_fill_depth_changed)
	_add_button(sidebar, "Create new flat terrain", _new_map)
	_small_text(sidebar, "Length and Ground Y apply to the next NEW map. Fill depth is editable anytime.")

	_heading(sidebar, "PEN TOOL")
	_tool_selector = OptionButton.new()
	for mode in ["Pen", "Edit", "Pan"]:
		_tool_selector.add_item(mode)
	sidebar.add_child(_tool_selector)
	_tool_selector.item_selected.connect(_select_tool)
	_small_text(sidebar, "PEN: Click to create an anchor. Click + drag to pull two tangent handles and draw a smooth curve. Click an existing anchor + drag to reshape its tangent.")
	_small_text(sidebar, "EDIT: Drag the selected anchor or its orange tangent handles. Hold Alt while dragging a handle to break symmetry.")
	_small_text(sidebar, "The two endpoints A/B are always kept at the map boundaries (X=0 / X=Length).")

	var history := HBoxContainer.new()
	sidebar.add_child(history)
	_add_button(history, "Undo", _undo).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_button(history, "Redo", _redo).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_button(sidebar, "Delete selected anchor", _delete_selected)
	_small_text(sidebar, "Delete cannot remove endpoint A or B. Ctrl+Z / Ctrl+Y also work when the viewport is focused.")

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(center)

	_canvas = TerrainCanvas.new()
	_canvas.custom_minimum_size = Vector2(400.0, 320.0)
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(_canvas)
	_canvas.edit_started.connect(_edit_started)
	_canvas.edit_changed.connect(_edit_changed)
	_canvas.edit_finished.connect(_edit_finished)
	_canvas.undo_requested.connect(_undo)
	_canvas.redo_requested.connect(_redo)

	var viewbar := HBoxContainer.new()
	center.add_child(viewbar)
	_add_button(viewbar, "−", _zoom_out)
	_add_button(viewbar, "+", _zoom_in)
	_add_button(viewbar, "Fit", _fit)
	var grid := CheckBox.new()
	grid.text = "Grid"
	grid.button_pressed = true
	grid.toggled.connect(_grid_toggled)
	viewbar.add_child(grid)
	_small_text(viewbar, "Mouse wheel: zoom  |  Right / middle drag: pan  |  Left: Pen / Edit")

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 200
	main.add_child(right)
	_heading(right, "CURRENT MAP")
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_info)
	_heading(right, "WORKFLOW")
	_small_text(right, "1. New Flat Map\n2. Pen: click + drag curves\n3. Edit anchors and handles\n4. Save editable .tres\n5. Bake SmartShape .tscn")
	_heading(right, "PREVIEW")
	_small_text(right, "The green surface is a schematic preview. Bake to inspect the final SmartShape2D grass material and collision.")
	_heading(right, "SOURCE OF TRUTH")
	_small_text(right, "Edit the .tres using this tool. Baked .tscn scenes are versioned outputs; manual scene edits will not sync back.")

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 28.0
	root.add_child(_status)


func _heading(parent: Control, value: String) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 15)
	parent.add_child(label)


func _small_text(parent: Control, value: String) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(0.76, 0.83, 0.86)
	parent.add_child(label)


func _add_button(parent: Control, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _spin(parent: Control, label_text: String, initial: float, minimum: float, maximum: float, increment: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 114.0
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = increment
	spin.value = initial
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	return spin


func _sync_ui() -> void:
	_syncing = true
	_map_name.text = _data.map_name
	_width.value = float(_data.width_px)
	_base_y.value = _data.base_y
	_fill_depth.value = _data.fill_depth_px
	_syncing = false


func _on_name_changed(new_name: String) -> void:
	if _syncing or _data == null:
		return
	_data.map_name = new_name.strip_edges() if new_name.strip_edges() != "" else "Grassland_AB"
	_dirty = true
	_refresh_info()


func _on_fill_depth_changed(depth: float) -> void:
	if _syncing or _data == null:
		return
	_data.fill_depth_px = depth
	_dirty = true
	_canvas.queue_redraw()
	_refresh_info()


func _new_map() -> void:
	_confirm_or_perform("new")


func _new_map_now() -> void:
	_data = DataScript.new()
	_data.map_name = _map_name.text.strip_edges() if _map_name.text.strip_edges() != "" else "Grassland_AB"
	_data.fill_depth_px = _fill_depth.value
	_data.create_flat(int(_width.value), _base_y.value)
	_source_path = ""
	_last_scene = ""
	_dirty = true
	_undo_stack.clear()
	_redo_stack.clear()
	_canvas.set_data(_data, true)
	_refresh_info()
	_set_status("Flat map created. Select Pen and click + drag to draw a smooth hill or valley.")


func _confirm_or_perform(action: String) -> void:
	_pending_action = action
	if _dirty:
		_confirmation.popup_centered()
	else:
		_confirm_action()


func _confirm_action() -> void:
	match _pending_action:
		"new":
			_new_map_now()
		"close":
			hide()
		"load":
			_load_map(_pending_path)
	_pending_action = ""


func _request_close() -> void:
	_confirm_or_perform("close")


func _open_file() -> void:
	_open_dialog.popup_centered_ratio(0.8)


func _open_selected(path: String) -> void:
	_pending_path = path
	_confirm_or_perform("load")


func _load_map(path: String) -> void:
	var loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or loaded.get_script() != DataScript:
		_set_status("Not a valid ItFall terrain .tres: " + path)
		return
	if loaded.ground_points.size() < 2 and loaded.anchors.size() < 2:
		_set_status("Terrain resource has no valid surface.")
		return
	var migrated: bool = loaded.anchors.size() < 2
	loaded.ensure_editable()
	_data = loaded
	_source_path = path
	_last_scene = ""
	_dirty = migrated
	_undo_stack.clear()
	_redo_stack.clear()
	_sync_ui()
	_canvas.set_data(_data, true)
	_refresh_info()
	_set_status("Opened %s%s" % [path, " (legacy profile converted to corner anchors; save to keep it)" if migrated else ""])


func _save() -> void:
	if _data == null:
		return
	if _source_path == "":
		_save_as()
	else:
		_save_to_path(_source_path)


func _save_as() -> void:
	if _data == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://generated_maps"))
	_save_dialog.current_dir = "res://generated_maps"
	_save_dialog.current_file = Baker._safe_name(_data.map_name) + ".tres"
	_save_dialog.popup_centered_ratio(0.8)


func _save_selected(path: String) -> void:
	if not path.ends_with(".tres"):
		path += ".tres"
	_save_to_path(path)


func _save_to_path(path: String) -> bool:
	if _data == null or not path.begins_with("res://"):
		_set_status("Save path must be under res://.")
		return false
	var error: Error = ResourceSaver.save(_data, path)
	if error != OK:
		_set_status("Save failed (%d): %s" % [error, path])
		return false
	_source_path = path
	_dirty = false
	EditorInterface.get_resource_filesystem().scan()
	_refresh_info()
	_set_status("Saved editable terrain: " + path)
	return true


func _bake() -> void:
	if _data == null:
		return
	var result: Dictionary = Baker.bake(_data, _source_path)
	if not result.get("ok", false):
		_set_status("Bake failed: " + str(result.get("message", "Unknown error")))
		return
	_source_path = str(result["data"])
	_last_scene = str(result["scene"])
	_dirty = false
	EditorInterface.get_resource_filesystem().scan()
	_refresh_info()
	_set_status("Baked: %s\nSource: %s" % [_last_scene, _source_path])


func _open_baked() -> void:
	if _last_scene == "":
		_set_status("Bake a map first.")
		return
	EditorInterface.open_scene_from_path(_last_scene)


func _select_tool(index: int) -> void:
	_canvas.tool_mode = _tool_selector.get_item_text(index)
	_canvas.queue_redraw()


func _snapshot() -> Dictionary:
	return {
		"anchors": _data.anchors.duplicate(),
		"handles_in": _data.handles_in.duplicate(),
		"handles_out": _data.handles_out.duplicate()
	}


func _restore(snapshot: Dictionary) -> void:
	_data.anchors = snapshot["anchors"].duplicate()
	_data.handles_in = snapshot["handles_in"].duplicate()
	_data.handles_out = snapshot["handles_out"].duplicate()
	_data.rebuild()
	_canvas.selected_index = -1
	_canvas.queue_redraw()
	_dirty = true
	_refresh_info()


func _edit_started() -> void:
	if _data == null:
		return
	_undo_stack.append(_snapshot())
	if _undo_stack.size() > 60:
		_undo_stack.pop_front()
	_redo_stack.clear()


func _edit_changed() -> void:
	_dirty = true
	_last_scene = ""
	_canvas.queue_redraw()
	_refresh_info()


func _edit_finished() -> void:
	_refresh_info()


func _undo() -> void:
	if _data == null or _undo_stack.is_empty():
		return
	_redo_stack.append(_snapshot())
	_restore(_undo_stack.pop_back())
	_set_status("Undo terrain edit.")


func _redo() -> void:
	if _data == null or _redo_stack.is_empty():
		return
	_undo_stack.append(_snapshot())
	_restore(_redo_stack.pop_back())
	_set_status("Redo terrain edit.")


func _delete_selected() -> void:
	_canvas.delete_selected()


func _zoom_in() -> void:
	_canvas._zoom_at(1.25, _canvas.size * 0.5)


func _zoom_out() -> void:
	_canvas._zoom_at(0.8, _canvas.size * 0.5)


func _fit() -> void:
	_canvas.fit_to_data()


func _grid_toggled(enabled: bool) -> void:
	_canvas.show_grid = enabled
	_canvas.queue_redraw()


func _refresh_info() -> void:
	if _data == null or _info == null:
		return
	_info.text = "Length: %d px\nAnchors: %d\nCurve samples: %d\nGround Y: %.0f\n\nSelected: %s\n\nEditable source:\n%s\n\n%s" % [
		_data.width_px,
		_data.anchors.size(),
		_data.ground_points.size(),
		_data.base_y,
		str(_canvas.selected_index + 1) if _canvas.selected_index >= 0 else "(none)",
		_source_path if _source_path != "" else "(not saved)",
		"Unsaved changes" if _dirty else "Saved"
	]


func _set_status(message: String) -> void:
	if _status != null:
		_status.text = message
