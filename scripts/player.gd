class_name Player
extends Node3D
## Arcade BMX controller. The bike lives in road coordinates (s = distance,
## lat = lateral offset, air = height above ground); no physics engine.

signal crashed(reason: String)
signal hopped
signal landed(impact: float)

const START_SPEED := 7.5
const MAX_CRUISE := 15.5
const ACCEL := 2.6
const BRAKE_DECEL := 9.0
const GRAVITY := 16.0
const HOP_VEL := 4.6
const BIKE_HALF_W := 0.28

var s := 0.0
var lat := 0.0
var speed := 0.0
var air := 0.0
var vy := 0.0
var steer_in := 0.0           # raw input -1..1
var brake_in := false
var active := false           # true while riding
var is_crashed := false
var rough_t := 0.0            # >0 while rattling over broken road
var lean := 0.0
var lat_vel := 0.0
var pitch := 0.0

var model: BikeModel
var headlight: SpotLight3D
var rim: OmniLight3D

var _steer := 0.0
var _crash_t := 0.0
var _crash_spin := Vector3.ZERO
var _crash_rot := Vector3.ZERO
var _crash_vel := Vector3.ZERO
var _crash_pos := Vector3.ZERO
var _crash_up := 0.0

func _ready() -> void:
	model = BikeModel.new()
	model.name = "Model"
	model.rotation.y = PI  # model is +Z forward; this node is -Z forward
	add_child(model)
	headlight = SpotLight3D.new()
	headlight.light_color = Color(1.0, 0.93, 0.78)
	headlight.light_energy = 11.0
	headlight.spot_range = 42.0
	headlight.spot_angle = 31.0
	headlight.spot_angle_attenuation = 0.8
	headlight.spot_attenuation = 0.9
	headlight.shadow_enabled = false  # the rift light casts the (visible) shadow
	headlight.shadow_bias = 0.05
	model.get_lamp_anchor().add_child(headlight)
	headlight.basis = Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -0.075)
	# A dim crimson rim light so the rider separates from the dark.
	rim = OmniLight3D.new()
	rim.light_color = Color(1.0, 0.72, 0.55)
	rim.light_energy = 2.2
	rim.omni_range = 4.5
	rim.omni_attenuation = 1.6
	rim.light_specular = 0.0  # no hot spot on the wet road
	rim.position = Vector3(0.6, 2.2, 1.9)
	add_child(rim)

func reset_to_start() -> void:
	s = 2.0
	lat = 1.6
	speed = 0.0
	air = 0.0
	vy = 0.0
	lat_vel = 0.0
	_steer = 0.0
	lean = 0.0
	pitch = 0.0
	is_crashed = false
	active = false
	rough_t = 0.0
	model.rotation = Vector3(0, PI, 0)
	model.position = Vector3.ZERO
	_place()

func cruise_target() -> float:
	return minf(START_SPEED + s / 260.0, MAX_CRUISE)

func is_airborne() -> bool:
	return air > 0.02

func try_hop() -> void:
	if active and not is_crashed and not is_airborne():
		vy = HOP_VEL
		air = 0.03
		hopped.emit()

func launch(v: float) -> void:
	if not is_airborne():
		vy = maxf(vy, v)
		air = 0.03
		hopped.emit()

func crash(reason: String) -> void:
	if is_crashed:
		return
	is_crashed = true
	active = false
	_crash_t = 0.0
	_crash_pos = global_position
	var fwd := -global_basis.z
	_crash_vel = fwd * speed * 0.55 + Vector3.UP * (2.8 + speed * 0.12) + global_basis.x * lat_vel * 0.6
	_crash_spin = Vector3(randf_range(6.0, 9.0), randf_range(-3.0, 3.0), randf_range(-4.0, 4.0) + lean * 4.0)
	_crash_rot = Vector3.ZERO
	crashed.emit(reason)

