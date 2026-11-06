class_name GameUI
extends CanvasLayer
## Touch controls + HUD + title / pause / game-over screens, built in code.
## Portrait, one thumb: drag anywhere to steer (relative to where the finger went
## down), a quick tap = HOP. HOP / BRAKE buttons sit in the bottom corners.
## Keyboard (desktop testing): A/D or arrows steer, Space hop, S/Down brake, Esc pause.

signal start_requested
signal hop_requested
signal pause_toggled

const RED := Color(0.92, 0.12, 0.08)
const FONT_TITLE := preload("res://assets/fonts/PlayfairDisplay.ttf")
const FONT_HUD := preload("res://assets/fonts/VT323-Regular.ttf")

var steer := 0.0
var brake_held := false
var state := "title"   # title | play | pause | over

var _steer_touch := -1
var _steer_origin := Vector2.ZERO
var _steer_pos := Vector2.ZERO
var _steer_t0 := 0.0
var _brake_touch := -1
var _key_steer := 0.0
var _pad: Control
var _hud: Control
var _title: Control
var _over: Control
var _pause: Control
var _hints: Control
var _dist_label: Label
var _speed_label: Label
var _rec_label: Label
var _time_label: Label
var _over_reason: Label
var _over_dist: Label
var _over_best: Label
var _title_best: Label
var _tap_label: Label
var _over_tap: Label
var _t := 0.0
var _over_t := 0.0
var _hint_t := 0.0
var _clock := 23 * 3600 + 41 * 60.0
var _title_font: FontVariation

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_title_font = FontVariation.new()
	_title_font.base_font = FONT_TITLE
	_title_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 900}
	_pad = TouchPad.new()
	_pad.ui = self
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pad)
	_build_hud()
	_build_title()
	_build_over()
	_build_pause()
	set_state("title")

# ------------------------------------------------------------------ helpers

func _label(text: String, size: int, color := Color.WHITE, font: Font = FONT_HUD) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _glow(l: Label, outline: Color, outline_size: int, glow: Color, glow_size: int) -> void:
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", outline_size)
	l.add_theme_color_override("font_shadow_color", glow)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", glow_size)

func _full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c

func _vbox(parent: Control, sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)
	return v

func _center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _bar(parent: Control, w: float) -> void:
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := ColorRect.new()
	r.color = RED
	r.custom_minimum_size = Vector2(w, 3)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(r)
	parent.add_child(c)

# ------------------------------------------------------------------ build

func _build_hud() -> void:
	_hud = _full(Control.new())
	_dist_label = _center(_label("0000 M", 54, Color(0.95, 0.9, 0.85)))
	_glow(_dist_label, Color(0.1, 0, 0), 4, Color(1, 0.1, 0.05, 0.55), 14)
	_dist_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_dist_label.position = Vector2(-150, 14)
	_dist_label.size = Vector2(300, 60)
	_hud.add_child(_dist_label)
	_speed_label = _center(_label("00 KM/H", 26, Color(0.85, 0.75, 0.7, 0.8)))
	_speed_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_speed_label.position = Vector2(-100, 70)
	_speed_label.size = Vector2(200, 30)
	_hud.add_child(_speed_label)
	_rec_label = _label("● REC", 32, RED)
	_rec_label.position = Vector2(30, 18)
	_hud.add_child(_rec_label)
	_time_label = _label("NOV 06 1984  23:41:00", 24, Color(0.9, 0.85, 0.8, 0.75))
	_time_label.position = Vector2(30, 52)
	_hud.add_child(_time_label)
	var pause_l := _label("II", 40, Color(0.95, 0.9, 0.85, 0.8))
	pause_l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_l.position = Vector2(-70, 14)
	_hud.add_child(pause_l)
	_hints = Control.new()
	_hints.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hints)
	var hl := _center(_label("◀  DRAG TO STEER  ▶", 36, Color(1, 0.9, 0.85, 0.9)))
	hl.set_anchors_preset(Control.PRESET_CENTER)
	hl.position = Vector2(-260, 120)
	hl.size = Vector2(520, 40)
	_glow(hl, Color(0, 0, 0, 0.8), 6, Color(0, 0, 0, 0), 0)
	_hints.add_child(hl)
	var hr := _center(_label("TAP TO HOP OVER POTHOLES", 30, Color(1, 0.9, 0.85, 0.9)))
	hr.set_anchors_preset(Control.PRESET_CENTER)
	hr.position = Vector2(-260, 165)
	hr.size = Vector2(520, 40)
	_glow(hr, Color(0, 0, 0, 0.8), 6, Color(0, 0, 0, 0), 0)
	_hints.add_child(hr)

