extends RefCounted
## Keep close combat large while retaining every live fighter in wider fights.
static func frame(player_x: float, enemy_positions: Array, aspect: float) -> Dictionary:
	var left := player_x
	var right := player_x
	for value in enemy_positions:
		left = minf(left, float(value))
		right = maxf(right, float(value))
	var mid := (left + right) * 0.5
	# Includes long hair, attack extension, and a small lens-punch safety margin.
	var half := (right - left) * 0.5 + 1.85
	var distance := maxf(9.7, half / (tan(deg_to_rad(16.1)) * maxf(aspect, 0.35)))
	return {"position":Vector3(mid, 2.65, distance), "target":Vector3(mid, 1.48, 0), "fov":34.0, "roll":0.0, "shot":"battle"}
