class_name ParisWorld2D
extends Node2D

## 2.5D Top-Down Hand-Painted Parisian Adventure World ('Bonjour Paris !')
## Renders the hand-painted Studio Ghibli-style Parisian map background,
## interactive item pickup stations, customer service table, street direction checkpoints,
## neighborhood exit archway, animated player with carry tray, and floating coin/heart popups.

signal station_interacted(vocab_id: String, station_pos: Vector2)
signal table_interacted(table_pos: Vector2)
signal direction_pad_entered(dir_key: String, pad_pos: Vector2)
signal exit_gate_entered()
signal phrase_option_selected(opt_text: String, idx: int)

const VIEW_W := 1280.0
const VIEW_H := 720.0

var map_textures: Dictionary = {}
var item_textures: Dictionary = {}
var player_tex: Texture2D
var customer_tex: Texture2D
var chloe_tex: Texture2D
var font_res: Font

var current_map_bg: String = "res://assets/sprites/map_cafe.jpg"
var current_mode: String = "MENU" # "MENU", "VOCAB", "COMBO", "DIRECTION", "DAILY_PHRASE", "GALLERY", "WAVE_SUMMARY"

var player_pos: Vector2 = Vector2(590.0, 560.0)
var player_vel: Vector2 = Vector2.ZERO
var player_target_pos: Vector2 = Vector2(-1.0, -1.0)
var player_facing: float = 1.0
var player_walk_phase: float = 0.0
var dash_timer: float = 0.0
var tray_items: Array = []

# Stations: Array of { "id": String, "fr": String, "en": String, "pos": Vector2, "highlight": bool, "show_en": bool, "slot": int }
var stations: Array[Dictionary] = []

# Customer Table state
var table_pos: Vector2 = Vector2(590.0, 470.0)
var table_visible: bool = true
var customer_order_ids: Array = []
var customer_order_text: String = ""
var customer_sub_text: String = ""
var customer_satisfied: bool = false
var patience_ratio: float = 1.0

# Direction Checkpoints: Array of { "key": String, "fr": String, "en": String, "badge": String, "pos": Vector2, "state": String ("active", "done", "idle") }
var dir_checkpoints: Array[Dictionary] = []

# Conversation Phrase Options (for DAILY_PHRASE / GRAMMAR)
var phrase_options: Array = []
var phrase_highlight_opt: String = ""

# Exit Archway state
var exit_gate_pos: Vector2 = Vector2(1145.0, 445.0)
var exit_gate_open: bool = false
var exit_gate_label: String = "★ NEXT CHAPTER →"

# Floating Popups & Sunlit Dust Particles
var popups: Array[Dictionary] = []
var dust_motes: Array[Dictionary] = []
var _anim_time: float = 0.0
var _station_cooldown: float = 0.0
var _table_cooldown: float = 0.0


func _ready() -> void:
	font_res = load("res://assets/fonts/DejaVuSans.ttf") as Font
	if ResourceLoader.exists("res://assets/sprites/player_char.svg"):
		player_tex = load("res://assets/sprites/player_char.svg") as Texture2D
	if ResourceLoader.exists("res://assets/sprites/customer_char.svg"):
		customer_tex = load("res://assets/sprites/customer_char.svg") as Texture2D
	if ResourceLoader.exists("res://assets/sprites/chloe_portrait.jpg"):
		chloe_tex = load("res://assets/sprites/chloe_portrait.jpg") as Texture2D

	for i in range(28):
		dust_motes.append({
			"pos": Vector2(randf_range(40.0, VIEW_W - 40.0), randf_range(80.0, VIEW_H - 80.0)),
			"vel": Vector2(randf_range(8.0, 22.0), randf_range(-6.0, 10.0)),
			"r": randf_range(2.0, 4.5),
			"phase": randf() * TAU,
		})


func get_map_tex(path: String) -> Texture2D:
	if map_textures.has(path):
		return map_textures[path]
	if ResourceLoader.exists(path):
		var t := load(path) as Texture2D
		if t:
			map_textures[path] = t
			return t
	return null


func get_item_tex(vid: String) -> Texture2D:
	if item_textures.has(vid):
		return item_textures[vid]
	var path := "res://assets/sprites/items/%s.svg" % vid
	if ResourceLoader.exists(path):
		var t := load(path) as Texture2D
		if t:
			item_textures[vid] = t
			return t
	return null


