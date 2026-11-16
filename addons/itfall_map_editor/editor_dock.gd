@tool
extends VBoxContainer

const Generator = preload("res://addons/itfall_map_editor/terrain_generator.gd")
const Baker = preload("res://addons/itfall_map_editor/map_baker.gd")
const Preview = preload("res://addons/itfall_map_editor/terrain_preview.gd")

var _map_name: LineEdit
var _fields: Dictionary = {}
var _preview: Control
var _status: Label
var _last_scene_path := ""
var _data


func _ready() -> void:
	_build_controls()
	_generate_preview()


func _build_controls() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 9)
	scroll.add_child(layout)

	_heading(layout, "Procedural 2.5D map", 16)
	_note(layout, "Generate a deterministic terrain preview, then bake an editable SmartShape2D scene. Existing maps are never overwritten.")
	var name_row := HBoxContainer.new()
	layout.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Map name"
	name_label.custom_minimum_size.x = 85.0
	name_row.add_child(name_label)
	_map_name = LineEdit.new()
	_map_name.text = "Grassland_AB"
	_map_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_map_name)
	_map_name.text_changed.connect(_mark_dirty)

	_heading(layout, "Terrain", 14)
	_field(layout, "Seed", "seed", 12345, 0, 2147483647, 1)
	_field(layout, "Length (px)", "width_px", 8000, 1024, 30000, 256)
	_field(layout, "Sample step", "sample_step_px", 64, 32, 256, 16)
	_field(layout, "Ground Y", "base_y", 280, -500, 1500, 10)
	_field(layout, "Hill height", "hill_amplitude", 110, 0, 550, 10)
	_field(layout, "Hill scale", "hill_span_px", 1800, 250, 8000, 50)
	_field(layout, "Fill depth", "fill_depth_px", 1800, 900, 4000, 100)

	_heading(layout, "Environment (per 1,000 px)", 14)
	_field(layout, "Trees", "trees_per_km", 6, 0, 30, 1)
	_field(layout, "Rocks", "rocks_per_km", 9, 0, 30, 1)

	_heading(layout, "Terrain preview", 14)
	_preview = Preview.new()
	_preview.custom_minimum_size = Vector2(300, 175)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_preview)

	var generate_button := Button.new()
	generate_button.text = "1. Generate preview"
	layout.add_child(generate_button)
	generate_button.pressed.connect(_generate_preview)

	var bake_button := Button.new()
	bake_button.text = "2. Bake + open SmartShape scene"
	layout.add_child(bake_button)
	bake_button.pressed.connect(_bake_scene)

	var open_button := Button.new()
	open_button.text = "Open last baked map"
	layout.add_child(open_button)
	open_button.pressed.connect(_open_last)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Ready."
	layout.add_child(_status)
	_note(layout, "Files go to res://generated_maps/. Each bake uses a new name. The original Terrain.tscn is untouched.")


func _heading(parent: Control, caption: String, font_size: int) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)


func _note(parent: Control, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(0.76, 0.80, 0.84)
	parent.add_child(label)


func _field(parent: Control, caption: String, key: String, value: float, min_val: float, max_val: float, step_value: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 118.0
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step_value
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	_fields[key] = spin
	spin.value_changed.connect(_mark_dirty)


func _mark_dirty(_value: Variant = null) -> void:
	_data = null
	if _status != null:
		_status.text = "Settings changed. Generate preview to see the new map."


func _settings() -> Dictionary:
	var result := {"map_name": _map_name.text.strip_edges()}
	if result["map_name"] == "":
		result["map_name"] = "Grassland_AB"
	for key in _fields.keys():
		result[key] = (_fields[key] as SpinBox).value
	return result


func _generate_preview() -> void:
	_data = Generator.create(_settings())
	_preview.set_terrain(_data)
	_status.text = "Preview generated: seed %d, %d terrain samples. Ready to bake." % [
		_data.seed, _data.ground_points.size()
	]


func _bake_scene() -> void:
	# Always rebuild from current control values, so baked data matches the preview/settings.
	_generate_preview()
	var result: Dictionary = Baker.bake(_data)
	if not result.get("ok", false):
		_status.text = "Bake failed: " + str(result.get("message", "Unknown error"))
		push_warning(_status.text)
		return
	_last_scene_path = str(result["scene"])
	var fs := EditorInterface.get_resource_filesystem()
	fs.update_file(str(result["data"]))
	fs.update_file(_last_scene_path)
	_status.text = "Saved scene: %s\nSaved seed/data: %s" % [result["scene"], result["data"]]
	EditorInterface.open_scene_from_path(_last_scene_path)


func _open_last() -> void:
	if _last_scene_path == "":
		_status.text = "No baked map yet. Press Bake first."
		return
	EditorInterface.open_scene_from_path(_last_scene_path)
