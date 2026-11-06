extends SceneTree
## Dev tool: renders the bike + rider from a few angles.
## Usage: godot --rendering-driver opengl3 -s tools/preview_bike.gd -- <out_prefix>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://bike"
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.25, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 60, 0)
	root.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	floor_mi.mesh = pm
	root.add_child(floor_mi)
	var bike: Node3D = load("res://scripts/bike_model.gd").new()
	root.add_child(bike)
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	cam.current = true
	var views := {
		"side": [Vector3(3.2, 0.9, 0.0), 0.6],
		"front34": [Vector3(1.8, 1.3, 2.2), 2.0],
		"back": [Vector3(-0.8, 1.6, -2.6), 4.0],
	}
	for k in views:
		bike.set("crank_angle", views[k][1])
		cam.look_at_from_position(views[k][0], Vector3(0, 0.6, 0))
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("%s_%s.png" % [out, k])
	print("done")
	quit()