func spawn_popup(pos: Vector2, text: String, col: Color = Color(1.0, 0.92, 0.36)) -> void:
	popups.append({
		"pos": pos,
		"text": text,
		"col": col,
		"life": 1.35,
		"max_life": 1.35,
	})


func clear_tray() -> void:
	tray_items.clear()
	queue_redraw()


func setup_stations_for_items(item_dicts: Array, highlight_ids: Array, show_english_labels: bool) -> void:
	stations.clear()
	var n := item_dicts.size()
	var xs := [215.0, 402.0, 590.0, 778.0, 965.0]
	var ys := [250.0, 232.0, 224.0, 232.0, 250.0]
	for i in range(n):
		var d: Dictionary = item_dicts[i]
		var vid := str(d.get("id", "tasse"))
		var sx: float = xs[i] if i < xs.size() else (200.0 + float(i) * 190.0)
		var sy: float = ys[i] if i < ys.size() else 245.0
		stations.append({
			"id": vid,
			"fr": str(d.get("fr_def", vid)),
			"en": str(d.get("en", "")),
			"pos": Vector2(sx, sy),
			"highlight": highlight_ids.has(vid),
			"show_en": show_english_labels or highlight_ids.has(vid),
			"slot": i + 1,
		})
	queue_redraw()


func setup_direction_checkpoints(steps: Array, cur_idx: int) -> void:
	dir_checkpoints.clear()
	var layout := {
		"gauche": Vector2(280.0, 445.0),
		"avant": Vector2(465.0, 325.0),
		"haut": Vector2(715.0, 325.0),
		"arriere": Vector2(590.0, 540.0),
		"droite": Vector2(900.0, 445.0),
	}
	var cur_key: String = str(steps[cur_idx]) if cur_idx < steps.size() else ""
	var order := ["gauche", "avant", "haut", "arriere", "droite"]
	for k in order:
		var info: Dictionary = VocabData.DIRECTION_INFO[k]
		var state_s := "idle"
		if k == cur_key:
			state_s = "active"
		else:
			for idx in range(cur_idx):
				if str(steps[idx]) == k:
					state_s = "done"
		dir_checkpoints.append({
			"key": k,
			"fr": str(info["fr"]),
			"en": str(info["en"]),
			"badge": str(info["badge"]),
			"pos": layout[k],
			"state": state_s,
		})
	queue_redraw()


func handle_click(click_pos: Vector2) -> void:
	if current_mode == "DAILY_PHRASE":
		var card_rects := _get_phrase_option_rects()
		for i in range(card_rects.size()):
			if card_rects[i].has_point(click_pos):
				phrase_option_selected.emit(str(phrase_options[i]), i)
				return

	# Check if clicked directly on a station, table, direction checkpoint, or exit gate
	player_target_pos = click_pos.clamp(Vector2(90.0, 185.0), Vector2(1190.0, 615.0))


func _get_phrase_option_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var n := phrase_options.size()
	var xs := [225.0, 640.0, 1055.0]
	for i in range(n):
		var cx: float = xs[i] if i < xs.size() else (225.0 + float(i) * 415.0)
		var cy := 345.0
		rects.append(Rect2(Vector2(cx - 195.0, cy - 58.0), Vector2(390.0, 116.0)))
	return rects


