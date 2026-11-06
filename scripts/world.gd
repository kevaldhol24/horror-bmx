class_name World
extends Node3D
## Streams road/terrain chunks around the player, decorates them per zone
## (Town -> Woods -> Cemetery, repeating), spawns obstacles and manages a small
## pool of flickering street lights. Fully deterministic per chunk index.

signal watcher_seen

const CHUNK_LEN := 24.0
const KEEP_BEHIND := 1
const KEEP_AHEAD := 9
const ZONE_LEN := 420.0
const ROW_STEP := 2.0
const SAFE_START := 70.0
const LIGHT_POOL := 5

enum Zone { TOWN, WOODS, CEMETERY }

var road_mat: ShaderMaterial
var suburb := Suburb.new()
var terrain_mat: ShaderMaterial
var obstacles: Array = []        # dicts, see _add_obstacle
var lamps: Array = []            # {pos, seed, dead}
var watchers: Array = []         # {node, s, triggered}

var _chunks := {}                # index -> Node3D
var _scenes := {}
var _lights: Array[OmniLight3D] = []
var _light_assign: Array = []
var _assign_timer := 0.0
var _flicker_boost := 0.0
var _t := 0.0
var mat_slab: StandardMaterial3D
var mat_hole: StandardMaterial3D
var mat_bulb: StandardMaterial3D
var mat_shadow: StandardMaterial3D
var mat_eye: StandardMaterial3D
var mat_stripe: StandardMaterial3D
var mat_wood: StandardMaterial3D

const CITY := "res://assets/models/city/"
const HALL := "res://assets/models/halloween/"

func _ready() -> void:
	road_mat = ShaderMaterial.new()
	road_mat.shader = preload("res://shaders/road.gdshader")
	road_mat.set_shader_parameter("half_width", RoadPath.ROAD_HALF_WIDTH)
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = preload("res://shaders/terrain.gdshader")
	mat_slab = _std(Color(0.2, 0.19, 0.18), 0.85)
	mat_hole = _std(Color(0.012, 0.01, 0.01), 0.25)
	mat_hole.metallic_specular = 0.9
	mat_bulb = _std(Color(1, 0.8, 0.5), 0.5)
	mat_bulb.emission_enabled = true
	mat_bulb.emission = Color(1.0, 0.62, 0.3)
	mat_bulb.emission_energy_multiplier = 4.0
	mat_shadow = _std(Color(0, 0, 0), 1.0)
	mat_shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_eye = _std(Color(1, 0.1, 0.05), 1.0)
	mat_eye.emission_enabled = true
	mat_eye.emission = Color(1, 0.08, 0.03)
	mat_eye.emission_energy_multiplier = 9.0
	mat_eye.disable_fog = true
	mat_stripe = _std(Color(0.85, 0.82, 0.78), 0.5)
	mat_wood = _std(Color(0.22, 0.13, 0.07), 0.9)
	for i in LIGHT_POOL:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.58, 0.28)
		l.omni_range = 16.0
		l.omni_attenuation = 1.3
		l.light_energy = 0.0
		l.shadow_enabled = false
		add_child(l)
		_lights.append(l)
		_light_assign.append(null)

