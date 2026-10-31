class_name GameManager
extends Node3D

## Master Orchestrator for FRANC-TIREUR : Opération Écho (CEFR A1–B1 Edition)
## Features:
## - Bright, high-contrast Parisian Sky-Dome Training Range (daylight stone courtyard, colonnade, clear sightlines)
## - Close-mid range (6.8m–7.8m), large, lane-separated 3D Blender targets with English concept tags
## - Seamless 4-Step Educational Scaling inside live rounds:
##     Step 1 (Tier 0): New Word Spotlight (Green target ring + French/English + IPA pronunciation tip)
##     Step 2 (Tier 1): Recall Shot (French text + audio, no green ring, 4 targets)
##     Step 3 (Tier 2): Pure Ear Shot (Audio only — identify spoken French by ear alone!)
##     Step 4 (Tier 3+): Riddles, Negation Traps, A2 3D Size/Speed Challenges & B1 Grammar Crystals
## - Supports both Mouse Aim + Click AND Quick-Shot Keys [1]–[4] for laptop/trackpad accessibility!

enum GameState {
	MENU,
	CALIBRATION,
	COMBAT,
	WAVE_SUMMARY,
	GALLERY,
}

const PROMPTS_PER_WAVE := 6
const PROMPT_TIME_LIMIT := 20.0
const ARENA_CENTER := Vector3(0.0, 0.0, -2.0)

var state: GameState = GameState.MENU
var srs: SRSEngine
var audio: AudioDirector
var player: PlayerController

var world_root: Node3D
var drones_root: Node3D
var pedestals_root: Node3D
var gallery_sign: Label3D
var pedestals: Array[PedestalStation] = []
var active_drones: Array[TargetDrone] = []

# Wave & Prompt runtime state
var wave_number: int = 1
var prompt_in_wave: int = 0
var wave_hits_clean: int = 0
var score: int = 0
var combo: int = 0
var shield_hp: float = 100.0

var calibration_queue: Array[String] = []
var current_calib_id: String = ""

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
var crosshair_reticle: CrosshairReticle
var _reticle_col: Color = Color(0.15, 0.95, 0.75, 0.95)
var hover_info_lbl: Label
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
var wave_bars: Array[ColorRect] = []

var menu_panel: PanelContainer
var menu_stats_lbl: Label
var sector_btn: Button
var l1_btn: Button

var summary_panel: PanelContainer
var summary_lbl: Label

var lexicon_panel: PanelContainer
var lexicon_grid: GridContainer
var lexicon_header_lbl: Label
var lexicon_open: bool = false

var _menu_orbit_angle: float = 0.0
var _menu_cam: Camera3D


func _ready() -> void:
	randomize()
	srs = SRSEngine.new()
	audio = AudioDirector.new()
	add_child(audio)

	world_root = Node3D.new()
	world_root.name = "WorldRoot"
	add_child(world_root)

	drones_root = Node3D.new()
	drones_root.name = "DronesRoot"
	world_root.add_child(drones_root)

	pedestals_root = Node3D.new()
	pedestals_root.name = "PedestalsRoot"
	world_root.add_child(pedestals_root)

	_build_environment_and_lights()
	_build_arena_geometry()
	_spawn_player()
	_spawn_gallery_pedestals()
	_build_ui()

	_enter_menu()

	var user_args := OS.get_cmdline_user_args()
	if user_args.has("--verify-screenshots"):
		_run_automated_verification()


# ==============================================================================
# BRIGHT STYLIZED DAYLIGHT TRAINING RANGE & LIGHTING
# ==============================================================================

func _build_environment_and_lights() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.14, 0.36, 0.76)
	sky_mat.sky_horizon_color = Color(0.45, 0.68, 0.92)
	sky_mat.ground_bottom_color = Color(0.12, 0.16, 0.24)
	sky_mat.ground_horizon_color = Color(0.28, 0.42, 0.64)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.72, 0.80, 0.94)
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	world_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.60, 0.80, 1.0)
	fill.light_energy = 0.42
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-35.0, 150.0, 0.0)
	world_root.add_child(fill)

	_menu_cam = Camera3D.new()
	_menu_cam.fov = 62.0
	world_root.add_child(_menu_cam)


