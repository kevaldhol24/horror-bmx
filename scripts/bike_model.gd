class_name BikeModel
extends Node3D
## Procedural BMX + a faceless hooded kid, posed every frame with analytic
## two-bone IK (legs follow the pedals, hands stay on the steered grips, torso
## leans and rises out of the saddle with effort).
## Local space: +Z forward, +Y up, +X = rider's left.

# Geometry (metres).
const WHEEL_R := 0.24
const REAR_AXLE := Vector3(0, WHEEL_R, -0.44)
const FRONT_AXLE := Vector3(0, WHEEL_R, 0.47)
const BB := Vector3(0, 0.29, -0.03)
const CRANK := 0.085
const PEDAL_X := 0.135
const SEAT_TOP := Vector3(0, 0.6, -0.2)
const SEAT_CLUSTER := Vector3(0, 0.455, -0.17)
const HEAD_TOP := Vector3(0, 0.58, 0.33)
const HEAD_BOT := Vector3(0, 0.46, 0.365)
const HIP_SEATED := Vector3(0, 0.665, -0.2)
const HIP_STANDING := Vector3(0, 0.83, -0.07)
const GRIP := Vector3(0.235, 0.83, 0.285)

var crank_angle := 0.0
var wheel_angle := 0.0
var steer := 0.0          # -1..1 visual handlebar turn
var effort := 0.0         # 0..1, more = stand on pedals / lean
var bob := 0.0
var headlight_on := true

var _front: Node3D
var _wheel_f: Node3D
var _wheel_r: Node3D
var _crankset: Node3D
var _pedal_l: Node3D
var _pedal_r: Node3D
var _rider: Node3D
var _parts := {}
var _crash_pose := 0.0
var lamp_mat: StandardMaterial3D

var mat_frame: StandardMaterial3D
var mat_chrome: StandardMaterial3D
var mat_tire: StandardMaterial3D
var mat_black: StandardMaterial3D

func _ready() -> void:
	_make_materials()
	_build_frame()
	_build_front()
	_wheel_r = _build_wheel(REAR_AXLE)
	add_child(_wheel_r)
	_build_drivetrain()
	_build_rider()

# ---------------------------------------------------------------- building

func _make_materials() -> void:
	mat_frame = StandardMaterial3D.new()
	mat_frame.albedo_color = Color(0.62, 0.04, 0.05)
	mat_frame.metallic = 0.55
	mat_frame.roughness = 0.32
	mat_chrome = StandardMaterial3D.new()
	mat_chrome.albedo_color = Color(0.75, 0.75, 0.78)
	mat_chrome.metallic = 1.0
	mat_chrome.roughness = 0.22
	mat_tire = StandardMaterial3D.new()
	mat_tire.albedo_color = Color(0.035, 0.032, 0.03)
	mat_tire.roughness = 0.92
	mat_black = StandardMaterial3D.new()
	mat_black.albedo_color = Color(0.06, 0.055, 0.055)
	mat_black.roughness = 0.6
	lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1, 0.95, 0.8)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1, 0.9, 0.7)
	lamp_mat.emission_energy_multiplier = 6.0

func _tube(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material, sides := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b)
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	var dir := (b - a).normalized()
	var up_ref := Vector3.FORWARD if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x := dir.cross(up_ref).normalized()
	var z := x.cross(dir).normalized()
	mi.transform = Transform3D(Basis(x, dir, z), (a + b) * 0.5)
	parent.add_child(mi)
	return mi

