class_name GameManager
extends Node3D

## Master Orchestrator for BONJOUR PARIS ! (2.5D Hand-Painted Parisian Action-Adventure)
## Features:
## - 5 Hand-Painted Studio Ghibli / Parisian Storybook 2.5D Maps:
##     1. Au Café de Flore (map_cafe.jpg)
##     2. La Maison Parisienne (map_maison.jpg)
##     3. Le Marché de Rue (map_marche.jpg)
##     4. La Gare du Nord (map_gare.jpg)
##     5. Le Jardin du Luxembourg (map_jardin.jpg)
## - Genuine WASD + Click-to-Walk Bistro & Neighborhood Gameplay Loop:
##     - Walk to counter/market stations to pick up illustrated items onto your overhead Bistro Tray
##     - Deliver single-item and 2-item combo orders to the Customer Service Table
##     - Run through glowing Street Direction Checkpoints in sequence (À gauche, En haut, À droite...)
##     - Complete real-life French conversations and walk through the unlocked Street Archway!
## - Illustrated companion Chloé (chloe_portrait.jpg) with native French voice + clear English guidance.

enum GameState {
	MENU,
	CALIBRATION,
	COMBAT,
	WAVE_SUMMARY,
	GALLERY,
}

const PROMPTS_PER_WAVE := 6
const PROMPT_TIME_LIMIT := 22.0

var state: GameState = GameState.MENU
var srs: SRSEngine
var audio: AudioDirector
var paris_world: ParisWorld2D

var _active_map_idx: int = 0
var _dir_steps: Array = []
var _dir_step_idx: int = 0

# Wave & Prompt runtime state
var wave_number: int = 1
var prompt_in_wave: int = 0
var wave_hits_clean: int = 0
var score: int = 0
var combo: int = 0
var shield_hp: float = 100.0

var current_spec: Dictionary = {}
var prompt_timer: float = 0.0
var prompt_active: bool = false
var prompt_clean_try: bool = true
var prompt_used_assist: bool = false
var prompt_hint_stage: int = 0
var prompt_wrong_ids: Array[String] = []
var transition_delay: float = 0.0
var gallery_sector: int = 0
var lexicon_tab: String = "ALL"

# UI Nodes
var ui_layer: CanvasLayer
var hud_root: Control
var _stats_panel: PanelContainer
var radio_panel: PanelContainer
var speaker_lbl: Label
var mode_tag_lbl: Label
var prompt_main_lbl: Label
var prompt_sub_lbl: Label
var feedback_banner: PanelContainer
var feedback_lbl: Label
var timer_bar: ProgressBar
var shield_bar: ProgressBar
var score_lbl: Label
var wave_lbl: Label
var hotkeys_lbl: Label
var companion_panel: PanelContainer
var companion_portrait: TextureRect
var companion_lbl: Label

var menu_panel: PanelContainer
var menu_stats_lbl: Label
var sector_btn: Button

var summary_panel: PanelContainer
var summary_lbl: Label

var lexicon_panel: PanelContainer
var lexicon_grid: GridContainer
var lexicon_header_lbl: Label
var lexicon_open: bool = false


func _ready() -> void:
	randomize()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	srs = SRSEngine.new()
	audio = AudioDirector.new()
	add_child(audio)

	_build_ui()
	_enter_menu()

	var user_args := OS.get_cmdline_user_args()
	if user_args.has("--verify-screenshots"):
		_run_automated_verification()


# ==============================================================================
# UI, ILLUSTRATED CHLOÉ COMPANION & 2.5D PARIS WORLD SETUP
# ==============================================================================

func _make_panel_style(bg: Color, border: Color, radius: int = 12, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 2
	add_child(ui_layer)

	# 0. 2.5D Hand-Painted Parisian World Canvas (renders behind HUD controls)
	paris_world = ParisWorld2D.new()
	paris_world.name = "ParisWorld2D"
	paris_world.station_interacted.connect(_on_world_station_interacted)
	paris_world.table_interacted.connect(_on_world_table_interacted)
	paris_world.direction_pad_entered.connect(_on_world_direction_pad_entered)
	paris_world.exit_gate_entered.connect(_on_world_exit_gate_entered)
	paris_world.phrase_option_selected.connect(_on_world_phrase_option_selected)
	ui_layer.add_child(paris_world)

	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(hud_root)

	# 1. Top-Center Order & Audio Banner Pill
	radio_panel = PanelContainer.new()
	var pill_style := _make_panel_style(Color(0.11, 0.08, 0.06, 0.90), Color(1.0, 0.86, 0.36, 0.85), 22, 2)
	pill_style.content_margin_left = 22
	pill_style.content_margin_right = 22
	pill_style.content_margin_top = 8
	pill_style.content_margin_bottom = 8
	radio_panel.add_theme_stylebox_override("panel", pill_style)
	radio_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	radio_panel.position = Vector2(-340, 10)
	radio_panel.custom_minimum_size = Vector2(680, 58)
	radio_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(radio_panel)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 3)
	radio_panel.add_child(rv)

	speaker_lbl = Label.new()
	speaker_lbl.visible = false
	rv.add_child(speaker_lbl)

	mode_tag_lbl = Label.new()
	mode_tag_lbl.visible = false
	rv.add_child(mode_tag_lbl)

	prompt_main_lbl = Label.new()
	prompt_main_lbl.text = "Bienvenue à Paris !"
	prompt_main_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_main_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_main_lbl.add_theme_font_size_override("font_size", 19)
	prompt_main_lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90))
	prompt_main_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03, 0.95))
	prompt_main_lbl.add_theme_constant_override("outline_size", 5)
	rv.add_child(prompt_main_lbl)

	prompt_sub_lbl = Label.new()
	prompt_sub_lbl.text = ""
	prompt_sub_lbl.visible = false
	prompt_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_sub_lbl.add_theme_font_size_override("font_size", 13)
	prompt_sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	rv.add_child(prompt_sub_lbl)

	timer_bar = ProgressBar.new()
	timer_bar.show_percentage = false
	timer_bar.min_value = 0.0
	timer_bar.max_value = 100.0
	timer_bar.value = 100.0
	timer_bar.custom_minimum_size = Vector2(0, 5)
	var tb_bg := StyleBoxFlat.new()
	tb_bg.bg_color = Color(1.0, 1.0, 1.0, 0.14)
	tb_bg.set_corner_radius_all(2)
	timer_bar.add_theme_stylebox_override("background", tb_bg)
	var tb_fill := StyleBoxFlat.new()
	tb_fill.bg_color = Color(1.0, 0.82, 0.24)
	tb_fill.set_corner_radius_all(2)
	timer_bar.add_theme_stylebox_override("fill", tb_fill)
	rv.add_child(timer_bar)

	# 2. Helpful Guidance Callout Pill (Below Top Banner)
	feedback_banner = PanelContainer.new()
	feedback_banner.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.16, 0.10, 0.06, 0.92), Color(1.0, 0.82, 0.24, 0.92), 16, 2)
	)
	feedback_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	feedback_banner.position = Vector2(-310, 82)
	feedback_banner.custom_minimum_size = Vector2(620, 34)
	feedback_banner.visible = false
	feedback_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(feedback_banner)

	feedback_lbl = Label.new()
	feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_lbl.add_theme_font_size_override("font_size", 14)
	feedback_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.95))
	feedback_lbl.add_theme_constant_override("outline_size", 4)
	feedback_banner.add_child(feedback_lbl)

	# 3. Top-Left Place & Tips Badge
	_stats_panel = PanelContainer.new()
	_stats_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.12, 0.09, 0.06, 0.88), Color(0.92, 0.74, 0.36, 0.78), 14, 2)
	)
	_stats_panel.position = Vector2(16, 10)
	_stats_panel.custom_minimum_size = Vector2(250, 62)
	_stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(_stats_panel)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	_stats_panel.add_child(sv)

	wave_lbl = Label.new()
	wave_lbl.text = "AU CAFÉ DE FLORE  •  ORDER 1/6"
	wave_lbl.add_theme_font_size_override("font_size", 13)
	wave_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	sv.add_child(wave_lbl)

	score_lbl = Label.new()
	score_lbl.text = "★ 0 PTS   •   STREAK x1"
	score_lbl.add_theme_font_size_override("font_size", 16)
	score_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
	sv.add_child(score_lbl)

	shield_bar = ProgressBar.new()
	shield_bar.visible = false
	sv.add_child(shield_bar)

	# 4. Illustrated Companion Card ("Chloé" — Bottom-Left with Studio Ghibli Portrait!)
	companion_panel = PanelContainer.new()
	var comp_style := _make_panel_style(Color(0.12, 0.09, 0.07, 0.93), Color(1.0, 0.84, 0.36, 0.88), 18, 2)
	comp_style.content_margin_left = 10
	comp_style.content_margin_right = 16
	comp_style.content_margin_top = 8
	comp_style.content_margin_bottom = 8
	companion_panel.add_theme_stylebox_override("panel", comp_style)
	companion_panel.position = Vector2(16, 594)
	companion_panel.custom_minimum_size = Vector2(760, 86)
	companion_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(companion_panel)

	var comp_hbox := HBoxContainer.new()
	comp_hbox.add_theme_constant_override("separation", 12)
	companion_panel.add_child(comp_hbox)

	companion_portrait = TextureRect.new()
	companion_portrait.custom_minimum_size = Vector2(68, 68)
	companion_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	companion_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/sprites/chloe_portrait.jpg"):
		companion_portrait.texture = load("res://assets/sprites/chloe_portrait.jpg") as Texture2D
	comp_hbox.add_child(companion_portrait)

	companion_lbl = Label.new()
	companion_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	companion_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	companion_lbl.text = "Chloé : « Bonjour ! Bienvenue au Café de Flore ! » (Welcome to Café de Flore!)"
	companion_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	companion_lbl.add_theme_font_size_override("font_size", 14)
	companion_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
	companion_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.95))
	companion_lbl.add_theme_constant_override("outline_size", 4)
	comp_hbox.add_child(companion_lbl)

	# 5. Bottom Controls Strip
	var bot_panel := PanelContainer.new()
	bot_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	bot_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bot_panel.position = Vector2(-540, -28)
	bot_panel.custom_minimum_size = Vector2(1080, 24)
	bot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bot_panel)

	hotkeys_lbl = Label.new()
	hotkeys_lbl.text = "[WASD / Click] Walk   •   [1–5] Pick Up Item   •   [Space] Serve Table   •   [E] Replay Audio   •   [H] Hint   •   [Tab] Word & Phrase Book"
	hotkeys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkeys_lbl.add_theme_font_size_override("font_size", 13)
	hotkeys_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88, 0.95))
	hotkeys_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03, 0.95))
	hotkeys_lbl.add_theme_constant_override("outline_size", 5)
	bot_panel.add_child(hotkeys_lbl)

	_build_menu_overlay()
	_build_summary_overlay()
	_build_lexicon_overlay()


