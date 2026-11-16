@tool
extends RefCounted

const OUTPUT_DIR := "res://generated_maps"
const EDGE_TEXTURE := "res://addons/rmsmartshape/documentation/imgs/grass.png"


static func bake(data) -> Dictionary:
	if data == null or data.ground_points.size() < 3:
		return {"ok": false, "message": "Generate terrain before baking."}

	var folder_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if folder_error != OK:
		return {"ok": false, "message": "Cannot create generated_maps directory."}

	var slug := _safe_name(data.map_name)
	var prefix := "%s/%s_%d" % [OUTPUT_DIR, slug, data.seed]
	var index := 1
	while FileAccess.file_exists(prefix + ".tscn") or FileAccess.file_exists(prefix + ".tres"):
		prefix = "%s/%s_%d_%03d" % [OUTPUT_DIR, slug, data.seed, index]
		index += 1
		if index > 999:
			return {"ok": false, "message": "Too many maps with this name and seed."}

	var resource_path := prefix + ".tres"
	var scene_path := prefix + ".tscn"
	var save_error := ResourceSaver.save(data, resource_path)
	if save_error != OK:
		return {"ok": false, "message": "Unable to save map data (%d)." % save_error}

	var scene_root := Node2D.new()
	scene_root.name = "Map_" + slug
	scene_root.set_meta("map_data_path", resource_path)

	_add_background(scene_root, data)
	_add_smart_shape(scene_root, data)
	_add_environment(scene_root, data)
	_add_spawns(scene_root, data)

	var packed := PackedScene.new()
	var pack_error := packed.pack(scene_root)
	scene_root.free()
	if pack_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))
		return {"ok": false, "message": "Cannot pack scene (%d)." % pack_error}

	var scene_error := ResourceSaver.save(packed, scene_path)
	if scene_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))
		return {"ok": false, "message": "Cannot save scene (%d)." % scene_error}

	return {"ok": true, "scene": scene_path, "data": resource_path}


static func _safe_name(value: String) -> String:
	var result := ""
	for i in range(value.length()):
		var c := value.substr(i, 1).to_lower()
		if "abcdefghijklmnopqrstuvwxyz0123456789_".contains(c):
			result += c
		else:
			result += "_"
	if result.is_empty():
		return "map"
	return result


static func _add_owned(parent: Node, child: Node, root: Node) -> void:
	parent.add_child(child)
	child.owner = root


static func _add_background(root: Node2D, data) -> void:
	var sky := Polygon2D.new()
	sky.name = "SkyBackground"
	sky.z_index = -100
	sky.color = Color(0.63, 0.82, 0.87)
	var top := -2200.0
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

	var points := SS2D_Point_Array.new()
	points.begin_update()
	for position in data.ground_points:
		points.add_point_direct(position)
	var bottom_y: float = data.base_y + data.fill_depth_px
	points.add_point_direct(Vector2(float(data.width_px), bottom_y))
	points.add_point_direct(Vector2(0.0, bottom_y))
	points.close_shape()
	points.end_update()
	shape.set_point_array(points)

	var material := SS2D_Material_Shape.new()
	var noise := FastNoiseLite.new()
	noise.seed = data.seed + 579
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.10
	var fill := NoiseTexture2D.new()
	fill.width = 256
	fill.height = 256
	fill.noise = noise
	fill.seamless = true
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.14, 0.31, 0.18),
		Color(0.23, 0.43, 0.25),
		Color(0.34, 0.53, 0.30)
	])
	fill.color_ramp = ramp
	var fill_array: Array[Texture2D] = [fill]
	material.fill_textures = fill_array
	material.fill_texture_scale = 1.0
	material.fill_texture_show_behind_parent = true

	var edge_tex := load(EDGE_TEXTURE) as Texture2D
	if edge_tex != null:
		var edge := SS2D_Material_Edge.new()
		var edge_array: Array[Texture2D] = [edge_tex]
		edge.textures = edge_array
		var meta := SS2D_Material_Edge_Metadata.new()
		meta.edge_material = edge
		meta.normal_range = SS2D_NormalRange.new(0.0, 180.0)
		material.add_edge_material(meta)
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
	# Store collision in the scene now; SmartShape can regenerate it when edited.
	var solid_polygon := data.ground_points.duplicate()
	solid_polygon.append(Vector2(float(data.width_px), bottom_y))
	solid_polygon.append(Vector2(0.0, bottom_y))
	polygon.polygon = solid_polygon
	_add_owned(body, polygon, root)
	shape.collision_polygon_node_path = NodePath("../GroundCollision/SolidGround")


static func _add_environment(root: Node2D, data) -> void:
	var environment := Node2D.new()
	environment.name = "Environment"
	_add_owned(root, environment, root)
	var rng := RandomNumberGenerator.new()
	rng.seed = (data.seed + 31213) & 0x7fffffff

	var tree_index := 0
	for point in data.tree_points:
		tree_index += 1
		var tree := Node2D.new()
		tree.name = "Tree_%03d" % tree_index
		tree.position = point
		_add_owned(environment, tree, root)
		var height := rng.randf_range(90.0, 160.0)
		var width := rng.randf_range(8.0, 14.0)
		_polygon(tree, root, "Trunk", PackedVector2Array([
			Vector2(-width, 0.0), Vector2(-width * 0.8, -height),
			Vector2(width * 0.8, -height), Vector2(width, 0.0)
		]), Color(0.29, 0.23, 0.17), -8)
		var crown := rng.randf_range(38.0, 57.0)
		_polygon(tree, root, "Leaves", PackedVector2Array([
			Vector2(-crown, -height + 14.0),
			Vector2(-crown * 0.75, -height - crown * 0.75),
			Vector2(-crown * 0.15, -height - crown * 1.2),
			Vector2(crown * 0.55, -height - crown * 0.95),
			Vector2(crown, -height - crown * 0.3),
			Vector2(crown * 0.85, -height + 15.0)
		]), Color(0.16 + rng.randf_range(0.0, 0.08), 0.39, 0.23), -7)

	var rock_index := 0
	for point in data.rock_points:
		rock_index += 1
		var rock := Node2D.new()
		rock.name = "Rock_%03d" % rock_index
		rock.position = point
		_add_owned(environment, rock, root)
		var radius := rng.randf_range(10.0, 26.0)
		_polygon(rock, root, "Stone", PackedVector2Array([
			Vector2(-radius, 0.0),
			Vector2(-radius * 0.85, -radius * 0.65),
			Vector2(-radius * 0.2, -radius * 1.10),
			Vector2(radius * 0.65, -radius * 0.9),
			Vector2(radius, 0.0)
		]), Color(0.40, 0.47, 0.45), -2)


static func _polygon(parent: Node, root: Node, name: String, verts: PackedVector2Array, color: Color, z: int) -> void:
	var polygon := Polygon2D.new()
	polygon.name = name
	polygon.color = color
	polygon.polygon = verts
	polygon.z_index = z
	_add_owned(parent, polygon, root)


static func _add_spawns(root: Node2D, data) -> void:
	var points := Node2D.new()
	points.name = "SpawnPoints"
	_add_owned(root, points, root)
	var left := Marker2D.new()
	left.name = "Entrance_A"
	left.position = Vector2(100.0, data.ground_y_at(100.0) - 40.0)
	_add_owned(points, left, root)
	var right := Marker2D.new()
	right.name = "Entrance_B"
	right.position = Vector2(float(data.width_px) - 100.0, data.ground_y_at(float(data.width_px) - 100.0) - 40.0)
	_add_owned(points, right, root)
