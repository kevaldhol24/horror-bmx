extends SceneTree
## Dev tool: renders only the sky shader, looking toward the rift.
## Usage: godot --rendering-driver opengl3 -s tools/preview_sky.gd -- out.png

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	get_root().add_child(we)
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 70
	get_root().add_child(cam)
	cam.look_at_from_position(Vector3.ZERO, Vector3(0, 0.3, -1), Vector3.UP)
	cam.current = true
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	quit()