func _make_mat(albedo: Color, rough: float = 0.45, metal: float = 0.15, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _add_static_box(parent: Node3D, size: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material, with_col: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)

	if with_col:
		var sb := StaticBody3D.new()
		sb.position = pos
		sb.rotation_degrees = rot_deg
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		parent.add_child(sb)


func _build_arena_geometry() -> void:
	var arena := Node3D.new()
	arena.name = "HolodeckArena"
	world_root.add_child(arena)

	# Rich mid-tone royal slate courtyard floor + navy-cobalt backdrop wall so bright 3D models pop with vivid saturation!
	var floor_mat := _make_mat(Color(0.18, 0.24, 0.35), 0.50, 0.15)
	var deck_mat := _make_mat(Color(0.24, 0.31, 0.44), 0.42, 0.18)
	var wall_mat := _make_mat(Color(0.14, 0.20, 0.32), 0.48, 0.25)
	var pillar_mat := _make_mat(Color(0.76, 0.82, 0.90), 0.35, 0.20)
	var gold_trim := _make_mat(Color(0.95, 0.78, 0.24), 0.25, 0.75)

	var lane_glow := _make_mat(Color(0.22, 0.78, 1.0), 0.2, 0.0, true)
	var fr_blue := _make_mat(Color(0.12, 0.38, 0.92), 0.2, 0.0, true)
	var fr_white := _make_mat(Color(0.96, 0.98, 1.0), 0.2, 0.0, true)
	var fr_red := _make_mat(Color(0.92, 0.18, 0.24), 0.2, 0.0, true)

	_add_static_box(arena, Vector3(42.0, 0.5, 42.0), Vector3(0, -0.25, 0), Vector3.ZERO, floor_mat, true)
	_add_static_box(arena, Vector3(16.0, 0.18, 6.0), Vector3(0, 0.09, 6.8), Vector3.ZERO, deck_mat, true)
	_add_static_box(arena, Vector3(22.0, 0.20, 6.5), Vector3(0, 0.10, -13.5), Vector3.ZERO, deck_mat, true)

	# Subtle firing-lane guide lines on the courtyard floor
	for gx in [-6.3, -2.1, 2.1, 6.3]:
		_add_static_box(arena, Vector3(0.08, 0.02, 16.0), Vector3(gx, 0.01, -1.0), Vector3.ZERO, lane_glow, false)
	for gz in [-4.0, 0.0, 4.0]:
		_add_static_box(arena, Vector3(20.0, 0.02, 0.08), Vector3(0.0, 0.01, gz), Vector3.ZERO, lane_glow, false)

	var oct_r := 18.5
	for i in range(8):
		var ang_deg := float(i) * 45.0
		var ang_rad := deg_to_rad(ang_deg)
		var wx := sin(ang_rad) * oct_r
		var wz := cos(ang_rad) * oct_r
		_add_static_box(arena, Vector3(15.8, 4.2, 0.8), Vector3(wx, 2.1, wz), Vector3(0, ang_deg, 0), wall_mat, true)
		_add_static_box(arena, Vector3(15.8, 0.18, 0.92), Vector3(wx, 4.25, wz), Vector3(0, ang_deg, 0), gold_trim, false)

		var inward := 0.972
		_add_static_box(arena, Vector3(15.0, 0.11, 0.12), Vector3(wx * inward, 3.65, wz * inward), Vector3(0, ang_deg, 0), fr_blue, false)
		_add_static_box(arena, Vector3(15.0, 0.11, 0.12), Vector3(wx * inward, 3.45, wz * inward), Vector3(0, ang_deg, 0), fr_white, false)
		_add_static_box(arena, Vector3(15.0, 0.11, 0.12), Vector3(wx * inward, 3.25, wz * inward), Vector3(0, ang_deg, 0), fr_red, false)

		var c_ang := deg_to_rad(ang_deg + 22.5)
		var cx := sin(c_ang) * (oct_r - 0.3)
		var cz := cos(c_ang) * (oct_r - 0.3)
		_add_static_box(arena, Vector3(0.95, 5.0, 0.95), Vector3(cx, 2.5, cz), Vector3(0, ang_deg + 22.5, 0), pillar_mat, true)

	gallery_sign = Label3D.new()
	gallery_sign.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	gallery_sign.text = "3D PRACTICE GALLERY (STAGES 1–9)  •  SHOOT ANY OBJECT TO HEAR IT"
	gallery_sign.position = Vector3(0, 3.85, -15.2)
	gallery_sign.font_size = 42
	gallery_sign.modulate = Color(1.0, 0.92, 0.38)
	gallery_sign.outline_size = 12
	arena.add_child(gallery_sign)


func _spawn_player() -> void:
	player = PlayerController.new()
	player.position = Vector3(0.0, 0.30, 6.8)
	world_root.add_child(player)
	player.look_toward_point(Vector3(0.0, 2.1, -0.8))
	player.fired_at_entity.connect(_on_player_fired)
	player.hovered_entity_changed.connect(_on_player_hovered)


func _spawn_gallery_pedestals() -> void:
	pedestals.clear()
	for ch in pedestals_root.get_children():
		ch.queue_free()

	var sec_ids := VocabData.get_sector_ids(0)
	var xs := [-7.2, -3.6, 0.0, 3.6, 7.2]
	for i in range(5):
		var ped := PedestalStation.new()
		pedestals_root.add_child(ped)
		var pos := Vector3(xs[i], 0.20, -13.2)
		ped.setup(sec_ids[i], pos, Vector3(0, 0.2, 6.0))
		pedestals.append(ped)


func _set_gallery_visible(enabled: bool) -> void:
	pedestals_root.visible = enabled
	if gallery_sign:
		gallery_sign.visible = enabled
	for ped in pedestals:
		if is_instance_valid(ped):
			ped.set_active_station(enabled)


func _refresh_gallery_pedestals(ids: Array[String]) -> void:
	for i in range(pedestals.size()):
		if i < ids.size():
			pedestals[i].set_active_station(true)
			pedestals[i].set_vocab(ids[i])
		else:
			pedestals[i].set_active_station(false)


# ==============================================================================
# CLEAN, ENGLISH-FIRST UI & HUD CONSTRUCTION
# ==============================================================================

func _make_panel_style(bg: Color, border: Color, radius: int = 12, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 11
	sb.content_margin_bottom = 11
	return sb


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(hud_root)

	# 1. Center Tactical Reticle & Hover Readout
	crosshair_reticle = CrosshairReticle.new()
	crosshair_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_reticle.set_anchors_preset(Control.PRESET_CENTER)
	crosshair_reticle.position = Vector2(-28, -28)
	crosshair_reticle.size = Vector2(56, 56)
	hud_root.add_child(crosshair_reticle)

	hover_info_lbl = Label.new()
	hover_info_lbl.text = ""
	hover_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hover_info_lbl.add_theme_font_size_override("font_size", 16)
	hover_info_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.38))
	hover_info_lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.10))
	hover_info_lbl.add_theme_constant_override("outline_size", 6)
	hover_info_lbl.set_anchors_preset(Control.PRESET_CENTER)
	hover_info_lbl.position = Vector2(-280, -212)
	hover_info_lbl.size = Vector2(560, 32)
	hud_root.add_child(hover_info_lbl)

	# 2. Top-Center Mission Prompt Banner
	var radio_panel := PanelContainer.new()
	radio_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.06, 0.11, 0.22, 0.93), Color(0.28, 0.84, 1.0, 0.95), 14, 2)
	)
	radio_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	radio_panel.position = Vector2(-410, 10)
	radio_panel.custom_minimum_size = Vector2(820, 120)
	radio_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(radio_panel)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	radio_panel.add_child(rv)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	rv.add_child(top_row)

	speaker_lbl = Label.new()
	speaker_lbl.text = "♪ VOICE: CMDT. HENRI"
	speaker_lbl.add_theme_font_size_override("font_size", 13)
	speaker_lbl.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0))
	top_row.add_child(speaker_lbl)

	var wave_box := HBoxContainer.new()
	wave_box.add_theme_constant_override("separation", 3)
	wave_box.custom_minimum_size = Vector2(92, 18)
	top_row.add_child(wave_box)
	wave_bars.clear()
	for i in range(12):
		var bar_wrap := Control.new()
		bar_wrap.custom_minimum_size = Vector2(5, 18)
		wave_box.add_child(bar_wrap)
		var bar := ColorRect.new()
		bar.color = Color(0.28, 1.0, 0.72)
		bar.position = Vector2(0, 7)
		bar.size = Vector2(5, 4)
		bar_wrap.add_child(bar)
		wave_bars.append(bar)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	mode_tag_lbl = Label.new()
	mode_tag_lbl.text = "STAGE 1 (A1) • STEP 1: LEARN & SHOOT"
	mode_tag_lbl.add_theme_font_size_override("font_size", 13)
	mode_tag_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30))
	top_row.add_child(mode_tag_lbl)

	prompt_main_lbl = Label.new()
	prompt_main_lbl.text = "Ready for Mission"
	prompt_main_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_main_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_main_lbl.add_theme_font_size_override("font_size", 21)
	prompt_main_lbl.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
	rv.add_child(prompt_main_lbl)

	prompt_sub_lbl = Label.new()
	prompt_sub_lbl.text = ""
	prompt_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_sub_lbl.add_theme_font_size_override("font_size", 13)
	prompt_sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	rv.add_child(prompt_sub_lbl)

	timer_bar = ProgressBar.new()
	timer_bar.show_percentage = false
	timer_bar.min_value = 0.0
	timer_bar.max_value = 100.0
	timer_bar.value = 100.0
	timer_bar.custom_minimum_size = Vector2(0, 7)
	var tb_fill := StyleBoxFlat.new()
	tb_fill.bg_color = Color(0.25, 0.92, 0.72)
	tb_fill.set_corner_radius_all(3)
	timer_bar.add_theme_stylebox_override("fill", tb_fill)
	rv.add_child(timer_bar)

	# 3. Feedback Banner (Hit / Mistake Coaching)
	feedback_banner = PanelContainer.new()
	feedback_banner.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.06, 0.14, 0.22, 0.95), Color(0.32, 1.0, 0.68, 0.95), 10, 2)
	)
	feedback_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	feedback_banner.position = Vector2(-390, 138)
	feedback_banner.custom_minimum_size = Vector2(780, 42)
	feedback_banner.visible = false
	feedback_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(feedback_banner)

	feedback_lbl = Label.new()
	feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_lbl.add_theme_font_size_override("font_size", 15)
	feedback_banner.add_child(feedback_lbl)

	# 4. Top-Left Score & Streak Panel
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.06, 0.11, 0.22, 0.90), Color(0.28, 0.62, 0.96, 0.85), 12, 2)
	)
	stats_panel.position = Vector2(14, 10)
	stats_panel.custom_minimum_size = Vector2(210, 106)
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(stats_panel)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	stats_panel.add_child(sv)

	wave_lbl = Label.new()
	wave_lbl.text = "ROUND 1  •  SHOT 1/6"
	wave_lbl.add_theme_font_size_override("font_size", 14)
	wave_lbl.add_theme_color_override("font_color", Color(0.62, 0.90, 1.0))
	sv.add_child(wave_lbl)

	score_lbl = Label.new()
	score_lbl.text = "SCORE: 0  (STREAK x1)"
	score_lbl.add_theme_font_size_override("font_size", 16)
	score_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	sv.add_child(score_lbl)

	var sh_lbl := Label.new()
	sh_lbl.text = "SHIELD INTEGRITY"
	sh_lbl.add_theme_font_size_override("font_size", 11)
	sh_lbl.add_theme_color_override("font_color", Color(0.75, 0.84, 0.96))
	sv.add_child(sh_lbl)

	shield_bar = ProgressBar.new()
	shield_bar.show_percentage = false
	shield_bar.max_value = 100.0
	shield_bar.value = 100.0
	shield_bar.custom_minimum_size = Vector2(0, 10)
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.24, 0.95, 0.62)
	sb_fill.set_corner_radius_all(4)
	shield_bar.add_theme_stylebox_override("fill", sb_fill)
	sv.add_child(shield_bar)

	# 5. Bottom Controls Legend Bar
	var bot_panel := PanelContainer.new()
	bot_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.05, 0.09, 0.18, 0.90), Color(0.24, 0.52, 0.86, 0.75), 10, 1)
	)
	bot_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bot_panel.position = Vector2(-530, -46)
	bot_panel.custom_minimum_size = Vector2(1060, 36)
	bot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bot_panel)

	hotkeys_lbl = Label.new()
	hotkeys_lbl.text = "[Mouse + Click] or [1-4] Shoot Target   •   [E] Replay Audio   •   [R] Slow Audio   •   [H] Show Hint   •   [Tab] Word List   •   [G] 3D Gallery   •   [Esc] Menu"
	hotkeys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkeys_lbl.add_theme_font_size_override("font_size", 13)
	hotkeys_lbl.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))
	bot_panel.add_child(hotkeys_lbl)

	_build_menu_overlay()
	_build_summary_overlay()
	_build_lexicon_overlay()