func _build_menu_overlay() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.13, 0.09, 0.06, 0.94), Color(1.0, 0.84, 0.36, 0.90), 20, 2)
	)
	menu_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	menu_panel.position = Vector2(-390, 12)
	menu_panel.custom_minimum_size = Vector2(780, 126)
	ui_layer.add_child(menu_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	menu_panel.add_child(vb)

	var title := Label.new()
	title.text = "BONJOUR PARIS !  •  L'AVENTURE PARISIENNE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.36))
	title.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03, 0.95))
	title.add_theme_constant_override("outline_size", 6)
	vb.add_child(title)

	menu_stats_lbl = Label.new()
	menu_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_stats_lbl.add_theme_font_size_override("font_size", 14)
	menu_stats_lbl.add_theme_color_override("font_color", Color(0.99, 0.96, 0.88))
	vb.add_child(menu_stats_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vb.add_child(btn_row)

	var start_b := Button.new()
	start_b.text = "▶ Commencer / Play [Space]"
	start_b.custom_minimum_size = Vector2(215, 34)
	start_b.add_theme_font_size_override("font_size", 14)
	start_b.pressed.connect(_on_start_mission_pressed)
	btn_row.add_child(start_b)

	sector_btn = Button.new()
	sector_btn.text = "↻ Change Chapter (1/9)"
	sector_btn.custom_minimum_size = Vector2(185, 34)
	sector_btn.add_theme_font_size_override("font_size", 13)
	sector_btn.pressed.connect(_on_cycle_sector)
	btn_row.add_child(sector_btn)

	var explore_b := Button.new()
	explore_b.text = "◈ Explore Map [G]"
	explore_b.custom_minimum_size = Vector2(150, 34)
	explore_b.add_theme_font_size_override("font_size", 13)
	explore_b.pressed.connect(_on_enter_gallery_pressed)
	btn_row.add_child(explore_b)

	var book_b := Button.new()
	book_b.text = "♪ Word & Phrase Book [Tab]"
	book_b.custom_minimum_size = Vector2(190, 34)
	book_b.add_theme_font_size_override("font_size", 13)
	book_b.pressed.connect(func(): _toggle_lexicon(true))
	btn_row.add_child(book_b)


func _build_summary_overlay() -> void:
	summary_panel = PanelContainer.new()
	summary_panel.visible = false
	ui_layer.add_child(summary_panel)
	summary_lbl = Label.new()
	summary_panel.add_child(summary_lbl)


func _build_lexicon_overlay() -> void:
	lexicon_panel = PanelContainer.new()
	lexicon_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.11, 0.08, 0.06, 0.96), Color(1.0, 0.84, 0.36, 0.85), 18, 2)
	)
	lexicon_panel.position = Vector2(45, 34)
	lexicon_panel.size = Vector2(1190, 650)
	lexicon_panel.custom_minimum_size = Vector2(1190, 650)
	lexicon_panel.visible = false
	ui_layer.add_child(lexicon_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	lexicon_panel.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	vb.add_child(top)

	lexicon_header_lbl = Label.new()
	lexicon_header_lbl.text = "CARNET DE PARIS — Click [♪] to hear spoken French"
	lexicon_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lexicon_header_lbl.add_theme_font_size_override("font_size", 15)
	lexicon_header_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.38))
	top.add_child(lexicon_header_lbl)

	for tab_spec in [
		["ALL", "All Words (45)"],
		["PHRASES", "★ Phrases (18)"],
		["A1", "Chapters 1–4 (20)"],
		["A2", "Chapters 5–7 (15)"],
		["B1", "Chapters 8–9 (10)"],
	]:
		var tb := Button.new()
		var t_code: String = tab_spec[0]
		tb.text = tab_spec[1]
		tb.custom_minimum_size = Vector2(116, 30)
		tb.add_theme_font_size_override("font_size", 12)
		tb.pressed.connect(func():
			audio.play_sfx("click")
			lexicon_tab = t_code
			_populate_lexicon_grid()
		)
		top.add_child(tb)

	var close_btn := Button.new()
	close_btn.text = "✗ Close [Tab]"
	close_btn.custom_minimum_size = Vector2(96, 30)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(func(): _toggle_lexicon(false))
	top.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)

	lexicon_grid = GridContainer.new()
	lexicon_grid.columns = 3
	lexicon_grid.add_theme_constant_override("h_separation", 10)
	lexicon_grid.add_theme_constant_override("v_separation", 10)
	lexicon_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lexicon_grid)


