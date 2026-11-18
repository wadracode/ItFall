@tool
extends Resource

# Editable Pen Tool source. SmartShape2D receives sampled ground_points only at bake time.
# Existing v0.2 resources remain loadable and are migrated on first open.
@export var map_name: String = "Grassland_AB"
@export var width_px: int = 8000
@export var base_y: float = 280.0
@export var fill_depth_px: float = 1800.0

@export var anchors: PackedVector2Array = PackedVector2Array()
@export var handles_in: PackedVector2Array = PackedVector2Array()
@export var handles_out: PackedVector2Array = PackedVector2Array()
@export var ground_points: PackedVector2Array = PackedVector2Array()

# Legacy fields: keep old .tres data compatible; the Pen Tool workflow never reads these.
@export var seed: int = 12345
@export var sample_step_px: int = 64
@export var hill_amplitude: float = 110.0
@export var hill_span_px: float = 1800.0
@export var trees_per_km: float = 6.0
@export var rocks_per_km: float = 9.0
@export var tree_points: PackedVector2Array = PackedVector2Array()
@export var rock_points: PackedVector2Array = PackedVector2Array()

const MIN_ANCHOR_SPACING := 24.0
const BAKE_STEP := 12.0


func create_flat(map_width: int, ground_y: float) -> void:
	width_px = clampi(map_width, 512, 100000)
	base_y = ground_y
	anchors = PackedVector2Array([Vector2(0.0, ground_y), Vector2(float(width_px), ground_y)])
	handles_in = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	handles_out = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	tree_points = PackedVector2Array()
	rock_points = PackedVector2Array()
	rebuild()


func ensure_editable() -> void:
	if anchors.size() >= 2 and handles_in.size() == anchors.size() and handles_out.size() == anchors.size():
		rebuild()
		return
	# Older terrain sources stored only sampled points; retain their exact profile
	# as corner anchors (no data loss on opening the legacy resource).
	if ground_points.size() >= 2:
		anchors = ground_points.duplicate()
		width_px = int(round(anchors[-1].x))
		handles_in = PackedVector2Array()
		handles_out = PackedVector2Array()
		for i in range(anchors.size()):
			handles_in.append(Vector2.ZERO)
			handles_out.append(Vector2.ZERO)
		rebuild()
		return
	create_flat(width_px, base_y)


func insert_anchor(world: Vector2) -> int:
	if anchors.size() < 2:
		return -1
	for i in range(1, anchors.size()):
		if world.x < anchors[i].x:
			if world.x - anchors[i - 1].x < MIN_ANCHOR_SPACING:
				return -1
			if anchors[i].x - world.x < MIN_ANCHOR_SPACING:
				return -1
			anchors.insert(i, world)
			handles_in.insert(i, Vector2.ZERO)
			handles_out.insert(i, Vector2.ZERO)
			rebuild()
			return i
	return -1


func move_anchor(index: int, world: Vector2) -> void:
	if index < 0 or index >= anchors.size():
		return
	if index == 0:
		world.x = 0.0
	elif index == anchors.size() - 1:
		world.x = float(width_px)
	else:
		world.x = clampf(world.x, anchors[index - 1].x + MIN_ANCHOR_SPACING, anchors[index + 1].x - MIN_ANCHOR_SPACING)
	anchors[index] = world
	_limit_all_handles()
	rebuild()


func set_handle(index: int, outgoing: bool, world: Vector2, mirror: bool = true) -> void:
	if index < 0 or index >= anchors.size():
		return
	# Endpoint tangents only exist toward the interior of the terrain.
	if (index == 0 and not outgoing) or (index == anchors.size() - 1 and outgoing):
		return
	var relative: Vector2 = world - anchors[index]
	var max_x := _max_handle_x(index, outgoing)
	if mirror and index > 0 and index < anchors.size() - 1:
		max_x = minf(max_x, _max_handle_x(index, not outgoing))
	if outgoing:
		relative.x = clampf(relative.x, 0.0, max_x)
	else:
		relative.x = clampf(relative.x, -max_x, 0.0)
	relative.y = clampf(relative.y, -4000.0, 4000.0)
	if outgoing:
		handles_out[index] = relative
		if mirror and index > 0:
			handles_in[index] = -relative
	else:
		handles_in[index] = relative
		if mirror and index < anchors.size() - 1:
			handles_out[index] = -relative
	rebuild()


func delete_anchor(index: int) -> bool:
	if index <= 0 or index >= anchors.size() - 1:
		return false
	anchors.remove_at(index)
	handles_in.remove_at(index)
	handles_out.remove_at(index)
	_limit_all_handles()
	rebuild()
	return true


func _max_handle_x(index: int, outgoing: bool) -> float:
	if outgoing:
		if index >= anchors.size() - 1:
			return 0.0
		return maxf(0.0, (anchors[index + 1].x - anchors[index].x) * 0.45)
	if index <= 0:
		return 0.0
	return maxf(0.0, (anchors[index].x - anchors[index - 1].x) * 0.45)


func _limit_all_handles() -> void:
	for i in range(anchors.size()):
		var incoming: Vector2 = handles_in[i]
		var outgoing: Vector2 = handles_out[i]
		incoming.x = clampf(incoming.x, -_max_handle_x(i, false), 0.0)
		outgoing.x = clampf(outgoing.x, 0.0, _max_handle_x(i, true))
		handles_in[i] = incoming
		handles_out[i] = outgoing


func rebuild() -> void:
	var samples := PackedVector2Array()
	if anchors.size() < 2:
		ground_points = samples
		return
	samples.append(anchors[0])
	for i in range(anchors.size() - 1):
		var a: Vector2 = anchors[i]
		var d: Vector2 = anchors[i + 1]
		var b: Vector2 = a + handles_out[i]
		var c: Vector2 = d + handles_in[i + 1]
		var count: int = maxi(2, int(ceil((d.x - a.x) / BAKE_STEP)))
		for step in range(1, count + 1):
			var t: float = float(step) / float(count)
			var u: float = 1.0 - t
			var p: Vector2 = u * u * u * a + 3.0 * u * u * t * b + 3.0 * u * t * t * c + t * t * t * d
			# Handles are constrained to monotonically increase X, so the
			# interpolated height can be searched efficiently by world X.
			if p.x > samples[-1].x + 0.00001:
				samples.append(p)
	ground_points = samples


func ground_y_at(x: float) -> float:
	if ground_points.is_empty():
		return base_y
	if ground_points.size() == 1:
		return ground_points[0].y
	var query_x: float = clampf(x, ground_points[0].x, ground_points[-1].x)
	var left := 0
	var right := ground_points.size() - 1
	while right - left > 1:
		var middle := (left + right) / 2
		if ground_points[middle].x < query_x:
			left = middle
		else:
			right = middle
	var a: Vector2 = ground_points[left]
	var b: Vector2 = ground_points[right]
	return lerpf(a.y, b.y, clampf((query_x - a.x) / maxf(0.0001, b.x - a.x), 0.0, 1.0))