func _build_menu_overlay() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.06, 0.10, 0.20, 0.95), Color(0.28, 0.84, 1.0, 0.95), 16, 2)
	)
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.position = Vector2(-380, -265)
	menu_panel.custom_minimum_size = Vector2(760, 530)
	ui_layer.add_child(menu_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 11)
	menu_panel.add_child(vb)

	var title := Label.new()
	title.text = "FRANC-TIREUR : OPÉRATION ÉCHO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.38, 0.94, 1.0))
	vb.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "3D French Target Shooter  •  Learn Vocabulary, Listening & Grammar (CEFR A1 → B1)"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	vb.add_child(subtitle)

	var desc := Label.new()
	desc.text = (
		"HOW TO PLAY:\n"
		+ "1. LEARN (Step 1): New French words appear with a green target ring, English translation, and pronunciation guide.\n"
		+ "2. RECALL (Step 2): The green ring disappears — read/hear the French word and shoot the matching 3D object!\n"
		+ "3. MASTER (Step 3+): Audio-only commands, A2 3D Size/Speed challenges (biggest/fastest), and B1 Grammar Crystals!\n"
		+ "★ TIP: Aim & Left-Click to shoot, OR press [1] [2] [3] [4] to quick-shoot targets from left to right!"
	)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.78, 0.90, 1.0))
	vb.add_child(desc)

	menu_stats_lbl = Label.new()
	menu_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_stats_lbl.add_theme_font_size_override("font_size", 14)
	menu_stats_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.72))
	vb.add_child(menu_stats_lbl)

	sector_btn = Button.new()
	sector_btn.custom_minimum_size = Vector2(0, 40)
	sector_btn.add_theme_font_size_override("font_size", 14)
	sector_btn.pressed.connect(_on_cycle_sector)
	vb.add_child(sector_btn)

	l1_btn = Button.new()
	l1_btn.custom_minimum_size = Vector2(0, 38)
	l1_btn.add_theme_font_size_override("font_size", 14)
	l1_btn.pressed.connect(_on_cycle_l1_mode)
	vb.add_child(l1_btn)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vb.add_child(btn_row)

	var start_btn := Button.new()
	start_btn.text = "▶ PLAY ROUND (6 SHOTS)"
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.custom_minimum_size = Vector2(0, 52)
	start_btn.add_theme_font_size_override("font_size", 18)
	start_btn.pressed.connect(_on_start_mission_pressed)
	btn_row.add_child(start_btn)

	var gal_btn := Button.new()
	gal_btn.text = "◈ 3D PRACTICE GALLERY (STAGES 1–9)"
	gal_btn.custom_minimum_size = Vector2(275, 52)
	gal_btn.add_theme_font_size_override("font_size", 14)
	gal_btn.pressed.connect(_on_enter_gallery_pressed)
	btn_row.add_child(gal_btn)

	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 12)
	vb.add_child(bot_row)

	var lex_btn := Button.new()
	lex_btn.text = "✦ WORD & GRAMMAR CODEX (45 WORDS + 16 GRAMMAR RULES) [Tab]"
	lex_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lex_btn.custom_minimum_size = Vector2(0, 38)
	lex_btn.add_theme_font_size_override("font_size", 13)
	lex_btn.pressed.connect(func(): _toggle_lexicon(true))
	bot_row.add_child(lex_btn)

	var rst_btn := Button.new()
	rst_btn.text = "↺ Reset Progress"
	rst_btn.custom_minimum_size = Vector2(155, 38)
	rst_btn.add_theme_font_size_override("font_size", 13)
	rst_btn.pressed.connect(func():
		audio.play_sfx("click")
		srs.reset_progress()
		_refresh_menu_labels()
	)
	bot_row.add_child(rst_btn)


func _build_summary_overlay() -> void:
	summary_panel = PanelContainer.new()
	summary_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.06, 0.11, 0.21, 0.96), Color(0.32, 1.0, 0.68, 0.95), 16, 2)
	)
	summary_panel.set_anchors_preset(Control.PRESET_CENTER)
	summary_panel.position = Vector2(-310, -195)
	summary_panel.custom_minimum_size = Vector2(620, 390)
	summary_panel.visible = false
	ui_layer.add_child(summary_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	summary_panel.add_child(vb)

	var hd := Label.new()
	hd.text = "✓ ROUND COMPLETE — PROGRESS REPORT"
	hd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hd.add_theme_font_size_override("font_size", 23)
	hd.add_theme_color_override("font_color", Color(0.35, 1.0, 0.72))
	vb.add_child(hd)

	summary_lbl = Label.new()
	summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_lbl.add_theme_font_size_override("font_size", 15)
	vb.add_child(summary_lbl)

	var next_btn := Button.new()
	next_btn.text = "▶ NEXT ROUND (CONTINUE)"
	next_btn.custom_minimum_size = Vector2(0, 48)
	next_btn.add_theme_font_size_override("font_size", 17)
	next_btn.pressed.connect(func():
		audio.play_sfx("click")
		summary_panel.visible = false
		hud_root.visible = true
		wave_number += 1
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_begin_wave()
	)
	vb.add_child(next_btn)

	var menu_b := Button.new()
	menu_b.text = "Return to Menu / Change Stage or Mode"
	menu_b.custom_minimum_size = Vector2(0, 38)
	menu_b.pressed.connect(func():
		audio.play_sfx("click")
		summary_panel.visible = false
		_enter_menu()
	)
	vb.add_child(menu_b)


func _build_lexicon_overlay() -> void:
	lexicon_panel = PanelContainer.new()
	lexicon_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.05, 0.08, 0.16, 0.97), Color(0.32, 0.85, 1.0, 0.95), 14, 2)
	)
	lexicon_panel.position = Vector2(50, 40)
	lexicon_panel.size = Vector2(1180, 640)
	lexicon_panel.custom_minimum_size = Vector2(1180, 640)
	lexicon_panel.visible = false
	ui_layer.add_child(lexicon_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	lexicon_panel.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	vb.add_child(top)

	lexicon_header_lbl = Label.new()
	lexicon_header_lbl.text = "WORD & GRAMMAR CODEX (A1–B1) — Click [♪] to hear pronunciation"
	lexicon_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lexicon_header_lbl.add_theme_font_size_override("font_size", 14)
	lexicon_header_lbl.add_theme_color_override("font_color", Color(0.42, 0.92, 1.0))
	top.add_child(lexicon_header_lbl)

	for tab_spec in [
		["ALL", "All (45)"],
		["A1", "A1 (20)"],
		["A2", "A2 (15)"],
		["B1", "B1 (10)"],
		["GRAM", "Grammar (16)"],
	]:
		var tb := Button.new()
		var t_code: String = tab_spec[0]
		tb.text = tab_spec[1]
		tb.custom_minimum_size = Vector2(88, 30)
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
	lexicon_grid.columns = 4
	lexicon_grid.add_theme_constant_override("h_separation", 10)
	lexicon_grid.add_theme_constant_override("v_separation", 10)
	lexicon_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lexicon_grid)


