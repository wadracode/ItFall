@tool
extends RefCounted

const TerrainData = preload("res://addons/itfall_map_editor/terrain_data.gd")


static func create(settings: Dictionary) -> Resource:
	var data = TerrainData.new()
	data.map_name = str(settings.get("map_name", "Grassland_AB"))
	data.seed = int(settings.get("seed", 12345))
	data.width_px = clampi(int(settings.get("width_px", 8000)), 1024, 30000)
	data.sample_step_px = clampi(int(settings.get("sample_step_px", 64)), 32, 256)
	data.base_y = float(settings.get("base_y", 280.0))
	data.hill_amplitude = clampf(float(settings.get("hill_amplitude", 110.0)), 0.0, 550.0)
	data.hill_span_px = clampf(float(settings.get("hill_span_px", 1800.0)), 250.0, 8000.0)
	data.fill_depth_px = clampf(float(settings.get("fill_depth_px", 1800.0)), 900.0, 4000.0)
	data.trees_per_km = clampf(float(settings.get("trees_per_km", 6.0)), 0.0, 30.0)
	data.rocks_per_km = clampf(float(settings.get("rocks_per_km", 9.0)), 0.0, 30.0)

	var hills := FastNoiseLite.new()
	hills.seed = data.seed
	hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hills.frequency = 1.0 / data.hill_span_px
	var detail := FastNoiseLite.new()
	detail.seed = data.seed + 9176
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail.frequency = 1.0 / (data.hill_span_px * 0.30)

	# Both ends return to base_y with flat slopes, ready for a later map graph.
	var segments := int(ceil(float(data.width_px) / float(data.sample_step_px)))
	for i in range(segments + 1):
		var x := minf(float(i * data.sample_step_px), float(data.width_px))
		var border_weight := clampf(minf(x, float(data.width_px) - x) / 500.0, 0.0, 1.0)
		border_weight = border_weight * border_weight * (3.0 - 2.0 * border_weight)
		var noise_value := hills.get_noise_1d(x) + detail.get_noise_1d(x) * 0.18
		data.ground_points.append(Vector2(x, data.base_y + noise_value * data.hill_amplitude * border_weight))

	regenerate_props(data)
	return data


static func regenerate_props(data) -> void:
	if data == null or data.ground_points.size() < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = (data.seed + 41279) & 0x7fffffff
	data.tree_points = PackedVector2Array()
	data.rock_points = PackedVector2Array()
	var tree_count := int(round(float(data.width_px) / 1000.0 * data.trees_per_km))
	var rock_count := int(round(float(data.width_px) / 1000.0 * data.rocks_per_km))
	for i in range(tree_count):
		var x := rng.randf_range(180.0, float(data.width_px) - 180.0)
		data.tree_points.append(Vector2(x, data.ground_y_at(x)))
	for i in range(rock_count):
		var x := rng.randf_range(80.0, float(data.width_px) - 80.0)
		data.rock_points.append(Vector2(x, data.ground_y_at(x)))
