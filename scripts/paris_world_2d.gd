class_name ParisWorld2D
extends Node2D

## 2.5D Top-Down Hand-Painted Parisian Adventure World ('Bonjour Paris !')
## Zero UI clutter, zero yellow answer spoilers, natural scene object placement,
## and genuine 4-way Parisian Street Crossroads navigation ('map_carrefour.jpg').

signal station_interacted(vocab_id: String, station_pos: Vector2)
signal table_interacted(table_pos: Vector2)
signal direction_pad_entered(dir_key: String, pad_pos: Vector2)
signal exit_gate_entered()
signal phrase_option_selected(opt_text: String, idx: int)

const VIEW_W := 1280.0
const VIEW_H := 720.0
const CROSSROADS_BG := "res://assets/sprites/map_carrefour.jpg"

## Natural, scene-integrated coordinates for each item in each Parisian location
const ITEM_SCENE_POS: Dictionary = {
	# Chapter 1: Au Café de Flore (map_cafe.jpg)
	"pomme": Vector2(275.0, 345.0),
	"fromage": Vector2(440.0, 335.0),
	"pain": Vector2(605.0, 355.0),
	"bouteille": Vector2(765.0, 375.0),
	"tasse": Vector2(915.0, 395.0),
	# Chapter 2: La Maison Parisienne (map_maison.jpg)
	"livre": Vector2(205.0, 435.0),
	"cle": Vector2(365.0, 290.0),
	"chaise": Vector2(535.0, 315.0),
	"lit": Vector2(730.0, 365.0),
	"lampe": Vector2(960.0, 415.0),
	# Chapter 3: Le Marché de Rue (map_marche.jpg)
	"chapeau": Vector2(180.0, 430.0),
	"parapluie": Vector2(335.0, 365.0),
	"lunettes": Vector2(495.0, 325.0),
	"sac": Vector2(685.0, 325.0),
	"horloge": Vector2(895.0, 375.0),
	# Chapter 4: La Gare du Nord (map_gare.jpg)
	"valise": Vector2(245.0, 455.0),
	"velo": Vector2(405.0, 375.0),
	"train": Vector2(590.0, 335.0),
	"voiture": Vector2(790.0, 375.0),
	"avion": Vector2(965.0, 430.0),
	# Chapter 5: Le Jardin du Luxembourg (map_jardin.jpg)
	"arbre": Vector2(235.0, 385.0),
	"fleur": Vector2(420.0, 340.0),
	"poisson": Vector2(630.0, 385.0),
	"soleil": Vector2(835.0, 335.0),
	"nuage": Vector2(980.0, 395.0),
}

var map_textures: Dictionary = {}
var item_textures: Dictionary = {}
var player_tex: Texture2D
var customer_tex: Texture2D
var chloe_tex: Texture2D
var font_res: Font

var current_map_bg: String = "res://assets/sprites/map_cafe.jpg"
var current_mode: String = "VOCAB" # "VOCAB", "COMBO", "DIRECTION", "DAILY_PHRASE", "GALLERY", "WAVE_SUMMARY"

var player_pos: Vector2 = Vector2(590.0, 520.0)
var player_vel: Vector2 = Vector2.ZERO
var player_target_pos: Vector2 = Vector2(-1.0, -1.0)
var player_facing: float = 1.0
var player_walk_phase: float = 0.0
var dash_timer: float = 0.0
var tray_items: Array = []

# Stations: Array of { "id": String, "fr": String, "en": String, "pos": Vector2, "highlight": bool, "show_en": bool, "slot": int }
var stations: Array[Dictionary] = []

# Customer / Chloé Table state
var table_pos: Vector2 = Vector2(590.0, 465.0)
var table_visible: bool = true
var customer_order_ids: Array = []

# Street Crossroads Exits (for DIRECTION mode)
var dir_checkpoints: Array[Dictionary] = []
var dir_hint_key: String = ""

