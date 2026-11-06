class_name Suburb
extends RefCounted
## Procedural 80s suburban props, each merged into ONE mesh with a surface per
## material (≈5 draw calls per house) so whole streets stay cheap on phones.
## Houses are built at the origin with their front facing +Z.

var mats := {}

func _init() -> void:
	var walls := [Color(0.72, 0.7, 0.66), Color(0.62, 0.66, 0.68), Color(0.7, 0.64, 0.52), Color(0.55, 0.52, 0.48), Color(0.6, 0.58, 0.62)]
	for i in walls.size():
		mats["wall%d" % i] = _m(walls[i], 0.85)
	mats["roof0"] = _m(Color(0.12, 0.11, 0.12), 0.8)
	mats["roof1"] = _m(Color(0.18, 0.12, 0.1), 0.8)
	mats["trim"] = _m(Color(0.82, 0.8, 0.76), 0.7)
	mats["dark"] = _m(Color(0.05, 0.05, 0.06), 0.3)
	var lit := _m(Color(1.0, 0.72, 0.42), 0.5)
	lit.emission_enabled = true
	lit.emission = Color(1.0, 0.62, 0.3)
	lit.emission_energy_multiplier = 2.6
	mats["lit"] = lit
	var tv := _m(Color(0.5, 0.6, 1.0), 0.5)
	tv.emission_enabled = true
	tv.emission = Color(0.45, 0.55, 1.0)
	tv.emission_energy_multiplier = 1.8
	mats["tv"] = tv
	mats["pole"] = _m(Color(0.09, 0.07, 0.06), 0.9)
	mats["wire"] = _m(Color(0.02, 0.02, 0.02), 0.6)
	mats["brick"] = _m(Color(0.22, 0.1, 0.08), 0.9)
	var gate := _m(Color(0.75, 0.9, 1.0), 0.4)
	gate.emission_enabled = true
	gate.emission = Color(0.55, 0.8, 1.0)
	gate.emission_energy_multiplier = 12.0
	mats["gate"] = gate

func _m(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

# ---------------------------------------------------------------- mesh builder

class Builder:
	var tools := {}
	var owner: Suburb

	func _init(o: Suburb) -> void:
		owner = o

	func _st(mat: String) -> SurfaceTool:
		if not tools.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[mat] = st
		return tools[mat]

	func box(mat: String, center: Vector3, size: Vector3, rot_y := 0.0) -> void:
		var bm := BoxMesh.new()
		bm.size = size
		_st(mat).append_from(bm, 0, Transform3D(Basis(Vector3.UP, rot_y), center))

	func xform_box(mat: String, xf: Transform3D, size: Vector3) -> void:
		var bm := BoxMesh.new()
		bm.size = size
		_st(mat).append_from(bm, 0, xf)

	func prism(mat: String, center: Vector3, size: Vector3, rot_y := 0.0) -> void:
		var pm := PrismMesh.new()
		pm.size = size
		_st(mat).append_from(pm, 0, Transform3D(Basis(Vector3.UP, rot_y), center))

	func cyl(mat: String, a: Vector3, b: Vector3, r: float, sides := 6) -> void:
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = a.distance_to(b)
		cm.radial_segments = sides
		cm.rings = 1
		var y := (b - a).normalized()
		var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
		var x := y.cross(ref).normalized()
		var z := x.cross(y)
		_st(mat).append_from(cm, 0, Transform3D(Basis(x, y, z), (a + b) * 0.5))

	func commit() -> MeshInstance3D:
		var mesh := ArrayMesh.new()
		for k in tools.keys():
			var st: SurfaceTool = tools[k]
			mesh = st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, owner.mats[k])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		return mi

# ---------------------------------------------------------------- house

