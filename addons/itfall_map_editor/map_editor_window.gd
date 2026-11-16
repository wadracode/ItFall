@tool
extends Window

const Generator = preload("res://addons/itfall_map_editor/terrain_generator.gd")
const Baker = preload("res://addons/itfall_map_editor/map_baker.gd")
const DataScript = preload("res://addons/itfall_map_editor/terrain_data.gd")
const TerrainCanvas = preload("res://addons/itfall_map_editor/terrain_canvas.gd")

var _data
var _source_path := ""
var _last_scene := ""
var _dirty := false
var _terrain_touched := false
var _settings_pending := false
var _syncing_fields := false

var _fields: Dictionary = {}
var _map_name: LineEdit
var _canvas
var _tool_selector: OptionButton
var _radius: SpinBox
var _strength: SpinBox
var _info: Label
var _status: Label
var _undo_stack: Array[PackedVector2Array] = []
var _redo_stack: Array[PackedVector2Array] = []
var _flatten_y: float = 0.0
var _pending_action := ""

var _open_dialog: EditorFileDialog
var _save_dialog: EditorFileDialog
var _confirmation: ConfirmationDialog


func _init() -> void:
	title = "ItFall Map Editor v2  |  Terrain Workspace"
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
	_open_dialog.title = "Open ItFall terrain data"
	_open_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_open_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.add_filter("*.tres", "Terrain data")
	add_child(_open_dialog)
	_open_dialog.file_selected.connect(_open_selected)

	_save_dialog = EditorFileDialog.new()
	_save_dialog.title = "Save ItFall terrain data"
	_save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.add_filter("*.tres", "Terrain data")
	add_child(_save_dialog)
	_save_dialog.file_selected.connect(_save_selected)

	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "Unsaved terrain changes"
	_confirmation.confirmed.connect(_confirm_action)
	add_child(_confirmation)