func _std(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

static func zone_at(s: float) -> int:
	return int(floor(s / ZONE_LEN)) % 3

func reset_world() -> void:
	for k in _chunks.keys():
		_chunks[k].queue_free()
	_chunks.clear()
	obstacles.clear()
	lamps.clear()
	watchers.clear()
	for i in LIGHT_POOL:
		_light_assign[i] = null
		_lights[i].light_energy = 0.0

func update_world(player_s: float, delta: float) -> void:
	_t += delta
	var ci := int(floor(player_s / CHUNK_LEN))
	for i in range(ci - KEEP_BEHIND, ci + KEEP_AHEAD + 1):
		if i >= -1 and not _chunks.has(i):
			_chunks[i] = _build_chunk(i)
	for k in _chunks.keys():
		if k < ci - KEEP_BEHIND or k > ci + KEEP_AHEAD:
			_drop_chunk(k)
	_update_lights(player_s, delta)
	_update_watchers(player_s, delta)

func flicker_burst(strength: float = 1.0) -> void:
	_flicker_boost = maxf(_flicker_boost, strength)

func _drop_chunk(k: int) -> void:
	var s0 := k * CHUNK_LEN
	var s1 := s0 + CHUNK_LEN
	obstacles = obstacles.filter(func(o): return o.s < s0 or o.s >= s1)
	lamps = lamps.filter(func(l): return l.s < s0 or l.s >= s1)
	watchers = watchers.filter(func(w): return w.s < s0 or w.s >= s1)
	_chunks[k].queue_free()
	_chunks.erase(k)

# ------------------------------------------------------------------ meshes

func _build_chunk(index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Chunk%d" % index
	add_child(root)
	var s0 := index * CHUNK_LEN
	root.add_child(_road_mesh(s0))
	root.add_child(_terrain_mesh(s0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(index * 7919 + 13)
	var zone := zone_at(s0 + CHUNK_LEN * 0.5)
	match zone:
		Zone.TOWN: _decorate_town(root, s0, rng)
		Zone.WOODS: _decorate_woods(root, s0, rng)
		Zone.CEMETERY: _decorate_cemetery(root, s0, rng)
	_decorate_common(root, s0, rng, zone)
	_spawn_obstacles(root, s0, rng, index)
	return root

func _road_mesh(s0: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lats := PackedFloat32Array([-RoadPath.ROAD_HALF_WIDTH, -1.8, 0.0, 1.8, RoadPath.ROAD_HALF_WIDTH])
	var rows := int(CHUNK_LEN / ROW_STEP)
	for r in rows:
		var sa := s0 + r * ROW_STEP
		var sb := sa + ROW_STEP
		for c in lats.size() - 1:
			var la := lats[c]
			var lb := lats[c + 1]
			var p00 := RoadPath.point(sa, la)
			var p01 := RoadPath.point(sa, lb)
			var p10 := RoadPath.point(sb, la)
			var p11 := RoadPath.point(sb, lb)
			_quad(st, p00, p01, p11, p10, Vector2(la, sa), Vector2(lb, sa), Vector2(lb, sb), Vector2(la, sb))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = road_mat
	return mi

func _terrain_mesh(s0: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := RoadPath.ROAD_HALF_WIDTH
	var lats := PackedFloat32Array([-90.0, -55.0, -34.0, -20.0, -13.0, -9.0, -6.5, -(edge + RoadPath.SHOULDER), -edge + 0.05])
	var all := PackedFloat32Array()
	for v in lats:
		all.append(v)
	for i in range(lats.size() - 1, -1, -1):
		all.append(-lats[i])
	var rows := int(CHUNK_LEN / ROW_STEP)
	for r in rows:
		var sa := s0 + r * ROW_STEP
		var sb := sa + ROW_STEP
		for c in all.size() - 1:
			var la := all[c]
			var lb := all[c + 1]
			if la >= -edge + 0.04 and lb <= edge - 0.04:
				continue  # under the asphalt
			var p00 := _ground(sa, la)
			var p01 := _ground(sa, lb)
			var p10 := _ground(sb, la)
			var p11 := _ground(sb, lb)
			var ga := _gravel_w(la)
			var gb := _gravel_w(lb)
			st.set_color(Color(ga, 0, 0)); st.add_vertex(p00)
			st.set_color(Color(gb, 0, 0)); st.add_vertex(p11)
			st.set_color(Color(gb, 0, 0)); st.add_vertex(p01)
			st.set_color(Color(ga, 0, 0)); st.add_vertex(p00)
			st.set_color(Color(ga, 0, 0)); st.add_vertex(p10)
			st.set_color(Color(gb, 0, 0)); st.add_vertex(p11)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = terrain_mat
	return mi

func _gravel_w(lat: float) -> float:
	return 1.0 if absf(lat) <= RoadPath.ROAD_HALF_WIDTH + RoadPath.SHOULDER + 0.01 else 0.0

func _ground(s: float, lat: float) -> Vector3:
	var p := RoadPath.point(s, lat)
	p.y = RoadPath.ground_height(s, lat)
	if absf(lat) < RoadPath.ROAD_HALF_WIDTH + 0.1:
		p.y -= 0.03
	return p

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	# a,b at near row; d,c at far row. Godot front faces are clockwise.
	st.set_uv(ua); st.add_vertex(a)
	st.set_uv(uc); st.add_vertex(c)
	st.set_uv(ub); st.add_vertex(b)
	st.set_uv(ua); st.add_vertex(a)
	st.set_uv(ud); st.add_vertex(d)
	st.set_uv(uc); st.add_vertex(c)

# ------------------------------------------------------------------ props

func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]

## Place a model at road coords. `face_road` turns its front (+Z) toward the road.
func _prop(root: Node3D, path: String, s: float, lat: float, scale_: float, yaw := 0.0, face_road := true, sink := 0.0) -> Node3D:
	var n: Node3D = _scene(path).instantiate()
	root.add_child(n)
	var p := RoadPath.point(s, lat)
	p.y = RoadPath.ground_height(s, lat) - sink
	var b := RoadPath.basis_at(s)
	# Flattened road frame: x = right, y = up, z = back toward the start.
	var flat_b := Basis(b.x, Vector3.UP, b.x.cross(Vector3.UP).normalized())
	var face := 0.0
	if face_road:
		face = -PI * 0.5 if lat > 0 else PI * 0.5
	n.transform = Transform3D(flat_b * Basis(Vector3.UP, face + yaw), p)
	n.scale = Vector3.ONE * scale_
	return n

func _decorate_town(root: Node3D, s0: float, rng: RandomNumberGenerator) -> void:
	# 80s suburb: procedural houses with lit windows, yards with bare trees,
	# parked cars, power line with cobra street lamps on the right side.
	for side in [-1.0, 1.0]:
		var s := s0 + rng.randf_range(0.0, 3.0)
		while s < s0 + CHUNK_LEN:
			if rng.randf() < 0.88:
				var house := suburb.make_house(rng)
				root.add_child(house)
				var hs := s + 6.0
				var lat: float = side * rng.randf_range(17.0, 19.5)
				var p := RoadPath.point(hs, lat)
				p.y = RoadPath.ground_height(hs, lat) - 0.2
				var rb := RoadPath.right(hs)
				var face: Vector3 = -rb * side   # front faces the road
				house.global_transform = Transform3D(Basis(Vector3.UP, atan2(face.x, face.z)), p)
				# Bare tree in the yard.
				if rng.randf() < 0.5:
					_prop(root, HALL + "tree_dead_medium.gltf", hs + rng.randf_range(-5, 5), side * rng.randf_range(10.5, 12.5), 1.6 * rng.randf_range(0.8, 1.2), rng.randf() * TAU, false, 0.2)
			s += rng.randf_range(15.0, 19.0)
	# Parked 80s cars along the curb.
	if rng.randf() < 0.55:
		var cars := ["car_sedan", "car_stationwagon", "car_hatchback", "car_sedan"]
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		_prop(root, CITY + cars[rng.randi() % cars.size()] + ".gltf", s0 + rng.randf_range(3, 20), side * rng.randf_range(7.4, 8.2), 4.6, rng.randf_range(-0.12, 0.12) + PI * 0.5, true)
	# Power line + street lamps (right side), plain street lights on the left.
	var line := suburb.make_power_line(s0, s0 + CHUNK_LEN, 7.6, func(ls: float, pos: Vector3, k: int):
		_lamp_bulb(root, pos)
		lamps.append({"s": ls, "pos": pos - Vector3(0, 0.3, 0), "seed": float(k) * 13.7, "dead": (k * 7) % 9 == 4, "warm": true}))
	if line:
		root.add_child(line)
	if rng.randf() < 0.15:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		_prop(root, CITY + "watertower.gltf", s0 + 10, side * rng.randf_range(32, 45), 9.0, rng.randf() * TAU, false)

func _lamp_bulb(root: Node3D, pos: Vector3) -> void:
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.14
	sm.radial_segments = 8
	sm.rings = 4
	bulb.mesh = sm
	bulb.material_override = mat_bulb
	root.add_child(bulb)
	bulb.global_position = pos - Vector3(0, 0.1, 0)

func _decorate_woods(root: Node3D, s0: float, rng: RandomNumberGenerator) -> void:
	var trees := ["tree_dead_large", "tree_dead_medium", "tree_dead_small", "tree_dead_large",
		"tree_pine_orange_large", "tree_pine_orange_medium", "tree_pine_yellow_large"]
	for i in 22:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lat := side * rng.randf_range(9.0, 60.0) * (0.35 + rng.randf() * 0.65) + side * 8.0
		var t: String = trees[rng.randi() % trees.size()]
		var sc := 1.9 if t.begins_with("tree_dead") else 1.35
		_prop(root, HALL + t + ".gltf", s0 + rng.randf_range(0, CHUNK_LEN), lat, sc * rng.randf_range(0.8, 1.25), rng.randf() * TAU, false, 0.2)
	# Broken fence runs along the verge.
	for side in [-1.0, 1.0]:
		if rng.randf() < 0.55:
			var s := s0
			while s < s0 + CHUNK_LEN:
				var f := "fence_seperate_broken" if rng.randf() < 0.45 else "fence_seperate"
				if rng.randf() < 0.85:
					_prop(root, HALL + f + ".gltf", s + 1.3, side * 7.4, 0.68, rng.randf_range(-0.1, 0.1), true, 0.05)
				s += 2.7
	if rng.randf() < 0.35:
		var ls := s0 + rng.randf_range(4, 20)
		_lantern_post(root, ls, (1.0 if rng.randf() < 0.5 else -1.0) * 6.9, rng)

func _decorate_cemetery(root: Node3D, s0: float, rng: RandomNumberGenerator) -> void:
	var side := 1.0 if (int(s0 / ZONE_LEN) % 2) == 0 else -1.0
	# Iron fence on the graveyard side.
	var s := s0
	while s < s0 + CHUNK_LEN:
		var f := "fence_broken" if rng.randf() < 0.25 else "fence"
		_prop(root, HALL + f + ".gltf", s + 1.3, side * 8.2, 0.65, 0.0, true, 0.05)
		if rng.randf() < 0.4:
			_prop(root, HALL + "fence_pillar.gltf", s, side * 8.2, 0.65, 0.0, true, 0.05)
		s += 2.6
	var graves := ["gravestone", "grave_A", "grave_B", "gravemarker_A", "gravemarker_B", "grave_A_destroyed"]
	for i in 14:
		var g: String = graves[rng.randi() % graves.size()]
		_prop(root, HALL + g + ".gltf", s0 + rng.randf_range(0, CHUNK_LEN), side * rng.randf_range(10.5, 34.0), 0.62, rng.randf_range(-0.3, 0.3), true, 0.05)
	if rng.randf() < 0.25:
		_prop(root, HALL + "crypt.gltf", s0 + 12, side * rng.randf_range(20, 30), 0.8, rng.randf_range(-0.2, 0.2))
	for i in 5:
		_prop(root, HALL + "tree_dead_large.gltf", s0 + rng.randf_range(0, CHUNK_LEN), side * rng.randf_range(12, 40), 1.9 * rng.randf_range(0.8, 1.2), rng.randf() * TAU, false, 0.2)
	# Other side: dark woods.
	for i in 8:
		var t := "tree_dead_medium" if rng.randf() < 0.5 else "tree_pine_orange_large"
		_prop(root, HALL + t + ".gltf", s0 + rng.randf_range(0, CHUNK_LEN), -side * rng.randf_range(10, 50), 1.6, rng.randf() * TAU, false, 0.2)
	if rng.randf() < 0.5:
		_lantern_post(root, s0 + rng.randf_range(4, 20), side * 7.0, rng)

func _decorate_common(root: Node3D, s0: float, rng: RandomNumberGenerator, zone: int) -> void:
	# Background silhouettes so the horizon is never empty.
	for i in 3:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		_prop(root, HALL + "tree_dead_large.gltf", s0 + rng.randf_range(0, CHUNK_LEN), side * rng.randf_range(60, 85), 3.2 * rng.randf_range(0.8, 1.3), rng.randf() * TAU, false, 0.5)
	# The Gate: once per town stretch, a building torn open by blue light, seen down the road.
	var zone_start: float = floor(s0 / ZONE_LEN) * ZONE_LEN
	var gate_s: float = zone_start + 330.0
	if zone == Zone.TOWN and gate_s >= s0 and gate_s < s0 + CHUNK_LEN and s0 > 100.0:
		var g := suburb.make_gate_building(rng)
		root.add_child(g)
		var gside := 1.0 if rng.randf() < 0.5 else -1.0
		var glat := gside * 21.0
		var gp := RoadPath.point(gate_s, glat)
		gp.y = RoadPath.ground_height(gate_s, glat)
		var face: Vector3 = (RoadPath.point(gate_s - 30.0, 0.0) - gp)
		face.y = 0.0
		face = face.normalized()
		g.global_transform = Transform3D(Basis(Vector3.UP, atan2(face.x, face.z)), gp)
	# The Watcher: a tall shadow figure that stands at the roadside.
	if s0 > 260.0 and rng.randf() < 0.075:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var ws := s0 + rng.randf_range(4, 20)
		var w := _make_watcher()
		root.add_child(w)
		var lat := side * (6.9 if zone != Zone.TOWN else 7.4)
		var p := RoadPath.point(ws, lat)
		p.y = RoadPath.ground_height(ws, lat)
		w.global_position = p
		var to_road := (RoadPath.point(ws - 6.0, 0) - p)
		to_road.y = 0
		w.look_at(p + to_road, Vector3.UP)
		w.scale = Vector3.ONE * 1.3
		watchers.append({"node": w, "s": ws, "triggered": false})

func _streetlight(root: Node3D, s: float, lat: float, rng: RandomNumberGenerator) -> void:
	# KayKit streetlight arm points along local -X; turn it toward the road.
	_prop(root, CITY + "streetlight.gltf", s, lat, 5.0, 0.0 if lat > 0 else PI, false)
	var dead := rng.randf() < 0.22
	var head := RoadPath.point(s, lat - signf(lat) * 1.05)
	head.y = RoadPath.ground_height(s, lat) + 4.45
	if not dead:
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.2
		bulb.mesh = sm
		bulb.material_override = mat_bulb
		root.add_child(bulb)
		bulb.global_position = head
	lamps.append({"s": s, "pos": head - Vector3(0, 0.4, 0), "seed": rng.randf() * 100.0, "dead": dead, "warm": true})

func _lantern_post(root: Node3D, s: float, lat: float, rng: RandomNumberGenerator) -> void:
	_prop(root, HALL + "post_lantern.gltf", s, lat, 0.75, 0.0, true, 0.0)
	var head := RoadPath.point(s, lat - signf(lat) * 0.7)
	head.y = RoadPath.ground_height(s, lat) + 2.4
	lamps.append({"s": s, "pos": head, "seed": rng.randf() * 100.0, "dead": false, "warm": false})

func _make_watcher() -> Node3D:
	var w := Node3D.new()
	w.name = "Watcher"
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.22
	cm.height = 2.5
	body.mesh = cm
	body.material_override = mat_shadow
	body.position = Vector3(0, 1.4, 0)
	body.scale = Vector3(1.0, 1.0, 0.7)
	w.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.5
	head.mesh = sm
	head.material_override = mat_shadow
	head.position = Vector3(0, 2.85, 0.03)
	w.add_child(head)
	for sx in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var am := CapsuleMesh.new()
		am.radius = 0.06
		am.height = 1.9
		arm.mesh = am
		arm.material_override = mat_shadow
		arm.position = Vector3(0.27 * sx, 1.55, 0.0)
		arm.rotation = Vector3(0, 0, 0.07 * sx)
		w.add_child(arm)
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.03
		em.height = 0.04
		eye.mesh = em
		eye.material_override = mat_eye
		eye.position = Vector3(0.07 * sx, 2.88, -0.17)
		w.add_child(eye)
	# A sick red glow behind it so it reads as a silhouette from far away.
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.12, 0.06)
	glow.light_energy = 4.0
	glow.omni_range = 7.0
	glow.position = Vector3(0, 1.6, 1.2)
	w.add_child(glow)
	return w

func _update_watchers(player_s: float, delta: float) -> void:
	for w in watchers:
		var n: Node3D = w.node
		if not is_instance_valid(n):
			continue
		var d: float = w.s - player_s
		if not w.triggered and d < 18.0 and d > 0.0:
			w.triggered = true
			flicker_burst(1.0)
			watcher_seen.emit()
		if w.triggered and n.visible:
			# Vanish while the lights are out.
			n.set_meta("t", float(n.get_meta("t", 0.0)) + delta)
			if float(n.get_meta("t")) > 0.45:
				n.visible = false

# ------------------------------------------------------------------ lights

func _update_lights(player_s: float, delta: float) -> void:
	_flicker_boost = maxf(0.0, _flicker_boost - delta * 0.7)
	_assign_timer -= delta
	if _assign_timer <= 0.0:
		_assign_timer = 0.2
		var cand: Array = []
		for l in lamps:
			if l.dead:
				continue
			var d: float = l.s - player_s
			if d > -14.0 and d < 80.0:
				cand.append(l)
		cand.sort_custom(func(a, b): return absf(a.s - player_s - 15.0) < absf(b.s - player_s - 15.0))
		for i in LIGHT_POOL:
			_light_assign[i] = cand[i] if i < cand.size() else null
	for i in LIGHT_POOL:
		var l: OmniLight3D = _lights[i]
		var a = _light_assign[i]
		if a == null:
			l.light_energy = move_toward(l.light_energy, 0.0, delta * 8.0)
			continue
		l.global_position = a.pos
		var sd: float = a.seed
		var base := 2.6 if a.warm else 1.6
		l.light_color = Color(1.0, 0.58, 0.28) if a.warm else Color(1.0, 0.42, 0.18)
		l.omni_range = 15.0 if a.warm else 9.0
		# Bad wiring: occasional drop-outs, plus global bursts from the Watcher.
		var n := sin(_t * 23.0 + sd) * sin(_t * 7.3 + sd * 2.0)
		var out := 1.0
		if fmod(_t * 0.37 + sd, 5.0) < 0.18:
			out = 0.1 if n > 0.0 else 0.9
		if _flicker_boost > 0.05:
			out *= 0.05 if sin(_t * 41.0 + sd) > 0.2 - _flicker_boost * 0.6 else 1.0
		l.light_energy = base * out * (0.92 + 0.08 * n)
	# Feed the same (flickering) lights to the wet-road reflection streaks.
	var pos := PackedVector3Array()
	var cols := PackedColorArray()
	for i in LIGHT_POOL:
		if _light_assign[i] != null and _lights[i].light_energy > 0.05:
			var lc: Color = _lights[i].light_color
			pos.append(_lights[i].global_position + Vector3(0, 0.35, 0))
			cols.append(Color(lc.r, lc.g * 0.85, lc.b * 0.7, _lights[i].light_energy))
	while pos.size() < 6:
		pos.append(Vector3.ZERO)
		cols.append(Color(0, 0, 0, 0))
	road_mat.set_shader_parameter("lamp_pos", pos)
	var v4 := []
	for c in cols:
		v4.append(Vector4(c.r, c.g, c.b, c.a))
	road_mat.set_shader_parameter("lamp_col", v4)
	road_mat.set_shader_parameter("lamp_count", mini(LIGHT_POOL, 6))

# ------------------------------------------------------------------ obstacles

func _add_obstacle(type: String, s: float, lat: float, half_w: float, half_len: float, height: float, node: Node3D) -> void:
	obstacles.append({"type": type, "s": s, "lat": lat, "half_w": half_w, "half_len": half_len, "height": height, "node": node, "hit": false})

const SLOT := 4.0

static func _slot_roll(k: int) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash(k * 92821 + 7)
	return r.randf()

static func _slot_has_obstacle(k: int) -> bool:
	var ss := k * SLOT
	if ss < SAFE_START:
		return false
	var diff := clampf((ss - SAFE_START) / 2600.0, 0.0, 1.0)
	var gap := lerpf(17.0, 10.0, diff)
	return _slot_roll(k) < SLOT / gap

func _spawn_obstacles(root: Node3D, s0: float, rng: RandomNumberGenerator, _index: int) -> void:
	# Global 4 m slots so spacing is independent of chunk size; a slot never
	# spawns right after another one, keeping a guaranteed escape gap.
	var k0 := int(ceil(s0 / SLOT))
	var k1 := int(floor((s0 + CHUNK_LEN - 0.001) / SLOT))
	for k in range(k0, k1 + 1):
		if not _slot_has_obstacle(k) or _slot_has_obstacle(k - 1):
			continue
		var s := k * SLOT + rng.randf_range(-1.0, 1.0)
		var diff := clampf((s - SAFE_START) / 2600.0, 0.0, 1.0)
		# Early road teaches: mostly potholes and ramps.
		var roll := rng.randf() * (0.66 if s < 260.0 else 1.0)
		var lat := rng.randf_range(-2.3, 2.3)
		if roll < 0.36:
			_pothole(root, s, lat, rng)
			if diff > 0.35 and rng.randf() < 0.5:
				_pothole(root, s + rng.randf_range(1.5, 3.0), clampf(lat + rng.randf_range(-2.5, 2.5), -2.8, 2.8), rng)
		elif roll < 0.52:
			_rubble(root, s, lat, rng)
		elif roll < 0.66:
			_ramp_slab(root, s, rng.randf_range(-1.6, 1.6), rng)
		elif roll < 0.78:
			_rough_patch(root, s, rng)
		elif roll < 0.9:
			_barrier(root, s, (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(1.2, 2.2))
		else:
			_fallen_tree(root, s, 1.0 if rng.randf() < 0.5 else -1.0)

func _on_road(root: Node3D, mi: Node3D, s: float, lat: float, yaw := 0.0, lift := 0.0) -> void:
	root.add_child(mi)
	var b := RoadPath.basis_at(s)
	mi.transform = Transform3D(b * Basis(Vector3.UP, yaw), RoadPath.point(s, lat) + b.y * lift)

func _pothole(root: Node3D, s: float, lat: float, rng: RandomNumberGenerator) -> void:
	var r := rng.randf_range(0.5, 0.85)
	var node := Node3D.new()
	var hole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 0.8
	cm.height = 0.04
	cm.radial_segments = 10
	hole.mesh = cm
	hole.material_override = mat_hole
	hole.scale = Vector3(1.0, 1.0, rng.randf_range(0.75, 1.2))
	node.add_child(hole)
	# Broken asphalt lip around the hole.
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf() * 0.4
		var chunk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.12, 0.3), rng.randf_range(0.04, 0.09), rng.randf_range(0.1, 0.22))
		chunk.mesh = bm
		chunk.material_override = mat_slab
		chunk.position = Vector3(cos(a) * r * 1.05, 0.02, sin(a) * r * 1.05 * hole.scale.z)
		chunk.rotation = Vector3(rng.randf_range(-0.4, 0.4), a, rng.randf_range(-0.4, 0.4))
		node.add_child(chunk)
	_on_road(root, node, s, lat, rng.randf() * TAU, 0.0)
	_add_obstacle("pothole", s, lat, r * 0.8, r * 0.8, 0.12, node)

func _rubble(root: Node3D, s: float, lat: float, rng: RandomNumberGenerator) -> void:
	var node := Node3D.new()
	for i in 7:
		var chunk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.35, 0.75), rng.randf_range(0.1, 0.22), rng.randf_range(0.3, 0.6))
		chunk.mesh = bm
		chunk.material_override = mat_slab
		chunk.position = Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.05, 0.22), rng.randf_range(-0.4, 0.4))
		chunk.rotation = Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU, rng.randf_range(-0.6, 0.6))
		node.add_child(chunk)
	_on_road(root, node, s, lat)
	_add_obstacle("rubble", s, lat, 0.85, 0.55, 0.36, node)