func _physics_process(delta: float) -> void:
	if is_crashed:
		_tumble(delta)
		return
	if active:
		var target := cruise_target()
		var off_road := absf(lat) > RoadPath.ROAD_HALF_WIDTH
		if off_road:
			target = minf(target, 6.0)
		if rough_t > 0.0:
			target = minf(target, 6.5)
		if brake_in and not is_airborne():
			speed = move_toward(speed, 0.0, BRAKE_DECEL * delta)
		elif is_airborne():
			speed = move_toward(speed, speed * 0.995, delta)
		else:
			var a := ACCEL if speed < target else ACCEL * 2.2
			speed = move_toward(speed, target, a * delta)
	else:
		speed = move_toward(speed, 0.0, 6.0 * delta)
	rough_t = maxf(0.0, rough_t - delta)
	# Steering: smoothed input -> lateral velocity. Less control in the air.
	var resp := 9.0 if not is_airborne() else 2.5
	_steer = lerpf(_steer, steer_in if active else 0.0, 1.0 - exp(-resp * delta))
	var steer_rate := 2.6 + speed * 0.27
	lat_vel = _steer * steer_rate * (0.55 if is_airborne() else 1.0)
	lat += lat_vel * delta
	if absf(lat) > RoadPath.RIDE_LIMIT:
		lat = clampf(lat, -RoadPath.RIDE_LIMIT, RoadPath.RIDE_LIMIT)
		lat_vel = 0.0
	s += speed * delta
	# Vertical.
	if air > 0.0 or vy > 0.0:
		vy -= GRAVITY * delta
		air += vy * delta
		if air <= 0.0:
			air = 0.0
			var impact := -vy
			vy = 0.0
			landed.emit(impact)
	lean = lerpf(lean, _steer * clampf(speed / 8.0, 0.3, 1.0) * 0.38, 1.0 - exp(-6.0 * delta))
	pitch = lerpf(pitch, clampf(vy * 0.05, -0.25, 0.25) if is_airborne() else 0.0, 1.0 - exp(-5.0 * delta))
	_place()
	_animate(delta)

func _place() -> void:
	var p := RoadPath.point(s, lat)
	p.y = RoadPath.ground_height(s, lat) + air
	var b := RoadPath.basis_at(s)
	var yaw := -atan2(lat_vel, maxf(speed, 2.0)) * 0.9
	var shake := Vector3.ZERO
	if rough_t > 0.0 and not is_airborne():
		shake = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.03
	global_transform = Transform3D(b * Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, lean) * Basis(Vector3.RIGHT, pitch), p)
	model.rotation = Vector3(shake.x, PI + shake.y, shake.z)

func _animate(delta: float) -> void:
	model.wheel_angle += speed / BikeModel.WHEEL_R * delta
	var pedaling := active and not is_airborne() and not brake_in
	var crank_rate := speed / BikeModel.WHEEL_R / 2.3 if pedaling else 0.0
	model.crank_angle += crank_rate * delta
	var want_effort := 0.0
	if pedaling and speed < cruise_target() - 1.5:
		want_effort = 1.0
	if is_airborne():
		want_effort = 0.7  # stand up over jumps
	if rough_t > 0.0:
		want_effort = 0.8
	model.effort = lerpf(model.effort, want_effort, 1.0 - exp(-4.0 * delta))
	model.steer = _steer * 0.6
	model.bob = sin(model.crank_angle * 2.0) * 0.008 * (1.0 if pedaling else 0.0)

func _tumble(delta: float) -> void:
	_crash_t += delta
	_crash_vel.y -= GRAVITY * delta
	_crash_pos += _crash_vel * delta
	var cs := s
	# Ground under the tumbling bike (approximate along road).
	var gy := RoadPath.ground_height(cs, lat)
	if _crash_pos.y < gy + 0.25:
		_crash_pos.y = gy + 0.25
		_crash_vel.y = absf(_crash_vel.y) * 0.25
		_crash_vel.x *= 0.6
		_crash_vel.z *= 0.6
		_crash_spin *= 0.55
	_crash_rot += _crash_spin * delta
	# Settle on its side.
	if _crash_t > 1.6:
		_crash_spin = _crash_spin.lerp(Vector3.ZERO, delta * 3.0)
		_crash_rot.z = lerp_angle(_crash_rot.z, PI * 0.5 * signf(_crash_rot.z + 0.001), delta * 2.0)
		_crash_rot.x = lerp_angle(_crash_rot.x, 0.0, delta * 2.0)
	var b := RoadPath.basis_at(s)
	global_transform = Transform3D(b * Basis.from_euler(_crash_rot), _crash_pos)
	speed = _crash_vel.length()
	model.wheel_angle += 18.0 * delta * maxf(0.0, 1.0 - _crash_t * 0.3)
	model.effort = 0.0