# Conversation Phrase Options (for DAILY_PHRASE / GRAMMAR)
var phrase_options: Array = []
var phrase_highlight_opt: String = ""

# Exit Archway state
var exit_gate_pos: Vector2 = Vector2(1145.0, 435.0)
var exit_gate_open: bool = false
var exit_gate_label: String = "★ NEXT CHAPTER →"

# Floating Popups & Sunlit Dust Particles
var popups: Array[Dictionary] = []
var dust_motes: Array[Dictionary] = []
var _anim_time: float = 0.0
var _station_cooldown: float = 0.0
var _table_cooldown: float = 0.0
var _dir_cooldown: float = 0.0
var _hover_pos: Vector2 = Vector2(-999.0, -999.0)


func _ready() -> void:
	font_res = load("res://assets/fonts/DejaVuSans.ttf") as Font
	if ResourceLoader.exists("res://assets/sprites/player_char.svg"):
		player_tex = load("res://assets/sprites/player_char.svg") as Texture2D
	if ResourceLoader.exists("res://assets/sprites/customer_char.svg"):
		customer_tex = load("res://assets/sprites/customer_char.svg") as Texture2D
	if ResourceLoader.exists("res://assets/sprites/chloe_portrait.jpg"):
		chloe_tex = load("res://assets/sprites/chloe_portrait.jpg") as Texture2D

	for i in range(18):
		dust_motes.append({
			"pos": Vector2(randf_range(40.0, VIEW_W - 40.0), randf_range(60.0, VIEW_H - 140.0)),
			"vel": Vector2(randf_range(8.0, 18.0), randf_range(-5.0, 8.0)),
			"r": randf_range(1.8, 3.6),
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
		"life": 1.25,
		"max_life": 1.25,
	})


func clear_tray() -> void:
	tray_items.clear()
	queue_redraw()


func setup_stations_for_items(item_dicts: Array, highlight_ids: Array, show_english_labels: bool) -> void:
	stations.clear()
	var n := item_dicts.size()
	var fallback_xs := [235.0, 415.0, 595.0, 775.0, 955.0]
	var fallback_ys := [375.0, 345.0, 355.0, 345.0, 375.0]
	for i in range(n):
		var d: Dictionary = item_dicts[i]
		var vid := str(d.get("id", "tasse"))
		var pos: Vector2
		if ITEM_SCENE_POS.has(vid):
			pos = ITEM_SCENE_POS[vid]
		else:
			var sx: float = fallback_xs[i] if i < fallback_xs.size() else (220.0 + float(i) * 185.0)
			var sy: float = fallback_ys[i] if i < fallback_ys.size() else 360.0
			pos = Vector2(sx, sy)
		stations.append({
			"id": vid,
			"fr": str(d.get("fr_def", vid)),
			"en": str(d.get("en", "")),
			"pos": pos,
			"highlight": highlight_ids.has(vid),
			"show_en": show_english_labels,
			"slot": i + 1,
		})
	queue_redraw()


func setup_direction_checkpoints(_steps: Array, _cur_idx: int, hint_only_key: String = "") -> void:
	dir_checkpoints.clear()
	dir_hint_key = hint_only_key
	# 4-Way Parisian Street Crossroads Avenues (North, South, West, East)
	var crossroads_exits := [
		{"key": "haut", "arrow": "▲", "pos": Vector2(640.0, 125.0)},
		{"key": "arriere", "arrow": "▼", "pos": Vector2(640.0, 505.0)},
		{"key": "gauche", "arrow": "◀", "pos": Vector2(215.0, 320.0)},
		{"key": "droite", "arrow": "▶", "pos": Vector2(1065.0, 320.0)},
	]
	for ex in crossroads_exits:
		var k: String = ex["key"]
		var info: Dictionary = VocabData.DIRECTION_INFO[k]
		dir_checkpoints.append({
			"key": k,
			"fr": str(info["fr"]),
			"en": str(info["en"]),
			"arrow": str(ex["arrow"]),
			"pos": ex["pos"],
		})
	queue_redraw()