func _process(delta: float) -> void:
	_anim_time += delta
	if _station_cooldown > 0.0:
		_station_cooldown = maxf(0.0, _station_cooldown - delta)
	if _table_cooldown > 0.0:
		_table_cooldown = maxf(0.0, _table_cooldown - delta)
	if dash_timer > 0.0:
		dash_timer = maxf(0.0, dash_timer - delta)

	# Update sunlit dust motes
	for m in dust_motes:
		var p: Vector2 = m["pos"] + m["vel"] * delta
		if p.x > VIEW_W:
			p.x = 0.0
		if p.y < 60.0:
			p.y = VIEW_H - 60.0
		if p.y > VIEW_H - 60.0:
			p.y = 60.0
		m["pos"] = p

	# Update floating popups
	for i in range(popups.size() - 1, -1, -1):
		var pop: Dictionary = popups[i]
		pop["life"] = float(pop["life"]) - delta
		pop["pos"] = (pop["pos"] as Vector2) + Vector2(0.0, -38.0 * delta)
		if float(pop["life"]) <= 0.0:
			popups.remove_at(i)

	# Player WASD / Arrow Keys & Click-to-Walk Movement
	var move_in := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		move_in.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		move_in.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		move_in.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		move_in.y += 1.0

	if Input.is_physical_key_pressed(KEY_SHIFT) and dash_timer <= 0.0:
		dash_timer = 0.25

	var spd := 520.0 if dash_timer > 0.0 else 340.0
	if move_in.length_squared() > 0.01:
		player_target_pos = Vector2(-1.0, -1.0)
		move_in = move_in.normalized()
		player_vel = move_in * spd
		player_pos += player_vel * delta
		if absf(move_in.x) > 0.05:
			player_facing = signf(move_in.x)
		player_walk_phase += delta * 14.0
	elif player_target_pos.x >= 0.0:
		var diff := player_target_pos - player_pos
		if diff.length() <= 10.0:
			player_pos = player_target_pos
			player_target_pos = Vector2(-1.0, -1.0)
			player_vel = Vector2.ZERO
		else:
			var dir := diff.normalized()
			player_vel = dir * (spd * 1.15)
			player_pos += player_vel * delta
			if absf(dir.x) > 0.05:
				player_facing = signf(dir.x)
			player_walk_phase += delta * 15.0
	else:
		player_vel = Vector2.ZERO

	player_pos.x = clampf(player_pos.x, 90.0, 1190.0)
	player_pos.y = clampf(player_pos.y, 185.0, 610.0)

	# Check Proximity Interactions!
	if current_mode in ["VOCAB", "COMBO", "GALLERY"]:
		if _station_cooldown <= 0.0:
			for st in stations:
				var s_pos: Vector2 = st["pos"]
				if player_pos.distance_to(s_pos) < 58.0:
					_station_cooldown = 0.52
					player_target_pos = Vector2(-1.0, -1.0)
					station_interacted.emit(str(st["id"]), s_pos)
					break

		if table_visible and _table_cooldown <= 0.0 and not tray_items.is_empty():
			if player_pos.distance_to(table_pos) < 76.0:
				_table_cooldown = 0.55
				player_target_pos = Vector2(-1.0, -1.0)
				table_interacted.emit(table_pos)

	elif current_mode == "DIRECTION":
		for cp in dir_checkpoints:
			if str(cp["state"]) == "active":
				var c_pos: Vector2 = cp["pos"]
				if player_pos.distance_to(c_pos) < 66.0:
					player_target_pos = Vector2(-1.0, -1.0)
					direction_pad_entered.emit(str(cp["key"]), c_pos)
					break

	elif current_mode == "DAILY_PHRASE":
		var rects := _get_phrase_option_rects()
		for i in range(rects.size()):
			var center := rects[i].get_center()
			if player_pos.distance_to(center) < 58.0 and _station_cooldown <= 0.0:
				_station_cooldown = 0.65
				player_target_pos = Vector2(-1.0, -1.0)
				phrase_option_selected.emit(str(phrase_options[i]), i)
				break

	if exit_gate_open and player_pos.distance_to(exit_gate_pos) < 78.0:
		player_target_pos = Vector2(-1.0, -1.0)
		exit_gate_entered.emit()

	queue_redraw()


func _draw_pill(rect: Rect2, bg_col: Color, border_col: Color, border_w: float = 2.0, radius: float = 12.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(int(border_w))
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, rect)


