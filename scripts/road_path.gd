class_name RoadPath
extends RefCounted
## The endless road is a pure function of distance `s` (metres travelled).
## World position of the road centre at distance s:  (center_x(s), height(s), -s).
## Everything (terrain, props, bike, camera) samples these functions, so there is
## no spline data to stream — chunks can be generated in any order.

const ROAD_HALF_WIDTH := 3.6      # asphalt half width (m)
const SHOULDER := 2.2             # gravel shoulder beyond asphalt (m)
const RIDE_LIMIT := ROAD_HALF_WIDTH + SHOULDER - 0.4

static func center_x(s: float) -> float:
	# Gentle, non-repeating curves (sum of incommensurate sines).
	return 14.0 * sin(s * 0.0071) + 7.0 * sin(s * 0.0173 + 1.3) + 3.0 * sin(s * 0.041 + 0.4)

static func height(s: float) -> float:
	return 2.2 * sin(s * 0.0093 + 0.7) + 1.1 * sin(s * 0.023 + 2.1)

static func dx_ds(s: float) -> float:
	return 14.0 * 0.0071 * cos(s * 0.0071) + 7.0 * 0.0173 * cos(s * 0.0173 + 1.3) + 3.0 * 0.041 * cos(s * 0.041 + 0.4)

static func dy_ds(s: float) -> float:
	return 2.2 * 0.0093 * cos(s * 0.0093 + 0.7) + 1.1 * 0.023 * cos(s * 0.023 + 2.1)

## Unit forward direction of the road (in world space) at s.
static func forward(s: float) -> Vector3:
	return Vector3(dx_ds(s), dy_ds(s), -1.0).normalized()

## Unit right vector (horizontal, perpendicular to forward).
static func right(s: float) -> Vector3:
	var f := Vector3(dx_ds(s), 0.0, -1.0).normalized()
	return Vector3(-f.z, 0.0, f.x)

## World point at distance s and lateral offset `lat` (+ = right of centre).
static func point(s: float, lat: float) -> Vector3:
	var r := right(s)
	return Vector3(center_x(s), height(s), -s) + r * lat

## Terrain height away from the road: road height blended into rolling hills.
static func ground_height(s: float, lat: float) -> float:
	var base := height(s)
	var a := absf(lat)
	var edge := ROAD_HALF_WIDTH + SHOULDER
	if a <= edge:
		return base - 0.02 * maxf(0.0, a - ROAD_HALF_WIDTH)
	var t := clampf((a - edge) / 30.0, 0.0, 1.0)
	var px := Vector3(center_x(s), 0, -s) + right(s) * lat
	var hills := 2.5 * sin(px.x * 0.05 + px.z * 0.031) + 1.6 * sin(px.x * 0.11 - px.z * 0.07)
	# Shallow ditch right next to the shoulder, then hills.
	var ditch := -0.35 * sin(clampf((a - edge) / 4.0, 0.0, 1.0) * PI)
	return base - 0.04 + ditch + t * t * (hills + 1.0)

## Transform that sits on the road at (s, lat) facing along the road.
static func basis_at(s: float) -> Basis:
	var f := forward(s)
	var up := Vector3.UP
	var r := f.cross(up).normalized()
	up = r.cross(f).normalized()
	return Basis(r, up, -f)
