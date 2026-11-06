extends SceneTree
## Dev tool: boots the game, auto-rides (dodging obstacles), saves screenshots.
## Usage: xvfb-run godot --rendering-driver opengl3 -s tools/capture.gd -- <out_prefix> [start_s] [shots]

var game: Node

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://cap"
	var start_s: float = float(args[1]) if args.size() > 1 else 0.0
	var shots: int = int(args[2]) if args.size() > 2 else 4
	var auto := not (args.size() > 3 and args[3] == "noauto")
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	for i in 30:
		await process_frame
	await _shot(out + "_title.png")
	if start_s > 0.0:
		game.player.s = start_s
		if not auto:
			game.player.lat = -0.3
	game._start_ride()
	var t := 0.0
	var n := 0
	var next_shot := 2.5
	while n < shots:
		await process_frame
		var dt := get_root().get_process_delta_time()
		t += dt
		if auto:
			_autopilot()
		if t >= next_shot:
			await _shot("%s_%02d.png" % [out, n])
			print("shot ", n, " s=", snappedf(game.player.s, 0.1), " state=", game.state, " zone=", World.zone_at(game.player.s), " fps=", Engine.get_frames_per_second())
			n += 1
			next_shot += 2.2
		if game.state == "crashed" and not has_meta("crash_shot"):
			set_meta("crash_shot", true)
			for k in 12:
				await process_frame
			await _shot("%s_crash.png" % out)
		if game.state == "over":
			for k in 40:
				await process_frame
			await _shot("%s_over.png" % out)
			print("crashed at ", game.player.s)
			break
	quit()

func _autopilot() -> void:
	var p = game.player
	var best_lat: float = p.lat
	var danger := false
	for o in game.world.obstacles:
		var ds: float = o.s - p.s
		if ds > 0.0 and ds < 14.0 and o.type != "ramp" and o.type != "rough":
			if absf(o.lat - p.lat) < o.half_w + 0.9:
				danger = true
				best_lat = o.lat - signf(o.lat - p.lat + 0.001) * (o.half_w + 1.3)
				if absf(best_lat) > 3.2:
					best_lat = o.lat + signf(o.lat) * -1.0 * (o.half_w + 1.3)
	var target := best_lat if danger else 1.6
	game.ui.steer = clampf((target - p.lat) * 0.8, -1.0, 1.0)

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(path)