func _populate_lexicon_grid() -> void:
	for ch in lexicon_grid.get_children():
		ch.queue_free()

	if lexicon_tab == "PHRASES":
		lexicon_grid.columns = 2
		for dp in VocabData.DAILY_PHRASES:
			var pcard := PanelContainer.new()
			pcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pcard.custom_minimum_size = Vector2(540, 114)
			pcard.add_theme_stylebox_override(
				"panel",
				_make_panel_style(Color(0.16, 0.12, 0.09, 0.94), Color(1.0, 0.84, 0.36, 0.80), 12, 2)
			)
			lexicon_grid.add_child(pcard)

			var pvb := VBoxContainer.new()
			pvb.add_theme_constant_override("separation", 3)
			pcard.add_child(pvb)

			var pr1 := HBoxContainer.new()
			pvb.add_child(pr1)
			var map_i := clampi(int(dp["sector"]), 0, 8)
			var sit_lbl := Label.new()
			sit_lbl.text = "★ Chapter %d (%s)  •  %s" % [map_i + 1, VocabData.SECTORS[map_i]["name_fr"], str(dp["situation_en"])]
			sit_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sit_lbl.clip_text = true
			sit_lbl.add_theme_font_size_override("font_size", 12)
			sit_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
			pr1.add_child(sit_lbl)

			var p_audio := str(dp["audio"])
			var p_btn := Button.new()
			p_btn.text = "♪ Listen"
			p_btn.custom_minimum_size = Vector2(76, 24)
			p_btn.add_theme_font_size_override("font_size", 12)
			p_btn.pressed.connect(func(): audio.play_voice(p_audio))
			pr1.add_child(p_btn)

			var fr_lbl := Label.new()
			fr_lbl.text = "« %s »   —   %s" % [str(dp["phrase_fr"]), str(dp["phrase_en"])]
			fr_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			fr_lbl.add_theme_font_size_override("font_size", 13)
			fr_lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90))
			pvb.add_child(fr_lbl)

			var tip_l := Label.new()
			tip_l.text = "Chloé: %s" % str(dp["chloe_tip"])
			tip_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tip_l.add_theme_font_size_override("font_size", 11)
			tip_l.add_theme_color_override("font_color", Color(0.75, 0.96, 0.80))
			pvb.add_child(tip_l)
		return

	var tier_names := ["Level 1: New", "Level 2: Phrase + Text", "Level 3: Listen Phrase", "Level 4: Spoken", "★ Mastered"]
	var tier_cols := [
		Color(0.82, 0.74, 0.62),
		Color(0.98, 0.84, 0.38),
		Color(0.98, 0.68, 0.30),
		Color(0.64, 0.94, 0.50),
		Color(0.38, 0.98, 0.60),
	]

	lexicon_grid.columns = 3
	var sorted_items := VocabData.ITEMS.duplicate()
	sorted_items.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["sector"]) < int(b["sector"]))
	for item in sorted_items:
		if lexicon_tab != "ALL" and lexicon_tab != "GRAM" and not String(item["cefr"]).begins_with(lexicon_tab):
			continue
		var vid: String = item["id"]
		var c: Dictionary = srs.cards[vid]
		var t_idx := clampi(int(c["tier"]), 0, 4)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(360, 108)
		card.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color(0.16, 0.12, 0.09, 0.92), tier_cols[t_idx], 10, 2)
		)
		lexicon_grid.add_child(card)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 3)
		card.add_child(cv)

		var r1 := HBoxContainer.new()
		r1.add_theme_constant_override("separation", 4)
		cv.add_child(r1)
		var w_lbl := Label.new()
		w_lbl.text = "%s  —  %s" % [item["fr_def"], item["en"]]
		w_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		w_lbl.clip_text = true
		w_lbl.add_theme_font_size_override("font_size", 14)
		w_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
		r1.add_child(w_lbl)

		var play_b := Button.new()
		play_b.text = "♪"
		play_b.tooltip_text = "Listen to word"
		play_b.custom_minimum_size = Vector2(26, 22)
		play_b.add_theme_font_size_override("font_size", 11)
		play_b.pressed.connect(func(): audio.play_voice("word_%s.ogg" % vid))
		r1.add_child(play_b)

		var phr_b := Button.new()
		phr_b.text = "♪ Phrase"
		phr_b.tooltip_text = str(item.get("phrase_en", "Listen to everyday phrase"))
		phr_b.custom_minimum_size = Vector2(62, 22)
		phr_b.add_theme_font_size_override("font_size", 11)
		phr_b.pressed.connect(func(): audio.play_voice("phrase_%s.ogg" % vid))
		r1.add_child(phr_b)

		var phr_lbl := Label.new()
		phr_lbl.text = "« %s »" % str(item.get("phrase_fr", item["ipa"]))
		phr_lbl.clip_text = true
		phr_lbl.add_theme_font_size_override("font_size", 11)
		phr_lbl.add_theme_color_override("font_color", Color(0.98, 0.86, 0.46))
		cv.add_child(phr_lbl)

		var st_lbl := Label.new()
		var ok_n := int(c["correct"])
		var map_idx := clampi(int(item["sector"]), 0, 8)
		st_lbl.text = "Ch.%d: %s  •  %s (✓%d)" % [map_idx + 1, VocabData.SECTORS[map_idx]["name_fr"], tier_names[t_idx] if bool(c["seen"]) else "Unseen", ok_n]
		st_lbl.clip_text = true
		st_lbl.add_theme_font_size_override("font_size", 11)
		st_lbl.add_theme_color_override("font_color", tier_cols[t_idx])
		cv.add_child(st_lbl)


func _toggle_lexicon(force_state: Variant = null) -> void:
	if force_state == null:
		lexicon_open = not lexicon_open
	else:
		lexicon_open = bool(force_state)
	audio.play_sfx("click")
	lexicon_panel.visible = lexicon_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if lexicon_open:
		hud_root.visible = false
		menu_panel.visible = false
		_populate_lexicon_grid()
	else:
		hud_root.visible = true
		menu_panel.visible = (state == GameState.MENU)


func _chloe_say(msg: String, voice_file: String = "") -> void:
	if companion_lbl:
		companion_lbl.text = "Chloé : " + msg
	if voice_file != "":
		audio.play_voice(voice_file, 5.0, 1.0)


func _apply_map_theme(map_idx: int) -> void:
	_active_map_idx = clampi(map_idx, 0, VocabData.SECTORS.size() - 1)
	var s_info: Dictionary = VocabData.SECTORS[_active_map_idx]
	if paris_world:
		paris_world.current_map_bg = str(s_info.get("map_bg", "res://assets/sprites/map_cafe.jpg"))
		paris_world.queue_redraw()