func _populate_lexicon_grid() -> void:
	for ch in lexicon_grid.get_children():
		ch.queue_free()

	var tier_names := ["Step 1: New", "Step 2: Recall", "Step 3: Audio Only", "Step 4: Context", "★ Mastered"]
	var tier_cols := [
		Color(0.55, 0.65, 0.78),
		Color(0.38, 0.80, 1.0),
		Color(0.75, 0.55, 1.0),
		Color(1.0, 0.82, 0.25),
		Color(0.30, 1.0, 0.68),
	]

	if lexicon_tab == "GRAM":
		lexicon_grid.columns = 2
		for g in VocabData.GRAMMAR_BREACHES:
			var gid: String = g["id"]
			var gc: Dictionary = srs.grammar_cards[gid]
			var t_idx := clampi(int(gc["tier"]), 0, 4)
			var card := PanelContainer.new()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.custom_minimum_size = Vector2(520, 118)
			card.add_theme_stylebox_override(
				"panel",
				_make_panel_style(Color(0.09, 0.08, 0.22, 0.95), tier_cols[t_idx], 8, 2)
			)
			lexicon_grid.add_child(card)

			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", 3)
			card.add_child(cv)

			var r1 := HBoxContainer.new()
			cv.add_child(r1)
			var w_lbl := Label.new()
			w_lbl.text = "[%s] %s  →  « %s »" % [g["cefr"], g["category"], g["correct"]]
			w_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			w_lbl.add_theme_font_size_override("font_size", 14)
			w_lbl.add_theme_color_override("font_color", Color(0.92, 0.82, 1.0))
			r1.add_child(w_lbl)

			var play_b := Button.new()
			play_b.text = "♪ Listen"
			play_b.add_theme_font_size_override("font_size", 12)
			var aud_f: String = g["audio"]
			play_b.pressed.connect(func(): audio.play_voice(aud_f))
			r1.add_child(play_b)

			var s_lbl := Label.new()
			s_lbl.text = "%s   (\"%s\")" % [g["sentence_full"], g["en"]]
			s_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			s_lbl.add_theme_font_size_override("font_size", 12)
			s_lbl.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
			cv.add_child(s_lbl)

			var rl_lbl := Label.new()
			rl_lbl.text = "%s   |   ✓%d  ✗%d" % [g["rule"], int(gc["correct"]), int(gc["wrong"])]
			rl_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rl_lbl.add_theme_font_size_override("font_size", 11)
			rl_lbl.add_theme_color_override("font_color", Color(0.68, 0.86, 0.98))
			cv.add_child(rl_lbl)
		return

	lexicon_grid.columns = 4
	for item in VocabData.ITEMS:
		if lexicon_tab != "ALL" and not String(item["cefr"]).begins_with(lexicon_tab):
			continue
		var vid: String = item["id"]
		var c: Dictionary = srs.cards[vid]
		var t_idx := clampi(int(c["tier"]), 0, 4)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(228, 102)
		card.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color(0.08, 0.12, 0.21, 0.95), tier_cols[t_idx], 8, 2)
		)
		lexicon_grid.add_child(card)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 3)
		card.add_child(cv)

		var r1 := HBoxContainer.new()
		cv.add_child(r1)
		var w_lbl := Label.new()
		w_lbl.text = "[%s] %s (%s)" % [item["cefr"], item["fr_def"], item["gender"]]
		w_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		w_lbl.clip_text = true
		w_lbl.add_theme_font_size_override("font_size", 13)
		w_lbl.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
		r1.add_child(w_lbl)

		var play_b := Button.new()
		play_b.text = "♪"
		play_b.tooltip_text = "Listen to pronunciation"
		play_b.custom_minimum_size = Vector2(28, 24)
		play_b.add_theme_font_size_override("font_size", 12)
		play_b.pressed.connect(func(): audio.play_voice("word_%s.ogg" % vid))
		r1.add_child(play_b)

		var en_lbl := Label.new()
		en_lbl.text = "%s  •  %s" % [item["en"], item["ipa"]]
		en_lbl.clip_text = true
		en_lbl.add_theme_font_size_override("font_size", 11)
		en_lbl.add_theme_color_override("font_color", Color(0.68, 0.84, 0.98))
		cv.add_child(en_lbl)

		var st_lbl := Label.new()
		var ok_n := int(c["correct"])
		var er_n := int(c["wrong"])
		st_lbl.text = "%s  |  ✓%d  ✗%d" % [tier_names[t_idx] if bool(c["seen"]) else "Unseen", ok_n, er_n]
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
	if lexicon_open:
		hud_root.visible = false
		menu_panel.visible = false
		summary_panel.visible = false
		_populate_lexicon_grid()
		player.controls_enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if state == GameState.MENU:
			menu_panel.visible = true
		elif state == GameState.WAVE_SUMMARY:
			summary_panel.visible = true
		elif state in [GameState.CALIBRATION, GameState.COMBAT, GameState.GALLERY]:
			hud_root.visible = true
			player.controls_enabled = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ==============================================================================
# STATE TRANSITIONS & GAMEPLAY FLOW
# ==============================================================================

func _enter_menu() -> void:
	state = GameState.MENU
	prompt_active = false
	_clear_drones()
	_set_gallery_visible(true)
	player.controls_enabled = false
	player.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu_cam.current = true
	hud_root.visible = false
	menu_panel.visible = true
	summary_panel.visible = false
	lexicon_panel.visible = false
	lexicon_open = false
	_refresh_menu_labels()


func _refresh_menu_labels() -> void:
	var st := srs.get_summary_stats()
	menu_stats_lbl.text = "Campaign Stage %d/9  •  Words Learned: %d/%d  •  Audio-Ready: %d  •  Grammar: %d/%d  •  Accuracy: %.0f%%" % [
		st["active_stage"], st["seen"], st["total_words"], st["listening_ready"], st["gram_seen"], st["gram_total"], st["accuracy"]
	]
	match srs.sector_filter:
		-1:
			var act_s := srs.get_active_campaign_sector()
			var s_info := VocabData.SECTORS[act_s]
			sector_btn.text = "◈ Mode: Guided Campaign (Currently on Stage %d/9: %s [%s]) — Click to change" % [
				act_s + 1, s_info["name_en"], s_info["cefr"]
			]
		-2:
			sector_btn.text = "◈ Mode: CEFR A1 Beginner Track (Stages 1–4 — 20 Core Words)"
		-3:
			sector_btn.text = "◈ Mode: CEFR A2 Everyday Track (Stages 5–7 + 3D Size/Speed Challenges + Grammar)"
		-4:
			sector_btn.text = "◈ Mode: CEFR B1 Intermediate Track (Stages 8–9 + DELF Dialogues + Subjunctive)"
		-5:
			sector_btn.text = "◈ Special Mode (A2): 3D Size, Speed & Position Challenges (Biggest, Fastest, Middle...)"
		-6:
			sector_btn.text = "◈ Special Mode (DELF A2–B1): Situational Listening Dialogues (16 Scenarios)"
		-7:
			sector_btn.text = "◈ Special Mode (A2–B1): Holographic Grammar & Phonetic Crystals (16 Rules)"
		_:
			var s_info := VocabData.SECTORS[clampi(srs.sector_filter, 0, VocabData.SECTORS.size() - 1)]
			sector_btn.text = "◈ Stage %d (%s): %s  •  %s" % [
				srs.sector_filter + 1, s_info["cefr"], s_info["name_en"], s_info["name_fr"]
			]

	var l1_names := [
		"✦ English Support: Smart Adaptive (Shows English on new words, fades as you master them)",
		"✦ English Support: Always Show English Translation & Pronunciation Tips",
		"✦ English Support: Hardcore 100% French Immersion",
	]
	l1_btn.text = l1_names[srs.l1_mode]


func _on_cycle_sector() -> void:
	audio.play_sfx("click")
	var order := [-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, -5, -6, -7, -2, -3, -4]
	var cur_idx := order.find(srs.sector_filter)
	srs.sector_filter = order[(cur_idx + 1) % order.size()]
	srs.save_progress()
	_refresh_menu_labels()


func _on_cycle_l1_mode() -> void:
	audio.play_sfx("click")
	srs.l1_mode = (srs.l1_mode + 1) % 3
	srs.save_progress()
	_refresh_menu_labels()