func _box(parent: Node3D, center: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _build_frame() -> void:
	var frame := Node3D.new()
	frame.name = "Frame"
	add_child(frame)
	var top_front := HEAD_TOP.lerp(HEAD_BOT, 0.25)
	_tube(frame, HEAD_TOP, HEAD_BOT, 0.024, mat_frame)            # head tube
	_tube(frame, top_front, SEAT_CLUSTER, 0.018, mat_frame)       # top tube
	_tube(frame, HEAD_BOT.lerp(HEAD_TOP, 0.15), BB, 0.021, mat_frame)  # down tube
	_tube(frame, BB, SEAT_CLUSTER, 0.019, mat_frame)              # seat tube
	# Gusset between top & down tube.
	_tube(frame, top_front.lerp(SEAT_CLUSTER, 0.2), HEAD_BOT.lerp(BB, 0.18), 0.012, mat_frame)
	for sx in [-1.0, 1.0]:
		var ax := REAR_AXLE + Vector3(0.055 * sx, 0, 0)
		_tube(frame, BB + Vector3(0.025 * sx, 0, 0), ax, 0.012, mat_frame)        # chain stay
		_tube(frame, SEAT_CLUSTER + Vector3(0.02 * sx, -0.02, 0), ax, 0.011, mat_frame)  # seat stay
		# Rear pegs (BMX!)
		_tube(frame, ax, ax + Vector3(0.09 * sx, 0, 0), 0.02, mat_chrome)
	# Seat post + seat.
	_tube(frame, SEAT_CLUSTER, SEAT_TOP + Vector3(0, -0.02, 0.01), 0.012, mat_chrome)
	var seat := _box(frame, SEAT_TOP + Vector3(0, 0.012, 0.01), Vector3(0.085, 0.035, 0.24), mat_black, Vector3(deg_to_rad(-6), 0, 0))
	seat.name = "Seat"
	# Rear reflector.
	var refl := StandardMaterial3D.new()
	refl.albedo_color = Color(0.6, 0.0, 0.0)
	refl.emission_enabled = true
	refl.emission = Color(1, 0.05, 0.02)
	refl.emission_energy_multiplier = 2.5
	_box(frame, SEAT_TOP + Vector3(0, -0.06, -0.14), Vector3(0.05, 0.03, 0.012), refl)

func _build_front() -> void:
	# Everything that turns with the handlebars pivots around the head tube axis.
	_front = Node3D.new()
	_front.name = "Front"
	add_child(_front)
	_front.position = HEAD_BOT
	var axis_up := (HEAD_TOP - HEAD_BOT).normalized()
	var local_axle := FRONT_AXLE - HEAD_BOT
	var crown := Vector3(0, -0.02, 0)
	for sx in [-1.0, 1.0]:
		_tube(_front, crown + Vector3(0.05 * sx, 0, 0), local_axle + Vector3(0.05 * sx, 0, 0), 0.013, mat_chrome)
		_tube(_front, local_axle + Vector3(0.05 * sx, 0, 0), local_axle + Vector3(0.12 * sx, 0, 0), 0.02, mat_chrome) # front pegs
	_box(_front, crown, Vector3(0.12, 0.025, 0.04), mat_chrome)
	# Stem + BMX riser bars.
	var stem_top := (HEAD_TOP - HEAD_BOT) + axis_up * 0.06
	_tube(_front, Vector3.ZERO, stem_top, 0.017, mat_chrome)
	var bar_base := stem_top + Vector3(0, 0, -0.02)
	var grip_l := GRIP - HEAD_BOT
	var grip_r := Vector3(-GRIP.x, GRIP.y, GRIP.z) - HEAD_BOT
	for g in [grip_l, grip_r]:
		var sx: float = signf(g.x)
		var up_pt := Vector3(sx * 0.11, g.y, g.z + 0.01)
		_tube(_front, bar_base + Vector3(sx * 0.07, 0, 0), up_pt, 0.009, mat_chrome)
		_tube(_front, up_pt, g + Vector3(sx * 0.06, 0, 0), 0.009, mat_chrome)
		_tube(_front, g - Vector3(sx * 0.04, 0, 0), g + Vector3(sx * 0.065, 0, 0), 0.016, mat_black)
	_tube(_front, bar_base + Vector3(0.075, 0, 0), bar_base + Vector3(-0.075, 0, 0), 0.009, mat_chrome)
	var cross_y := lerpf(bar_base.y, grip_l.y, 0.55)
	_tube(_front, Vector3(0.09, cross_y, grip_l.z + 0.005), Vector3(-0.09, cross_y, grip_l.z + 0.005), 0.007, mat_chrome)
	# Headlamp on the crossbar.
	var lamp_pos := Vector3(0, cross_y - 0.035, grip_l.z + 0.05)
	var housing := _tube(_front, lamp_pos - Vector3(0, 0, 0.04), lamp_pos + Vector3(0, 0, 0.03), 0.04, mat_black, 12)
	housing.name = "LampHousing"
	_tube(_front, lamp_pos + Vector3(0, 0, 0.03), lamp_pos + Vector3(0, 0, 0.036), 0.034, lamp_mat, 12)
	var lamp_anchor := Node3D.new()
	lamp_anchor.name = "LampAnchor"
	lamp_anchor.position = lamp_pos + Vector3(0, 0, 0.05)
	_front.add_child(lamp_anchor)
	# Front wheel.
	_wheel_f = _build_wheel(local_axle)
	_front.add_child(_wheel_f)
	# Tilt the steering axis back like a real head angle.
	_front.set_meta("axis", axis_up)

func get_lamp_anchor() -> Node3D:
	return _front.get_node("LampAnchor")

func _build_wheel(center: Vector3) -> Node3D:
	var w := Node3D.new()
	w.position = center
	var tire := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = WHEEL_R - 0.045
	tm.outer_radius = WHEEL_R
	tm.rings = 28
	tm.ring_segments = 8
	tire.mesh = tm
	tire.material_override = mat_tire
	tire.rotation = Vector3(0, 0, PI * 0.5)
	w.add_child(tire)
	var rim := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = WHEEL_R - 0.058
	rm.outer_radius = WHEEL_R - 0.04
	rm.rings = 24
	rm.ring_segments = 4
	rim.mesh = rm
	rim.material_override = mat_chrome
	rim.rotation = Vector3(0, 0, PI * 0.5)
	w.add_child(rim)
	_tube(w, Vector3(-0.045, 0, 0), Vector3(0.045, 0, 0), 0.022, mat_chrome, 10) # hub
	var spokes := 18
	for i in spokes:
		var a := TAU * float(i) / spokes
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(0, cos(a), sin(a)) * (WHEEL_R - 0.052)
		_tube(w, Vector3(0.03 * side, 0, 0), p, 0.0035, mat_chrome, 4)
	return w

func _build_drivetrain() -> void:
	_crankset = Node3D.new()
	_crankset.position = BB
	add_child(_crankset)
	# Chainring (big BMX sprocket) + chain.
	var ring := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.075
	rc.bottom_radius = 0.075
	rc.height = 0.008
	rc.radial_segments = 20
	ring.mesh = rc
	ring.material_override = mat_chrome
	ring.rotation = Vector3(0, 0, PI * 0.5)
	ring.position = Vector3(-0.05, 0, 0)
	_crankset.add_child(ring)
	var chain_mat := mat_black
	var rear := REAR_AXLE - BB + Vector3(-0.05, 0, 0)
	_tube(self, BB + Vector3(-0.05, 0.072, 0), REAR_AXLE + Vector3(-0.05, 0.03, 0), 0.006, chain_mat, 4)
	_tube(self, BB + Vector3(-0.05, -0.072, 0), REAR_AXLE + Vector3(-0.05, -0.03, 0), 0.006, chain_mat, 4)
	var cog := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = 0.01
	cog.mesh = cm
	cog.material_override = mat_chrome
	cog.rotation = Vector3(0, 0, PI * 0.5)
	cog.position = rear + BB
	add_child(cog)
	_pedal_l = Node3D.new()
	_pedal_r = Node3D.new()
	add_child(_pedal_l)
	add_child(_pedal_r)
	for p in [_pedal_l, _pedal_r]:
		_box(p, Vector3.ZERO, Vector3(0.09, 0.018, 0.075), mat_black)


# ---------------------------------------------------------------- rider

func _mat(c: Color, rough := 0.8, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _capsule(name_: String, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = r * 2.0 + 0.1
	cm.radial_segments = 10
	cm.rings = 3
	mi.mesh = cm
	mi.material_override = mat
	mi.set_meta("r", r)
	_rider.add_child(mi)
	_parts[name_] = mi
	return mi

func _sphere(name_: String, r: float, mat: Material, h := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0 * h
	sm.radial_segments = 14
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat
	_rider.add_child(mi)
	_parts[name_] = mi
	return mi

func _boxpart(name_: String, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	_rider.add_child(mi)
	_parts[name_] = mi
	return mi

func _build_rider() -> void:
	_rider = Node3D.new()
	_rider.name = "Rider"
	add_child(_rider)
	var coat := _mat(Color(0.1, 0.13, 0.25), 0.6)        # navy jacket
	coat.metallic_specular = 0.6
	var coat_dark := _mat(Color(0.07, 0.09, 0.17), 0.65)
	var jeans := _mat(Color(0.2, 0.2, 0.13), 0.85)         # olive cargo pants
	var shoe := _mat(Color(0.88, 0.86, 0.82), 0.6)         # white high-tops
	var sole := _mat(Color(0.75, 0.73, 0.7), 0.7)
	var pack := _mat(Color(0.5, 0.13, 0.08), 0.75)         # rust-red backpack
	var skin := _mat(Color(0.55, 0.38, 0.3), 0.7)
	var void_mat := _mat(Color(0, 0, 0), 1.0, true)
	_capsule("torso", 0.13, coat).set_meta("scale", Vector3(1.12, 1.0, 0.82))
	_capsule("coat_hem", 0.125, coat_dark).set_meta("scale", Vector3(1.2, 1.0, 0.75))
	for s in ["l", "r"]:
		_capsule("thigh_" + s, 0.06, jeans)
		_capsule("shin_" + s, 0.05, jeans)
		_capsule("uarm_" + s, 0.048, coat)
		_capsule("farm_" + s, 0.042, coat)
		_sphere("hand_" + s, 0.042, skin)
		_boxpart("shoe_" + s, Vector3(0.085, 0.07, 0.19), shoe)
		_boxpart("sole_" + s, Vector3(0.088, 0.02, 0.195), sole)
	_sphere("hood", 0.145, coat, 1.08)
	_sphere("face", 0.098, void_mat, 1.1)
	_boxpart("backpack", Vector3(0.25, 0.3, 0.13), pack)
	_boxpart("pack_flap", Vector3(0.26, 0.1, 0.14), _mat(Color(0.36, 0.09, 0.06), 0.8))

func _place_limb(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var r: float = mi.get_meta("r")
	var v := b - a
	var len := maxf(v.length(), 0.001)
	(mi.mesh as CapsuleMesh).height = len + r * 2.0
	var y := v / len
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.UP
	var x := y.cross(ref).normalized()
	var z := x.cross(y)
	var sc: Vector3 = mi.get_meta("scale", Vector3.ONE)
	mi.transform = Transform3D(Basis(x * sc.x, y * sc.y, z * sc.z), (a + b) * 0.5)

func _orient(mi: Node3D, center: Vector3, fwd: Vector3, up: Vector3) -> void:
	var z := fwd.normalized()
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	mi.transform = Transform3D(Basis(x, y, z), center)

static func _solve_knee(a: Vector3, target: Vector3, la: float, lb: float, pole: Vector3) -> Array:
	var to_t := target - a
	var d := clampf(to_t.length(), 0.02, (la + lb) * 0.995)
	var dir := to_t.normalized()
	var cos_a := clampf((la * la + d * d - lb * lb) / (2.0 * la * d), -1.0, 1.0)
	var bend := pole - dir * pole.dot(dir)
	if bend.length_squared() < 1e-6:
		bend = Vector3.FORWARD
	bend = bend.normalized()
	var mid := a + dir * (la * cos_a) + bend * (la * sqrt(maxf(0.0, 1.0 - cos_a * cos_a)))
	return [mid, a + dir * d]

# ---------------------------------------------------------------- animation

func _process(_delta: float) -> void:
	_wheel_f.rotation.x = wheel_angle
	_wheel_r.rotation.x = wheel_angle
	var axis: Vector3 = _front.get_meta("axis")
	_front.basis = Basis(axis, -steer * 0.45)
	_crankset.rotation.x = crank_angle
	var pl := BB + Vector3(PEDAL_X, cos(crank_angle) * CRANK, sin(crank_angle) * CRANK)
	var pr := BB + Vector3(-PEDAL_X, cos(crank_angle + PI) * CRANK, sin(crank_angle + PI) * CRANK)
	_pedal_l.position = pl
	_pedal_r.position = pr
	_pose_rider(pl, pr)

func _pose_rider(pl: Vector3, pr: Vector3) -> void:
	var e := clampf(effort, 0.0, 1.0)
	var pelvis := HIP_SEATED.lerp(HIP_STANDING, e) + Vector3(0, bob, 0)
	# Standing riders rock side to side with each stroke.
	pelvis.x += sin(crank_angle) * 0.03 * e
	var lean := deg_to_rad(lerpf(26.0, 40.0, e))
	var side_tilt := -steer * 0.15 + sin(crank_angle) * 0.06 * e
	var t := Vector3(sin(side_tilt), cos(lean), sin(lean)).normalized()
	var right_v := Vector3(1, 0, 0)  # rider's left in +X
	var neck := pelvis + t * 0.43
	var chest := pelvis + t * 0.36
	_place_limb(_parts["torso"], pelvis + t * 0.06, neck - t * 0.04)
	_place_limb(_parts["coat_hem"], pelvis + t * 0.02, pelvis + t * 0.1)
	var torso_fwd := Vector3(0, -sin(lean), cos(lean))
	# Hood + faceless void.
	var head_up := (t + Vector3.UP * 1.6).normalized()
	var look := (torso_fwd * 0.3 + Vector3(steer * 0.35, 0.0, 1.0)).normalized()
	var head := neck + head_up * 0.13
	_orient(_parts["hood"], head, look, head_up)
	_orient(_parts["face"], head + look * 0.068 + head_up * -0.012, look, head_up)
	# Backpack sits on the back of the torso.
	_orient(_parts["backpack"], pelvis + t * 0.25 - torso_fwd * 0.155, -torso_fwd, t)
	_orient(_parts["pack_flap"], pelvis + t * 0.36 - torso_fwd * 0.165, -torso_fwd, t)
	# Grips follow the steered front end.
	var gl := _front.transform * (GRIP - HEAD_BOT)
	var gr := _front.transform * (Vector3(-GRIP.x, GRIP.y, GRIP.z) - HEAD_BOT)
	for s in ["l", "r"]:
		var sx := 1.0 if s == "l" else -1.0
		var hip := pelvis + right_v * 0.085 * sx
		var pedal := pl if s == "l" else pr
		var ankle := pedal + Vector3(0, 0.06, -0.035)
		var leg := _solve_knee(hip, ankle, 0.37, 0.36, Vector3(0.12 * sx, 0.3, 1.0))
		_place_limb(_parts["thigh_" + s], hip, leg[0])
		_place_limb(_parts["shin_" + s], leg[0], leg[1])
		var foot_c: Vector3 = leg[1] + Vector3(0, -0.03, 0.055)
		_orient(_parts["shoe_" + s], foot_c, Vector3(0, -0.05, 1), Vector3.UP)
		_orient(_parts["sole_" + s], foot_c + Vector3(0, -0.04, 0), Vector3(0, -0.05, 1), Vector3.UP)
		var shoulder := chest + right_v * 0.15 * sx + torso_fwd * 0.01
		var grip := gl if s == "l" else gr
		var arm := _solve_knee(shoulder, grip, 0.25, 0.25, Vector3(0.8 * sx, -0.7, -0.2))
		_place_limb(_parts["uarm_" + s], shoulder, arm[0])
		_place_limb(_parts["farm_" + s], arm[0], arm[1])
		(_parts["hand_" + s] as Node3D).position = arm[1]