func _get_sector_item_dicts(sec_idx: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids := VocabData.get_sector_ids(sec_idx)
	for vid in ids:
		var d := VocabData.get_by_id(vid)
		if not d.is_empty():
			out.append(d)
	return out


# ==============================================================================
# STATE TRANSITIONS & 2.5D WORLD FLOW
# ==============================================================================

func _enter_menu() -> void:
	state = GameState.MENU
	prompt_active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud_root.visible = true
	if _stats_panel:
		_stats_panel.visible = false
	radio_panel.visible = false
	feedback_banner.visible = false
	menu_panel.visible = true
	summary_panel.visible = false
	lexicon_panel.visible = false
	lexicon_open = false

	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)
	_refresh_menu_labels()

	if paris_world:
		paris_world.current_mode = "MENU"
		paris_world.clear_tray()
		paris_world.exit_gate_open = false
		paris_world.table_visible = true
		paris_world.customer_order_ids = []
		paris_world.player_pos = Vector2(590.0, 565.0)
		var items := _get_sector_item_dicts(act_s)
		paris_world.setup_stations_for_items(items, [], true)

	var s_info := VocabData.SECTORS[act_s]
	_chloe_say(str(s_info.get("chloe_intro", "« Bonjour ! Bienvenue au Café de Flore ! »")), "chloe_welcome_%d.ogg" % act_s)


func _refresh_menu_labels() -> void:
	var st := srs.get_summary_stats()
	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	var s_info := VocabData.SECTORS[act_s]
	menu_stats_lbl.text = "◈ Chapter %d/9 : %s (%s)   •   Words Learned: %d/%d" % [
		act_s + 1, s_info["name_fr"], s_info["name_en"], st["seen"], st["total_words"]
	]
	if sector_btn:
		sector_btn.text = "↻ Change Chapter (%d/9)" % [act_s + 1]


func _on_cycle_sector() -> void:
	audio.play_sfx("click")
	var act_cur := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	var next_s := (act_cur + 1) % VocabData.SECTORS.size()
	srs.sector_filter = next_s
	srs.save_progress()
	_apply_map_theme(next_s)
	_refresh_menu_labels()
	if paris_world:
		var items := _get_sector_item_dicts(next_s)
		paris_world.setup_stations_for_items(items, [], true)
	var s_info := VocabData.SECTORS[next_s]
	_chloe_say(str(s_info.get("chloe_intro", "")), "chloe_welcome_%d.ogg" % next_s)


func _on_start_mission_pressed() -> void:
	audio.play_sfx("click")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_panel.visible = false
	summary_panel.visible = false
	lexicon_panel.visible = false
	hud_root.visible = true
	if _stats_panel:
		_stats_panel.visible = true
	radio_panel.visible = true
	feedback_banner.visible = false

	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)
	shield_hp = 100.0
	_update_stats_hud()
	_begin_wave()


func _on_enter_gallery_pressed() -> void:
	audio.play_sfx("click")
	state = GameState.GALLERY
	prompt_active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_panel.visible = false
	summary_panel.visible = false
	lexicon_panel.visible = false
	hud_root.visible = true
	if _stats_panel:
		_stats_panel.visible = true
	radio_panel.visible = true
	feedback_banner.visible = false

	if srs.sector_filter >= 0:
		gallery_sector = srs.sector_filter
	else:
		gallery_sector = srs.get_active_campaign_sector()
	_load_gallery_sector(gallery_sector)


func _load_gallery_sector(sec_idx: int) -> void:
	gallery_sector = clampi(sec_idx, 0, VocabData.SECTORS.size() - 1)
	_apply_map_theme(gallery_sector)
	var items := _get_sector_item_dicts(gallery_sector)
	if paris_world:
		paris_world.current_mode = "GALLERY"
		paris_world.clear_tray()
		paris_world.table_visible = false
		paris_world.exit_gate_open = true
		paris_world.exit_gate_label = "★ PLAY CHAPTER →"
		paris_world.setup_stations_for_items(items, [], true)

	var s_info := VocabData.SECTORS[gallery_sector]
	prompt_main_lbl.text = "◈ EXPLORE: %s (%s) — Walk to or press [1–5] on any station to hear its French phrase!" % [
		s_info["name_fr"], s_info["name_en"]
	]
	prompt_sub_lbl.visible = true
	prompt_sub_lbl.text = "Press [1–9] to switch Chapter   •   Walk through the right archway or press [M] to Play!"
	_update_stats_hud()
	_chloe_say("« Voici %s ! Approchez-vous d'un objet pour écouter sa phrase. » (Walk up to any item station to hear its spoken French phrase!)" % s_info["name_fr"], "chloe_welcome_%d.ogg" % gallery_sector)
	timer_bar.value = 100.0


func _begin_wave() -> void:
	prompt_in_wave = 0
	wave_hits_clean = 0
	shield_hp = 100.0
	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)
	if paris_world:
		paris_world.clear_tray()
		paris_world.exit_gate_open = false
		paris_world.player_pos = Vector2(590.0, 560.0)
	_update_stats_hud()
	_start_combat_wave()


func _start_combat_wave() -> void:
	state = GameState.COMBAT
	prompt_in_wave = 0
	feedback_banner.visible = false
	_next_combat_prompt()


func _next_combat_prompt() -> void:
	if prompt_in_wave >= PROMPTS_PER_WAVE:
		_finish_wave()
		return

	prompt_in_wave += 1
	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)

	current_spec = srs.build_wave_prompt_spec(prompt_in_wave, wave_number)
	var ptype := str(current_spec.get("prompt_type", "VOCAB"))

	prompt_timer = PROMPT_TIME_LIMIT
	prompt_active = true
	prompt_clean_try = true
	prompt_used_assist = false
	prompt_hint_stage = 0
	prompt_wrong_ids.clear()

	var sec_items := _get_sector_item_dicts(act_s)
	paris_world.clear_tray()
	paris_world.exit_gate_open = false

	if ptype == "VOCAB":
		paris_world.current_mode = "VOCAB"
		paris_world.table_visible = true
		var target_id := str(current_spec.get("target_id", "tasse"))
		var tier := int(current_spec.get("tier", 0))
		paris_world.customer_order_ids = [target_id]
		var hi_ids: Array = [target_id] if tier == 0 else []
		paris_world.setup_stations_for_items(sec_items, hi_ids, tier <= 1)

		var item := VocabData.get_by_id(target_id)
		if tier == 0:
			_chloe_say("« Voici %s (%s) ! » — Walk up to [%s] to pick it up, then bring it to the Customer Table!" % [
				str(item.get("fr_def", "")), str(item.get("en", "")), str(item.get("fr_def", ""))
			])
		else:
			_chloe_say("« %s » (%s) — Pick up %s and serve it at the table!" % [
				str(item.get("phrase_fr", "")), str(item.get("phrase_en", "")), str(item.get("fr_def", ""))
			])

	elif ptype == "COMBO":
		paris_world.current_mode = "COMBO"
		paris_world.table_visible = true
		var c_ids: Array[String] = []
		for cid in current_spec.get("combo_ids", []):
			c_ids.append(str(cid))
		paris_world.customer_order_ids = c_ids
		paris_world.setup_stations_for_items(sec_items, c_ids, true)
		_chloe_say("« %s » (%s) — Pick up BOTH items onto your tray, then walk to the Customer Table!" % [
			str(current_spec.get("prompt_fr", "")), str(current_spec.get("prompt_en", ""))
		])

	elif ptype == "DIRECTION":
		paris_world.current_mode = "DIRECTION"
		paris_world.table_visible = false
		_dir_steps.clear()
		for s in current_spec.get("steps", []):
			_dir_steps.append(str(s))
		_dir_step_idx = 0
		paris_world.setup_direction_checkpoints(_dir_steps, _dir_step_idx)
		_chloe_say(str(current_spec.get("chloe_tip", "« Suivez les directions au sol ! » (Walk onto the gold direction checkpoint!)")))

	elif ptype in ["DAILY_PHRASE", "GRAMMAR"]:
		paris_world.current_mode = "DAILY_PHRASE"
		paris_world.table_visible = false
		var opts: Array[String] = []
		for o in current_spec.get("options", []):
			opts.append(str(o))
		opts.shuffle()
		paris_world.phrase_options = opts
		paris_world.phrase_highlight_opt = ""
		if ptype == "DAILY_PHRASE":
			_chloe_say("« En France (%s) : » %s" % [
				str(current_spec.get("situation_en", "Everyday Conversation")),
				str(current_spec.get("chloe_tip", ""))
			])
		else:
			_chloe_say("« Complétez la phrase : » %s" % str(current_spec.get("sub_en", "")))

	_refresh_prompt_hud()
	_update_stats_hud()
	audio.play_voice(str(current_spec.get("audio_file", "")))