func _create_ui() -> void:
	var base := MarginContainer.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.add_theme_constant_override("margin_left", 10)
	base.add_theme_constant_override("margin_right", 10)
	base.add_theme_constant_override("margin_top", 10)
	base.add_theme_constant_override("margin_bottom", 10)
	add_child(base)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	base.add_child(root)

	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)
	_add_button(toolbar, "New", _new_map)
	_add_button(toolbar, "Open .tres", _open_file)
	_add_button(toolbar, "Save", _save)
	_add_button(toolbar, "Save As...", _save_as)
	_add_button(toolbar, "Bake SmartShape", _bake)
	_add_button(toolbar, "Open Baked", _open_baked)
	toolbar.add_spacer(false)
	var fit := _add_button(toolbar, "Fit map", _fit)
	fit.tooltip_text = "Fit the complete map width in the viewport."

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(270, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(scroll)
	var sidebar := VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 7)
	scroll.add_child(sidebar)

	_heading(sidebar, "MAP GENERATOR")
	_map_name = LineEdit.new()
	_map_name.text = "Grassland_AB"
	_map_name.placeholder_text = "Map name"
	sidebar.add_child(_map_name)
	_map_name.text_changed.connect(_on_settings_changed)

	_field(sidebar, "Seed", "seed", 12345.0, 0.0, 2147483647.0, 1.0)
	_field(sidebar, "Length", "width_px", 8000.0, 1024.0, 30000.0, 256.0)
	_field(sidebar, "Sample step", "sample_step_px", 64.0, 32.0, 256.0, 16.0)
	_field(sidebar, "Ground Y", "base_y", 280.0, -500.0, 1500.0, 10.0)
	_field(sidebar, "Hill height", "hill_amplitude", 110.0, 0.0, 550.0, 10.0)
	_field(sidebar, "Hill scale", "hill_span_px", 1800.0, 250.0, 8000.0, 50.0)
	_field(sidebar, "Fill depth", "fill_depth_px", 1800.0, 900.0, 4000.0, 100.0)

	_add_button(sidebar, "Generate new terrain", _request_generate)
	_small_text(sidebar, "Generate replaces the profile in the viewport. Sculpting happens below.")

	_heading(sidebar, "TERRAIN BRUSHES")
	_tool_selector = OptionButton.new()
	for tool in ["Pan", "Raise", "Lower", "Smooth", "Flatten"]:
		_tool_selector.add_item(tool)
	sidebar.add_child(_tool_selector)
	_tool_selector.item_selected.connect(_select_tool)
	_radius = _custom_field(sidebar, "Radius", 190.0, 25.0, 800.0, 25.0)
	_strength = _custom_field(sidebar, "Strength", 16.0, 1.0, 80.0, 1.0)
	_radius.value_changed.connect(_brush_settings_changed)
	var history_bar := HBoxContainer.new()
	sidebar.add_child(history_bar)
	_add_button(history_bar, "Undo", _undo).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_button(history_bar, "Redo", _redo).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_heading(sidebar, "ENVIRONMENT")
	_field(sidebar, "Trees / 1k px", "trees_per_km", 6.0, 0.0, 30.0, 1.0)
	_field(sidebar, "Rocks / 1k px", "rocks_per_km", 9.0, 0.0, 30.0, 1.0)
	_add_button(sidebar, "Redistribute objects", _redistribute)
	_small_text(sidebar, "Trees and rocks are placeholders. Sculpt edits automatically reposition them.")

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(center)

	_canvas = TerrainCanvas.new()
	_canvas.custom_minimum_size = Vector2(400, 320)
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(_canvas)
	_canvas.stroke_started.connect(_stroke_start)
	_canvas.stroke_moved.connect(_stroke_move)
	_canvas.stroke_finished.connect(_stroke_finish)
	_canvas.brush_radius = _radius.value

	var view_toolbar := HBoxContainer.new()
	center.add_child(view_toolbar)
	_add_button(view_toolbar, "−", _zoom_out)
	_add_button(view_toolbar, "+", _zoom_in)
	_add_button(view_toolbar, "Fit", _fit)
	var grid := CheckBox.new()
	grid.text = "Grid"
	grid.button_pressed = true
	grid.toggled.connect(_grid_toggled)
	view_toolbar.add_child(grid)
	_small_text(view_toolbar, "Wheel: zoom  |  RMB: pan  |  LMB: edit")

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 200
	main.add_child(right)
	_heading(right, "WORKSPACE")
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_info)
	_heading(right, "EXPORT PIPELINE")
	_small_text(right, "1. Generate from Seed\n2. Sculpt the terrain\n3. Save source .tres\n4. Bake .tscn\n5. Run your scene")
	_heading(right, "SMARTSHAPE2D")
	_small_text(right, "The baker creates SmartShape2D + solid collision automatically. You do not need to edit its points by hand.")
	_heading(right, "IMPORTANT")
	_small_text(right, "This is a 2D authoring view, not a live game. Editing a previously baked scene directly will not sync back into .tres. Re-baking creates a new scene, preserving older outputs.")

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 28
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
	label.modulate = Color(0.74, 0.80, 0.83)
	parent.add_child(label)