func _on_start_mission_pressed() -> void:
	audio.play_sfx("click")
	menu_panel.visible = false
	summary_panel.visible = false
	lexicon_panel.visible = false
	hud_root.visible = true
	hover_info_lbl.text = ""
	_set_gallery_visible(false)
	player.visible = true
	player.camera.current = true
	player.position = Vector3(0.0, 0.30, 6.8)
	player.look_toward_point(Vector3(0.0, 2.1, -0.8))
	player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	shield_hp = 100.0
	_update_stats_hud()
	_begin_wave()


func _on_enter_gallery_pressed() -> void:
	audio.play_sfx("click")
	state = GameState.GALLERY
	prompt_active = false
	_clear_drones()
	_set_gallery_visible(true)
	menu_panel.visible = false
	summary_panel.visible = false
	lexicon_panel.visible = false
	hud_root.visible = true
	feedback_banner.visible = false
	player.visible = true
	player.camera.current = true
	player.position = Vector3(0.0, 0.30, -7.0)
	player.look_toward_point(Vector3(0.0, 1.6, -13.2))
	player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if srs.sector_filter >= 0:
		gallery_sector = srs.sector_filter
	elif srs.sector_filter == -1:
		gallery_sector = srs.get_active_campaign_sector()
	elif srs.sector_filter == -3:
		gallery_sector = 4
	elif srs.sector_filter == -4:
		gallery_sector = 7
	else:
		gallery_sector = 0
	_load_gallery_sector(gallery_sector)
	audio.play_voice("radio_welcome.ogg")


func _load_gallery_sector(sec_idx: int) -> void:
	gallery_sector = clampi(sec_idx, 0, VocabData.SECTORS.size() - 1)
	var ids := VocabData.get_sector_ids(gallery_sector)
	_refresh_gallery_pedestals(ids)
	var s_info := VocabData.SECTORS[gallery_sector]
	speaker_lbl.text = "◈ 3D PRACTICE GALLERY (%s)" % s_info["cefr"]
	mode_tag_lbl.text = "Press [1–9] to Switch Stage (1–9)  •  Press [M] to Start Combat Round"
	prompt_main_lbl.text = "Stage %d: %s  (%s)" % [gallery_sector + 1, s_info["name_en"], s_info["name_fr"]]
	prompt_sub_lbl.text = "Pronunciation Focus: %s — Shoot any pedestal to hear native French audio!" % s_info["focus"]
	timer_bar.value = 100.0


func _begin_wave() -> void:
	prompt_in_wave = 0
	wave_hits_clean = 0
	shield_hp = minf(100.0, shield_hp + 25.0)
	_set_gallery_visible(false)
	_update_stats_hud()
	# Jump straight into active, well-paced 6-shot Combat Rounds!
	_start_combat_wave()


func _start_calibration_phase() -> void:
	state = GameState.CALIBRATION
	prompt_active = false
	_clear_drones()
	feedback_banner.visible = false

	var count := calibration_queue.size()
	for i in range(count):
		var vid := calibration_queue[i]
		var item := VocabData.get_by_id(vid)
		var spread := (float(i) - float(count - 1) * 0.5) * 4.2
		var pos := Vector3(spread, 2.15, -0.2)
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(vid, pos, player.global_position, 0.20, 1.10)
		d.show_calibration_card("%s (%s)" % [item["fr_def"], item["fr_indef"]], item["en"])
		d.set_beacon(i == 0, Color(0.18, 0.96, 0.62) if i == 0 else Color(0.3, 0.5, 0.7))
		active_drones.append(d)

	_focus_next_calibration_target()


func _focus_next_calibration_target() -> void:
	if calibration_queue.is_empty():
		_start_combat_wave()
		return

	current_calib_id = calibration_queue[0]
	var item := VocabData.get_by_id(current_calib_id)
	for d in active_drones:
		if is_instance_valid(d):
			d.set_beacon(d.vocab_id == current_calib_id, Color(0.18, 0.96, 0.62))

	speaker_lbl.text = "♪ LT. DENISE (STAGE INTRO %s)" % item.get("cefr", "A1")
	mode_tag_lbl.text = "NEW WORD SPOTLIGHT  •  SHOOT TO LEARN (%d left)" % calibration_queue.size()
	prompt_main_lbl.text = "« %s  •  %s »   =   %s" % [item["fr_indef"], item["fr_def"], item["en"]]
	prompt_sub_lbl.text = "Pronunciation: %s   |   Tip: %s" % [item["ipa"], item["tip"]]
	timer_bar.value = 100.0
	audio.play_voice("word_%s.ogg" % current_calib_id)


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
	_clear_drones()

	current_spec = srs.build_wave_prompt_spec(prompt_in_wave)
	var ptype := str(current_spec.get("prompt_type", "VOCAB"))

	if ptype == "MODIFIER":
		_spawn_modifier_drones(current_spec)
	elif ptype == "SCENARIO":
		_spawn_scenario_drones(current_spec)
	elif ptype == "GRAMMAR":
		_spawn_grammar_drones(current_spec)
	else:
		_spawn_vocab_drones(current_spec)

	prompt_timer = PROMPT_TIME_LIMIT
	prompt_active = true
	prompt_clean_try = true
	prompt_used_assist = false
	prompt_hint_stage = 0
	prompt_wrong_ids.clear()

	_refresh_prompt_hud()
	_update_stats_hud()
	audio.play_voice(str(current_spec["audio_file"]))


func _spawn_vocab_drones(spec: Dictionary) -> void:
	var target_id := str(spec["target_id"])
	var tier := int(spec.get("tier", 0))
	var decoy_count := 2 if tier == 0 else 3
	var distractors := srs.select_distractors(target_id, decoy_count, str(spec["required_decoy"]))
	var spawn_ids: Array[String] = [target_id]
	spawn_ids.append_array(distractors)
	spawn_ids.shuffle()

	var n := spawn_ids.size()
	var xs3 := [-4.4, 0.0, 4.4]
	var xs4 := [-6.3, -2.1, 2.1, 6.3]
	for i in range(n):
		var sx: float = xs3[i] if n == 3 else (xs4[i] if i < 4 else (float(i - 2) * 3.5))
		var sz: float = -0.3 if (i % 2 == 0) else -0.9
		var height := 2.18
		var d := TargetDrone.new()
		drones_root.add_child(d)
		var mv := 0.25 if tier == 0 else (0.55 + float(mini(wave_number, 5)) * 0.05)
		d.setup(spawn_ids[i], Vector3(sx, height, sz), player.global_position, mv, 1.12)
		# On Step 1 (Tier 0 — New Word), spotlight the target with a green ring & bilingual badge!
		if tier == 0 and spawn_ids[i] == target_id:
			var item := VocabData.get_by_id(target_id)
			d.show_calibration_card(str(item.get("fr_def", target_id)), str(item.get("en", "")))
		active_drones.append(d)


func _spawn_scenario_drones(spec: Dictionary) -> void:
	var target_id := str(spec["target_id"])
	var decoys: Array = spec.get("decoys", [])
	var spawn_ids: Array[String] = [target_id]
	for dec in decoys:
		var ds := str(dec)
		if ds != target_id and not spawn_ids.has(ds):
			spawn_ids.append(ds)
	spawn_ids.shuffle()

	var n := spawn_ids.size()
	var xs4 := [-6.3, -2.1, 2.1, 6.3]
	for i in range(n):
		var sx: float = xs4[i] if i < 4 else (float(i - 2) * 3.5)
		var sz := -0.5 if (i % 2 == 0) else -1.1
		var height := 2.20
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(spawn_ids[i], Vector3(sx, height, sz), player.global_position, 0.50, 1.12)
		active_drones.append(d)


func _spawn_grammar_drones(spec: Dictionary) -> void:
	var opts: Array = spec["options"].duplicate()
	opts.shuffle()
	var xs := [-6.3, -2.1, 2.1, 6.3]
	for i in range(opts.size()):
		var opt_txt := str(opts[i])
		var pos := Vector3(xs[i], 2.25, -0.5)
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup("holo_crystal", pos, player.global_position, 0.22, 1.15, opt_txt)
		d.configure_as_grammar_crystal(opt_txt, i + 1)
		active_drones.append(d)


