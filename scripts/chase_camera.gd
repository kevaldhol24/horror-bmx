class_name ChaseCamera
extends Camera3D
## Third-person follow camera with speed FOV, roll, trauma shake and a slow
## orbit mode for the title screen.

var target: Player
var mode := "orbit"        # "orbit" | "chase" | "crash"
var trauma := 0.0
var _orbit := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0
var _look := Vector3.ZERO
var _roll := 0.0

func _ready() -> void:
	_noise.frequency = 2.2
	fov = 56.0
	near = 0.08
	far = 400.0

func add_trauma(a: float) -> void:
	trauma = clampf(trauma + a, 0.0, 1.0)

func snap() -> void:
	_update(1.0, true)

func _process(delta: float) -> void:
	_t += delta
	_update(delta, false)

func _update(delta: float, instant: bool) -> void:
	if target == null:
		return
	var tp := target.global_position
	var b := RoadPath.basis_at(target.s)
	var fwd := -b.z
	var want_pos: Vector3
	var want_look: Vector3
	var want_fov := 56.0
	match mode:
		"orbit":
			_orbit += delta * 0.16
			var ang := 2.4 + sin(_orbit) * 0.9
			var off := (b.x * sin(ang) + b.z * cos(ang)) * 4.1 + Vector3.UP * 1.25
			want_pos = tp + off
			want_look = tp + Vector3.UP * 0.75
			want_fov = 44.0
		"chase":
			var sp := clampf(target.speed / Player.MAX_CRUISE, 0.0, 1.0)
			var back := lerpf(3.7, 4.6, sp)
			want_pos = tp - fwd * back + Vector3.UP * lerpf(1.75, 1.95, sp) + b.x * target.lat_vel * -0.08
			want_look = tp + fwd * 4.0 + Vector3.UP * 0.9
			want_fov = lerpf(56.0, 66.0, sp)
		"crash":
			want_pos = global_position.lerp(tp - fwd * 4.5 + Vector3.UP * 2.6, delta * 0.8)
			want_look = tp + Vector3.UP * 0.4
			want_fov = 55.0
	# Keep the camera above the ground.
	var cam_s := target.s - (want_pos - tp).dot(fwd)
	var g := RoadPath.ground_height(cam_s, target.lat) + 0.5
	want_pos.y = maxf(want_pos.y, g)
	var k := 1.0 if instant else 1.0 - exp(-(9.0 if mode == "chase" else 3.0) * delta)
	global_position = global_position.lerp(want_pos, k)
	_look = want_look if instant else _look.lerp(want_look, 1.0 - exp(-12.0 * delta))
	fov = lerpf(fov, want_fov, 1.0 if instant else 1.0 - exp(-3.0 * delta))
	look_at(_look, Vector3.UP)
	# Roll with the lean, plus trauma shake.
	var want_roll := target.lean * 0.35 if mode == "chase" else 0.0
	_roll = lerpf(_roll, want_roll, 1.0 - exp(-5.0 * delta))
	trauma = maxf(0.0, trauma - delta * 1.4)
	var sh := trauma * trauma
	var rough := 0.18 if target.rough_t > 0.0 else 0.0
	sh = maxf(sh, rough * 0.4)
	rotate_object_local(Vector3.FORWARD, _roll + _noise.get_noise_2d(_t * 40.0, 3.0) * 0.06 * sh)
	rotate_object_local(Vector3.RIGHT, _noise.get_noise_2d(_t * 40.0, 11.0) * 0.08 * sh)
	rotate_object_local(Vector3.UP, _noise.get_noise_2d(_t * 40.0, 23.0) * 0.08 * sh)