func make_house(rng: RandomNumberGenerator) -> MeshInstance3D:
	var b := Builder.new(self)
	var w := rng.randf_range(8.0, 11.5)
	var d := rng.randf_range(7.0, 9.0)
	var floors := 2 if rng.randf() < 0.45 else 1
	var fh := 2.9
	var wh := fh * floors
	var wall := "wall%d" % (rng.randi() % 5)
	var roof := "roof%d" % (rng.randi() % 2)
	# Foundation + walls.
	b.box("dark", Vector3(0, 0.25, 0), Vector3(w + 0.2, 0.5, d + 0.2))
	b.box(wall, Vector3(0, 0.5 + wh * 0.5, 0), Vector3(w, wh, d))
	# Gable roof, ridge parallel to the street (prism triangle is in XY, extruded on Z).
	var rh := rng.randf_range(2.0, 2.8)
	b.prism(roof, Vector3(0, 0.5 + wh + rh * 0.5, 0), Vector3(d + 0.9, rh, w + 0.7), PI * 0.5)
	b.box("trim", Vector3(0, 0.5 + wh + 0.05, 0), Vector3(w + 0.5, 0.12, d + 0.5))
	# Chimney.
	if rng.randf() < 0.6:
		b.box("brick", Vector3(w * 0.3 * (1.0 if rng.randf() < 0.5 else -1.0), 0.5 + wh + rh * 0.7, -d * 0.15), Vector3(0.7, rh * 1.3, 0.7))
	# Front windows + door.
	var front := d * 0.5 + 0.03
	var door_x := rng.randf_range(-w * 0.25, w * 0.25)
	b.box("trim", Vector3(door_x, 1.6, front), Vector3(1.25, 2.3, 0.06))
	b.box("dark", Vector3(door_x, 1.55, front + 0.02), Vector3(0.95, 2.1, 0.06))
	var any_lit := false
	for f in floors:
		var y := 0.5 + f * fh + 1.55
		var xs := [-w * 0.36, -w * 0.12, w * 0.12, w * 0.36]
		for x in xs:
			if f == 0 and absf(x - door_x) < 1.3:
				continue
			if rng.randf() < 0.2:
				continue
			b.box("trim", Vector3(x, y, front), Vector3(1.35, 1.55, 0.06))
			var r := rng.randf()
			var mat := "lit" if r < 0.42 else ("tv" if r < 0.5 else "dark")
			if mat != "dark":
				any_lit = true
			b.box(mat, Vector3(x, y, front + 0.02), Vector3(1.1, 1.3, 0.06))
	# Side windows (visible as you approach).
	for side in [-1.0, 1.0]:
		var r := rng.randf()
		b.box("lit" if r < 0.35 else "dark", Vector3(side * (w * 0.5 + 0.03), 0.5 + 1.55, d * 0.2), Vector3(0.06, 1.2, 1.0))
	# Porch: slab, posts, little roof.
	if rng.randf() < 0.75:
		var pw := rng.randf_range(3.0, 4.5)
		var pz := front + 1.1
		b.box("trim", Vector3(door_x, 0.35, pz), Vector3(pw, 0.2, 2.2))
		for sx in [-0.5, 0.5]:
			b.box("trim", Vector3(door_x + sx * (pw - 0.3), 1.6, pz + 0.9), Vector3(0.16, 2.4, 0.16))
		b.box(roof, Vector3(door_x, 2.9, pz + 0.1), Vector3(pw + 0.3, 0.18, 2.6))
	# Garage on one side.
	if rng.randf() < 0.45:
		var gs := 1.0 if rng.randf() < 0.5 else -1.0
		var gx := gs * (w * 0.5 + 2.0)
		b.box(wall, Vector3(gx, 0.5 + 1.4, d * 0.05), Vector3(3.8, 2.8, d * 0.85))
		b.prism(roof, Vector3(gx, 0.5 + 2.8 + 0.6, d * 0.05), Vector3(d * 0.85 + 0.4, 1.2, 4.2), PI * 0.5)
		b.box("trim", Vector3(gx, 1.5, d * 0.05 + d * 0.425 + 0.03), Vector3(3.0, 2.2, 0.06))
	var mi := b.commit()
	mi.set_meta("lit", any_lit)
	return mi

func make_mailbox(b: Builder, at: Vector3, yaw: float) -> void:
	b.box("pole", at + Vector3(0, 0.55, 0), Vector3(0.1, 1.1, 0.1))
	b.xform_box("wall%d" % 3, Transform3D(Basis(Vector3.UP, yaw), at + Vector3(0, 1.15, 0)), Vector3(0.25, 0.28, 0.5))

# ---------------------------------------------------------------- gate landmark