func _ramp_slab(root: Node3D, s: float, lat: float, rng: RandomNumberGenerator) -> void:
	# A slab of road heaved up by something underneath — launches you.
	var node := Node3D.new()
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 0.14, 2.4)
	slab.mesh = bm
	slab.material_override = road_mat
	slab.rotation = Vector3(deg_to_rad(-13.0), 0, rng.randf_range(-0.05, 0.05))
	slab.position = Vector3(0, 0.22, 0)
	node.add_child(slab)
	var crack := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(2.2, 0.05, 0.5)
	crack.mesh = cb
	crack.material_override = mat_hole
	crack.position = Vector3(0, 0.0, -1.3)
	node.add_child(crack)
	_on_road(root, node, s, lat)
	_add_obstacle("ramp", s, lat, 1.0, 1.2, 0.0, node)

func _rough_patch(root: Node3D, s: float, rng: RandomNumberGenerator) -> void:
	var node := Node3D.new()
	var w := rng.randf_range(2.5, 4.5)
	var lat := rng.randf_range(-RoadPath.ROAD_HALF_WIDTH + w * 0.5, RoadPath.ROAD_HALF_WIDTH - w * 0.5)
	for i in 26:
		var chunk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.2, 0.5), 0.05, rng.randf_range(0.2, 0.5))
		chunk.mesh = bm
		chunk.material_override = mat_slab if i % 3 else mat_hole
		chunk.position = Vector3(rng.randf_range(-w * 0.5, w * 0.5), 0.01, rng.randf_range(-2.5, 2.5))
		chunk.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))
		node.add_child(chunk)
	_on_road(root, node, s, lat)
	_add_obstacle("rough", s, lat, w * 0.5, 2.6, 0.0, node)

