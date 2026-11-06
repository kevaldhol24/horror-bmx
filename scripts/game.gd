extends Node3D
## Root of the game. Builds the scene in code, runs the title -> ride ->
## wipe-out loop, resolves obstacle collisions and drives the horror FX.

const SAVE_PATH := "user://save.cfg"

var world: World
var player: Player
var cam: ChaseCamera
var ui: GameUI
var audio: AudioDirector
var env: Environment
var sky_mat: ShaderMaterial
var moon: DirectionalLight3D
var vhs_mat: ShaderMaterial
var spores: CPUParticles3D

var state := "title"
var best := 0.0
var _lightning_timer := 6.0
var _flash := 0.0
var _thunder_delay := -1.0
var _danger := 0.0
var _glitch := 0.0
var _over_timer := 0.0

func _ready() -> void:
	_load_best()
	_build_environment()
	world = World.new()
	world.name = "World"
	add_child(world)
	world.watcher_seen.connect(_on_watcher)
	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.crashed.connect(_on_crashed)
	player.hopped.connect(func(): audio.play("hop", -4.0, randf_range(0.9, 1.1)))
	player.landed.connect(_on_landed)
	cam = ChaseCamera.new()
	cam.target = player
	add_child(cam)
	cam.current = true
	_build_overlay()
	_build_spores()
	audio = AudioDirector.new()
	add_child(audio)
	ui = GameUI.new()
	add_child(ui)
	ui.start_requested.connect(_start_ride)
	ui.hop_requested.connect(func(): player.try_hop())
	ui.pause_toggled.connect(_toggle_pause)
	_go_title()

# ------------------------------------------------------------------ setup

func _build_environment() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_AUTOMATIC
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.12, 0.12)
	env.ambient_light_energy = 0.22
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.26, 0.03, 0.028)
	env.fog_light_energy = 1.0
	env.fog_density = 0.0105
	env.fog_sky_affect = 0.15
	env.fog_height = 6.0
	env.fog_height_density = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(1.0, 0.35, 0.28)
	moon.light_energy = 0.45
	moon.shadow_enabled = false
	add_child(moon)
	# Light comes from the red horizon ahead, so riders read as silhouettes.
	moon.look_at_from_position(Vector3.ZERO, Vector3(-0.25, -0.35, 0.94), Vector3.UP)
	sky_mat.set_shader_parameter("moon_dir", Vector3(0.25, 0.22, -0.94))

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_mat = ShaderMaterial.new()
	vhs_mat.shader = preload("res://shaders/vhs.gdshader")
	rect.material = vhs_mat
	layer.add_child(rect)

func _build_spores() -> void:
	# Drifting ash / spores, always around the camera.
	spores = CPUParticles3D.new()
	spores.amount = 220
	spores.lifetime = 7.0
	spores.preprocess = 7.0
	spores.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	spores.emission_box_extents = Vector3(16, 7, 22)
	spores.direction = Vector3(0.2, 1, 0)
	spores.spread = 60.0
	spores.gravity = Vector3(0.0, 0.08, 0.0)
	spores.initial_velocity_min = 0.05
	spores.initial_velocity_max = 0.35
	spores.scale_amount_min = 0.5
	spores.scale_amount_max = 1.4
	spores.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.75, 0.65, 0.55)
	m.disable_fog = true
	q.material = m
	spores.mesh = q
	add_child(spores)

# ------------------------------------------------------------------ flow

func _go_title() -> void:
	state = "title"
	get_tree().paused = false
	world.reset_world()
	player.reset_to_start()
	world.update_world(player.s, 0.0)
	cam.mode = "orbit"
	cam.snap()
	ui.show_title(best)

func _start_ride() -> void:
	if state == "over":
		world.reset_world()
		player.reset_to_start()
		world.update_world(player.s, 0.0)
		cam.mode = "chase"
		cam.snap()
	state = "play"
	player.active = true
	player.speed = maxf(player.speed, 3.0)
	cam.mode = "chase"
	ui.set_state("play")

func _toggle_pause() -> void:
	if state == "play":
		state = "pause"
		get_tree().paused = true
		ui.set_state("pause")
	elif state == "pause":
		state = "play"
		get_tree().paused = false
		ui.set_state("play")

func _on_crashed(reason: String) -> void:
	state = "crashed"
	_over_timer = 1.4
	cam.mode = "crash"
	cam.add_trauma(0.9)
	_glitch = 1.0
	_danger = 1.0
	audio.play("crash", 0.0)
	Input.vibrate_handheld(180)
	var dist := player.s
	var is_new := dist > best
	if is_new:
		best = dist
		_save_best()
	ui.set_meta("pending", [reason, dist, best, is_new])