func handle_click(click_pos: Vector2) -> void:
	if current_mode == "DAILY_PHRASE":
		var card_rects := _get_phrase_option_rects()
		for i in range(card_rects.size()):
			if card_rects[i].has_point(click_pos):
				phrase_option_selected.emit(str(phrase_options[i]), i)
				return

	player_target_pos = click_pos.clamp(Vector2(80.0, 95.0), Vector2(1200.0, 545.0))


func _get_phrase_option_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var n := phrase_options.size()
	var xs := [250.0, 640.0, 1030.0]
	for i in range(n):
		var cx: float = xs[i] if i < xs.size() else (250.0 + float(i) * 390.0)
		var cy := 520.0
		rects.append(Rect2(Vector2(cx - 180.0, cy - 28.0), Vector2(360.0, 54.0)))
	return rects


func _process(delta: float) -> void:
	_anim_time += delta
	_hover_pos = get_viewport().get_mouse_position()
	if _station_cooldown > 0.0:
		_station_cooldown = maxf(0.0, _station_cooldown - delta)
	if _table_cooldown > 0.0:
		_table_cooldown = maxf(0.0, _table_cooldown - delta)
	if _dir_cooldown > 0.0:
		_dir_cooldown = maxf(0.0, _dir_cooldown - delta)
	if dash_timer > 0.0:
		dash_timer = maxf(0.0, dash_timer - delta)

	# Update sunlit dust motes
	for m in dust_motes:
		var p: Vector2 = m["pos"] + m["vel"] * delta
		if p.x > VIEW_W:
			p.x = 0.0
		if p.y < 50.0:
			p.y = VIEW_H - 140.0
		if p.y > VIEW_H - 140.0:
			p.y = 50.0
		m["pos"] = p

	# Update floating popups
	for i in range(popups.size() - 1, -1, -1):
		var pop: Dictionary = popups[i]
		pop["life"] = float(pop["life"]) - delta
		pop["pos"] = (pop["pos"] as Vector2) + Vector2(0.0, -34.0 * delta)
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

	var spd := 520.0 if dash_timer > 0.0 else 350.0
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

	player_pos.x = clampf(player_pos.x, 80.0, 1200.0)
	player_pos.y = clampf(player_pos.y, 95.0, 545.0)

	# Check Proximity Interactions!
	if current_mode in ["VOCAB", "COMBO", "GALLERY"]:
		if _station_cooldown <= 0.0:
			for st in stations:
				var s_pos: Vector2 = st["pos"]
				if player_pos.distance_to(s_pos) < 52.0:
					_station_cooldown = 0.55
					player_target_pos = Vector2(-1.0, -1.0)
					station_interacted.emit(str(st["id"]), s_pos)
					break

		if table_visible and _table_cooldown <= 0.0 and not tray_items.is_empty():
			if player_pos.distance_to(table_pos) < 68.0:
				_table_cooldown = 0.55
				player_target_pos = Vector2(-1.0, -1.0)
				table_interacted.emit(table_pos)

	elif current_mode == "DIRECTION":
		if _dir_cooldown <= 0.0:
			for cp in dir_checkpoints:
				var c_pos: Vector2 = cp["pos"]
				if player_pos.distance_to(c_pos) < 68.0:
					_dir_cooldown = 0.65
					player_target_pos = Vector2(-1.0, -1.0)
					direction_pad_entered.emit(str(cp["key"]), c_pos)
					break

	if exit_gate_open and player_pos.distance_to(exit_gate_pos) < 72.0:
		player_target_pos = Vector2(-1.0, -1.0)
		exit_gate_entered.emit()

	queue_redraw()


func _draw_pill(rect: Rect2, bg_col: Color, border_col: Color, border_w: float = 1.5, radius: float = 10.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(int(border_w))
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, rect)


