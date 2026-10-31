class_name GameManager
extends Node3D

## Master Orchestrator for FRANC-TIREUR : Opération Écho (Édition Complète CEFR A1–B1)
## Builds the 3D Cyber-Parisian Holodeck Arena, manages Calibration + 4 Combat Modes:
##   1. Standard 3D Vocabulary SRS (45 Blender models across 9 Sectors, Tiers 0–4)
##   2. A2 3D Spatial, Scale & Motion Modifiers (comparatives, superlatives, prepositions, relative clauses)
##   3. DELF A2–B1 Situational Listening Scenarios (connected discourse & multi-object traps)
##   4. A2–B1 Holographic Data-Crystal Grammar & Phonetic Breaches (`holo_crystal.blend`)
## Plus 9-Sector Reconnaissance Gallery, [Tab] SRS Lexicon & Grammar Matrix, and automated screenshot verification.

enum GameState {
	MENU,
	CALIBRATION,
	COMBAT,
	WAVE_SUMMARY,
	GALLERY,
}

const PROMPTS_PER_WAVE := 6
const PROMPT_TIME_LIMIT := 18.0
const ARENA_CENTER := Vector3(0.0, 0.0, -3.5)

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
var lexicon_tab: String = "ALL" # "ALL", "A1", "A2", "B1", "GRAM"

# UI Nodes
var ui_layer: CanvasLayer
var hud_root: Control
var crosshair_reticle: CrosshairReticle
var _reticle_col: Color = Color(0.35, 0.95, 1.0, 0.92)
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
# 3D ENVIRONMENT & ARENA CONSTRUCTION
# ==============================================================================

func _build_environment_and_lights() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.05, 0.10, 0.22)
	sky_mat.sky_horizon_color = Color(0.14, 0.26, 0.46)
	sky_mat.ground_bottom_color = Color(0.04, 0.06, 0.11)
	sky_mat.ground_horizon_color = Color(0.10, 0.18, 0.32)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.58, 0.68, 0.88)
	env.ambient_light_energy = 0.88
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.90)
	sun.light_energy = 1.28
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 50.0
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	world_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.78, 1.0)
	fill.light_energy = 0.55
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-32.0, 148.0, 0.0)
	world_root.add_child(fill)

	_menu_cam = Camera3D.new()
	_menu_cam.fov = 66.0
	world_root.add_child(_menu_cam)


func _make_mat(albedo: Color, rough: float = 0.45, metal: float = 0.2, unshaded: bool = false) -> StandardMaterial3D:
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

	var floor_mat := _make_mat(Color(0.09, 0.12, 0.18), 0.55, 0.30)
	var deck_mat := _make_mat(Color(0.13, 0.17, 0.25), 0.45, 0.35)
	var wall_mat := _make_mat(Color(0.11, 0.15, 0.23), 0.50, 0.40)
	var pillar_mat := _make_mat(Color(0.17, 0.22, 0.33), 0.35, 0.55)

	var cyan_glow := _make_mat(Color(0.18, 0.82, 1.0), 0.2, 0.0, true)
	var fr_blue := _make_mat(Color(0.14, 0.38, 0.92), 0.2, 0.0, true)
	var fr_white := _make_mat(Color(0.94, 0.96, 1.0), 0.2, 0.0, true)
	var fr_red := _make_mat(Color(0.90, 0.18, 0.24), 0.2, 0.0, true)

	_add_static_box(arena, Vector3(42.0, 0.5, 42.0), Vector3(0, -0.25, 0), Vector3.ZERO, floor_mat, true)
	_add_static_box(arena, Vector3(14.0, 0.24, 7.0), Vector3(0, 0.12, 8.5), Vector3.ZERO, deck_mat, true)
	_add_static_box(arena, Vector3(22.0, 0.20, 6.5), Vector3(0, 0.10, -13.5), Vector3.ZERO, deck_mat, true)

	for gx in [-12.0, -6.0, 0.0, 6.0, 12.0]:
		_add_static_box(arena, Vector3(0.07, 0.02, 34.0), Vector3(gx, 0.01, -1.0), Vector3.ZERO, cyan_glow, false)
	for gz in [-10.0, -5.0, 0.0, 5.0]:
		_add_static_box(arena, Vector3(32.0, 0.02, 0.07), Vector3(0.0, 0.01, gz), Vector3.ZERO, cyan_glow, false)

	var oct_r := 19.5
	for i in range(8):
		var ang_deg := float(i) * 45.0
		var ang_rad := deg_to_rad(ang_deg)
		var wx := sin(ang_rad) * oct_r
		var wz := cos(ang_rad) * oct_r
		_add_static_box(arena, Vector3(16.6, 5.6, 0.8), Vector3(wx, 2.8, wz), Vector3(0, ang_deg, 0), wall_mat, true)
		var inward := 0.975
		_add_static_box(arena, Vector3(15.8, 0.11, 0.12), Vector3(wx * inward, 4.55, wz * inward), Vector3(0, ang_deg, 0), fr_blue, false)
		_add_static_box(arena, Vector3(15.8, 0.11, 0.12), Vector3(wx * inward, 4.35, wz * inward), Vector3(0, ang_deg, 0), fr_white, false)
		_add_static_box(arena, Vector3(15.8, 0.11, 0.12), Vector3(wx * inward, 4.15, wz * inward), Vector3(0, ang_deg, 0), fr_red, false)

		var c_ang := deg_to_rad(ang_deg + 22.5)
		var cx := sin(c_ang) * (oct_r - 0.3)
		var cz := cos(c_ang) * (oct_r - 0.3)
		_add_static_box(arena, Vector3(1.1, 6.2, 1.1), Vector3(cx, 3.1, cz), Vector3(0, ang_deg + 22.5, 0), pillar_mat, true)

	for pos in [Vector3(-8.2, 0.65, -1.5), Vector3(8.2, 0.65, -1.5), Vector3(-10.5, 0.65, -8.5), Vector3(10.5, 0.65, -8.5)]:
		_add_static_box(arena, Vector3(1.0, 1.3, 1.0), pos, Vector3(0, 45, 0), pillar_mat, true)
		_add_static_box(arena, Vector3(1.06, 0.08, 1.06), pos + Vector3(0, 0.62, 0), Vector3(0, 45, 0), cyan_glow, false)

	gallery_sign = Label3D.new()
	gallery_sign.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	gallery_sign.text = "GALERIE DE RECONNAISSANCE (9 SECTEURS A1–B1)  •  TIREZ POUR ÉCOUTER"
	gallery_sign.position = Vector3(0, 3.85, -15.5)
	gallery_sign.font_size = 42
	gallery_sign.modulate = Color(0.45, 0.90, 1.0)
	gallery_sign.outline_size = 10
	arena.add_child(gallery_sign)