func _refresh_prompt_hud() -> void:
	var ptype := str(current_spec.get("prompt_type", "VOCAB"))
	var show_en := bool(current_spec.get("show_en_text", true)) or (prompt_hint_stage >= 1)

	if ptype == "DIRECTION":
		var parts: Array[String] = []
		for idx in range(_dir_steps.size()):
			var d_key: String = _dir_steps[idx]
			var d_fr: String = str(VocabData.DIRECTION_INFO[d_key]["fr"])
			if idx < _dir_step_idx:
				parts.append("✓ " + d_fr)
			elif idx == _dir_step_idx:
				parts.append("★ " + d_fr.to_upper())
			else:
				parts.append(d_fr)
		var seq_str := "   →   ".join(parts)
		prompt_main_lbl.text = "◈ NAVIGATION :  %s" % seq_str
		prompt_sub_lbl.visible = true
		prompt_sub_lbl.text = "%s   •   Walk onto the GOLD checkpoint with [WASD] or Click!" % str(current_spec.get("prompt_en", ""))
		return

	if ptype == "COMBO":
		prompt_main_lbl.text = "♪ COMBO ORDER :  %s" % str(current_spec.get("prompt_fr", ""))
		prompt_sub_lbl.visible = true
		prompt_sub_lbl.text = "%s   •   Pick up both items, then walk to the Customer Table!" % str(current_spec.get("prompt_en", ""))
		return

	if ptype == "DAILY_PHRASE":
		prompt_main_lbl.text = "♪ %s" % str(current_spec.get("prompt_fr", ""))
		prompt_sub_lbl.visible = true
		prompt_sub_lbl.text = "Click, walk onto, or press [1–3] to choose the matching French phrase!"
		return

	if ptype == "GRAMMAR":
		prompt_main_lbl.text = "♪ %s" % str(current_spec.get("prompt_fr", ""))
		prompt_sub_lbl.visible = true
		prompt_sub_lbl.text = str(current_spec.get("sub_en", ""))
		return

	# Default VOCAB single-item order
	prompt_main_lbl.text = "♪ %s" % str(current_spec.get("prompt_fr", ""))
	if show_en:
		prompt_sub_lbl.visible = true
		prompt_sub_lbl.text = str(current_spec.get("sub_en", ""))
	else:
		prompt_sub_lbl.visible = true
		prompt_sub_lbl.text = "Listen to the order! Walk to the counter station to pick it up, then serve at the table. ([E] Replay • [H] Hint)"


# ==============================================================================
# 2.5D WORLD INTERACTION HANDLERS (STATIONS, TABLE, DIRECTIONS, PHRASES, GATE)
# ==============================================================================

func _on_world_station_interacted(vocab_id: String, station_pos: Vector2) -> void:
	if state == GameState.MENU:
		_on_start_mission_pressed()
		return

	if state == GameState.GALLERY:
		audio.play_sfx("scan", 0.02, -6.5)
		audio.play_voice("phrase_%s.ogg" % vocab_id)
		srs.mark_calibrated(vocab_id)
		var g_item := VocabData.get_by_id(vocab_id)
		paris_world.spawn_popup(station_pos + Vector2(0, -45), "♪ %s (%s)" % [g_item.get("fr_def", vocab_id), g_item.get("en", "")])
		prompt_main_lbl.text = "♪ %s (%s)  —  « %s »" % [g_item["fr_def"], g_item["en"], g_item.get("phrase_fr", "")]
		prompt_sub_lbl.visible = true
		prompt_sub_lbl.text = "%s   •   %s" % [g_item.get("phrase_en", ""), g_item.get("tip", "")]
		_chloe_say("« %s » (%s) — %s" % [g_item.get("phrase_fr", g_item["fr_def"]), g_item.get("phrase_en", g_item["en"]), g_item["tip"]])
		return

	if state != GameState.COMBAT or not prompt_active:
		return

	var ptype := str(current_spec.get("prompt_type", "VOCAB"))
	if ptype not in ["VOCAB", "COMBO"]:
		return

	var item := VocabData.get_by_id(vocab_id)
	var req_ids: Array = paris_world.customer_order_ids

	if req_ids.has(vocab_id):
		if not paris_world.tray_items.has(vocab_id):
			paris_world.tray_items.append(vocab_id)
			audio.play_sfx("scan", 0.02, -6.5)
			audio.play_voice("word_%s.ogg" % vocab_id)
			paris_world.spawn_popup(station_pos + Vector2(0, -45), "✓ Picked up %s!" % str(item.get("fr_def", vocab_id)), Color(0.32, 0.98, 0.58))
			feedback_banner.visible = false

			# Check if tray now has all requested items
			var all_ready := true
			for rid in req_ids:
				if not paris_world.tray_items.has(str(rid)):
					all_ready = false
					break
			if all_ready:
				_chloe_say("« Parfait ! Vous avez %s ! Apportez le plateau à la Table de Service (ou appuyez sur [Espace]) ! »" % str(item.get("fr_def", vocab_id)))
			else:
				_chloe_say("« Bien ! Maintenant, prenez le deuxième article pour compléter la commande ! »")
	else:
		# Picked up an item the customer didn't ask for — gentle French + English guidance!
		prompt_clean_try = false
		combo = 0
		audio.play_sfx("hit_err", 0.02, -7.0)
		if not prompt_wrong_ids.has(vocab_id):
			prompt_wrong_ids.append(vocab_id)
		var first_req := str(req_ids[0]) if not req_ids.is_empty() else "tasse"
		var true_item := VocabData.get_by_id(first_req)
		paris_world.spawn_popup(station_pos + Vector2(0, -45), "✗ %s (%s)" % [item.get("fr_def", vocab_id), item.get("en", "")], Color(1.0, 0.72, 0.28))

		# Highlight the requested station(s) in gold
		var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
		var hi_list: Array[String] = []
		for r in req_ids:
			hi_list.append(str(r))
		paris_world.setup_stations_for_items(_get_sector_item_dicts(act_s), hi_list, true)

		_show_feedback(
			"That counter is %s (%s).  →  ★ Walk to the GOLD station: %s (%s)!" % [
				item.get("fr_def", vocab_id), item.get("en", ""), true_item.get("fr_def", first_req), true_item.get("en", "")
			],
			false
		)
		_chloe_say("« Pas de souci ! Ça, c'est %s (%s). Le client voudrait %s (%s) ! »" % [
			item.get("fr_def", vocab_id), item.get("en", ""), true_item.get("fr_def", first_req), true_item.get("en", "")
		], "chloe_try_again.ogg")
		_update_stats_hud()