func _barrier(root: Node3D, s: float, lat: float) -> void:
	var node := Node3D.new()
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 0.28, 0.06)
	board.mesh = bm
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/stripes.gdshader")
	board.material_override = sm
	board.position = Vector3(0, 0.9, 0)
	node.add_child(board)
	for sx in [-0.8, 0.8]:
		for sz in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.07, 1.05, 0.07)
			leg.mesh = lm
			leg.material_override = mat_wood
			leg.position = Vector3(sx, 0.5, 0.15 * sz)
			leg.rotation = Vector3(0.28 * sz, 0, 0)
			node.add_child(leg)
	# Blinking warning lamp.
	var lamp := MeshInstance3D.new()
	var lsm := SphereMesh.new()
	lsm.radius = 0.08
	lsm.height = 0.12
	lamp.mesh = lsm
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(1, 0.4, 0.05)
	lmat.emission_enabled = true
	lmat.emission = Color(1, 0.35, 0.02)
	lmat.emission_energy_multiplier = 5.0
	lamp.material_override = lmat
	lamp.position = Vector3(0.85, 1.12, 0)
	lamp.name = "Blink"
	node.add_child(lamp)
	_on_road(root, node, s, lat, PI)
	_add_obstacle("barrier", s, lat, 1.05, 0.3, 1.2, node)

func _fallen_tree(root: Node3D, s: float, side: float) -> void:
	var node := Node3D.new()
	var t: Node3D = _scene(HALL + "tree_dead_medium.gltf").instantiate()
	node.add_child(t)
	t.scale = Vector3.ONE * 1.25
	# Lay the tree on its side across one lane.
	t.rotation = Vector3(0, 0, PI * 0.5 * side)
	t.position = Vector3(side * 4.6, 0.25, 0)
	_on_road(root, node, s, 0.0)
	_add_obstacle("log", s, side * 1.5, 2.15, 0.35, 0.45, node)