func _build_title() -> void:
	_title = _full(Control.new())
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(shade)
	var v := _vbox(_title, 4)
	v.offset_top = -10
	_bar(v, 540)
	var t := _center(_label("NIGHT RIDE", 100, Color(0.06, 0.0, 0.0), _title_font))
	_glow(t, RED, 5, Color(1.0, 0.08, 0.04, 0.75), 26)
	v.add_child(t)
	_bar(v, 540)
	var sub := _center(_label("D O N ' T   S T O P   P E D A L I N G", 24, Color(0.95, 0.75, 0.7, 0.85)))
	v.add_child(sub)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 640)
	v.add_child(sp)
	_tap_label = _center(_label("TAP TO RIDE", 46, Color(1, 0.92, 0.88)))
	_glow(_tap_label, Color(0.2, 0, 0), 4, Color(1, 0.1, 0.05, 0.6), 12)
	v.add_child(_tap_label)
	_title_best = _center(_label("", 28, Color(0.9, 0.7, 0.65, 0.8)))
	v.add_child(_title_best)

func _build_over() -> void:
	_over = _full(Control.new())
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0, 0.01, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.add_child(shade)
	var v := _vbox(_over, 2)
	var t := _center(_label("WIPED OUT", 86, Color(0.06, 0, 0), _title_font))
	_glow(t, RED, 5, Color(1, 0.08, 0.04, 0.75), 24)
	v.add_child(t)
	_over_reason = _center(_label("", 32, Color(0.95, 0.8, 0.75)))
	v.add_child(_over_reason)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	v.add_child(sp)
	_over_dist = _center(_label("0 M", 72, Color(0.98, 0.94, 0.9)))
	_glow(_over_dist, Color(0.1, 0, 0), 4, Color(1, 0.1, 0.05, 0.5), 14)
	v.add_child(_over_dist)
	_over_best = _center(_label("", 30, Color(0.9, 0.7, 0.65, 0.85)))
	v.add_child(_over_best)
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 30)
	v.add_child(sp2)
	_over_tap = _center(_label("TAP TO RIDE AGAIN", 40, Color(1, 0.92, 0.88)))
	v.add_child(_over_tap)

func _build_pause() -> void:
	_pause = _full(Control.new())
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause.add_child(shade)
	var v := _vbox(_pause, 10)
	var t := _center(_label("PAUSED", 90, Color(0.06, 0, 0), _title_font))
	_glow(t, RED, 5, Color(1, 0.08, 0.04, 0.7), 22)
	v.add_child(t)
	v.add_child(_center(_label("TAP TO CONTINUE", 40, Color(1, 0.92, 0.88))))

# ------------------------------------------------------------------ state

func set_state(s: String) -> void:
	state = s
	_title.visible = s == "title"
	_hud.visible = s == "play" or s == "pause"
	_over.visible = s == "over"
	_pause.visible = s == "pause"
	_pad.visible = s == "play"
	if s == "play":
		_hint_t = 7.0
	if s == "over":
		_over_t = 0.0
	_steer_touch = -1
	_brake_touch = -1
	brake_held = false
	steer = 0.0

func show_title(best: float) -> void:
	_title_best.text = ("BEST  %d M" % int(best)) if best > 0.0 else ""
	set_state("title")

func show_over(reason: String, dist: float, best: float, is_new: bool) -> void:
	_over_reason.text = reason
	_over_dist.text = "%d M" % int(dist)
	_over_best.text = ("NEW BEST!" if is_new else "BEST  %d M" % int(best))
	set_state("over")

func update_hud(dist: float, speed_ms: float, delta: float) -> void:
	_dist_label.text = "%04d M" % int(dist)
	_speed_label.text = "%02d KM/H" % int(speed_ms * 3.6)
	_clock += delta
	var c := int(_clock)
	_time_label.text = "NOV 06 1984  %02d:%02d:%02d" % [(c / 3600) % 24, (c / 60) % 60, c % 60]

