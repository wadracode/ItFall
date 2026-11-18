@tool
extends RefCounted

const OUTPUT_DIR := "res://generated_maps"
const EDGE_TEXTURE := "res://assets/terrain/grassland/grassland_surface_edge.svg"
const FILL_TEXTURE := "res://assets/terrain/grassland/grassland_fill.svg"


static func bake(data, source_path: String = "") -> Dictionary:
	if data == null:
		return {"ok": false, "message": "No editable terrain selected."}
	data.ensure_editable()
	if data.ground_points.size() < 2:
		return {"ok": false, "message": "Draw a terrain surface before baking."}

	var folder_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if folder_error != OK:
		return {"ok": false, "message": "Cannot create generated_maps folder."}

	var resource_path := ""
	var scene_path := ""
	var created_source := false
	if source_path != "":
		if not source_path.begins_with("res://") or not source_path.ends_with(".tres"):
			return {"ok": false, "message": "Invalid editable source path."}
		resource_path = source_path
		var scene_base := source_path.get_basename() + "_bake"
		scene_path = scene_base + ".tscn"
		var index := 1
		while FileAccess.file_exists(scene_path):
			scene_path = scene_base + "_%03d.tscn" % index
			index += 1
			if index > 999:
				return {"ok": false, "message": "Too many baked versions."}
	else:
		var slug := _safe_name(data.map_name)
		var prefix := "%s/%s" % [OUTPUT_DIR, slug]
		var index := 1
		while FileAccess.file_exists(prefix + ".tscn") or FileAccess.file_exists(prefix + ".tres"):
			prefix = "%s/%s_%03d" % [OUTPUT_DIR, slug, index]
			index += 1
			if index > 999:
				return {"ok": false, "message": "Too many maps with this name."}
		resource_path = prefix + ".tres"
		scene_path = prefix + ".tscn"
		created_source = true

	var resource_error: Error = ResourceSaver.save(data, resource_path)
	if resource_error != OK:
		return {"ok": false, "message": "Unable to save editable terrain (%d)." % resource_error}

	var root := Node2D.new()
	root.name = "Map_" + _safe_name(data.map_name)
	root.set_meta("map_data_path", resource_path)
	_add_background(root, data)
	_add_smart_shape(root, data)
	_add_spawns(root, data)

	var packed := PackedScene.new()
	var pack_error: Error = packed.pack(root)
	root.free()
	if pack_error != OK:
		if created_source:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))
		return {"ok": false, "message": "Cannot pack scene (%d)." % pack_error}

	var scene_error: Error = ResourceSaver.save(packed, scene_path)
	if scene_error != OK:
		if created_source:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))
		return {"ok": false, "message": "Cannot save scene (%d)." % scene_error}

	return {"ok": true, "scene": scene_path, "data": resource_path}


static func _safe_name(value: String) -> String:
	var result := ""
	for i in range(value.length()):
		var character := value.substr(i, 1).to_lower()
		if "abcdefghijklmnopqrstuvwxyz0123456789_".contains(character):
			result += character
		else:
			result += "_"
	return result if result != "" else "map"


static func _add_owned(parent: Node, child: Node, root: Node) -> void:
	parent.add_child(child)
	child.owner = root


static func _add_background(root: Node2D, data) -> void:
	var sky := Polygon2D.new()
	sky.name = "SkyBackground"
	sky.z_index = -100
	sky.color = Color(0.63, 0.82, 0.87)
	var top := data.base_y - 2400.0
	var bottom := data.base_y + data.fill_depth_px + 150.0
	sky.polygon = PackedVector2Array([
		Vector2(-1024.0, top),
		Vector2(float(data.width_px) + 1024.0, top),
		Vector2(float(data.width_px) + 1024.0, bottom),
		Vector2(-1024.0, bottom)
	])
	_add_owned(root, sky, root)


static func _add_smart_shape(root: Node2D, data) -> void:
	var shape := SS2D_Shape.new()
	shape.name = "SmartShapeGround"
	shape.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	shape.render_edges = true

	var curve_points := SS2D_Point_Array.new()
	curve_points.begin_update()
	for position in data.ground_points:
		curve_points.add_point_direct(position)
	var bottom_y: float = maxf(data.base_y + data.fill_depth_px, _maximum_terrain_y(data) + 600.0)
	curve_points.add_point_direct(Vector2(float(data.width_px), bottom_y))
	curve_points.add_point_direct(Vector2(0.0, bottom_y))
	curve_points.close_shape()
	curve_points.end_update()
	shape.set_point_array(curve_points)

	var material := SS2D_Material_Shape.new()
	var fill := load(FILL_TEXTURE) as Texture2D
	if fill == null:
		push_warning("ItFall fill texture missing. Using a simple green gradient.")
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(0.23, 0.43, 0.26), Color(0.31, 0.52, 0.31)])
		var fallback := GradientTexture2D.new()
		fallback.width = 256
		fallback.height = 256
		fallback.gradient = gradient
		fill = fallback
	var fill_array: Array[Texture2D] = [fill]
	material.fill_textures = fill_array
	material.fill_texture_scale = 1.0
	material.fill_texture_show_behind_parent = true

	var edge_texture := load(EDGE_TEXTURE) as Texture2D
	if edge_texture != null:
		var edge := SS2D_Material_Edge.new()
		var edge_array: Array[Texture2D] = [edge_texture]
		edge.textures = edge_array
		var edge_meta := SS2D_Material_Edge_Metadata.new()
		edge_meta.edge_material = edge
		edge_meta.normal_range = SS2D_NormalRange.new(0.0, 180.0)
		material.add_edge_material(edge_meta)
	else:
		shape.render_edges = false

	shape.shape_material = material
	shape.collision_update_mode = SS2D_Shape.CollisionUpdateMode.Editor
	_add_owned(root, shape, root)

	var body := StaticBody2D.new()
	body.name = "GroundCollision"
	_add_owned(root, body, root)
	var polygon := CollisionPolygon2D.new()
	polygon.name = "SolidGround"
	var verts: PackedVector2Array = data.ground_points.duplicate()
	verts.append(Vector2(float(data.width_px), bottom_y))
	verts.append(Vector2(0.0, bottom_y))
	polygon.polygon = verts
	_add_owned(body, polygon, root)
	shape.collision_polygon_node_path = NodePath("../GroundCollision/SolidGround")


static func _maximum_terrain_y(data) -> float:
	var biggest: float = data.base_y
	for point in data.ground_points:
		biggest = maxf(biggest, point.y)
	return biggest


static func _add_spawns(root: Node2D, data) -> void:
	var group := Node2D.new()
	group.name = "SpawnPoints"
	_add_owned(root, group, root)

	var left := Marker2D.new()
	left.name = "Entrance_A"
	left.position = Vector2(100.0, data.ground_y_at(100.0) - 40.0)
	_add_owned(group, left, root)

	var right := Marker2D.new()
	right.name = "Entrance_B"
	right.position = Vector2(float(data.width_px) - 100.0, data.ground_y_at(float(data.width_px) - 100.0) - 40.0)
	_add_owned(group, right, root)