## A dark brick building torn open by a blue-white glowing gate.
func make_gate_building(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var b := Builder.new(self)
	var w := 22.0
	var h := 16.0
	var d := 14.0
	b.box("brick", Vector3(0, h * 0.5, 0), Vector3(w, h, d))
	b.box("dark", Vector3(0, h + 0.4, 0), Vector3(w + 0.6, 0.8, d + 0.6))
	for f in 4:
		for i in 7:
			var x := -w * 0.42 + i * (w * 0.84 / 6.0)
			var y := 2.5 + f * 3.6
			if absf(x) < 2.6:
				continue
			b.box("dark" if rng.randf() < 0.85 else "lit", Vector3(x, y, d * 0.5 + 0.03), Vector3(1.4, 2.0, 0.06))
	# The jagged gate: a stack of offset glowing slivers.
	var y0 := 0.0
	var seg := 0
	while y0 < h * 0.8:
		var hh := rng.randf_range(0.8, 1.6)
		var ww := lerpf(3.6, 0.4, y0 / (h * 0.8)) * rng.randf_range(0.7, 1.2)
		b.box("gate", Vector3(rng.randf_range(-0.35, 0.35), y0 + hh * 0.5, d * 0.5 + 0.05), Vector3(ww, hh, 0.12))
		y0 += hh * 0.85
		seg += 1
	root.add_child(b.commit())
	var l := OmniLight3D.new()
	l.light_color = Color(0.5, 0.75, 1.0)
	l.light_energy = 9.0
	l.omni_range = 30.0
	l.position = Vector3(0, 4.0, d * 0.5 + 4.0)
	root.add_child(l)
	return root

# ---------------------------------------------------------------- power lines

const POLE_GAP := 32.0
const POLE_H := 8.5

## Poles + sagging wires for the stretch [s0, s1), connecting to the next pole
## even if it lives in the next chunk. `lat` is the side offset.
func make_power_line(s0: float, s1: float, lat: float, lamp_cb: Callable) -> MeshInstance3D:
	var b := Builder.new(self)
	var k0 := int(ceil(s0 / POLE_GAP))
	var k1 := int(floor((s1 - 0.001) / POLE_GAP))
	var any := false
	for k in range(k0, k1 + 1):
		var s := k * POLE_GAP
		var base := _pole_base(s, lat)
		var top := base + Vector3(0, POLE_H, 0)
		b.cyl("pole", base, top, 0.14, 6)
		var r := RoadPath.right(s)
		var arm_a := top - Vector3(0, 0.6, 0) - r * 1.1
		var arm_b := top - Vector3(0, 0.6, 0) + r * 1.1
		b.cyl("pole", arm_a, arm_b, 0.07, 4)
		b.cyl("pole", top - Vector3(0, 1.6, 0) - r * 0.6, top - Vector3(0, 1.6, 0) + r * 0.6, 0.06, 4)
		# Street lamp arm on most poles (cobra head toward the road).
		if k % 3 != 2:
			var to_road := -signf(lat) * r
			var arm_root := base + Vector3(0, 6.2, 0)
			var head := arm_root + to_road * 2.4 + Vector3(0, 0.5, 0)
			b.cyl("pole", arm_root, head, 0.05, 4)
			b.box("dark", head + to_road * 0.25, Vector3(0.35, 0.16, 0.7), atan2(to_road.x, to_road.z))
			lamp_cb.call(s, head + to_road * 0.25 - Vector3(0, 0.2, 0), k)
		# Wires to the next pole (3 wires, catenary-ish sag).
		var nbase := _pole_base(s + POLE_GAP, lat)
		var ntop := nbase + Vector3(0, POLE_H, 0)
		var nr := RoadPath.right(s + POLE_GAP)
		for off in [-0.9, 0.0, 0.9]:
			var a: Vector3 = top - Vector3(0, 0.55, 0) + r * off
			var c: Vector3 = ntop - Vector3(0, 0.55, 0) + nr * off
			if off == 0.0:
				a = top - Vector3(0, 1.55, 0)
				c = ntop - Vector3(0, 1.55, 0)
			var prev: Vector3 = a
			for i in range(1, 7):
				var t := i / 6.0
				var p: Vector3 = a.lerp(c, t) - Vector3(0, sin(t * PI) * 0.9, 0)
				b.cyl("wire", prev, p, 0.022, 3)
				prev = p
		any = true
	if not any:
		return null
	return b.commit()

func _pole_base(s: float, lat: float) -> Vector3:
	var p := RoadPath.point(s, lat)
	p.y = RoadPath.ground_height(s, lat)
	return p