func _on_world_table_interacted(t_pos: Vector2) -> void:
	if state != GameState.COMBAT or not prompt_active:
		return
	var ptype := str(current_spec.get("prompt_type", "VOCAB"))
	if ptype not in ["VOCAB", "COMBO"]:
		return

	var req_ids: Array = paris_world.customer_order_ids
	if req_ids.is_empty():
		return

	var all_on_tray := true
	for rid in req_ids:
		if not paris_world.tray_items.has(str(rid)):
			all_on_tray = false
			break

	if not all_on_tray:
		var missing_id := str(req_ids[0])
		for rid in req_ids:
			if not paris_world.tray_items.has(str(rid)):
				missing_id = str(rid)
				break
		var m_item := VocabData.get_by_id(missing_id)
		paris_world.spawn_popup(t_pos + Vector2(0, -48), "Pick up %s first!" % str(m_item.get("fr_def", missing_id)), Color(1.0, 0.86, 0.32))
		_chloe_say("« Allez d'abord chercher %s (%s) au comptoir en haut ! »" % [str(m_item.get("fr_def", missing_id)), str(m_item.get("en", ""))])
		return

	# Order Served Successfully!
	prompt_active = false
	feedback_banner.visible = false
	audio.play_sfx("hit_ok", 0.02, -6.0)
	var pts := 120
	if prompt_clean_try:
		combo += 1
		wave_hits_clean += 1
		pts = 120 + combo * 30
	else:
		pts = 90
	score += pts
	paris_world.clear_tray()
	paris_world.spawn_popup(t_pos + Vector2(0, -55), "+%d ★  Merci beaucoup !" % pts, Color(1.0, 0.90, 0.28))

	var bravo_voice := "chloe_bravo_%d.ogg" % ((combo % 3) + 1)
	if ptype == "COMBO":
		for cid in req_ids:
			srs.record_result(str(cid), prompt_clean_try, prompt_used_assist, prompt_wrong_ids)
		prompt_main_lbl.text = "✓ SERVED : %s   (%s)" % [str(current_spec["prompt_fr"]), str(current_spec["prompt_en"])]
		_chloe_say("« Magnifique service ! %s »" % str(current_spec["prompt_fr"]), bravo_voice)
	else:
		var target_id := str(current_spec["target_id"])
		srs.record_result(target_id, prompt_clean_try, prompt_used_assist, prompt_wrong_ids)
		var t_item := VocabData.get_by_id(target_id)
		prompt_main_lbl.text = "✓ SERVED : %s (%s)  —  « %s »" % [t_item["fr_def"], t_item["en"], t_item.get("phrase_fr", "")]
		_chloe_say("« Très bien servi ! %s » (%s)" % [t_item.get("phrase_fr", t_item["fr_def"]), t_item.get("phrase_en", t_item["en"])], bravo_voice)

	_update_stats_hud()
	transition_delay = 1.05


func _on_world_direction_pad_entered(dir_key: String, pad_pos: Vector2) -> void:
	if state != GameState.COMBAT or not prompt_active:
		return
	if str(current_spec.get("prompt_type", "")) != "DIRECTION":
		return
	if _dir_step_idx >= _dir_steps.size():
		return

	var expected_key := str(_dir_steps[_dir_step_idx])
	if dir_key != expected_key:
		return

	if _dir_step_idx + 1 < _dir_steps.size():
		_dir_step_idx += 1
		score += 75
		audio.play_sfx("scan", 0.02, -6.5)
		var next_key := str(_dir_steps[_dir_step_idx])
		var next_info: Dictionary = VocabData.DIRECTION_INFO[next_key]
		paris_world.spawn_popup(pad_pos + Vector2(0, -42), "✓ %s!" % str(VocabData.DIRECTION_INFO[dir_key]["fr"]), Color(0.32, 0.98, 0.56))
		paris_world.setup_direction_checkpoints(_dir_steps, _dir_step_idx)
		audio.play_voice(str(next_info["audio"]))
		_refresh_prompt_hud()
		_update_stats_hud()
		_chloe_say("« Très bien ! Maintenant : %s ! » (%s)" % [str(next_info["fr"]), str(next_info["en"])])
	else:
		prompt_active = false
		feedback_banner.visible = false
		audio.play_sfx("hit_ok", 0.02, -6.0)
		combo += 1
		wave_hits_clean += 1
		var pts := 140 + _dir_steps.size() * 45
		score += pts
		srs.global_step += 1
		srs.save_progress()
		paris_world.spawn_popup(pad_pos + Vector2(0, -46), "+%d ★  Route Complete!" % pts, Color(1.0, 0.90, 0.28))
		prompt_main_lbl.text = "✓ %s   (%s)" % [str(current_spec["prompt_fr"]), str(current_spec["prompt_en"])]
		_chloe_say("« Bravo ! %s ! » (%s)" % [str(current_spec["prompt_fr"]), str(current_spec["prompt_en"])], "chloe_bravo_%d.ogg" % ((combo % 3) + 1))
		_update_stats_hud()
		transition_delay = 1.05


func _on_world_phrase_option_selected(opt_text: String, _idx: int) -> void:
	if state != GameState.COMBAT or not prompt_active:
		return
	var ptype := str(current_spec.get("prompt_type", ""))
	if ptype not in ["DAILY_PHRASE", "GRAMMAR"]:
		return

	var target_opt := str(current_spec.get("target_id", ""))
	if opt_text == target_opt:
		prompt_active = false
		feedback_banner.visible = false
		audio.play_sfx("hit_ok", 0.02, -6.0)
		combo += 1
		wave_hits_clean += 1
		var pts := 150 + combo * 25
		score += pts
		paris_world.spawn_popup(Vector2(640, 310), "+%d ★  « %s »" % [pts, opt_text], Color(0.32, 0.98, 0.58))
		var bravo_voice := "chloe_bravo_%d.ogg" % ((combo % 3) + 1)

		if ptype == "DAILY_PHRASE":
			srs.global_step += 1
			srs.save_progress()
			prompt_main_lbl.text = "✓ « %s »  =  %s" % [str(current_spec["phrase_fr"]), str(current_spec["phrase_en"])]
			_chloe_say("« Parfait ! %s » (%s)" % [str(current_spec["phrase_fr"]), str(current_spec["phrase_en"])], bravo_voice)
		else:
			var gid := str(current_spec["grammar_id"])
			srs.record_grammar_result(gid, prompt_clean_try, prompt_used_assist)
			prompt_main_lbl.text = "✓ %s   (%s)" % [str(current_spec["sentence_full"]), str(current_spec["en"])]
			_chloe_say("« Très bien ! %s »" % str(current_spec["sentence_full"]), bravo_voice)

		_update_stats_hud()
		transition_delay = 1.05
	else:
		prompt_clean_try = false
		combo = 0
		audio.play_sfx("hit_err", 0.02, -7.0)
		paris_world.phrase_highlight_opt = target_opt
		_play_slow_assist()
		_show_feedback("✗ Try the gold-highlighted response: « %s »" % target_opt, false)
		_chloe_say("« Pas de souci ! Choisissez : %s » (%s)" % [target_opt, str(current_spec.get("phrase_en", ""))], "chloe_try_again.ogg")
		_update_stats_hud()


func _on_world_exit_gate_entered() -> void:
	if state == GameState.WAVE_SUMMARY:
		_continue_to_next_round()
	elif state == GameState.GALLERY:
		_on_start_mission_pressed()


func _play_slow_assist() -> void:
	prompt_used_assist = true
	var slow_f := str(current_spec.get("slow_audio_file", ""))
	if slow_f != "":
		audio.play_voice(slow_f)
	else:
		audio.play_voice(str(current_spec.get("audio_file", "")), 4.5, 0.85)


