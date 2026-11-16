@tool
extends Resource

# Authoring data is independent of the renderer. Saved as .tres beside a baked scene.
@export var map_name: String = "Grassland_AB"
@export var seed: int = 12345
@export var width_px: int = 8000
@export var sample_step_px: int = 64
@export var base_y: float = 280.0
@export var hill_amplitude: float = 110.0
@export var hill_span_px: float = 1800.0
@export var fill_depth_px: float = 1800.0
@export var trees_per_km: float = 6.0
@export var rocks_per_km: float = 9.0

@export var ground_points: PackedVector2Array = PackedVector2Array()
@export var tree_points: PackedVector2Array = PackedVector2Array()
@export var rock_points: PackedVector2Array = PackedVector2Array()


func ground_y_at(x: float) -> float:
	if ground_points.is_empty():
		return base_y
	var clamped_x := clampf(x, 0.0, float(width_px))
	var left := mini(int(floor(clamped_x / float(sample_step_px))), ground_points.size() - 2)
	left = maxi(left, 0)
	var a := ground_points[left]
	var b := ground_points[left + 1]
	return lerpf(a.y, b.y, clampf((clamped_x - a.x) / maxf(b.x - a.x, 0.001), 0.0, 1.0))
