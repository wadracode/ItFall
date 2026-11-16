@tool
extends EditorPlugin

const MapWindow = preload("res://addons/itfall_map_editor/map_editor_window.gd")

var _map_window: Window


func _enter_tree() -> void:
	add_tool_menu_item("ItFall Map Editor", _open_map_editor)


func _exit_tree() -> void:
	remove_tool_menu_item("ItFall Map Editor")
	if is_instance_valid(_map_window):
		_map_window.queue_free()
		_map_window = null


func _open_map_editor() -> void:
	if not is_instance_valid(_map_window):
		_map_window = MapWindow.new()
		_map_window.visible = false
		EditorInterface.get_base_control().add_child(_map_window)
	_map_window.popup_centered(Vector2i(1380, 820))
	_map_window.grab_focus()