func _spawn_player() -> void:
	player = PlayerController.new()
	player.position = Vector3(0.0, 0.35, 8.2)
	world_root.add_child(player)
	player.look_toward_point(Vector3(0.0, 1.5, -6.0))
	player.fired_at_entity.connect(_on_player_fired)
	player.hovered_entity_changed.connect(_on_player_hovered)


func _spawn_gallery_pedestals() -> void:
	pedestals.clear()
	for ch in pedestals_root.get_children():
		ch.queue_free()

	var sec_ids := VocabData.get_sector_ids(0)
	var xs := [-8.0, -4.0, 0.0, 4.0, 8.0]
	for i in range(5):
		var ped := PedestalStation.new()
		pedestals_root.add_child(ped)
		var pos := Vector3(xs[i], 0.20, -13.4)
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
# TACTICAL UI & LEXICON CONSTRUCTION
# ==============================================================================

func _make_panel_style(bg: Color, border: Color, radius: int = 10, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(hud_root)

	# 1. Custom Vector Tactical Reticle & Hover Readout
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
	hover_info_lbl.add_theme_color_override("font_color", Color(0.65, 0.96, 1.0))
	hover_info_lbl.set_anchors_preset(Control.PRESET_CENTER)
	hover_info_lbl.position = Vector2(-260, 28)
	hover_info_lbl.size = Vector2(520, 44)
	hud_root.add_child(hover_info_lbl)

	# 2. Top-Center Radio Comms & Waveform Panel
	var radio_panel := PanelContainer.new()
	radio_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.05, 0.08, 0.15, 0.90), Color(0.22, 0.78, 1.0, 0.85), 12, 2)
	)
	radio_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	radio_panel.position = Vector2(-390, 12)
	radio_panel.custom_minimum_size = Vector2(780, 122)
	radio_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(radio_panel)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 5)
	radio_panel.add_child(rv)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	rv.add_child(top_row)

	speaker_lbl = Label.new()
	speaker_lbl.text = "◉ RADIO : CMDT. HENRI"
	speaker_lbl.add_theme_font_size_override("font_size", 14)
	speaker_lbl.add_theme_color_override("font_color", Color(0.35, 0.88, 1.0))
	top_row.add_child(speaker_lbl)

	var wave_box := HBoxContainer.new()
	wave_box.add_theme_constant_override("separation", 3)
	wave_box.custom_minimum_size = Vector2(96, 20)
	top_row.add_child(wave_box)
	wave_bars.clear()
	for i in range(12):
		var bar_wrap := Control.new()
		bar_wrap.custom_minimum_size = Vector2(5, 20)
		wave_box.add_child(bar_wrap)
		var bar := ColorRect.new()
		bar.color = Color(0.25, 0.95, 0.78)
		bar.position = Vector2(0, 8)
		bar.size = Vector2(5, 4)
		bar_wrap.add_child(bar)
		wave_bars.append(bar)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	mode_tag_lbl = Label.new()
	mode_tag_lbl.text = "A1 • TIER 0 • CALIBRAGE"
	mode_tag_lbl.add_theme_font_size_override("font_size", 13)
	mode_tag_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
	top_row.add_child(mode_tag_lbl)

	prompt_main_lbl = Label.new()
	prompt_main_lbl.text = "Prêt pour l'Opération Écho"
	prompt_main_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_main_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_main_lbl.add_theme_font_size_override("font_size", 19)
	prompt_main_lbl.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	rv.add_child(prompt_main_lbl)

	prompt_sub_lbl = Label.new()
	prompt_sub_lbl.text = ""
	prompt_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_sub_lbl.add_theme_font_size_override("font_size", 13)
	prompt_sub_lbl.add_theme_color_override("font_color", Color(0.68, 0.84, 1.0))
	rv.add_child(prompt_sub_lbl)

	timer_bar = ProgressBar.new()
	timer_bar.show_percentage = false
	timer_bar.min_value = 0.0
	timer_bar.max_value = 100.0
	timer_bar.value = 100.0
	timer_bar.custom_minimum_size = Vector2(0, 7)
	var tb_fill := StyleBoxFlat.new()
	tb_fill.bg_color = Color(0.25, 0.88, 1.0)
	tb_fill.set_corner_radius_all(3)
	timer_bar.add_theme_stylebox_override("fill", tb_fill)
	rv.add_child(timer_bar)

	# 3. Contrastive Feedback Banner
	feedback_banner = PanelContainer.new()
	feedback_banner.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.08, 0.14, 0.22, 0.93), Color(0.32, 1.0, 0.68, 0.9), 10, 2)
	)
	feedback_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	feedback_banner.position = Vector2(-370, 144)
	feedback_banner.custom_minimum_size = Vector2(740, 44)
	feedback_banner.visible = false
	feedback_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(feedback_banner)

	feedback_lbl = Label.new()
	feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_lbl.add_theme_font_size_override("font_size", 14)
	feedback_banner.add_child(feedback_lbl)

	# 4. Top-Left Tactical Stats
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.05, 0.08, 0.15, 0.86), Color(0.20, 0.48, 0.88, 0.75), 10, 2)
	)
	stats_panel.position = Vector2(14, 12)
	stats_panel.custom_minimum_size = Vector2(226, 108)
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(stats_panel)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 5)
	stats_panel.add_child(sv)

	wave_lbl = Label.new()
	wave_lbl.text = "VAGUE 1  •  0/6"
	wave_lbl.add_theme_font_size_override("font_size", 15)
	wave_lbl.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
	sv.add_child(wave_lbl)

	score_lbl = Label.new()
	score_lbl.text = "SCORE : 0   (x1)"
	score_lbl.add_theme_font_size_override("font_size", 17)
	score_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	sv.add_child(score_lbl)

	var sh_lbl := Label.new()
	sh_lbl.text = "BOUCLIER ACOUSTIQUE"
	sh_lbl.add_theme_font_size_override("font_size", 11)
	sh_lbl.add_theme_color_override("font_color", Color(0.68, 0.78, 0.92))
	sv.add_child(sh_lbl)

	shield_bar = ProgressBar.new()
	shield_bar.show_percentage = false
	shield_bar.max_value = 100.0
	shield_bar.value = 100.0
	shield_bar.custom_minimum_size = Vector2(0, 10)
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.24, 0.92, 0.62)
	sb_fill.set_corner_radius_all(4)
	shield_bar.add_theme_stylebox_override("fill", sb_fill)
	sv.add_child(shield_bar)

	# 5. Bottom Controls Legend Bar
	var bot_panel := PanelContainer.new()
	bot_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.04, 0.07, 0.13, 0.84), Color(0.18, 0.40, 0.72, 0.65), 8, 1)
	)
	bot_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bot_panel.position = Vector2(-510, -48)
	bot_panel.custom_minimum_size = Vector2(1020, 36)
	bot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bot_panel)

	hotkeys_lbl = Label.new()
	hotkeys_lbl.text = "[WASD] Move  •  [Click / F] Shoot  •  [Right-Click / V] Zoom  •  [E] Replay  •  [R] Slow  •  [H] Hint  •  [Tab] SRS Matrix (A1–B1)  •  [G] Gallery [1-9]  •  [Esc] Menu"
	hotkeys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkeys_lbl.add_theme_font_size_override("font_size", 12)
	hotkeys_lbl.add_theme_color_override("font_color", Color(0.78, 0.89, 1.0))
	bot_panel.add_child(hotkeys_lbl)

	_build_menu_overlay()
	_build_summary_overlay()
	_build_lexicon_overlay()