func _spawn_modifier_drones(spec: Dictionary) -> void:
	var layout := str(spec["layout"])
	var vid := str(spec["base_vocab_id"])
	var xs4 := [-6.3, -2.1, 2.1, 6.3]
	var target_slot := randi() % 4

	if layout == "pos_left":
		target_slot = 0
	elif layout == "pos_right":
		target_slot = 3
	elif layout == "pos_middle":
		var xs3 := [-5.2, 0.0, 5.2]
		for i in range(3):
			var is_t := (i == 1)
			var d := TargetDrone.new()
			drones_root.add_child(d)
			d.setup(vid, Vector3(xs3[i], 2.20, -0.5), player.global_position, 0.15, 1.12, "MOD_TARGET" if is_t else ("DECOY_%d" % i))
			d.custom_ok_label = "+150  ✓ Au milieu (In the middle)!"
			d.custom_wrong_label = "✗ On the side (shoot the MIDDLE one)!"
			active_drones.append(d)
		return

	for i in range(4):
		var is_t := (i == target_slot)
		var tag := "MOD_TARGET" if is_t else ("DECOY_%d" % i)
		var pos := Vector3(xs4[i], 2.20, -0.5)
		var mv := 0.45
		var sc := 1.0
		var ok_lbl := "+150  ✓ Correct target!"
		var err_lbl := "✗ Wrong target!"

		match layout:
			"scale_max":
				sc = 1.65 if is_t else (0.64 + float(i) * 0.08)
				mv = 0.35
				ok_lbl = "+150  ✓ La plus grande (The biggest)!"
				err_lbl = "✗ Too small (shoot the BIGGEST one)!"
			"scale_min":
				sc = 0.56 if is_t else (1.18 + float(i) * 0.10)
				mv = 0.35
				ok_lbl = "+150  ✓ Le plus petit (The smallest)!"
				err_lbl = "✗ Too big (shoot the SMALLEST one)!"
			"speed_max":
				mv = 2.60 if is_t else 0.18
				ok_lbl = "+150  ✓ Le plus rapide (The fastest)!"
				err_lbl = "✗ Too slow (shoot the FASTEST one)!"
			"speed_zero":
				mv = 0.0 if is_t else 1.65
				ok_lbl = "+150  ✓ Immobile (Motionless)!"
				err_lbl = "✗ Moving (shoot the MOTIONLESS one)!"
			"height_max":
				pos.y = 3.85 if is_t else 1.50
				mv = 0.30
				ok_lbl = "+150  ✓ Le plus haut (The highest)!"
				err_lbl = "✗ Too low (shoot the HIGHEST one)!"
			"height_min":
				pos.y = 1.25 if is_t else 3.55
				mv = 0.30
				ok_lbl = "+150  ✓ Le plus bas (The lowest)!"
				err_lbl = "✗ Too high (shoot the LOWEST one)!"
			"pos_left":
				mv = 0.12
				ok_lbl = "+150  ✓ À gauche (Far left)!"
				err_lbl = "✗ Not on the far left!"
			"pos_right":
				mv = 0.12
				ok_lbl = "+150  ✓ À droite (Far right)!"
				err_lbl = "✗ Not on the far right!"
			"dist_min":
				pos.z = 2.2 if is_t else -3.2
				mv = 0.30
				ok_lbl = "+150  ✓ Le plus proche (The closest)!"
				err_lbl = "✗ Too far back (shoot the CLOSEST one)!"
			"dist_max":
				pos.z = -3.8 if is_t else 1.8
				mv = 0.30
				ok_lbl = "+150  ✓ La plus éloignée (The farthest)!"
				err_lbl = "✗ Too close (shoot the FARTHEST one)!"
			"big_stationary":
				if is_t:
					sc = 1.60
					mv = 0.0
				elif i % 2 == 0:
					sc = 1.60
					mv = 1.80
				else:
					sc = 0.62
					mv = 0.0
				ok_lbl = "+150  ✓ Grand ET immobile (Big AND motionless)!"
				err_lbl = "✗ Must be BOTH big and motionless!"

		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(vid, pos, player.global_position, mv, sc, tag)
		d.custom_ok_label = ok_lbl
		d.custom_wrong_label = err_lbl
		active_drones.append(d)


func _refresh_prompt_hud() -> void:
	speaker_lbl.text = "♪ VOICE: " + str(current_spec["speaker"])
	mode_tag_lbl.text = str(current_spec["mode_tag"])

	var ptype := str(current_spec.get("prompt_type", "VOCAB"))
	var show_fr := bool(current_spec["show_fr_text"]) or (prompt_hint_stage >= 1)
	var show_en := bool(current_spec["show_en_text"]) or (prompt_hint_stage >= 2)

	if show_fr:
		prompt_main_lbl.text = "♪ %s" % str(current_spec["prompt_fr"])
	else:
		if ptype == "SCENARIO":
			prompt_main_lbl.text = "◉ DIALOGUE: %s   (Press [H] for Transcript • [E] Replay)" % str(current_spec.get("question_fr", "Listen carefully!"))
		elif ptype == "MODIFIER":
			prompt_main_lbl.text = "◉ 3D CHALLENGE: Listen to the size/speed/position command!  ([H] Show Text • [E] Replay)"
		elif int(current_spec["tier"]) >= 3:
			prompt_main_lbl.text = "◉ RIDDLE / CLUE: Listen & shoot the matching object!  ([H] Show Text • [E] Replay)"
		else:
			prompt_main_lbl.text = "◉ AUDIO ONLY: Listen to the French word & shoot the matching object!  ([H] Hint • [E] Replay)"

	if show_en:
		prompt_sub_lbl.text = str(current_spec["sub_en"])
	else:
		if ptype == "GRAMMAR":
			prompt_sub_lbl.text = "Shoot the Crystal (or press [1–4]) that completes the sentence!  •  [E] Replay  •  [H] Show Grammar Rule"
		else:
			prompt_sub_lbl.text = "Press [1–4] or Click to shoot  •  [E] Replay Audio  •  [R] Slow Audio  •  [H] Reveal Translation / Hint"


# ==============================================================================
# SHOOTING, CONTRASTIVE FEEDBACK & INPUTS
# ==============================================================================

func _on_player_hovered(entity: Node) -> void:
	if entity is PedestalStation:
		var p := entity as PedestalStation
		var item := VocabData.get_by_id(p.vocab_id)
		_reticle_col = Color(0.35, 1.0, 0.78)
		hover_info_lbl.text = "[Click] Hear Pronunciation: %s (%s)" % [item.get("fr_def", ""), item.get("en", "")]
	elif entity is TargetDrone:
		_reticle_col = Color(1.0, 0.90, 0.25)
		var td := entity as TargetDrone
		if td.is_grammar_crystal:
			hover_info_lbl.text = "Aiming at Option: « %s »  [Click to Shoot]" % td.grammar_option
		else:
			var item := VocabData.get_by_id(td.vocab_id)
			if state == GameState.CALIBRATION or int(current_spec.get("tier", 0)) == 0:
				hover_info_lbl.text = "Aiming at: %s (%s)" % [item.get("fr_def", ""), item.get("en", "")]
			else:
				hover_info_lbl.text = "Aiming at: %s" % str(item.get("en", td.vocab_id)).to_upper()
	else:
		_reticle_col = Color(0.25, 0.95, 0.80, 0.92)
		hover_info_lbl.text = ""


