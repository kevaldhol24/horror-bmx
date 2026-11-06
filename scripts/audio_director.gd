class_name AudioDirector
extends Node
## Loops (music, ambience, tyres, freewheel, rough road) + one-shots.

const A := "res://assets/audio/"

var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var tire: AudioStreamPlayer
var freewheel: AudioStreamPlayer
var rough: AudioStreamPlayer
var _oneshots := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = _loop("synth_theme.wav", -9.0)
	ambience = _loop("ambience.wav", -8.0)
	tire = _loop("tire_roll.wav", -80.0)
	freewheel = _loop("freewheel.wav", -80.0)
	rough = _loop("rough.wav", -80.0)
	for n in ["thunder", "crash", "hop", "land", "sting", "buzz", "heartbeat"]:
		var p := AudioStreamPlayer.new()
		p.stream = load(A + n + ".wav")
		add_child(p)
		_oneshots[n] = p
	music.play()
	ambience.play()
	tire.play()
	freewheel.play()
	rough.play()

func _loop(file: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var st: AudioStreamWAV = load(A + file)
	st = st.duplicate()
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = int(st.get_length() * st.mix_rate)
	p.stream = st
	p.volume_db = db
	add_child(p)
	return p

func play(n: String, db := 0.0, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = _oneshots.get(n)
	if p:
		p.volume_db = db
		p.pitch_scale = pitch
		p.play()

func update_ride(speed: float, airborne: bool, pedaling: bool, rough_on: bool, riding: bool, delta: float) -> void:
	var sp := clampf(speed / 15.0, 0.0, 1.0)
	var tire_db := lerpf(-40.0, -10.0, sp) if (riding and not airborne and speed > 0.5) else -80.0
	tire.volume_db = lerpf(tire.volume_db, tire_db, 1.0 - exp(-8.0 * delta))
	tire.pitch_scale = lerpf(0.7, 1.35, sp)
	var fw_db := -16.0 if (riding and speed > 2.0 and (airborne or not pedaling)) else -80.0
	freewheel.volume_db = lerpf(freewheel.volume_db, fw_db, 1.0 - exp(-10.0 * delta))
	freewheel.pitch_scale = lerpf(0.6, 1.4, sp)
	var r_db := -6.0 if rough_on and not airborne else -80.0
	rough.volume_db = lerpf(rough.volume_db, r_db, 1.0 - exp(-12.0 * delta))

func set_music_level(db: float, delta: float) -> void:
	music.volume_db = lerpf(music.volume_db, db, 1.0 - exp(-2.0 * delta))