func _add_button(parent: Control, title_text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title_text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _field(parent: Control, label_text: String, field_name: String, initial: float, minimum: float, maximum: float, step_value: float) -> void:
	var spin := _custom_field(parent, label_text, initial, minimum, maximum, step_value)
	_fields[field_name] = spin
	spin.value_changed.connect(_on_settings_changed)


func _custom_field(parent: Control, label_text: String, initial: float, minimum: float, maximum: float, step_value: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 110.0
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step_value
	spin.value = initial
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	return spin


func _settings() -> Dictionary:
	var settings: Dictionary = {"map_name": _map_name.text.strip_edges()}
	if settings["map_name"] == "":
		settings["map_name"] = "Grassland_AB"
	for key in _fields:
		settings[key] = (_fields[key] as SpinBox).value
	return settings


func _sync_fields_from_data() -> void:
	_syncing_fields = true
	_map_name.text = _data.map_name
	for key in _fields.keys():
		(_fields[key] as SpinBox).value = _data.get(key)
	_syncing_fields = false
	_settings_pending = false


func _on_settings_changed(_value: Variant = null) -> void:
	if _syncing_fields:
		return
	_settings_pending = true
	_set_status("Settings changed. Press Generate to replace terrain, or Redistribute objects to keep sculpting.")


func _new_map() -> void:
	_confirm_or_perform("new")


func _new_map_now() -> void:
	_data = Generator.create(_settings())
	_source_path = ""
	_last_scene = ""
	_dirty = true
	_terrain_touched = false
	_settings_pending = false
	_undo_stack.clear()
	_redo_stack.clear()
	_canvas.set_data(_data, true)
	_refresh_info()
	_set_status("New terrain from seed %d. Drag with sculpt tools, then Save or Bake." % _data.seed)


func _request_generate() -> void:
	if _terrain_touched:
		_confirm_or_perform("generate")
	else:
		_generate_now()


func _generate_now() -> void:
	_data = Generator.create(_settings())
	# A regenerated map becomes a new source. Never overwrite an old hand-edited .tres.
	_source_path = ""
	_last_scene = ""
	_dirty = true
	_terrain_touched = false
	_settings_pending = false
	_undo_stack.clear()
	_redo_stack.clear()
	_canvas.set_data(_data, true)
	_refresh_info()
	_set_status("Generated a new profile. Source and any previous bakes are preserved.")


func _confirm_or_perform(action: String) -> void:
	if not _dirty:
		_pending_action = action
		_confirm_action()
		return
	_pending_action = action
	_confirmation.dialog_text = "There are unsaved changes. Continue and discard them?"
	_confirmation.popup_centered()


func _confirm_action() -> void:
	match _pending_action:
		"new":
			_new_map_now()
		"generate":
			_generate_now()
		"close":
			hide()
		"open":
			_open_dialog.popup_centered_ratio(0.8)
		"load":
			_load_map(_pending_path)
	_pending_action = ""


var _pending_path := ""


func _request_close() -> void:
	_confirm_or_perform("close")


func _open_file() -> void:
	_confirm_or_perform("open")


func _open_selected(path: String) -> void:
	if _dirty:
		_pending_path = path
		_confirm_or_perform("load")
	else:
		_load_map(path)


func _load_map(path: String) -> void:
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or loaded.get_script() != DataScript:
		_set_status("Not an ItFall terrain data .tres: " + path)
		return
	_data = loaded
	if _data.ground_points.size() < 3:
		_set_status("Invalid terrain data: not enough terrain samples.")
		return
	_source_path = path
	_last_scene = ""
	_dirty = false
	_terrain_touched = false
	_settings_pending = false
	_undo_stack.clear()
	_redo_stack.clear()
	_sync_fields_from_data()
	_canvas.set_data(_data, true)
	_refresh_info()
	_set_status("Opened source: " + path)


func _save() -> void:
	if _data == null:
		return
	if _source_path == "":
		_save_as()
	else:
		_save_to_path(_source_path)


func _save_as() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://generated_maps"))
	_save_dialog.current_dir = "res://generated_maps"
	_save_dialog.current_file = Baker._safe_name(_data.map_name) + "_" + str(_data.seed) + ".tres"
	_save_dialog.popup_centered_ratio(0.8)


func _save_selected(path: String) -> void:
	if not path.ends_with(".tres"):
		path += ".tres"
	_save_to_path(path)


func _save_to_path(path: String) -> bool:
	if _data == null or not path.begins_with("res://"):
		_set_status("Invalid map save path.")
		return false
	if _settings_pending:
		_set_status("Generator settings were changed but not applied. Click Generate first or restore the prior values.")
		return false
	var error: Error = ResourceSaver.save(_data, path)
	if error != OK:
		_set_status("Save failed (%d): %s" % [error, path])
		return false
	_source_path = path
	_dirty = false
	EditorInterface.get_resource_filesystem().scan()
	_refresh_info()
	_set_status("Saved editable map: " + path)
	return true


func _bake() -> void:
	if _data == null:
		return
	if _settings_pending:
		_set_status("Click Generate to apply settings before baking.")
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
	_set_status("Baked scene: %s\nEditable source: %s" % [_last_scene, _source_path])


func _open_baked() -> void:
	if _last_scene == "":
		_set_status("No scene baked in this session yet.")
		return
	EditorInterface.open_scene_from_path(_last_scene)


func _redistribute() -> void:
	if _data == null:
		return
	_data.map_name = _map_name.text.strip_edges()
	_data.trees_per_km = float((_fields["trees_per_km"] as SpinBox).value)
	_data.rocks_per_km = float((_fields["rocks_per_km"] as SpinBox).value)
	Generator.regenerate_props(_data)
	_dirty = true
	_settings_pending = _terrain_settings_differ()
	_canvas.queue_redraw()
	_refresh_info()
	_set_status("Repositioned trees and rocks without regenerating terrain.")


func _terrain_settings_differ() -> bool:
	if _data == null:
		return false
	for key in ["seed", "width_px", "sample_step_px", "base_y", "hill_amplitude", "hill_span_px", "fill_depth_px"]:
		if not is_equal_approx(float((_fields[key] as SpinBox).value), float(_data.get(key))):
			return true
	return false


func _select_tool(index: int) -> void:
	_canvas.tool_mode = _tool_selector.get_item_text(index)
	_canvas.queue_redraw()


func _brush_settings_changed(_value: float) -> void:
	_canvas.brush_radius = _radius.value
	_canvas.queue_redraw()


func _stroke_start(pos: Vector2) -> void:
	if _data == null:
		return
	_undo_stack.append(_data.ground_points.duplicate())
	if _undo_stack.size() > 40:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_flatten_y = _data.ground_y_at(pos.x)
	_apply_brush(pos)


func _stroke_move(pos: Vector2) -> void:
	_apply_brush(pos)


func _stroke_finish() -> void:
	_refresh_info()


func _apply_brush(pos: Vector2) -> void:
	var originals: PackedVector2Array = _data.ground_points
	var next_points: PackedVector2Array = originals.duplicate()
	var mode: String = _canvas.tool_mode
	var radius: float = _radius.value
	var strength: float = _strength.value
	for i in range(1, originals.size() - 1):
		var point: Vector2 = originals[i]
		var distance: float = absf(point.x - pos.x)
		if distance > radius:
			continue
		var weight: float = pow(1.0 - distance / radius, 2.0)
		match mode:
			"Raise":
				point.y -= strength * weight
			"Lower":
				point.y += strength * weight
			"Flatten":
				point.y = lerpf(point.y, _flatten_y, clampf(strength / 38.0 * weight, 0.0, 1.0))
			"Smooth":
				var start: int = maxi(i - 2, 0)
				var stop: int = mini(i + 2, originals.size() - 1)
				var mean_y := 0.0
				for j in range(start, stop + 1):
					mean_y += originals[j].y
				mean_y /= float(stop - start + 1)
				point.y = lerpf(point.y, mean_y, clampf(strength / 28.0 * weight, 0.0, 1.0))
		point.y = clampf(point.y, _data.base_y - 900.0, _data.base_y + 900.0)
		next_points[i] = point
	_data.ground_points = next_points
	_reproject_props()
	_dirty = true
	_terrain_touched = true
	_canvas.queue_redraw()


func _reproject_props() -> void:
	var trees := PackedVector2Array()
	for point in _data.tree_points:
		trees.append(Vector2(point.x, _data.ground_y_at(point.x)))
	_data.tree_points = trees
	var rocks := PackedVector2Array()
	for point in _data.rock_points:
		rocks.append(Vector2(point.x, _data.ground_y_at(point.x)))
	_data.rock_points = rocks


func _undo() -> void:
	if _data == null or _undo_stack.is_empty():
		return
	_redo_stack.append(_data.ground_points.duplicate())
	_data.ground_points = _undo_stack.pop_back()
	_reproject_props()
	_dirty = true
	_canvas.queue_redraw()
	_set_status("Undo terrain stroke.")


func _redo() -> void:
	if _data == null or _redo_stack.is_empty():
		return
	_undo_stack.append(_data.ground_points.duplicate())
	_data.ground_points = _redo_stack.pop_back()
	_reproject_props()
	_dirty = true
	_canvas.queue_redraw()
	_set_status("Redo terrain stroke.")


func _zoom_in() -> void:
	_canvas._zoom_at(1.25, _canvas.size * 0.5)


func _zoom_out() -> void:
	_canvas._zoom_at(0.8, _canvas.size * 0.5)


func _fit() -> void:
	_canvas.fit_to_data()


func _grid_toggled(value: bool) -> void:
	_canvas.show_grid = value
	_canvas.queue_redraw()


func _refresh_info() -> void:
	if _data == null or _info == null:
		return
	_info.text = "Seed: %d\nWidth: %d px\nPoints: %d\nTrees: %d\nRocks: %d\n\nSource:\n%s\n\n%s" % [
		_data.seed,
		_data.width_px,
		_data.ground_points.size(),
		_data.tree_points.size(),
		_data.rock_points.size(),
		_source_path if _source_path != "" else "(not saved yet)",
		"Unsaved changes" if _dirty else "Saved"
	]


func _set_status(value: String) -> void:
	if _status != null:
		_status.text = value