func _draw() -> void:
	# 1. Hand-Painted Studio Ghibli / Parisian Storybook 2.5D Map Background
	var bg_tex := get_map_tex(current_map_bg)
	if bg_tex:
		draw_texture_rect(bg_tex, Rect2(0.0, 0.0, VIEW_W, VIEW_H), false)
	else:
		draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color(0.88, 0.80, 0.68))

	# Subtle warm vignette/contrast layer so interactive tokens & text pop with 100% clarity
	draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color(0.10, 0.07, 0.04, 0.14))

	# 2. Sunlit Parisian Dust Motes
	for m in dust_motes:
		var alpha := 0.25 + 0.20 * sin(_anim_time * 2.0 + float(m["phase"]))
		draw_circle(m["pos"], float(m["r"]), Color(1.0, 0.95, 0.72, alpha))

	# 3. Draw Interactive Pickup Stations (VOCAB, COMBO, GALLERY, MENU preview)
	if current_mode in ["VOCAB", "COMBO", "GALLERY", "MENU"]:
		for st in stations:
			_draw_station(st)

	# 4. Draw Customer Service Table (VOCAB, COMBO)
	if table_visible and current_mode in ["VOCAB", "COMBO"]:
		_draw_customer_table()

	# 5. Draw Street Direction Checkpoints (DIRECTION)
	if current_mode == "DIRECTION":
		_draw_direction_checkpoints()

	# 6. Draw Conversational Response Cards on the Terrace (DAILY_PHRASE)
	if current_mode == "DAILY_PHRASE":
		_draw_phrase_cards()

	# 7. Draw Neighborhood Exit Archway Gate (when Chapter Complete or during play)
	if current_mode != "MENU":
		_draw_exit_gate()

	# 8. Draw Animated Player Character & Overhead Bistro Tray
	_draw_player()

	# 9. Draw Floating Score / Feedback Popups
	for pop in popups:
		var life_ratio := clampf(float(pop["life"]) / float(pop["max_life"]), 0.0, 1.0)
		var p_pos: Vector2 = pop["pos"]
		var col: Color = pop["col"]
		col.a = life_ratio
		var txt := str(pop["text"])
		if font_res:
			var r := Rect2(p_pos.x - 135.0, p_pos.y - 20.0, 270.0, 34.0)
			_draw_pill(r, Color(0.12, 0.09, 0.06, 0.88 * life_ratio), col, 2.0, 10.0)
			draw_string(font_res, Vector2(r.position.x, p_pos.y + 4.0), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, col)


func _draw_station(st: Dictionary) -> void:
	var pos: Vector2 = st["pos"]
	var vid := str(st["id"])
	var is_hi := bool(st["highlight"])
	var in_tray := tray_items.has(vid)
	var pulse := sin(_anim_time * 5.0) * 0.5 + 0.5

	# Counter pedestal shadow
	draw_circle(pos + Vector2(0.0, 8.0), 48.0, Color(0.08, 0.05, 0.03, 0.38))

	# Spotlight pulse ring for new words or hints
	if is_hi:
		draw_arc(pos, 54.0 + pulse * 6.0, 0.0, TAU, 48, Color(1.0, 0.86, 0.22, 0.95), 5.0, true)
		var arrow_y := pos.y - 84.0 - pulse * 8.0
		var pill_r := Rect2(pos.x - 95.0, arrow_y - 26.0, 190.0, 28.0)
		_draw_pill(pill_r, Color(0.16, 0.11, 0.05, 0.94), Color(1.0, 0.86, 0.24), 2.0, 8.0)
		if font_res:
			draw_string(font_res, Vector2(pill_r.position.x, arrow_y - 6.0), "⬇ PICK UP [%d] ⬇" % int(st["slot"]), HORIZONTAL_ALIGNMENT_CENTER, pill_r.size.x, 14, Color(1.0, 0.92, 0.38))
	elif in_tray:
		draw_arc(pos, 51.0, 0.0, TAU, 40, Color(0.28, 0.95, 0.56, 0.92), 4.0, true)

	# Crisp Vector Item Badge
	var itex := get_item_tex(vid)
	if itex:
		var sz := Vector2(88.0, 88.0)
		draw_texture_rect(itex, Rect2(pos - sz * 0.5, sz), false)
	else:
		draw_circle(pos, 40.0, Color(0.96, 0.88, 0.72))

	# Clean Label Pill below the station
	var show_en := bool(st["show_en"])
	var lbl_h := 44.0 if show_en else 28.0
	var lbl_w := 168.0
	var lbl_r := Rect2(pos.x - lbl_w * 0.5, pos.y + 42.0, lbl_w, lbl_h)
	var border_c := Color(1.0, 0.84, 0.22) if is_hi else (Color(0.32, 0.94, 0.58) if in_tray else Color(0.84, 0.68, 0.38, 0.92))
	_draw_pill(lbl_r, Color(0.13, 0.10, 0.08, 0.92), border_c, 2.0, 9.0)

	if font_res:
		var top_txt := "[%d] %s" % [int(st["slot"]), str(st["fr"])]
		draw_string(font_res, Vector2(lbl_r.position.x, lbl_r.position.y + 19.0), top_txt, HORIZONTAL_ALIGNMENT_CENTER, lbl_w, 15, Color(1.0, 0.97, 0.88))
		if show_en:
			draw_string(font_res, Vector2(lbl_r.position.x, lbl_r.position.y + 37.0), "(%s)" % str(st["en"]), HORIZONTAL_ALIGNMENT_CENTER, lbl_w, 13, Color(1.0, 0.86, 0.46))