func _on_landed(impact: float) -> void:
	if impact > 3.0:
		audio.play("land", lerpf(-12.0, -2.0, clampf((impact - 3.0) / 6.0, 0, 1)))
		cam.add_trauma(clampf(impact / 14.0, 0.0, 0.5))

func _on_watcher() -> void:
	audio.play("sting", -3.0)
	audio.play("buzz", -6.0)
	_glitch = maxf(_glitch, 0.8)
	_danger = maxf(_danger, 0.6)
	cam.add_trauma(0.25)

# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	if state == "pause":
		return
	world.update_world(player.s, delta)
	if state == "play":
		player.steer_in = ui.steer
		player.brake_in = ui.brake_held
		_check_collisions()
		ui.update_hud(player.s, player.speed, delta)
	elif state == "crashed":
		player.steer_in = 0.0
		_over_timer -= delta
		if _over_timer <= 0.0:
			state = "over"
			var p: Array = ui.get_meta("pending")
			ui.show_over(p[0], p[1], p[2], p[3])
	var riding := state == "play"
	audio.update_ride(player.speed, player.is_airborne(), player.model.effort > 0.4 or player.speed < player.cruise_target(), player.rough_t > 0.0, riding, delta)
	audio.set_music_level(-9.0 if state != "crashed" else -20.0, delta)
	_update_fx(delta)
	spores.global_position = cam.global_position + (-cam.global_basis.z) * 12.0

func _check_collisions() -> void:
	var ground_air := player.air
	for o in world.obstacles:
		var ds: float = o.s - player.s
		if absf(ds) > o.half_len + 0.5:
			continue
		if absf(player.lat - o.lat) > o.half_w + Player.BIKE_HALF_W:
			continue
		if absf(ds) > o.half_len:
			continue
		match o.type:
			"ramp":
				if not o.hit and not player.is_airborne():
					o.hit = true
					player.launch(2.6 + player.speed * 0.36)
					cam.add_trauma(0.2)
			"rough":
				player.rough_t = 0.25
				if not o.hit:
					o.hit = true
					cam.add_trauma(0.15)
			_:
				if ground_air < o.height:
					var reasons := {
						"pothole": "HIT A POTHOLE",
						"rubble": "WRECKED ON BROKEN ROAD",
						"barrier": "ROAD CLOSED",
						"log": "TOOK A TREE TO THE FACE",
					}
					player.crash(reasons.get(o.type, "WIPED OUT"))
					return

func _update_fx(delta: float) -> void:
	# Lightning.
	_lightning_timer -= delta
	if _lightning_timer <= 0.0:
		_lightning_timer = randf_range(9.0, 22.0)
		_flash = 1.0
		_thunder_delay = randf_range(0.3, 1.6)
		world.flicker_burst(0.5)
	if _thunder_delay > 0.0:
		_thunder_delay -= delta
		if _thunder_delay <= 0.0:
			audio.play("thunder", randf_range(-6.0, 0.0), randf_range(0.85, 1.1))
			cam.add_trauma(0.12)
	# Double-strike flash envelope.
	_flash = maxf(0.0, _flash - delta * 2.2)
	var f := _flash * (0.6 + 0.4 * sin(_flash * 40.0))
	sky_mat.set_shader_parameter("flash", f)
	moon.light_energy = 0.45 + f * 2.5
	env.ambient_light_energy = 0.22 + f * 0.9
	# Danger pulse when close to the Watcher / after a crash.
	_danger = maxf(0.0, _danger - delta * 0.6)
	_glitch = maxf(0.0, _glitch - delta * 0.9)
	vhs_mat.set_shader_parameter("danger", _danger)
	vhs_mat.set_shader_parameter("glitch", _glitch)
	vhs_mat.set_shader_parameter("flash", f * 0.08)
	# Headlight flickers with the weirdness too.
	var hl := 11.0
	if _glitch > 0.2 and sin(Time.get_ticks_msec() * 0.05) > 0.3:
		hl = 1.0
	player.headlight.light_energy = hl

# ------------------------------------------------------------------ save

func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		best = float(cf.get_value("run", "best", 0.0))

func _save_best() -> void:
	var cf := ConfigFile.new()
	cf.set_value("run", "best", best)
	cf.save(SAVE_PATH)