func _on_player_fired(entity: Node, _hit_pos: Vector3) -> void:
	audio.play_sfx("laser")

	if entity is PedestalStation:
		var ped := entity as PedestalStation
		ped.trigger_scan_pulse()
		audio.play_sfx("scan", 0.02, -4.0)
		audio.play_voice("word_%s.ogg" % ped.vocab_id)
		srs.mark_calibrated(ped.vocab_id)
		var item := VocabData.get_by_id(ped.vocab_id)
		_show_feedback("♪ [%s] %s (%s) = %s  |  Tip: %s" % [item["cefr"], item["fr_def"], item["fr_indef"], item["en"], item["tip"]], true)
		return

	if not (entity is TargetDrone):
		return

	var drone := entity as TargetDrone
	if drone.is_destroyed:
		return

	if state == GameState.CALIBRATION:
		var vid := drone.vocab_id
		audio.play_sfx("scan", 0.02, -2.0)
		if vid != current_calib_id:
			audio.play_voice("word_%s.ogg" % vid)
		srs.mark_calibrated(vid)
		drone.explode_success(world_root, 100)
		active_drones.erase(drone)
		calibration_queue.erase(vid)
		score += 100
		_update_stats_hud()
		transition_delay = 0.50
		return

	if state == GameState.COMBAT and prompt_active:
		var ptype := str(current_spec.get("prompt_type", "VOCAB"))
		var target_tag := str(current_spec["target_id"])

		if drone.drone_tag == target_tag:
			prompt_active = false
			audio.play_sfx("hit_ok", 0.02, -1.5)
			var pts := 100
			if prompt_clean_try:
				combo += 1
				wave_hits_clean += 1
				pts = (100 + combo * 25) * (1 + int(current_spec["tier"]))
			else:
				pts = 60
			score += pts
			drone.explode_success(world_root, pts)
			active_drones.erase(drone)

			if ptype == "GRAMMAR":
				var gid := str(current_spec["grammar_id"])
				srs.record_grammar_result(gid, prompt_clean_try, prompt_used_assist)
				audio.play_voice(str(current_spec["audio_file"]))
				_show_feedback("✓ Correct! « %s »  —  %s" % [current_spec["sentence_full"], current_spec["rule"]], true)
				prompt_main_lbl.text = "✓ « %s »" % str(current_spec["sentence_full"])
				prompt_sub_lbl.text = str(current_spec["en"])
			elif ptype == "MODIFIER":
				srs.global_step += 1
				srs.save_progress()
				_show_feedback("✓ Nice shot! « %s »  —  %s" % [current_spec["prompt_fr"], current_spec["rule"]], true)
				prompt_main_lbl.text = "✓ « %s »" % str(current_spec["prompt_fr"])
				prompt_sub_lbl.text = str(current_spec["sub_en"])
			else:
				var res := srs.record_result(target_tag, prompt_clean_try, prompt_used_assist, prompt_wrong_ids)
				var t_item := VocabData.get_by_id(target_tag)
				var tier_badges := ["Step 1 (Intro)", "Step 2 (Recall)", "Step 3 (Audio Only)", "Step 4 (Context)", "★ Mastered"]
				var new_t := clampi(int(res["new_tier"]), 0, 4)
				_show_feedback(
					"✓ %s = %s  •  %s   [Now at: %s]" % [
						t_item["fr_def"], t_item["en"], t_item["ipa"], tier_badges[new_t]
					],
					true
				)
				prompt_main_lbl.text = "✓ %s (%s) — %s" % [t_item["fr_def"], t_item["fr_indef"], t_item["en"]]
				prompt_sub_lbl.text = "Pronunciation: %s  •  %s" % [t_item["ipa"], t_item["tip"]]

			_update_stats_hud()
			transition_delay = 0.72
		else:
			# Wrong drone shot: explain what was hit and highlight the right target so the player learns immediately!
			prompt_clean_try = false
			combo = 0
			shield_hp = maxf(10.0, shield_hp - 12.0)
			audio.play_sfx("hit_err", 0.02, -1.0)
			audio.play_sfx("shield_hit", 0.01, -3.0)
			drone.flash_wrong_hit()

			if ptype == "GRAMMAR":
				_highlight_true_target(target_tag)
				_show_feedback(
					"✗ Not « %s »! Shoot the gold-highlighted crystal « %s » (%s)" % [
						drone.grammar_option, target_tag, current_spec["rule"]
					],
					false
				)
			elif ptype == "MODIFIER":
				_highlight_true_target("MOD_TARGET")
				_show_feedback(
					"✗ %s  →  « %s » (%s) — Shoot the gold-highlighted target!" % [
						drone.custom_wrong_label, current_spec["prompt_fr"], current_spec["sub_en"]
					],
					false
				)
			else:
				if not prompt_wrong_ids.has(drone.vocab_id):
					prompt_wrong_ids.append(drone.vocab_id)
				var hit_item := VocabData.get_by_id(drone.vocab_id)
				var true_item := VocabData.get_by_id(target_tag)
				_highlight_true_target(target_tag)
				_play_slow_assist()
				_show_feedback(
					"✗ You shot %s (%s)!  Target is: %s (%s) — Shoot the gold-highlighted target!" % [
						hit_item["fr_def"], hit_item["en"], true_item["fr_def"], true_item["en"]
					],
					false
				)
			_update_stats_hud()


func _highlight_true_target(target_tag: String) -> void:
	for d in active_drones:
		if is_instance_valid(d) and not d.is_destroyed:
			if d.drone_tag == target_tag:
				d.set_beacon(true, Color(1.0, 0.85, 0.15))


func _play_slow_assist() -> void:
	prompt_used_assist = true
	var ptype := str(current_spec.get("prompt_type", "VOCAB"))
	var slow_f := str(current_spec.get("slow_audio_file", ""))
	if slow_f != "":
		audio.play_voice(slow_f)
	else:
		audio.play_voice(str(current_spec.get("audio_file", "")), 0.80)

	if ptype == "VOCAB":
		var tid := str(current_spec.get("target_id", ""))
		var item := VocabData.get_by_id(tid)
		if not item.is_empty():
			prompt_sub_lbl.text = "Slow Audio: %s  •  Tip: %s" % [item["ipa"], item["tip"]]
	elif ptype == "SCENARIO":
		prompt_main_lbl.text = "♪ %s" % str(current_spec["prompt_fr"])
	elif ptype == "MODIFIER":
		prompt_main_lbl.text = "♪ %s" % str(current_spec["prompt_fr"])
		prompt_sub_lbl.text = str(current_spec["sub_en"])
	elif ptype == "GRAMMAR":
		prompt_sub_lbl.text = str(current_spec["sub_en"])


func _show_feedback(msg: String, is_ok: bool) -> void:
	feedback_banner.visible = true
	var border_col := Color(0.28, 1.0, 0.68, 0.95) if is_ok else Color(1.0, 0.40, 0.40, 0.95)
	var bg_col := Color(0.05, 0.16, 0.14, 0.95) if is_ok else Color(0.22, 0.06, 0.09, 0.95)
	feedback_banner.add_theme_stylebox_override("panel", _make_panel_style(bg_col, border_col, 10, 2))
	feedback_lbl.text = msg
	feedback_lbl.add_theme_color_override("font_color", Color(0.65, 1.0, 0.82) if is_ok else Color(1.0, 0.78, 0.78))


func _update_stats_hud() -> void:
	wave_lbl.text = "ROUND %d  •  SHOT %d/%d" % [wave_number, prompt_in_wave, PROMPTS_PER_WAVE]
	score_lbl.text = "SCORE: %d  (x%d)" % [score, maxi(1, combo)]
	shield_bar.value = shield_hp


func _finish_wave() -> void:
	state = GameState.WAVE_SUMMARY
	prompt_active = false
	_clear_drones()
	feedback_banner.visible = false
	hud_root.visible = false
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	audio.play_sfx("wave_up")
	audio.play_voice("radio_bravo.ogg")

	var st := srs.get_summary_stats()
	summary_lbl.text = (
		"Round %d Cleared!   •   Clean First-Try Hits: %d/%d\n"
		+ "Score: %d   •   Current Streak: x%d   •   Overall Accuracy: %.0f%%\n\n"
		+ "Campaign Stage: %d/9   •   3D Words Learned: %d/%d\n"
		+ "Audio-Ready Words (Step 3+): %d   •   Grammar Rules Seen: %d/%d"
	) % [
		wave_number, wave_hits_clean, PROMPTS_PER_WAVE,
		score, maxi(1, combo), st["accuracy"],
		st["active_stage"], st["seen"], st["total_words"],
		st["listening_ready"], st["gram_seen"], st["gram_total"]
	]
	summary_panel.visible = true


func _clear_drones() -> void:
	active_drones.clear()
	for ch in drones_root.get_children():
		ch.queue_free()