func _draw() -> void:
	# 1. Hand-Painted Studio Ghibli / Parisian Storybook 2.5D Map Background
	var bg_path := CROSSROADS_BG if current_mode == "DIRECTION" else current_map_bg
	var bg_tex := get_map_tex(bg_path)
	if bg_tex:
		draw_texture_rect(bg_tex, Rect2(0.0, 0.0, VIEW_W, VIEW_H), false)
	else:
		draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color(0.88, 0.80, 0.68))

	# 2. Sunlit Parisian Dust Motes
	for m in dust_motes:
		var alpha := 0.22 + 0.16 * sin(_anim_time * 2.0 + float(m["phase"]))
		draw_circle(m["pos"], float(m["r"]), Color(1.0, 0.95, 0.72, alpha))

	# 3. Draw Natural Scene Objects (VOCAB, COMBO, GALLERY)
	if current_mode in ["VOCAB", "COMBO", "GALLERY"]:
		for st in stations:
			_draw_station(st)

	# 4. Draw Customer / Chloé Delivery Spot (VOCAB, COMBO)
	if table_visible and current_mode in ["VOCAB", "COMBO"]:
		_draw_customer_table()

	# 5. Draw 4-Way Parisian Street Crossroads Arrows (DIRECTION)
	if current_mode == "DIRECTION":
		_draw_direction_checkpoints()

	# 6. Draw Clean Conversational Response Choices (DAILY_PHRASE)
	if current_mode == "DAILY_PHRASE":
		_draw_phrase_cards()

	# 7. Draw Exit Archway only when open
	if exit_gate_open:
		_draw_exit_gate()

	# 8. Draw Animated Player Character & Overhead Bistro Tray
	_draw_player()

	# 9. Draw Floating Popups
	for pop in popups:
		var life_ratio := clampf(float(pop["life"]) / float(pop["max_life"]), 0.0, 1.0)
		var p_pos: Vector2 = pop["pos"]
		var col: Color = pop["col"]
		col.a = life_ratio
		var txt := str(pop["text"])
		if font_res:
			var r := Rect2(p_pos.x - 110.0, p_pos.y - 16.0, 220.0, 28.0)
			_draw_pill(r, Color(0.12, 0.09, 0.06, 0.88 * life_ratio), col, 1.5, 9.0)
			draw_string(font_res, Vector2(r.position.x, p_pos.y + 3.0), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, col)


func _draw_station(st: Dictionary) -> void:
	var pos: Vector2 = st["pos"]
	var vid := str(st["id"])
	var is_hi := bool(st["highlight"])
	var in_tray := tray_items.has(vid)
	var is_near := (player_pos.distance_to(pos) < 82.0) or (_hover_pos.distance_to(pos) < 42.0)
	var pulse := sin(_anim_time * 5.0) * 0.5 + 0.5

	# Soft natural contact shadow on the counter/floor (no giant white circle plate!)
	draw_circle(pos + Vector2(0.0, 16.0), 24.0, Color(0.06, 0.04, 0.02, 0.34))

	# Only show a helper ring if the player explicitly requested a hint ([H]), made a mistake, or already picked it up
	if is_hi:
		draw_arc(pos, 34.0 + pulse * 4.0, 0.0, TAU, 36, Color(1.0, 0.86, 0.22, 0.92), 3.5, true)
	elif in_tray:
		draw_arc(pos, 31.0, 0.0, TAU, 32, Color(0.28, 0.94, 0.56, 0.85), 3.0, true)
	elif is_near:
		draw_arc(pos, 30.0, 0.0, TAU, 32, Color(1.0, 0.96, 0.82, 0.65), 2.0, true)

	# Proportional 56x56 Item Sprite sitting naturally in the scene
	var itex := get_item_tex(vid)
	if itex:
		var sz := Vector2(56.0, 56.0)
		var hover_lift := -3.0 if is_near else 0.0
		draw_texture_rect(itex, Rect2(pos - sz * 0.5 + Vector2(0.0, hover_lift), sz), false)

	# Only show a small label in GALLERY mode, when hinted (is_hi), or when hovering/walking right next to it
	if current_mode == "GALLERY" or is_hi:
		var lbl_w := 136.0
		var lbl_r := Rect2(pos.x - lbl_w * 0.5, pos.y + 28.0, lbl_w, 24.0)
		_draw_pill(lbl_r, Color(0.12, 0.09, 0.07, 0.88), Color(1.0, 0.86, 0.32, 0.85), 1.5, 8.0)
		if font_res:
			draw_string(font_res, Vector2(lbl_r.position.x, lbl_r.position.y + 16.0), str(st["fr"]), HORIZONTAL_ALIGNMENT_CENTER, lbl_w, 13, Color(1.0, 0.97, 0.88))