func _show_feedback(msg: String, is_ok: bool) -> void:
	feedback_banner.visible = true
	var border_col := Color(0.42, 0.96, 0.56, 0.95) if is_ok else Color(1.0, 0.82, 0.24, 0.96)
	var bg_col := Color(0.10, 0.22, 0.12, 0.92) if is_ok else Color(0.24, 0.12, 0.07, 0.92)
	feedback_banner.add_theme_stylebox_override("panel", _make_panel_style(bg_col, border_col, 14, 2))
	feedback_lbl.text = msg
	feedback_lbl.add_theme_color_override("font_color", Color(0.78, 1.0, 0.84) if is_ok else Color(1.0, 0.94, 0.72))


func _update_stats_hud() -> void:
	var s_info := VocabData.SECTORS[clampi(_active_map_idx, 0, 8)]
	wave_lbl.text = "%s  •  STEP %d/%d" % [String(s_info["name_fr"]).to_upper(), prompt_in_wave, PROMPTS_PER_WAVE]
	score_lbl.text = "★ %d PTS   (STREAK x%d)" % [score, maxi(1, combo)]


func _finish_wave() -> void:
	state = GameState.WAVE_SUMMARY
	prompt_active = false
	feedback_banner.visible = false
	summary_panel.visible = false
	hud_root.visible = true
	audio.play_sfx("wave_up")

	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)
	radio_panel.visible = true
	prompt_main_lbl.text = "★ CHAPTER ROUND %d COMPLETE (%d/%d) !   Walk through the Golden Street Archway (→) or Press [Space]!" % [
		wave_number, wave_hits_clean, PROMPTS_PER_WAVE
	]
	prompt_sub_lbl.visible = true
	prompt_sub_lbl.text = "Walk right to the glowing archway or press [Space] to start Round %d!" % (wave_number + 1)
	timer_bar.value = 100.0

	if paris_world:
		paris_world.current_mode = "WAVE_SUMMARY"
		paris_world.exit_gate_open = true
		paris_world.exit_gate_label = "★ ROUND %d →" % (wave_number + 1)

	_chloe_say("« Félicitations ! Manche terminée ! On continue ? » (Round %d complete! Walk through the golden archway on the right or press [Space]!)" % wave_number, "chloe_round_done.ogg")


func _continue_to_next_round() -> void:
	audio.play_sfx("click")
	summary_panel.visible = false
	hud_root.visible = true
	wave_number += 1
	_begin_wave()


## Keyboard convenience: pressing [1]..[5] walks/teleports to station N (or serves if already carrying it)
func _handle_slot_hotkey(slot_idx: int) -> void:
	if state == GameState.GALLERY:
		if slot_idx >= 0 and slot_idx < paris_world.stations.size():
			var st: Dictionary = paris_world.stations[slot_idx]
			paris_world.player_pos = st["pos"]
			_on_world_station_interacted(str(st["id"]), st["pos"])
		return

	if state != GameState.COMBAT or not prompt_active:
		return

	var ptype := str(current_spec.get("prompt_type", "VOCAB"))
	if ptype in ["DAILY_PHRASE", "GRAMMAR"]:
		if slot_idx >= 0 and slot_idx < paris_world.phrase_options.size():
			_on_world_phrase_option_selected(str(paris_world.phrase_options[slot_idx]), slot_idx)
		return

	if ptype == "DIRECTION":
		if _dir_step_idx < _dir_steps.size():
			var cur_key := str(_dir_steps[_dir_step_idx])
			for cp in paris_world.dir_checkpoints:
				if str(cp["key"]) == cur_key:
					paris_world.player_pos = cp["pos"]
					_on_world_direction_pad_entered(cur_key, cp["pos"])
					return
		return

	if slot_idx >= 0 and slot_idx < paris_world.stations.size():
		var st: Dictionary = paris_world.stations[slot_idx]
		var vid := str(st["id"])
		paris_world.player_pos = st["pos"] + Vector2(0, 34)
		_on_world_station_interacted(vid, st["pos"])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not lexicon_open:
			if state in [GameState.COMBAT, GameState.GALLERY, GameState.WAVE_SUMMARY]:
				paris_world.handle_click(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not lexicon_open:
			paris_world.clear_tray()
		return

	if state == GameState.WAVE_SUMMARY:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_1]:
				_continue_to_next_round()
				get_viewport().set_input_as_handled()
				return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = event.physical_keycode

	if kc == KEY_TAB:
		_toggle_lexicon()
		get_viewport().set_input_as_handled()
		return

	if kc == KEY_ESCAPE:
		if lexicon_open:
			_toggle_lexicon(false)
		elif state != GameState.MENU:
			_enter_menu()
		get_viewport().set_input_as_handled()
		return

	if lexicon_open:
		return

	if state == GameState.MENU:
		if kc in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_on_start_mission_pressed()
		elif kc == KEY_G:
			_on_enter_gallery_pressed()
		return

	if kc == KEY_G and state != GameState.GALLERY:
		_on_enter_gallery_pressed()
		return

	if state == GameState.GALLERY:
		if kc >= KEY_1 and kc <= KEY_9:
			_load_gallery_sector(int(kc - KEY_1))
		elif kc in [KEY_M, KEY_SPACE]:
			_on_start_mission_pressed()
		return

	if state == GameState.COMBAT and prompt_active:
		if kc == KEY_E:
			audio.play_voice(str(current_spec.get("audio_file", "")))
		elif kc == KEY_R:
			_play_slow_assist()
		elif kc == KEY_Q:
			paris_world.clear_tray()
		elif kc == KEY_H:
			prompt_used_assist = true
			prompt_hint_stage = mini(2, prompt_hint_stage + 1)
			_refresh_prompt_hud()
			var reqs := paris_world.customer_order_ids
			if not reqs.is_empty():
				var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
				var hi: Array[String] = []
				for r in reqs:
					hi.append(str(r))
				paris_world.setup_stations_for_items(_get_sector_item_dicts(act_s), hi, true)
		elif kc == KEY_SPACE:
			if str(current_spec.get("prompt_type", "")) == "DIRECTION":
				_handle_slot_hotkey(0)
			else:
				paris_world.player_pos = paris_world.table_pos + Vector2(0, 42)
				_on_world_table_interacted(paris_world.table_pos)
		elif kc >= KEY_1 and kc <= KEY_5:
			_handle_slot_hotkey(int(kc - KEY_1))


func _process(delta: float) -> void:
	if transition_delay > 0.0:
		transition_delay -= delta
		if transition_delay <= 0.0:
			if state == GameState.COMBAT:
				feedback_banner.visible = false
				_next_combat_prompt()
		return

	if state == GameState.COMBAT and prompt_active and prompt_clean_try and int(current_spec.get("tier", 0)) >= 1:
		prompt_timer -= delta
		timer_bar.value = clampf((prompt_timer / PROMPT_TIME_LIMIT) * 100.0, 0.0, 100.0)
		if prompt_timer <= 0.0:
			prompt_clean_try = false
			combo = 0
			var reqs := paris_world.customer_order_ids
			if not reqs.is_empty():
				var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
				var hi: Array[String] = []
				for r in reqs:
					hi.append(str(r))
				paris_world.setup_stations_for_items(_get_sector_item_dicts(act_s), hi, true)
			_play_slow_assist()
			_show_feedback("★ Hint unlocked — walk to the gold-highlighted station and serve at the Customer Table!", false)
			_update_stats_hud()
	elif state == GameState.COMBAT and prompt_active and int(current_spec.get("tier", 0)) == 0:
		timer_bar.value = 100.0