func _draw_customer_table() -> void:
	var pulse := sin(_anim_time * 4.5) * 0.5 + 0.5
	var ready_to_serve := false
	if not customer_order_ids.is_empty():
		ready_to_serve = true
		for req_id in customer_order_ids:
			if not tray_items.has(str(req_id)):
				ready_to_serve = false
				break

	# Bistro table rug/halo
	var ring_col := Color(0.28, 0.96, 0.54, 0.95) if ready_to_serve else Color(1.0, 0.84, 0.28, 0.78)
	draw_circle(table_pos + Vector2(0.0, 10.0), 58.0, Color(0.10, 0.07, 0.04, 0.36))
	draw_arc(table_pos, 56.0 + (pulse * 6.0 if ready_to_serve else 0.0), 0.0, TAU, 48, ring_col, 4.5, true)

	# Round Parisian Marble Bistro Table
	draw_circle(table_pos, 46.0, Color(0.78, 0.56, 0.24))
	draw_circle(table_pos, 41.0, Color(0.97, 0.94, 0.88))

	# Draw Seated Customer slightly to the left of the table
	if customer_tex:
		var c_pos := table_pos + Vector2(-88.0, -48.0)
		draw_texture_rect(customer_tex, Rect2(c_pos, Vector2(76.0, 88.0)), false)

	# Draw Requested Item(s) inside the Table Order Bubble
	var n_req := customer_order_ids.size()
	for i in range(n_req):
		var rid := str(customer_order_ids[i])
		var offset_x := (float(i) - float(n_req - 1) * 0.5) * 44.0
		var icon_p := table_pos + Vector2(offset_x, -4.0)
		var itex := get_item_tex(rid)
		var has_it := tray_items.has(rid)
		if itex:
			draw_texture_rect(itex, Rect2(icon_p - Vector2(22.0, 22.0), Vector2(44.0, 44.0)), false)
		if has_it:
			draw_arc(icon_p, 23.0, 0.0, TAU, 24, Color(0.25, 0.96, 0.52), 3.0, true)

	# Action prompt below table
	var tbl_r := Rect2(table_pos.x - 165.0, table_pos.y + 50.0, 330.0, 32.0)
	var tbl_bg := Color(0.10, 0.24, 0.14, 0.94) if ready_to_serve else Color(0.14, 0.10, 0.07, 0.90)
	_draw_pill(tbl_r, tbl_bg, ring_col, 2.0, 9.0)
	if font_res:
		var prompt_t := "★ WALK HERE OR PRESS [SPACE] TO SERVE! ★" if ready_to_serve else "Table de Service (Pick up item above first!)"
		draw_string(font_res, Vector2(tbl_r.position.x, tbl_r.position.y + 21.0), prompt_t, HORIZONTAL_ALIGNMENT_CENTER, tbl_r.size.x, 13, Color(1.0, 0.96, 0.84))


func _draw_direction_checkpoints() -> void:
	var pulse := sin(_anim_time * 5.5) * 0.5 + 0.5
	for cp in dir_checkpoints:
		var pos: Vector2 = cp["pos"]
		var st := str(cp["state"])
		var r_col := Color(0.42, 0.82, 1.0, 0.80)
		var bg_col := Color(0.12, 0.18, 0.26, 0.86)
		var prefix := ""
		if st == "active":
			r_col = Color(1.0, 0.86, 0.20, 0.98)
			bg_col = Color(0.28, 0.20, 0.06, 0.94)
			prefix = "★ "
		elif st == "done":
			r_col = Color(0.28, 0.95, 0.54, 0.95)
			bg_col = Color(0.10, 0.24, 0.14, 0.92)
			prefix = "✓ "

		draw_circle(pos, 42.0, bg_col)
		draw_arc(pos, 44.0 + (pulse * 6.0 if st == "active" else 0.0), 0.0, TAU, 40, r_col, 4.5, true)

		var pill_w := 210.0
		var pill_r := Rect2(pos.x - pill_w * 0.5, pos.y - 16.0, pill_w, 32.0)
		_draw_pill(pill_r, bg_col, r_col, 2.0, 10.0)
		if font_res:
			draw_string(font_res, Vector2(pill_r.position.x, pill_r.position.y + 21.0), prefix + str(cp["badge"]), HORIZONTAL_ALIGNMENT_CENTER, pill_w, 14, Color(1.0, 0.97, 0.86))