func _draw_customer_table() -> void:
	var pulse := sin(_anim_time * 4.5) * 0.5 + 0.5
	var ready_to_serve := (not customer_order_ids.is_empty()) and (tray_items.size() >= customer_order_ids.size())

	# Soft shadow under customer
	draw_circle(table_pos + Vector2(0.0, 22.0), 28.0, Color(0.08, 0.05, 0.03, 0.34))

	# Only pulse a delivery ring when the player has collected all items for the order!
	if ready_to_serve:
		draw_arc(table_pos + Vector2(0.0, 8.0), 38.0 + pulse * 5.0, 0.0, TAU, 40, Color(0.30, 0.96, 0.56, 0.90), 3.5, true)

	if customer_tex:
		draw_texture_rect(customer_tex, Rect2(table_pos - Vector2(36.0, 44.0), Vector2(72.0, 84.0)), false)

	# Small, clean speech indicator above the customer (NO item picture spoiling the answer!)
	var tag_w := 148.0 if ready_to_serve else 104.0
	var tag_r := Rect2(table_pos.x - tag_w * 0.5, table_pos.y - 68.0, tag_w, 24.0)
	var border_c := Color(0.32, 0.96, 0.56) if ready_to_serve else Color(0.95, 0.82, 0.42, 0.80)
	_draw_pill(tag_r, Color(0.12, 0.09, 0.07, 0.88), border_c, 1.5, 8.0)
	if font_res:
		var t_str := "★ Serve Here [Space]" if ready_to_serve else "★ Commande"
		draw_string(font_res, Vector2(tag_r.position.x, tag_r.position.y + 16.0), t_str, HORIZONTAL_ALIGNMENT_CENTER, tag_w, 12, Color(1.0, 0.97, 0.88))