## Allows pressing [1], [2], [3], or [4] during Combat to quick-shoot the Nth target from left to right!
func _quick_shoot_slot(slot_idx: int) -> void:
	var valid_drones: Array[TargetDrone] = []
	for d in active_drones:
		if is_instance_valid(d) and not d.is_destroyed:
			valid_drones.append(d)
	if valid_drones.is_empty():
		return
	valid_drones.sort_custom(func(a: TargetDrone, b: TargetDrone): return a.global_position.x < b.global_position.x)
	if slot_idx >= 0 and slot_idx < valid_drones.size():
		var target_d := valid_drones[slot_idx]
		player.look_toward_point(target_d.global_position)
		player._spawn_laser_beam(player.muzzle_marker.global_position, target_d.global_position, target_d)
		_on_player_fired(target_d, target_d.global_position)


func _unhandled_input(event: InputEvent) -> void:
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

	if lexicon_open or state == GameState.MENU or state == GameState.WAVE_SUMMARY:
		return

	if kc == KEY_G:
		if state != GameState.GALLERY:
			_on_enter_gallery_pressed()
		return

	if state == GameState.GALLERY:
		if kc >= KEY_1 and kc <= KEY_9:
			_load_gallery_sector(int(kc - KEY_1))
		elif kc == KEY_M:
			_on_start_mission_pressed()
		return

	if state == GameState.COMBAT and prompt_active:
		if kc == KEY_E:
			audio.play_voice(str(current_spec["audio_file"]))
		elif kc == KEY_R:
			_play_slow_assist()
		elif kc == KEY_H:
			prompt_used_assist = true
			prompt_hint_stage = mini(2, prompt_hint_stage + 1)
			_refresh_prompt_hud()
		elif kc >= KEY_1 and kc <= KEY_4:
			_quick_shoot_slot(int(kc - KEY_1))


func _process(delta: float) -> void:
	if state == GameState.MENU:
		_menu_orbit_angle += delta * 0.18
		_menu_cam.global_position = Vector3(sin(_menu_orbit_angle) * 13.5, 4.8, cos(_menu_orbit_angle) * 13.5 - 2.0)
		_menu_cam.look_at(Vector3(0, 1.5, -6.5), Vector3.UP)
		return

	if crosshair_reticle and player:
		crosshair_reticle.set_state(_reticle_col, player.is_aiming)

	var bars := audio.get_waveform_bars(12)
	for i in range(mini(bars.size(), wave_bars.size())):
		var h := bars[i] * 18.0
		wave_bars[i].size.y = h
		wave_bars[i].position.y = (18.0 - h) * 0.5

	if transition_delay > 0.0:
		transition_delay -= delta
		if transition_delay <= 0.0:
			if state == GameState.CALIBRATION:
				_focus_next_calibration_target()
			elif state == GameState.COMBAT:
				feedback_banner.visible = false
				_next_combat_prompt()
		return

	if state == GameState.COMBAT and prompt_active:
		prompt_timer -= delta
		timer_bar.value = clampf((prompt_timer / PROMPT_TIME_LIMIT) * 100.0, 0.0, 100.0)
		if prompt_timer <= 0.0:
			prompt_clean_try = false
			combo = 0
			shield_hp = maxf(10.0, shield_hp - 10.0)
			var target_tag := str(current_spec["target_id"])
			_highlight_true_target(target_tag)
			_play_slow_assist()
			_show_feedback("! Time up! Shoot the gold-highlighted target to continue!", false)
			prompt_timer = 10.0
			_update_stats_hud()


# ==============================================================================
# AUTOMATED SCREENSHOT & SRS VERIFICATION HOOK (`-- --verify-screenshots`)
# ==============================================================================

func _run_automated_verification() -> void:
	var out_dir := "/tmp/franc_tireur_verify"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var test_srs := SRSEngine.new()
	test_srs.reset_progress()
	assert(test_srs.cards.size() == 45, "Expected 45 CEFR A1-B1 vocabulary cards")
	assert(test_srs.grammar_cards.size() == 16, "Expected 16 CEFR A2-B1 grammar breach cards")
	assert(test_srs.get_active_campaign_sector() == 0, "New campaign should start at Stage 1 (Sector 0)")
	test_srs.mark_calibrated("pomme")
	var r1 := test_srs.record_result("pomme", true, false, [])
	assert(int(r1["new_tier"]) == 1, "Clean hit should advance Step 1 (Tier 0) -> Step 2 (Tier 1)")
	var r2 := test_srs.record_result("pomme", true, false, [])
	assert(int(r2["new_tier"]) == 2, "Clean hit should advance Step 2 (Tier 1) -> Step 3 (Tier 2 Audio Only)")
	var r_err := test_srs.record_result("pomme", false, false, ["fromage"])
	assert(int(r_err["new_tier"]) == 1, "Mistake should drop Tier 2 -> Tier 1 and log confusion")
	var rg := test_srs.record_grammar_result("gram_09", true, false)
	assert(int(rg["new_tier"]) == 1, "Grammar breach card should advance tier on clean hit")
	print("VERIFY_OK: CEFR A1-B1 SRS Engine (45 vocab + 16 grammar + modifiers + scenarios) passed.")

	srs.reset_progress()
	srs.sector_filter = -1
	_refresh_menu_labels()
	for i in range(4):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/01_menu.png")

	# 2. Step 1 (Tier 0): New Word Spotlight in Stage 1 showcasing the new Apple (`pomme.blend`) & Heart (`coeur.blend`)
	srs.reset_progress()
	srs.sector_filter = 0
	_on_start_mission_pressed()
	_clear_drones()
	current_spec = srs.build_prompt_spec("pomme")
	var demo_ids := ["fromage", "pomme", "coeur"]
	var demo_xs := [-4.4, 0.0, 4.4]
	for i in range(3):
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(demo_ids[i], Vector3(demo_xs[i], 2.18, -0.3), player.global_position, 0.0, 1.15)
		if demo_ids[i] == "pomme":
			d.show_calibration_card("la pomme", "the apple")
		active_drones.append(d)
	_refresh_prompt_hud()
	player.look_toward_point(Vector3(0.0, 2.15, -0.3))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/02_calibration_3d.png")

	# 3. Step 3 (Tier 2): Pure Listening Combat at close-mid range
	srs.sector_filter = 4
	for vid in ["avion", "train", "voiture", "velo", "valise"]:
		srs.mark_calibrated(vid)
		srs.cards[vid]["tier"] = 2
	_clear_drones()
	current_spec = srs.build_prompt_spec("avion")
	_spawn_vocab_drones(current_spec)
	_refresh_prompt_hud()
	player.look_toward_point(Vector3(0.0, 2.20, -0.5))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/03_combat_pure_listening.png")

	# 4. A2 3D Spatial & Comparative Modifier Operation ("Tirez sur la cible la plus grande !")
	_clear_drones()
	current_spec = srs.build_modifier_prompt_spec(0)
	_spawn_modifier_drones(current_spec)
	prompt_hint_stage = 1
	_refresh_prompt_hud()
	player.look_toward_point(Vector3(0.0, 2.20, -0.5))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/06_a2_spatial_modifiers.png")

	# 5. B1 Holographic Data-Crystal Grammar Breach
	_clear_drones()
	current_spec = srs.build_grammar_prompt_spec("gram_09")
	_spawn_grammar_drones(current_spec)
	prompt_hint_stage = 2
	_refresh_prompt_hud()
	player.look_toward_point(Vector3(0.0, 2.25, -0.5))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/07_b1_grammar_breach.png")

	# 6. 3D Practice Gallery showing Sector 4 (fleur, coeur, poisson, etoile, fusee)
	_on_enter_gallery_pressed()
	_load_gallery_sector(3)
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/05_gallery_study.png")

	# 7. Interactive [Tab] SRS Lexicon (with HUD cleanly hidden behind it!)
	lexicon_tab = "ALL"
	_toggle_lexicon(true)
	for i in range(4):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/04_srs_lexicon.png")

	# 8. Interactive [Tab] Grammar Breach Matrix (A2-B1)
	lexicon_tab = "GRAM"
	_populate_lexicon_grid()
	for i in range(4):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/08_srs_grammar_matrix.png")

	srs.reset_progress()
	print("VERIFY_OK: Saved 8 rendered screenshots to " + out_dir)
	get_tree().quit(0)


func _save_viewport_png(file_path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(file_path)