func _process(delta: float) -> void:
	_t += delta
	_rec_label.modulate.a = 1.0 if fmod(_t, 1.0) < 0.6 else 0.15
	_tap_label.modulate.a = 0.55 + 0.45 * sin(_t * 3.0)
	_over_t += delta
	_over_tap.modulate.a = (0.55 + 0.45 * sin(_t * 3.0)) if _over_t > 1.0 else 0.0
	if _hint_t > 0.0:
		_hint_t -= delta
	_hints.modulate.a = clampf(_hint_t / 1.5, 0.0, 1.0)
	# Keyboard steering (desktop).
	var k := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		k -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		k += 1.0
	_key_steer = k
	if _steer_touch < 0:
		steer = _key_steer
	var kb_brake := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	brake_held = (_brake_touch >= 0) or kb_brake
	_pad.queue_redraw()

# ------------------------------------------------------------------ input

func hop_center() -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	return Vector2(vs.x - 125, vs.y - 170)

func brake_center() -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	return Vector2(115, vs.y - 150)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_W, KEY_UP:
				if state == "play":
					hop_requested.emit()
				elif state != "pause":
					start_requested.emit()
			KEY_ENTER:
				if state == "title" or (state == "over" and _over_t > 1.0):
					start_requested.emit()
			KEY_ESCAPE, KEY_P:
				if state == "play" or state == "pause":
					pause_toggled.emit()
		return
	if event is InputEventScreenTouch:
		_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		if event.index == _steer_touch:
			_steer_pos = event.position
			steer = clampf((_steer_pos.x - _steer_origin.x) / 110.0, -1.0, 1.0)

func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var vs := get_viewport().get_visible_rect().size
	if not pressed:
		if idx == _steer_touch:
			_steer_touch = -1
			steer = _key_steer
			# Quick tap without dragging = hop.
			if state == "play" and _t - _steer_t0 < 0.22 and pos.distance_to(_steer_origin) < 28.0:
				hop_requested.emit()
		if idx == _brake_touch:
			_brake_touch = -1
		return
	match state:
		"title":
			start_requested.emit()
			return
		"over":
			if _over_t > 1.0:
				start_requested.emit()
			return
		"pause":
			pause_toggled.emit()
			return
	# Playing.
	if pos.x > vs.x - 120 and pos.y < 110:
		pause_toggled.emit()
		return
	if pos.distance_to(brake_center()) < 80.0:
		_brake_touch = idx
		return
	if pos.distance_to(hop_center()) < 95.0:
		hop_requested.emit()
		return
	if _steer_touch < 0:
		_steer_touch = idx
		_steer_t0 = _t
		_steer_origin = pos
		_steer_pos = pos
		steer = 0.0

class TouchPad extends Control:
	var ui: GameUI

	func _draw() -> void:
		if ui == null:
			return
		var hop := ui.hop_center()
		var brk := ui.brake_center()
		var col := Color(1, 0.92, 0.88, 0.16)
		var edge := Color(1, 0.3, 0.2, 0.55)
		draw_circle(hop, 88, col)
		draw_arc(hop, 88, 0, TAU, 48, edge, 3.0, true)
		draw_string(GameUI.FONT_HUD, hop + Vector2(-34, 14), "HOP", HORIZONTAL_ALIGNMENT_CENTER, -1, 44, Color(1, 0.95, 0.9, 0.85))
		var bcol := Color(1, 0.92, 0.88, 0.28) if ui.brake_held else col
		draw_circle(brk, 62, bcol)
		draw_arc(brk, 62, 0, TAU, 40, edge, 3.0, true)
		draw_string(GameUI.FONT_HUD, brk + Vector2(-38, 11), "BRAKE", HORIZONTAL_ALIGNMENT_CENTER, -1, 32, Color(1, 0.95, 0.9, 0.8))
		if ui._steer_touch >= 0:
			var o := ui._steer_origin
			draw_arc(o, 110, 0, TAU, 48, Color(1, 0.9, 0.85, 0.25), 3.0, true)
			draw_line(o + Vector2(-110, 0), o + Vector2(110, 0), Color(1, 0.9, 0.85, 0.15), 2.0)
			draw_circle(o + Vector2(ui.steer * 110.0, 0), 34, Color(1, 0.35, 0.25, 0.45))
