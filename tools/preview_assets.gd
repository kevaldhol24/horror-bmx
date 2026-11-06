extends SceneTree
## Dev tool: lays out models in a grid and saves a screenshot.
## Usage: godot --rendering-driver opengl3 -s tools/preview_assets.gd -- <out.png> <dir> [filter]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://preview.png"
	var dir: String = args[1] if args.size() > 1 else "res://assets/models/city"
	var filt: String = args[2] if args.size() > 2 else ""
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.3, 0.35)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	root3d.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root3d.add_child(sun)
	var files: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if (f.ends_with(".gltf") or f.ends_with(".glb")) and (filt == "" or f.contains(filt)):
			files.append(f)
	var cols := int(ceil(sqrt(files.size())))
	var spacing := 3.0
	var i := 0
	for f in files:
		var ps: PackedScene = load(dir + "/" + f)
		if ps == null:
			continue
		var n: Node3D = ps.instantiate()
		root3d.add_child(n)
		n.position = Vector3((i % cols) * spacing, 0, (i / cols) * spacing)
		var l := Label3D.new()
		l.text = f.get_basename()
		l.pixel_size = 0.004
		l.position = n.position + Vector3(0, -0.2, 1.2)
		l.rotation_degrees.x = -60
		root3d.add_child(l)
		i += 1
	var cam := Camera3D.new()
	root3d.add_child(cam)
	var c := (cols - 1) * spacing * 0.5
	cam.position = Vector3(c, cols * spacing * 0.9, c + cols * spacing * 0.9)
	cam.look_at(Vector3(c, 0, c))
	cam.current = true
	for k in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	print("saved ", out, " models=", i)
	quit()