func _build_menu_overlay() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.05, 0.08, 0.16, 0.94), Color(0.25, 0.80, 1.0, 0.92), 16, 2)
	)
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.position = Vector2(-365, -255)
	menu_panel.custom_minimum_size = Vector2(730, 510)
	ui_layer.add_child(menu_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 11)
	menu_panel.add_child(vb)

	var title := Label.new()
	title.text = "FRANC-TIREUR : OPÉRATION ÉCHO (A1 – B1)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.38, 0.92, 1.0))
	vb.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "3D Tactical French Sharpshooter  •  CEFR A1, A2 & B1 Listening, Space & Grammar"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.84, 0.91, 1.0))
	vb.add_child(subtitle)

	var desc := Label.new()
	desc.text = (
		"• 45 Modèles 3D Blender (9 Secteurs A1–B1) : Identifiez les objets à l'oreille sans béquille textuelle.\n"
		+ "• Modificateurs 3D (A2) : Comparatifs, superlatifs, vitesse & prépositions spatiales (le plus grand, immobile, au milieu...).\n"
		+ "• Dialogues DELF & Brèches Grammaticales (A2–B1) : Passé composé vs imparfait, pronoms (y/en/leur), conditionnel & subjonctif."
	)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.72, 0.84, 0.96))
	vb.add_child(desc)

	menu_stats_lbl = Label.new()
	menu_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_stats_lbl.add_theme_font_size_override("font_size", 13)
	menu_stats_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.72))
	vb.add_child(menu_stats_lbl)

	sector_btn = Button.new()
	sector_btn.custom_minimum_size = Vector2(0, 38)
	sector_btn.pressed.connect(_on_cycle_sector)
	vb.add_child(sector_btn)

	l1_btn = Button.new()
	l1_btn.custom_minimum_size = Vector2(0, 38)
	l1_btn.pressed.connect(_on_cycle_l1_mode)
	vb.add_child(l1_btn)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vb.add_child(btn_row)

	var start_btn := Button.new()
	start_btn.text = "▶ LANCER LA MISSION (COMBAT SRS A1–B1)"
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.custom_minimum_size = Vector2(0, 48)
	start_btn.pressed.connect(_on_start_mission_pressed)
	btn_row.add_child(start_btn)

	var gal_btn := Button.new()
	gal_btn.text = "◈ GALERIE 3D (9 SECTEURS)"
	gal_btn.custom_minimum_size = Vector2(225, 48)
	gal_btn.pressed.connect(_on_enter_gallery_pressed)
	btn_row.add_child(gal_btn)

	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 12)
	vb.add_child(bot_row)

	var lex_btn := Button.new()
	lex_btn.text = "✦ MATRICE SRS : 45 MOTS 3D + 16 BRÈCHES GRAMMATICALES"
	lex_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lex_btn.custom_minimum_size = Vector2(0, 36)
	lex_btn.pressed.connect(func(): _toggle_lexicon(true))
	bot_row.add_child(lex_btn)

	var rst_btn := Button.new()
	rst_btn.text = "↺ Réinitialiser SRS"
	rst_btn.custom_minimum_size = Vector2(170, 36)
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
		_make_panel_style(Color(0.05, 0.09, 0.17, 0.94), Color(0.32, 1.0, 0.68, 0.92), 16, 2)
	)
	summary_panel.set_anchors_preset(Control.PRESET_CENTER)
	summary_panel.position = Vector2(-290, -185)
	summary_panel.custom_minimum_size = Vector2(580, 370)
	summary_panel.visible = false
	ui_layer.add_child(summary_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	summary_panel.add_child(vb)

	var hd := Label.new()
	hd.text = "✓ VAGUE TERMINÉE — RAPPORT TACTIQUE CECRL"
	hd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hd.add_theme_font_size_override("font_size", 22)
	hd.add_theme_color_override("font_color", Color(0.35, 1.0, 0.72))
	vb.add_child(hd)

	summary_lbl = Label.new()
	summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_lbl.add_theme_font_size_override("font_size", 15)
	vb.add_child(summary_lbl)

	var next_btn := Button.new()
	next_btn.text = "▶ VAGUE SUIVANTE (CONTINUER)"
	next_btn.custom_minimum_size = Vector2(0, 46)
	next_btn.pressed.connect(func():
		audio.play_sfx("click")
		summary_panel.visible = false
		wave_number += 1
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_begin_wave()
	)
	vb.add_child(next_btn)

	var menu_b := Button.new()
	menu_b.text = "Retour au Menu / Changer de Programme CECRL"
	menu_b.custom_minimum_size = Vector2(0, 36)
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
		_make_panel_style(Color(0.04, 0.07, 0.14, 0.96), Color(0.32, 0.85, 1.0, 0.92), 14, 2)
	)
	lexicon_panel.set_anchors_preset(Control.PRESET_CENTER)
	lexicon_panel.position = Vector2(-590, -320)
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
	lexicon_header_lbl.text = "MATRICE SRS CECRL (A1–B1) — Cliquez sur [♪] pour écouter"
	lexicon_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lexicon_header_lbl.add_theme_font_size_override("font_size", 14)
	lexicon_header_lbl.add_theme_color_override("font_color", Color(0.42, 0.92, 1.0))
	top.add_child(lexicon_header_lbl)

	for tab_spec in [
		["ALL", "Tous (45)"],
		["A1", "A1 (20)"],
		["A2", "A2 (15)"],
		["B1", "B1 (10)"],
		["GRAM", "Grammaire A2–B1 (16)"],
	]:
		var tb := Button.new()
		var t_code: String = tab_spec[0]
		tb.text = tab_spec[1]
		tb.custom_minimum_size = Vector2(92, 30)
		tb.add_theme_font_size_override("font_size", 12)
		tb.pressed.connect(func():
			audio.play_sfx("click")
			lexicon_tab = t_code
			_populate_lexicon_grid()
		)
		top.add_child(tb)

	var close_btn := Button.new()
	close_btn.text = "✗ Fermer [Tab]"
	close_btn.custom_minimum_size = Vector2(112, 30)
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

	var tier_names := ["T0 Nouveau", "T1 Texte FR", "T2 Écoute Pure", "T3 Contexte", "T4 Maîtrisé"]
	var tier_cols := [
		Color(0.55, 0.62, 0.72),
		Color(0.38, 0.78, 1.0),
		Color(0.75, 0.55, 1.0),
		Color(1.0, 0.80, 0.25),
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
			play_b.text = "♪ Phrase"
			play_b.add_theme_font_size_override("font_size", 12)
			var aud_f: String = g["audio"]
			play_b.pressed.connect(func(): audio.play_voice(aud_f))
			r1.add_child(play_b)

			var s_lbl := Label.new()
			s_lbl.text = g["sentence_full"]
			s_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			s_lbl.add_theme_font_size_override("font_size", 13)
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
		play_b.tooltip_text = "Écouter la prononciation"
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
		st_lbl.text = "%s  |  ✓%d  ✗%d" % [tier_names[t_idx] if bool(c["seen"]) else "Non vu", ok_n, er_n]
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
		_populate_lexicon_grid()
		player.controls_enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if state in [GameState.CALIBRATION, GameState.COMBAT, GameState.GALLERY]:
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
	menu_stats_lbl.text = "SRS : %d/%d Mots 3D  •  %d Écoute Pure (T2+)  •  %d/%d Grammaire A2–B1  •  Précision %.0f%%" % [
		st["seen"], st["total_words"], st["listening_ready"], st["gram_seen"], st["gram_total"], st["accuracy"]
	]
	match srs.sector_filter:
		-1:
			sector_btn.text = "◈ Programme : Cursus Complet Adaptatif CECRL (A1 → A2 → B1 — 45 Mots + Grammaire)"
		-2:
			sector_btn.text = "◈ Programme CECRL A1 : Fondations & Survie (Secteurs 1–4 — 20 Mots)"
		-3:
			sector_btn.text = "◈ Programme CECRL A2 : Vie Quotidienne, Espace 3D, Dialogues & Grammaire (Secteurs 5–7)"
		-4:
			sector_btn.text = "◈ Programme CECRL B1 : Urgences, Société, Discours DELF & Subjonctif (Secteurs 8–9)"
		-5:
			sector_btn.text = "◈ Opération Spéciale A2 : Modificateurs 3D, Comparatifs & Prépositions Spatiales"
		-6:
			sector_btn.text = "◈ Opération Spéciale DELF A2–B1 : Dialogues & Compréhension Orale (16 Scénarios)"
		-7:
			sector_btn.text = "◈ Opération Spéciale A2–B1 : Brèches Grammaticales & Phonétiques (16 Cristaux 3D)"
		_:
			var s_info := VocabData.SECTORS[clampi(srs.sector_filter, 0, VocabData.SECTORS.size() - 1)]
			sector_btn.text = "◈ %s (%s)" % [s_info["name_fr"], s_info["name_en"]]

	var l1_names := [
		"✦ Support Anglais (L1) : Estompage Adaptatif SRS (Recommandé)",
		"✦ Support Anglais (L1) : Toujours afficher la traduction",
		"✦ Support Anglais (L1) : Immersion 100% Français",
	]
	l1_btn.text = l1_names[srs.l1_mode]


func _on_cycle_sector() -> void:
	audio.play_sfx("click")
	var order := [-1, -2, -3, -4, -5, -6, -7, 0, 1, 2, 3, 4, 5, 6, 7, 8]
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
	hud_root.visible = true
	hover_info_lbl.text = ""
	_set_gallery_visible(false)
	player.visible = true
	player.camera.current = true
	player.position = Vector3(0.0, 0.35, 8.2)
	player.look_toward_point(Vector3(0.0, 1.6, -5.0))
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
	hud_root.visible = true
	feedback_banner.visible = false
	player.visible = true
	player.camera.current = true
	player.position = Vector3(0.0, 0.35, -7.2)
	player.look_toward_point(Vector3(0.0, 1.5, -13.4))
	player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if srs.sector_filter >= 0:
		gallery_sector = srs.sector_filter
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
	speaker_lbl.text = "◈ GALERIE DE RECONNAISSANCE (%s)" % s_info["cefr"]
	mode_tag_lbl.text = "[1-9] Changer de Secteur (1–9)  •  [M] Lancer Combat"
	prompt_main_lbl.text = s_info["name_fr"]
	prompt_sub_lbl.text = "Focus phonétique : %s — Tirez sur un piédestal pour écouter !" % s_info["focus"]
	timer_bar.value = 100.0


func _begin_wave() -> void:
	prompt_in_wave = 0
	shield_hp = minf(100.0, shield_hp + 25.0)
	_set_gallery_visible(false)
	_update_stats_hud()

	calibration_queue = srs.get_words_to_calibrate(3)
	if not calibration_queue.is_empty():
		_start_calibration_phase()
	else:
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
		var spread := (float(i) - float(count - 1) * 0.5) * 4.4
		var pos := Vector3(spread, 2.15, -2.5)
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(vid, pos, player.global_position, 0.22)
		d.show_calibration_card("%s (%s)" % [item["fr_def"], item["fr_indef"]], item["en"])
		d.set_beacon(i == 0, Color(0.20, 0.95, 1.0) if i == 0 else Color(0.3, 0.5, 0.7))
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
			d.set_beacon(d.vocab_id == current_calib_id, Color(0.20, 1.0, 0.80))

	speaker_lbl.text = "◉ LT. DENISE (CALIBRAGE %s)" % item.get("cefr", "A1")
	mode_tag_lbl.text = "NOUVEAU MOT  •  TIREZ POUR MÉMORISER (%d restant)" % calibration_queue.size()
	prompt_main_lbl.text = "« %s  •  %s »  —  %s" % [item["fr_indef"], item["fr_def"], item["en"]]
	prompt_sub_lbl.text = "%s   |   Note : %s" % [item["ipa"], item["tip"]]
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
	var distractors := srs.select_distractors(target_id, 4, str(spec["required_decoy"]))
	var spawn_ids: Array[String] = [target_id]
	spawn_ids.append_array(distractors)
	spawn_ids.shuffle()

	var n := spawn_ids.size()
	for i in range(n):
		var frac := float(i) / float(maxi(1, n - 1))
		var ang := lerpf(-0.96, 0.96, frac) + randf_range(-0.06, 0.06)
		var dist := randf_range(10.2, 13.8) if (i % 2 == 0) else randf_range(12.6, 15.8)
		var height := randf_range(1.90, 3.30)
		var sx := sin(ang) * dist
		var sz := 7.5 - cos(ang) * dist
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(spawn_ids[i], Vector3(sx, height, sz), player.global_position, 0.85 + float(wave_number) * 0.04)
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
	for i in range(n):
		var frac := float(i) / float(maxi(1, n - 1))
		var ang := lerpf(-0.85, 0.85, frac)
		var dist := 11.8 if (i % 2 == 0) else 13.6
		var height := 2.35
		var sx := sin(ang) * dist
		var sz := 7.5 - cos(ang) * dist
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(spawn_ids[i], Vector3(sx, height, sz), player.global_position, 0.72)
		active_drones.append(d)


func _spawn_grammar_drones(spec: Dictionary) -> void:
	var opts: Array = spec["options"].duplicate()
	opts.shuffle()
	var xs := [-7.2, -2.4, 2.4, 7.2]
	for i in range(opts.size()):
		var opt_txt := str(opts[i])
		var pos := Vector3(xs[i], 2.35, -3.6)
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup("holo_crystal", pos, player.global_position, 0.28, 1.08, opt_txt)
		d.configure_as_grammar_crystal(opt_txt, i + 1)
		active_drones.append(d)


func _spawn_modifier_drones(spec: Dictionary) -> void:
	var layout := str(spec["layout"])
	var vid := str(spec["base_vocab_id"])
	var xs4 := [-7.5, -2.5, 2.5, 7.5]
	var target_slot := randi() % 4

	if layout == "pos_left":
		target_slot = 0
	elif layout == "pos_right":
		target_slot = 3
	elif layout == "pos_middle":
		var xs3 := [-6.4, 0.0, 6.4]
		for i in range(3):
			var is_t := (i == 1)
			var d := TargetDrone.new()
			drones_root.add_child(d)
			d.setup(vid, Vector3(xs3[i], 2.35, -3.8), player.global_position, 0.15, 1.05, "MOD_TARGET" if is_t else ("DECOY_%d" % i))
			d.custom_ok_label = "✓ Au milieu !"
			d.custom_wrong_label = "✗ Sur le côté (pas au milieu) !"
			active_drones.append(d)
		return

	for i in range(4):
		var is_t := (i == target_slot)
		var tag := "MOD_TARGET" if is_t else ("DECOY_%d" % i)
		var pos := Vector3(xs4[i], 2.35, -3.8)
		var mv := 0.55
		var sc := 1.0
		var ok_lbl := "✓ Cible correcte !"
		var err_lbl := "✗ Mauvaise cible !"

		match layout:
			"scale_max":
				sc = 1.68 if is_t else (0.64 + float(i) * 0.08)
				mv = 0.45
				ok_lbl = "✓ La plus grande !"
				err_lbl = "✗ Trop petit (visez la plus grande) !"
			"scale_min":
				sc = 0.56 if is_t else (1.18 + float(i) * 0.12)
				mv = 0.45
				ok_lbl = "✓ Le plus petit !"
				err_lbl = "✗ Trop grand (visez le plus petit) !"
			"speed_max":
				mv = 2.65 if is_t else 0.22
				ok_lbl = "✓ Le plus rapide !"
				err_lbl = "✗ Trop lent (visez celui qui bouge vite) !"
			"speed_zero":
				mv = 0.0 if is_t else 1.65
				ok_lbl = "✓ Immobile !"
				err_lbl = "✗ Il bouge (visez celui qui est immobile) !"
			"height_max":
				pos.y = 4.15 if is_t else 1.55
				mv = 0.35
				ok_lbl = "✓ Le plus haut !"
				err_lbl = "✗ Trop bas (visez le plus haut) !"
			"height_min":
				pos.y = 1.25 if is_t else 3.70
				mv = 0.35
				ok_lbl = "✓ Le plus bas !"
				err_lbl = "✗ Trop haut (visez le plus bas) !"
			"pos_left":
				mv = 0.12
				ok_lbl = "✓ Tout à gauche !"
				err_lbl = "✗ Pas tout à gauche !"
			"pos_right":
				mv = 0.12
				ok_lbl = "✓ Tout à droite !"
				err_lbl = "✗ Pas tout à droite !"
			"dist_min":
				pos.z = 0.6 if is_t else -7.5
				mv = 0.35
				ok_lbl = "✓ Le plus proche !"
				err_lbl = "✗ Trop loin (visez le plus proche) !"
			"dist_max":
				pos.z = -8.6 if is_t else -0.4
				mv = 0.35
				ok_lbl = "✓ La plus éloignée !"
				err_lbl = "✗ Trop proche (visez au fond) !"
			"big_stationary":
				if is_t:
					sc = 1.62
					mv = 0.0
				elif i % 2 == 0:
					sc = 1.62
					mv = 1.85
				else:
					sc = 0.62
					mv = 0.0
				ok_lbl = "✓ Grand ET immobile !"
				err_lbl = "✗ Doit être à la fois GRAND et IMMOBILE !"

		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(vid, pos, player.global_position, mv, sc, tag)
		d.custom_ok_label = ok_lbl
		d.custom_wrong_label = err_lbl
		active_drones.append(d)


func _refresh_prompt_hud() -> void:
	speaker_lbl.text = "◉ RADIO : " + str(current_spec["speaker"])
	mode_tag_lbl.text = str(current_spec["mode_tag"])

	var ptype := str(current_spec.get("prompt_type", "VOCAB"))
	var show_fr := bool(current_spec["show_fr_text"]) or (prompt_hint_stage >= 1)
	var show_en := bool(current_spec["show_en_text"]) or (prompt_hint_stage >= 2)

	if show_fr:
		prompt_main_lbl.text = "♪ %s" % str(current_spec["prompt_fr"])
	else:
		if ptype == "SCENARIO":
			prompt_main_lbl.text = "◉ DIALOGUE DELF — %s  ([E] Réécouter • [R] Lent • [H] Transcription)" % str(current_spec.get("question_fr", "Écoutez !"))
		elif ptype == "MODIFIER":
			prompt_main_lbl.text = "◉ ESPACE & MODIFICATEURS 3D — Écoutez la consigne spatiale !  ([E] Réécouter • [R] Lent • [H] Texte)"
		elif int(current_spec["tier"]) >= 3:
			prompt_main_lbl.text = "◉ ÉCOUTE CONTEXTUELLE — Décodez l'ordre vocal !  ([E] Réécouter • [R] Lent • [H] Texte)"
		else:
			prompt_main_lbl.text = "◉ ÉCOUTE PURE — Signal vocal uniquement !  ([E] Réécouter • [R] Lent • [H] Texte)"

	if show_en:
		prompt_sub_lbl.text = str(current_spec["sub_en"])
	else:
		if ptype == "GRAMMAR":
			prompt_sub_lbl.text = "Tirez sur le Cristal 3D qui complète la phrase !   •   [E] Réécouter   •   [H] Règle & Traduction"
		else:
			prompt_sub_lbl.text = "[R] Écoute lente articulée   •   [H] Dévoiler transcription / explication"


# ==============================================================================
# SHOOTING, CONTRASTIVE FEEDBACK & INPUTS
# ==============================================================================

func _on_player_hovered(entity: Node) -> void:
	if entity is PedestalStation:
		var p := entity as PedestalStation
		var item := VocabData.get_by_id(p.vocab_id)
		_reticle_col = Color(0.35, 1.0, 0.78)
		hover_info_lbl.text = "[Click] Écouter : %s (%s)" % [item.get("fr_def", ""), item.get("en", "")]
	elif entity is TargetDrone:
		_reticle_col = Color(1.0, 0.88, 0.28)
		var td := entity as TargetDrone
		if state == GameState.CALIBRATION:
			var item := VocabData.get_by_id(td.vocab_id)
			hover_info_lbl.text = "Scannez : %s — %s" % [item.get("fr_def", ""), item.get("en", "")]
		elif td.is_grammar_crystal:
			hover_info_lbl.text = "Cristal Grammatical : « %s »" % td.grammar_option
		else:
			hover_info_lbl.text = ""
	else:
		_reticle_col = Color(0.35, 0.95, 1.0, 0.92)
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
		_show_feedback("♪ [%s] %s (%s) — %s  |  %s" % [item["cefr"], item["fr_def"], item["fr_indef"], item["en"], item["tip"]], true)
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
		drone.explode_success(world_root)
		active_drones.erase(drone)
		calibration_queue.erase(vid)
		score += 40
		_update_stats_hud()
		transition_delay = 0.65
		return

	if state == GameState.COMBAT and prompt_active:
		var ptype := str(current_spec.get("prompt_type", "VOCAB"))
		var target_tag := str(current_spec["target_id"])

		if drone.drone_tag == target_tag:
			prompt_active = false
			audio.play_sfx("hit_ok", 0.02, -1.5)
			drone.explode_success(world_root)
			active_drones.erase(drone)

			if prompt_clean_try:
				combo += 1
				score += (100 + combo * 25) * (1 + int(current_spec["tier"]))
			else:
				score += 55

			if ptype == "GRAMMAR":
				var gid := str(current_spec["grammar_id"])
				srs.record_grammar_result(gid, prompt_clean_try, prompt_used_assist)
				audio.play_voice(str(current_spec["audio_file"]))
				_show_feedback("✓ Exact ! « %s »  —  %s" % [ current_spec["sentence_full"], current_spec["rule"] ], true)
				prompt_main_lbl.text = "✓ « %s »" % str(current_spec["sentence_full"])
				prompt_sub_lbl.text = str(current_spec["en"])
			elif ptype == "MODIFIER":
				srs.global_step += 1
				srs.save_progress()
				_show_feedback("✓ Bravo ! « %s »  —  %s" % [ current_spec["prompt_fr"], current_spec["rule"] ], true)
				prompt_main_lbl.text = "✓ « %s »" % str(current_spec["prompt_fr"])
				prompt_sub_lbl.text = str(current_spec["sub_en"])
			else:
				var res := srs.record_result(target_tag, prompt_clean_try, prompt_used_assist, prompt_wrong_ids)
				var item := VocabData.get_by_id(target_tag)
				var tier_arrow := ("  [Tier %d → %d ↑]" % [res["prev_tier"], res["new_tier"]]) if int(res["new_tier"]) > int(res["prev_tier"]) else ""
				_show_feedback(
					"✓ Bravo !  [%s] %s (%s) = %s   %s   (Prochaine révision : +%d)" % [
						item["cefr"], item["fr_def"], item["fr_indef"], item["en"], tier_arrow, int(res["next_in_prompts"])
					],
					true
				)
				prompt_main_lbl.text = "✓ %s" % str(current_spec["prompt_fr"])
				prompt_sub_lbl.text = "%s  •  %s  •  %s" % [item["fr_def"], item["ipa"], item["en"]]

			_update_stats_hud()
			transition_delay = 1.55
		else:
			audio.play_sfx("hit_err", 0.02, -1.0)
			audio.play_sfx("shield_hit", 0.03, -3.0)
			drone.flash_wrong_hit()

			prompt_clean_try = false
			combo = 0
			shield_hp = maxf(10.0, shield_hp - 15.0)
			if not prompt_wrong_ids.has(drone.vocab_id):
				prompt_wrong_ids.append(drone.vocab_id)

			if ptype == "GRAMMAR":
				_show_feedback(
					"✗ Non, pas « %s » !  →  Visez « %s »  |  %s" % [
						drone.grammar_option, target_tag, current_spec["rule"]
					],
					false
				)
				_highlight_true_target(target_tag)
				audio.play_voice(str(current_spec["audio_file"]), 2.0, 0.86)
			elif ptype == "MODIFIER":
				_show_feedback(
					"✗ %s  →  Consigne : « %s » (%s)" % [
						drone.custom_wrong_label, current_spec["prompt_fr"], current_spec["rule"]
					],
					false
				)
				_highlight_true_target(target_tag)
				audio.play_voice(str(current_spec["audio_file"]), 2.0, 0.86)
			else:
				var hit_item := VocabData.get_by_id(drone.vocab_id)
				var goal_item := VocabData.get_by_id(target_tag)
				_show_feedback(
					"✗ Non ! Ça, c'est %s (%s).  →  Visez %s (%s) !" % [
						hit_item.get("fr_def", drone.vocab_id), hit_item.get("en", ""),
						goal_item.get("fr_def", target_tag), goal_item.get("en", "")
					],
					false
				)
				_highlight_true_target(target_tag)
				audio.play_voice("slow_%s.ogg" % target_tag)

			prompt_timer = maxf(prompt_timer, 8.5)
			_update_stats_hud()


func _highlight_true_target(target_tag: String) -> void:
	for d in active_drones:
		if is_instance_valid(d) and d.drone_tag == target_tag:
			d.set_beacon(true, Color(1.0, 0.85, 0.18))


func _show_feedback(msg: String, positive: bool) -> void:
	feedback_banner.visible = true
	feedback_lbl.text = msg
	var border_col := Color(0.30, 1.0, 0.68, 0.95) if positive else Color(1.0, 0.42, 0.42, 0.95)
	feedback_banner.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.06, 0.11, 0.19, 0.94), border_col, 10, 2)
	)
	feedback_lbl.add_theme_color_override("font_color", Color(0.75, 1.0, 0.88) if positive else Color(1.0, 0.78, 0.78))