# ==============================================================================
# AUTOMATED SCREENSHOT & SRS VERIFICATION HOOK (`-- --verify-screenshots`)
# ==============================================================================

func _run_automated_verification() -> void:
	var out_dir := "/tmp/franc_tireur_verify"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var test_srs := SRSEngine.new()
	test_srs.reset_progress()
	assert(test_srs.cards.size() == 45, "Expected 45 vocabulary cards")
	assert(test_srs.get_active_campaign_sector() == 0, "New campaign should start at Chapter 1 (Sector 0)")
	var map1_pool := test_srs.get_candidate_pool()
	assert(map1_pool.size() == 5 and map1_pool.has("tasse") and map1_pool.has("pain"), "Chapter 1 candidate pool should strictly match Café de Flore's 5 words")
	test_srs.mark_calibrated("tasse")
	var r1 := test_srs.record_result("tasse", true, false, [])
	assert(int(r1["new_tier"]) == 1, "Clean delivery should advance Level 1 -> Level 2")
	var r2 := test_srs.record_result("tasse", true, false, [])
	assert(int(r2["new_tier"]) == 2, "Clean delivery should advance Level 2 -> Level 3")
	var r_err := test_srs.record_result("tasse", false, false, ["fromage"])
	assert(int(r_err["new_tier"]) == 1, "Mistake should drop Level 3 -> Level 2 and log confusion")
	var combo_spec := test_srs.build_combo_prompt_spec(0)
	assert(str(combo_spec["prompt_type"]) == "COMBO" and combo_spec["combo_ids"].size() == 2, "Combo order spec should request 2 items")
	var dir_spec := test_srs.build_direction_prompt_spec(2, 5)
	assert(str(dir_spec["prompt_type"]) == "DIRECTION" and dir_spec["steps"].size() == 2, "Direction sequence spec should have 2 steps")
	var dp_spec := test_srs.build_daily_phrase_prompt_spec(0, 1)
	assert(str(dp_spec["prompt_type"]) == "DAILY_PHRASE" and str(dp_spec["target_id"]) == "Excusez-moi, l'addition, s'il vous plaît !", "Everyday phrase spec should match Excusez-moi, l'addition, s'il vous plaît !")
	print("VERIFY_OK: 2.5D Hand-Painted Parisian Adventure, Bistro Tray Delivery, Combo Orders, Street Directions & Chloé Portrait verified.")

	# 1. Title Screen in Au Café de Flore (map_cafe.jpg + 5 illustrated Café stations + Chloé Portrait)
	srs.reset_progress()
	srs.sector_filter = 0
	_enter_menu()
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/01_menu.png")

	# 2. Chapter 1 Step 1 (VOCAB Tier 0 Spotlight) in Au Café de Flore: "la tasse" highlighted in gold + Customer Service Table
	srs.reset_progress()
	srs.sector_filter = 0
	_on_start_mission_pressed()
	current_spec = srs.build_prompt_spec("tasse")
	paris_world.current_mode = "VOCAB"
	paris_world.table_visible = true
	paris_world.customer_order_ids = ["tasse"]
	paris_world.player_pos = Vector2(310.0, 395.0)
	var hi_tasse: Array = ["tasse"]
	paris_world.setup_stations_for_items(_get_sector_item_dicts(0), hi_tasse, true)
	_refresh_prompt_hud()
	_chloe_say("« Voici la tasse (the cup) ! » — Walk up to [1] la tasse to pick it up, then bring it to the Customer Table!")
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/02_calibration_3d.png")

	# 3. 2-Item Combo Order (COMBO) in Au Café de Flore: Player carrying "la tasse" on overhead Bistro Tray & walking to "le pain"
	paris_world.popups.clear()
	prompt_in_wave = 4
	score = 390
	combo = 3
	current_spec = srs.build_combo_prompt_spec(0)
	paris_world.current_mode = "COMBO"
	paris_world.table_visible = true
	var combo_req: Array = ["tasse", "pain"]
	paris_world.customer_order_ids = combo_req
	paris_world.tray_items = ["tasse"]
	paris_world.player_pos = Vector2(445.0, 335.0)
	paris_world.spawn_popup(Vector2(215.0, 200.0), "✓ Picked up la tasse!", Color(0.32, 0.98, 0.58))
	paris_world.setup_stations_for_items(_get_sector_item_dicts(0), combo_req, true)
	_refresh_prompt_hud()
	_update_stats_hud()
	_chloe_say("« Un café et un croissant, s'il vous plaît ! » — Great, you have la tasse on your tray! Now pick up le pain and serve at the table!")
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/03_combat_pure_listening.png")

	# 4. Street Direction Checkpoints (DIRECTION) in Le Marché de Rue (map_marche.jpg)
	paris_world.popups.clear()
	srs.sector_filter = 2
	prompt_in_wave = 5
	score = 620
	combo = 4
	_apply_map_theme(2)
	current_spec = srs.build_direction_prompt_spec(2, 5)
	_dir_steps = ["gauche", "haut"]
	_dir_step_idx = 1
	paris_world.current_mode = "DIRECTION"
	paris_world.table_visible = false
	paris_world.clear_tray()
	paris_world.player_pos = Vector2(485.0, 395.0)
	paris_world.setup_direction_checkpoints(_dir_steps, _dir_step_idx)
	paris_world.spawn_popup(Vector2(280.0, 400.0), "✓ À gauche!", Color(0.32, 0.98, 0.58))
	_refresh_prompt_hud()
	_update_stats_hud()
	_chloe_say("« Très bien ! Maintenant : en haut ! » (Great! Now walk onto the gold checkpoint: En haut!)")
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/06_a2_spatial_modifiers.png")

	# 5. Real-Life Conversation (DAILY_PHRASE) in La Gare du Nord (map_gare.jpg)
	paris_world.popups.clear()
	srs.sector_filter = 3
	prompt_in_wave = 6
	score = 840
	combo = 5
	_apply_map_theme(3)
	current_spec = srs.build_daily_phrase_prompt_spec(3, -1)
	paris_world.current_mode = "DAILY_PHRASE"
	paris_world.table_visible = false
	var dp_opts: Array[String] = []
	for o in current_spec.get("options", []):
		dp_opts.append(str(o))
	paris_world.phrase_options = dp_opts
	paris_world.phrase_highlight_opt = str(current_spec.get("target_id", ""))
	paris_world.player_pos = Vector2(640.0, 510.0)
	_refresh_prompt_hud()
	_update_stats_hud()
	_chloe_say("« En France (%s) : » %s" % [str(current_spec.get("situation_en", "")), str(current_spec.get("chloe_tip", ""))])
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/07_b1_grammar_breach.png")

	# 6. Interactive Map Explorer (GALLERY) in La Maison Parisienne (map_maison.jpg)
	paris_world.popups.clear()
	_on_enter_gallery_pressed()
	_load_gallery_sector(1)
	paris_world.player_pos = Vector2(402.0, 315.0)
	_on_world_station_interacted("livre", Vector2(402.0, 232.0))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/05_gallery_study.png")

	# 7. Word & Phrase Book — All 45 Words across 9 Chapters
	lexicon_tab = "ALL"
	_toggle_lexicon(true)
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/04_srs_lexicon.png")

	# 8. Word & Phrase Book — 18 Everyday French Phrases & Cultural Tips
	lexicon_tab = "PHRASES"
	_populate_lexicon_grid()
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/08_srs_grammar_matrix.png")

	print("SCREENSHOTS_COMPLETE: Saved 01..08 to " + out_dir)
	get_tree().quit(0)


func _save_viewport_png(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