func _draw_phrase_cards() -> void:
	var rects := _get_phrase_option_rects()
	for i in range(rects.size()):
		var r := rects[i]
		var opt := str(phrase_options[i])
		var is_hi: bool = (phrase_highlight_opt != "" and opt == phrase_highlight_opt)
		var border_c := Color(1.0, 0.86, 0.22) if is_hi else Color(0.84, 0.68, 0.38, 0.95)
		var bg_c := Color(0.24, 0.18, 0.07, 0.95) if is_hi else Color(0.14, 0.11, 0.09, 0.93)
		_draw_pill(r, bg_c, border_c, 3.0 if is_hi else 2.0, 14.0)
		if font_res:
			draw_string(font_res, Vector2(r.position.x, r.position.y + 30.0), "RESPONSE [%d]  (Click, Walk Here, or Press [%d])" % [i + 1, i + 1], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, Color(1.0, 0.86, 0.44))
			draw_string(font_res, Vector2(r.position.x + 8.0, r.position.y + 68.0), "« %s »" % opt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16.0, 14, Color(1.0, 0.98, 0.90))


func _draw_exit_gate() -> void:
	var pulse := sin(_anim_time * 5.0) * 0.5 + 0.5
	var g_col := Color(1.0, 0.86, 0.22, 0.98) if exit_gate_open else Color(0.75, 0.70, 0.62, 0.45)
	var bg_col := Color(0.24, 0.17, 0.05, 0.94) if exit_gate_open else Color(0.14, 0.12, 0.10, 0.65)
	draw_circle(exit_gate_pos, 46.0, bg_col)
	draw_arc(exit_gate_pos, 48.0 + (pulse * 7.0 if exit_gate_open else 0.0), 0.0, TAU, 40, g_col, 4.0, true)
	var r := Rect2(exit_gate_pos.x - 115.0, exit_gate_pos.y + 52.0, 230.0, 32.0)
	_draw_pill(r, bg_col, g_col, 2.0, 9.0)
	if font_res:
		var lbl := exit_gate_label if exit_gate_open else "Next Street (6/6 Tasks)"
		draw_string(font_res, Vector2(r.position.x, r.position.y + 21.0), lbl, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, Color(1.0, 0.95, 0.78))


func _draw_player() -> void:
	var bob := sin(player_walk_phase) * 3.5 if player_vel.length_squared() > 4.0 else sin(_anim_time * 2.5) * 1.5
	var draw_p := player_pos + Vector2(0.0, bob)

	# Player selection ring on floor
	draw_arc(player_pos + Vector2(0.0, 14.0), 28.0, 0.0, TAU, 32, Color(1.0, 0.90, 0.42, 0.85), 3.0, true)

	if player_tex:
		var sz := Vector2(76.0, 88.0)
		draw_texture_rect(player_tex, Rect2(draw_p - Vector2(sz.x * 0.5, sz.y * 0.78), sz), false)
	else:
		draw_circle(draw_p, 24.0, Color(0.25, 0.55, 0.95))

	# Draw Overhead Carry Tray if holding items!
	if not tray_items.is_empty():
		var tray_center := draw_p + Vector2(0.0, -82.0)
		var tray_w := 56.0 + float(tray_items.size() - 1) * 44.0
		var tray_r := Rect2(tray_center.x - tray_w * 0.5, tray_center.y - 24.0, tray_w, 48.0)
		_draw_pill(tray_r, Color(0.18, 0.12, 0.06, 0.94), Color(1.0, 0.86, 0.28), 2.5, 14.0)
		for i in range(tray_items.size()):
			var tid := str(tray_items[i])
			var ix := tray_center.x + (float(i) - float(tray_items.size() - 1) * 0.5) * 42.0
			var itex := get_item_tex(tid)
			if itex:
				draw_texture_rect(itex, Rect2(Vector2(ix - 20.0, tray_center.y - 20.0), Vector2(40.0, 40.0)), false)