func _finish_wave() -> void:
	state = GameState.WAVE_SUMMARY
	prompt_active = false
	_clear_drones()
	audio.play_sfx("wave_up", 0.0, -1.0)
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var st := srs.get_summary_stats()
	summary_lbl.text = (
		"Vague %d accomplie !\n\n" % wave_number
		+ "• Score total : %d   |   Série actuelle : x%d\n" % [score, combo]
		+ "• Vocabulaire 3D (A1–B1) découvert : %d / %d\n" % [st["seen"], st["total_words"]]
		+ "• Prêts en Écoute Pure (Tier 2+) : %d\n" % st["listening_ready"]
		+ "• Maîtrisés en Contexte (Tier 3+) : %d\n" % st["mastered"]
		+ "• Brèches Grammaticales A2–B1 : %d / %d étudiées\n" % [st["gram_seen"], st["gram_total"]]
		+ "• Précision globale : %.0f%%" % st["accuracy"]
	)
	summary_panel.visible = true


func _clear_drones() -> void:
	active_drones.clear()
	for ch in drones_root.get_children():
		ch.queue_free()


func _update_stats_hud() -> void:
	wave_lbl.text = "VAGUE %d  •  ORDRE %d/%d" % [wave_number, prompt_in_wave, PROMPTS_PER_WAVE]
	score_lbl.text = "SCORE : %d   (x%d)" % [score, maxi(1, combo)]
	shield_bar.value = shield_hp