func _draw_direction_checkpoints() -> void:
	# Subtle, identical street-sign arrows at the 4 avenues of the crossroads (NO answer spoiled!)
	var pulse := sin(_anim_time * 5.0) * 0.5 + 0.5
	for cp in dir_checkpoints:
		var pos: Vector2 = cp["pos"]
		var k := str(cp["key"])
		var is_hinted := (dir_hint_key != "" and dir_hint_key == k)
		var is_near := (player_pos.distance_to(pos) < 85.0) or (_hover_pos.distance_to(pos) < 55.0)

		var border_col := Color(1.0, 0.86, 0.24, 0.95) if is_hinted else (Color(1.0, 0.95, 0.78, 0.90) if is_near else Color(0.86, 0.74, 0.48, 0.72))
		var bg_col := Color(0.24, 0.17, 0.06, 0.92) if is_hinted else Color(0.13, 0.10, 0.08, 0.82)

		var r := Rect2(pos.x - 42.0, pos.y - 18.0, 84.0, 36.0)
		_draw_pill(r, bg_col, border_col, 2.5 if is_hinted else 1.5, 12.0)
		if is_hinted:
			draw_arc(pos, 34.0 + pulse * 5.0, 0.0, TAU, 32, Color(1.0, 0.86, 0.22, 0.90), 3.0, true)
		if font_res:
			draw_string(font_res, Vector2(r.position.x, r.position.y + 24.0), str(cp["arrow"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color(1.0, 0.97, 0.88))


func _draw_phrase_cards() -> void:
	# Clean, compact dialogue response buttons right above the bottom dialogue bar
	var rects := _get_phrase_option_rects()
	for i in range(rects.size()):
		var r := rects[i]
		var opt := str(phrase_options[i])
		var is_hi: bool = (phrase_highlight_opt != "" and opt == phrase_highlight_opt)
		var is_hover: bool = r.has_point(_hover_pos)
		var border_c := Color(1.0, 0.86, 0.22) if is_hi else (Color(1.0, 0.92, 0.56) if is_hover else Color(0.84, 0.68, 0.38, 0.88))
		var bg_c := Color(0.24, 0.18, 0.07, 0.95) if is_hi else (Color(0.18, 0.14, 0.10, 0.95) if is_hover else Color(0.12, 0.09, 0.07, 0.92))
		_draw_pill(r, bg_c, border_c, 2.5 if is_hi else 1.5, 12.0)
		if font_res:
			draw_string(font_res, Vector2(r.position.x + 8.0, r.position.y + 32.0), "[%d] « %s »" % [i + 1, opt], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16.0, 13, Color(1.0, 0.98, 0.90))


func _draw_exit_gate() -> void:
	var pulse := sin(_anim_time * 5.0) * 0.5 + 0.5
	var g_col := Color(1.0, 0.86, 0.22, 0.95)
	var bg_col := Color(0.20, 0.14, 0.05, 0.90)
	draw_arc(exit_gate_pos, 36.0 + pulse * 5.0, 0.0, TAU, 36, g_col, 3.5, true)
	var r := Rect2(exit_gate_pos.x - 85.0, exit_gate_pos.y + 42.0, 170.0, 26.0)
	_draw_pill(r, bg_col, g_col, 1.5, 8.0)
	if font_res:
		draw_string(font_res, Vector2(r.position.x, r.position.y + 18.0), exit_gate_label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, Color(1.0, 0.95, 0.78))


func _draw_player() -> void:
	var bob := sin(player_walk_phase) * 3.0 if player_vel.length_squared() > 4.0 else sin(_anim_time * 2.5) * 1.2
	var draw_p := player_pos + Vector2(0.0, bob)

	# Subtle ground shadow under player
	draw_circle(player_pos + Vector2(0.0, 12.0), 20.0, Color(0.06, 0.04, 0.02, 0.34))
	draw_arc(player_pos + Vector2(0.0, 12.0), 22.0, 0.0, TAU, 28, Color(1.0, 0.90, 0.42, 0.70), 2.0, true)

	if player_tex:
		var sz := Vector2(68.0, 78.0)
		draw_texture_rect(player_tex, Rect2(draw_p - Vector2(sz.x * 0.5, sz.y * 0.78), sz), false)
	else:
		draw_circle(draw_p, 22.0, Color(0.25, 0.55, 0.95))

	# Draw Overhead Carry Tray if holding items!
	if not tray_items.is_empty():
		var tray_center := draw_p + Vector2(0.0, -74.0)
		var tray_w := 48.0 + float(tray_items.size() - 1) * 38.0
		var tray_r := Rect2(tray_center.x - tray_w * 0.5, tray_center.y - 20.0, tray_w, 40.0)
		_draw_pill(tray_r, Color(0.16, 0.11, 0.06, 0.94), Color(1.0, 0.86, 0.28), 2.0, 12.0)
		for i in range(tray_items.size()):
			var tid := str(tray_items[i])
			var ix := tray_center.x + (float(i) - float(tray_items.size() - 1) * 0.5) * 36.0
			var itex := get_item_tex(tid)
			if itex:
				draw_texture_rect(itex, Rect2(Vector2(ix - 17.0, tray_center.y - 17.0), Vector2(34.0, 34.0)), false)