func _play_slow_assist() -> void:
	prompt_used_assist = true
	var ptype := str(current_spec.get("prompt_type", "VOCAB"))
	var slow_file := str(current_spec.get("slow_audio_file", ""))
	if slow_file != "":
		audio.play_voice(slow_file)
	else:
		audio.play_voice(str(current_spec["audio_file"]), 2.0, 0.82)

	if ptype == "VOCAB" or ptype == "SCENARIO":
		var item := VocabData.get_by_id(str(current_spec["target_id"]))
		if not item.is_empty():
			_show_feedback("♪ Écoute ralentie : %s   |   Note : %s" % [item["ipa"], item["tip"]], true)
	elif ptype == "MODIFIER":
		_show_feedback("♪ Écoute ralentie : « %s »   |   %s" % [current_spec["prompt_fr"], current_spec["rule"]], true)
	elif ptype == "GRAMMAR":
		_show_feedback("♪ Écoute ralentie   |   Règle : %s" % str(current_spec["rule"]), true)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: Key = event.physical_keycode

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

	if lexicon_open or state == GameState.MENU:
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


func _process(delta: float) -> void:
	if state == GameState.MENU:
		_menu_orbit_angle += delta * 0.18
		_menu_cam.global_position = Vector3(sin(_menu_orbit_angle) * 14.0, 5.2, cos(_menu_orbit_angle) * 14.0 - 2.0)
		_menu_cam.look_at(Vector3(0, 1.5, -6.5), Vector3.UP)
		return

	if crosshair_reticle and player:
		crosshair_reticle.set_state(_reticle_col, player.is_aiming)

	var bars := audio.get_waveform_bars(12)
	for i in range(mini(bars.size(), wave_bars.size())):
		var h := bars[i] * 20.0
		wave_bars[i].size.y = h
		wave_bars[i].position.y = (20.0 - h) * 0.5

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
			_show_feedback("! Temps écoulé ! Tirez sur le drone illuminé en jaune !", false)
			prompt_timer = 9.0
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
	test_srs.mark_calibrated("avion")
	var r1 := test_srs.record_result("avion", true, false, [])
	assert(int(r1["new_tier"]) == 1, "Clean hit should advance Tier 0 -> Tier 1")
	var r2 := test_srs.record_result("avion", true, false, [])
	assert(int(r2["new_tier"]) == 2, "Clean hit should advance Tier 1 -> Tier 2 (Pure Listening)")
	var r_err := test_srs.record_result("avion", false, false, ["train"])
	assert(int(r_err["new_tier"]) == 1, "Mistake should drop Tier 2 -> Tier 1 and log confusion")
	var rg := test_srs.record_grammar_result("gram_09", true, false)
	assert(int(rg["new_tier"]) == 1, "Grammar breach card should advance tier on clean hit")
	print("VERIFY_OK: CEFR A1-B1 SRS Engine (45 vocab + 16 grammar + modifiers + scenarios) passed.")

	for i in range(4):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/01_menu.png")

	# 2. Calibration phase with A2 Travel & Transport 3D models (avion, train, voiture)
	srs.sector_filter = 4
	_on_start_mission_pressed()
	player.look_toward_point(Vector3(0.0, 2.1, -2.5))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/02_calibration_3d.png")

	# 3. Pure Listening Combat with A2/B1 3D models
	srs.sector_filter = -1
	for vid in ["avion", "train", "voiture", "ordinateur", "ambulance", "arbre", "soleil", "globe"]:
		srs.mark_calibrated(vid)
		srs.cards[vid]["tier"] = 2
	_start_combat_wave()
	player.look_toward_point(Vector3(0.0, 2.35, -5.0))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/03_combat_pure_listening.png")

	# 4. A2 3D Spatial & Comparative Modifier Operation ("Tirez sur la cible la plus grande !")
	_clear_drones()
	current_spec = srs.build_modifier_prompt_spec(0)
	_spawn_modifier_drones(current_spec)
	prompt_hint_stage = 1
	_refresh_prompt_hud()
	player.look_toward_point(Vector3(0.0, 2.35, -3.8))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/06_a2_spatial_modifiers.png")

	# 5. B1 Holographic Data-Crystal Grammar Breach ("Il faut absolument que vous [ ___ ] à l'heure pour le train.")
	_clear_drones()
	current_spec = srs.build_grammar_prompt_spec("gram_09")
	_spawn_grammar_drones(current_spec)
	prompt_hint_stage = 2
	_refresh_prompt_hud()
	player.look_toward_point(Vector3(0.0, 2.35, -3.6))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/07_b1_grammar_breach.png")

	# 6. Galerie de Reconnaissance showing Sector 8 (B1 Santé & Société: médicament, ambulance, lettre, journal, cadeau)
	_on_enter_gallery_pressed()
	_load_gallery_sector(7)
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/05_gallery_study.png")

	# 7. Interactive [Tab] SRS Lexicon & Grammar Matrix
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
