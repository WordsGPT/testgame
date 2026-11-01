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
# WARM SUNNY FRENCH COURTYARD & PARK RANGE
# ==============================================================================

func _build_environment_and_lights() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.46, 0.72, 0.90)
	sky_mat.sky_horizon_color = Color(0.98, 0.86, 0.70)
	sky_mat.ground_bottom_color = Color(0.38, 0.48, 0.28)
	sky_mat.ground_horizon_color = Color(0.88, 0.78, 0.62)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.88, 0.76)
	env.ambient_light_energy = 0.46
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	world_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.96, 0.86, 0.72)
	fill.light_energy = 0.24
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-35.0, 150.0, 0.0)
	world_root.add_child(fill)

	_menu_cam = Camera3D.new()
	_menu_cam.fov = 60.0
	world_root.add_child(_menu_cam)


func _make_mat(albedo: Color, rough: float = 0.82, metal: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.12
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


func _add_park_tree(parent: Node3D, pos: Vector3, scale_f: float, trunk_mat: Material, leaf_mat: Material) -> void:
	var t_root := Node3D.new()
	t_root.position = pos
	t_root.scale = Vector3.ONE * scale_f
	parent.add_child(t_root)

	var trunk := MeshInstance3D.new()
	var tcyl := CylinderMesh.new()
	tcyl.top_radius = 0.22
	tcyl.bottom_radius = 0.30
	tcyl.height = 2.4
	trunk.mesh = tcyl
	trunk.material_override = trunk_mat
	trunk.position = Vector3(0, 1.2, 0)
	t_root.add_child(trunk)

	for i in range(3):
		var crown := MeshInstance3D.new()
		var sph := SphereMesh.new()
		var r := 1.45 - float(i) * 0.28
		sph.radius = r
		sph.height = r * 1.65
		crown.mesh = sph
		crown.material_override = leaf_mat
		crown.position = Vector3(0, 2.7 + float(i) * 1.15, 0)
		t_root.add_child(crown)


func _build_arena_geometry() -> void:
	var arena := Node3D.new()
	arena.name = "HolodeckArena"
	world_root.add_child(arena)

	# Warm Mediterranean Sandstone Courtyard + Terracotta & Timber Architecture + Green Park Perimeter
	var grass_mat := _make_mat(Color(0.32, 0.50, 0.24), 0.90, 0.0)
	var stone_court := _make_mat(Color(0.68, 0.59, 0.47), 0.88, 0.0)
	var stone_tile := _make_mat(Color(0.75, 0.67, 0.55), 0.88, 0.0)
	var timber_mat := _make_mat(Color(0.45, 0.27, 0.15), 0.84, 0.0)
	var wall_cream := _make_mat(Color(0.84, 0.76, 0.64), 0.86, 0.0)
	var terra_mat := _make_mat(Color(0.74, 0.33, 0.20), 0.82, 0.0)
	var leaf_mat := _make_mat(Color(0.24, 0.48, 0.22), 0.88, 0.0)
	var leaf_light := _make_mat(Color(0.32, 0.56, 0.26), 0.88, 0.0)

	# Outer grass park & inner warm stone courtyard
	_add_static_box(arena, Vector3(64.0, 0.5, 64.0), Vector3(0, -0.28, 0), Vector3.ZERO, grass_mat, true)
	_add_static_box(arena, Vector3(26.0, 0.10, 28.0), Vector3(0, -0.02, -1.0), Vector3.ZERO, stone_court, true)

	# Alternating warm travertine lane strips (subtle natural stone, zero neon grid!)
	for lx in [-6.0, -2.0, 2.0, 6.0]:
		_add_static_box(arena, Vector3(2.8, 0.03, 14.0), Vector3(lx, 0.02, -1.5), Vector3.ZERO, stone_tile, false)

	# Player timber shooting deck & warm terracotta defense barricade line at z = 3.6
	_add_static_box(arena, Vector3(16.0, 0.18, 5.5), Vector3(0, 0.09, 6.8), Vector3.ZERO, timber_mat, true)
	_add_static_box(arena, Vector3(15.2, 0.52, 0.38), Vector3(0, 0.26, 3.6), Vector3.ZERO, wall_cream, false)
	_add_static_box(arena, Vector3(15.4, 0.12, 0.46), Vector3(0, 0.56, 3.6), Vector3.ZERO, terra_mat, false)

	# Practice Gallery terrace at north end
	_add_static_box(arena, Vector3(20.0, 0.20, 6.0), Vector3(0, 0.10, -13.5), Vector3.ZERO, stone_tile, true)

	# Low warm limestone garden wall & timber pergola posts around courtyard
	var oct_r := 18.5
	for i in range(8):
		var ang_deg := float(i) * 45.0
		var ang_rad := deg_to_rad(ang_deg)
		var wx := sin(ang_rad) * oct_r
		var wz := cos(ang_rad) * oct_r
		_add_static_box(arena, Vector3(15.8, 2.2, 0.75), Vector3(wx, 1.1, wz), Vector3(0, ang_deg, 0), wall_cream, true)
		_add_static_box(arena, Vector3(16.0, 0.24, 0.92), Vector3(wx, 2.30, wz), Vector3(0, ang_deg, 0), terra_mat, false)

		var c_ang := deg_to_rad(ang_deg + 22.5)
		var cx := sin(c_ang) * (oct_r - 0.3)
		var cz := cos(c_ang) * (oct_r - 0.3)
		_add_static_box(arena, Vector3(0.65, 3.4, 0.65), Vector3(cx, 1.7, cz), Vector3(0, ang_deg + 22.5, 0), timber_mat, true)
		_add_static_box(arena, Vector3(0.85, 0.22, 0.85), Vector3(cx, 3.5, cz), Vector3(0, ang_deg + 22.5, 0), terra_mat, false)

	# Lush stylized park trees surrounding the courtyard wall
	var tree_spots := [
		Vector3(-14.5, 0, -16.5), Vector3(-7.5, 0, -19.5), Vector3(0.0, 0, -20.5),
		Vector3(7.5, 0, -19.5), Vector3(14.5, 0, -16.5),
		Vector3(-19.5, 0, -6.0), Vector3(19.5, 0, -6.0),
		Vector3(-19.0, 0, 4.0), Vector3(19.0, 0, 4.0),
	]
	for idx in range(tree_spots.size()):
		var lmat := leaf_mat if (idx % 2 == 0) else leaf_light
		var sc := 1.05 + float(idx % 3) * 0.16
		_add_park_tree(arena, tree_spots[idx], sc, timber_mat, lmat)

	gallery_sign = Label3D.new()
	gallery_sign.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	gallery_sign.text = "PRACTICE GALLERY (STAGES 1–9)  •  SHOOT ANY OBJECT TO HEAR IT"
	gallery_sign.position = Vector3(0, 4.45, -15.5)
	gallery_sign.font_size = 38
	gallery_sign.modulate = Color(0.99, 0.94, 0.78)
	gallery_sign.outline_size = 12
	gallery_sign.outline_modulate = Color(0.18, 0.11, 0.06, 0.95)
	gallery_sign.visible = false
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
	hover_info_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.52))
	hover_info_lbl.add_theme_color_override("font_outline_color", Color(0.14, 0.08, 0.04))
	hover_info_lbl.add_theme_constant_override("outline_size", 6)
	hover_info_lbl.set_anchors_preset(Control.PRESET_CENTER)
	hover_info_lbl.position = Vector2(-280, -212)
	hover_info_lbl.size = Vector2(560, 32)
	hud_root.add_child(hover_info_lbl)

	# 2. Top-Center Compact Arcade Prompt Banner (Warm Espresso & Gold)
	var radio_panel := PanelContainer.new()
	radio_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.15, 0.11, 0.08, 0.94), Color(0.90, 0.68, 0.28, 0.96), 14, 2)
	)
	radio_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	radio_panel.position = Vector2(-360, 10)
	radio_panel.custom_minimum_size = Vector2(720, 106)
	radio_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(radio_panel)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	radio_panel.add_child(rv)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	rv.add_child(top_row)

	speaker_lbl = Label.new()
	speaker_lbl.text = "♪ FRENCH AUDIO"
	speaker_lbl.add_theme_font_size_override("font_size", 13)
	speaker_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.42))
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
		bar.color = Color(0.98, 0.78, 0.28)
		bar.position = Vector2(0, 7)
		bar.size = Vector2(5, 4)
		bar_wrap.add_child(bar)
		wave_bars.append(bar)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	mode_tag_lbl = Label.new()
	mode_tag_lbl.text = "STAGE 1 • LEVEL 1: NEW WORD"
	mode_tag_lbl.add_theme_font_size_override("font_size", 13)
	mode_tag_lbl.add_theme_color_override("font_color", Color(0.68, 0.96, 0.62))
	top_row.add_child(mode_tag_lbl)

	prompt_main_lbl = Label.new()
	prompt_main_lbl.text = "Ready"
	prompt_main_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_main_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_main_lbl.add_theme_font_size_override("font_size", 24)
	prompt_main_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90))
	rv.add_child(prompt_main_lbl)

	prompt_sub_lbl = Label.new()
	prompt_sub_lbl.text = ""
	prompt_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_sub_lbl.add_theme_font_size_override("font_size", 14)
	prompt_sub_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65))
	rv.add_child(prompt_sub_lbl)

	timer_bar = ProgressBar.new()
	timer_bar.show_percentage = false
	timer_bar.min_value = 0.0
	timer_bar.max_value = 100.0
	timer_bar.value = 100.0
	timer_bar.custom_minimum_size = Vector2(0, 7)
	var tb_fill := StyleBoxFlat.new()
	tb_fill.bg_color = Color(0.95, 0.72, 0.24)
	tb_fill.set_corner_radius_all(3)
	timer_bar.add_theme_stylebox_override("fill", tb_fill)
	rv.add_child(timer_bar)

	# 3. Feedback Banner (Only shown when paused on a mistake so text never flies by unread!)
	feedback_banner = PanelContainer.new()
	feedback_banner.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.20, 0.09, 0.07, 0.96), Color(0.96, 0.76, 0.25, 0.96), 10, 2)
	)
	feedback_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	feedback_banner.position = Vector2(-360, 124)
	feedback_banner.custom_minimum_size = Vector2(720, 40)
	feedback_banner.visible = false
	feedback_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(feedback_banner)

	feedback_lbl = Label.new()
	feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_lbl.add_theme_font_size_override("font_size", 15)
	feedback_banner.add_child(feedback_lbl)

	# 4. Top-Left Score, Combo & Defense Barricade Hearts
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.15, 0.11, 0.08, 0.92), Color(0.86, 0.64, 0.26, 0.90), 12, 2)
	)
	stats_panel.position = Vector2(14, 10)
	stats_panel.custom_minimum_size = Vector2(215, 104)
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(stats_panel)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	stats_panel.add_child(sv)

	wave_lbl = Label.new()
	wave_lbl.text = "ROUND 1  •  TARGET 1/6"
	wave_lbl.add_theme_font_size_override("font_size", 14)
	wave_lbl.add_theme_color_override("font_color", Color(0.98, 0.90, 0.72))
	sv.add_child(wave_lbl)

	score_lbl = Label.new()
	score_lbl.text = "SCORE: 0  (STREAK x1)"
	score_lbl.add_theme_font_size_override("font_size", 16)
	score_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	sv.add_child(score_lbl)

	var sh_lbl := Label.new()
	sh_lbl.text = "BARRICADE HEALTH"
	sh_lbl.add_theme_font_size_override("font_size", 11)
	sh_lbl.add_theme_color_override("font_color", Color(0.92, 0.82, 0.68))
	sv.add_child(sh_lbl)

	shield_bar = ProgressBar.new()
	shield_bar.show_percentage = false
	shield_bar.max_value = 100.0
	shield_bar.value = 100.0
	shield_bar.custom_minimum_size = Vector2(0, 10)
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.32, 0.88, 0.46)
	sb_fill.set_corner_radius_all(4)
	shield_bar.add_theme_stylebox_override("fill", sb_fill)
	sv.add_child(shield_bar)

	# 5. Bottom Compact Hotkeys Pill
	var bot_panel := PanelContainer.new()
	bot_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.14, 0.10, 0.07, 0.90), Color(0.76, 0.56, 0.24, 0.80), 10, 1)
	)
	bot_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bot_panel.position = Vector2(-460, -44)
	bot_panel.custom_minimum_size = Vector2(920, 34)
	bot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bot_panel)

	hotkeys_lbl = Label.new()
	hotkeys_lbl.text = "[Click] or [1-4] Shoot   •   [WASD] Move   •   [E] Replay Audio   •   [H] Hint   •   [Tab] Word Book   •   [Esc] Menu"
	hotkeys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkeys_lbl.add_theme_font_size_override("font_size", 13)
	hotkeys_lbl.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82))
	bot_panel.add_child(hotkeys_lbl)

	_build_menu_overlay()
	_build_summary_overlay()
	_build_lexicon_overlay()


func _build_menu_overlay() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.15, 0.11, 0.08, 0.96), Color(0.92, 0.70, 0.28, 0.98), 18, 3)
	)
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.position = Vector2(-280, -185)
	menu_panel.custom_minimum_size = Vector2(560, 370)
	ui_layer.add_child(menu_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	menu_panel.add_child(vb)

	var title := Label.new()
	title.text = "FRANC-TIREUR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36))
	vb.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "French Target Arcade  •  Stop the targets before they reach your barricade!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.96, 0.90, 0.78))
	vb.add_child(subtitle)

	menu_stats_lbl = Label.new()
	menu_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_stats_lbl.add_theme_font_size_override("font_size", 15)
	menu_stats_lbl.add_theme_color_override("font_color", Color(0.52, 0.96, 0.62))
	vb.add_child(menu_stats_lbl)

	var start_btn := Button.new()
	start_btn.text = "▶ PLAY STAGE 1"
	start_btn.custom_minimum_size = Vector2(0, 56)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.pressed.connect(_on_start_mission_pressed)
	vb.add_child(start_btn)

	sector_btn = Button.new()
	sector_btn.custom_minimum_size = Vector2(0, 40)
	sector_btn.add_theme_font_size_override("font_size", 14)
	sector_btn.pressed.connect(_on_cycle_sector)
	vb.add_child(sector_btn)

	# Keep l1_btn hidden or compact in advanced options so menu stays ultra-clean
	l1_btn = Button.new()
	l1_btn.visible = false
	vb.add_child(l1_btn)

	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 10)
	vb.add_child(bot_row)

	var lex_btn := Button.new()
	lex_btn.text = "Word Book (45 Words) [Tab]"
	lex_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lex_btn.custom_minimum_size = Vector2(0, 40)
	lex_btn.add_theme_font_size_override("font_size", 13)
	lex_btn.pressed.connect(func(): _toggle_lexicon(true))
	bot_row.add_child(lex_btn)

	var gal_btn := Button.new()
	gal_btn.text = "Practice Range [G]"
	gal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gal_btn.custom_minimum_size = Vector2(0, 40)
	gal_btn.add_theme_font_size_override("font_size", 13)
	gal_btn.pressed.connect(_on_enter_gallery_pressed)
	bot_row.add_child(gal_btn)

	var rst_btn := Button.new()
	rst_btn.text = "↺ Reset"
	rst_btn.custom_minimum_size = Vector2(90, 40)
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
		_make_panel_style(Color(0.15, 0.11, 0.08, 0.97), Color(0.45, 0.92, 0.52, 0.96), 16, 2)
	)
	summary_panel.set_anchors_preset(Control.PRESET_CENTER)
	summary_panel.position = Vector2(-260, -170)
	summary_panel.custom_minimum_size = Vector2(520, 340)
	summary_panel.visible = false
	ui_layer.add_child(summary_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	summary_panel.add_child(vb)

	var hd := Label.new()
	hd.text = "✓ ROUND COMPLETE!"
	hd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hd.add_theme_font_size_override("font_size", 26)
	hd.add_theme_color_override("font_color", Color(0.52, 0.98, 0.62))
	vb.add_child(hd)

	summary_lbl = Label.new()
	summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_lbl.add_theme_font_size_override("font_size", 16)
	summary_lbl.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	vb.add_child(summary_lbl)

	var next_btn := Button.new()
	next_btn.text = "▶ NEXT ROUND  [Press Space or Click]"
	next_btn.custom_minimum_size = Vector2(0, 52)
	next_btn.add_theme_font_size_override("font_size", 18)
	next_btn.pressed.connect(_continue_to_next_round)
	vb.add_child(next_btn)

	var menu_b := Button.new()
	menu_b.text = "Back to Menu [Esc]"
	menu_b.custom_minimum_size = Vector2(0, 38)
	menu_b.pressed.connect(func():
		audio.play_sfx("click")
		summary_panel.visible = false
		_enter_menu()
	)
	vb.add_child(menu_b)


func _continue_to_next_round() -> void:
	audio.play_sfx("click")
	summary_panel.visible = false
	hud_root.visible = true
	wave_number += 1
	player.visible = true
	player.camera.current = true
	player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_begin_wave()


func _build_lexicon_overlay() -> void:
	lexicon_panel = PanelContainer.new()
	lexicon_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.14, 0.10, 0.07, 0.98), Color(0.90, 0.68, 0.28, 0.96), 14, 2)
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
	lexicon_header_lbl.text = "FRENCH WORD BOOK (45 Words) — Click [♪] to hear native pronunciation"
	lexicon_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lexicon_header_lbl.add_theme_font_size_override("font_size", 15)
	lexicon_header_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))
	top.add_child(lexicon_header_lbl)

	for tab_spec in [
		["ALL", "All (45)"],
		["A1", "Stages 1–4 (20)"],
		["A2", "Stages 5–7 (15)"],
		["B1", "Stages 8–9 (10)"],
	]:
		var tb := Button.new()
		var t_code: String = tab_spec[0]
		tb.text = tab_spec[1]
		tb.custom_minimum_size = Vector2(110, 30)
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

	var tier_names := ["Level 1: New", "Level 2: Read & Shoot", "Level 3: Audio Only", "Level 4: Phrases", "★ Mastered"]
	var tier_cols := [
		Color(0.75, 0.68, 0.58),
		Color(0.98, 0.82, 0.36),
		Color(0.98, 0.64, 0.28),
		Color(0.62, 0.92, 0.48),
		Color(0.36, 0.98, 0.58),
	]

	lexicon_grid.columns = 4
	for item in VocabData.ITEMS:
		if lexicon_tab != "ALL" and lexicon_tab != "GRAM" and not String(item["cefr"]).begins_with(lexicon_tab):
			continue
		var vid: String = item["id"]
		var c: Dictionary = srs.cards[vid]
		var t_idx := clampi(int(c["tier"]), 0, 4)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(228, 102)
		card.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color(0.20, 0.15, 0.11, 0.96), tier_cols[t_idx], 8, 2)
		)
		lexicon_grid.add_child(card)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 3)
		card.add_child(cv)

		var r1 := HBoxContainer.new()
		cv.add_child(r1)
		var w_lbl := Label.new()
		w_lbl.text = "%s  —  %s" % [item["fr_def"], item["en"]]
		w_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		w_lbl.clip_text = true
		w_lbl.add_theme_font_size_override("font_size", 14)
		w_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
		r1.add_child(w_lbl)

		var play_b := Button.new()
		play_b.text = "♪"
		play_b.tooltip_text = "Listen to pronunciation"
		play_b.custom_minimum_size = Vector2(28, 24)
		play_b.add_theme_font_size_override("font_size", 12)
		play_b.pressed.connect(func(): audio.play_voice("word_%s.ogg" % vid))
		r1.add_child(play_b)

		var en_lbl := Label.new()
		en_lbl.text = str(item["ipa"])
		en_lbl.clip_text = true
		en_lbl.add_theme_font_size_override("font_size", 12)
		en_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.46))
		cv.add_child(en_lbl)

		var st_lbl := Label.new()
		var ok_n := int(c["correct"])
		st_lbl.text = "Stage %d  •  %s  (✓%d)" % [int(item["sector"]) + 1, tier_names[t_idx] if bool(c["seen"]) else "Not seen yet", ok_n]
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
		drones_root.visible = false
		pedestals_root.visible = false
		_populate_lexicon_grid()
		player.controls_enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		drones_root.visible = (state in [GameState.CALIBRATION, GameState.COMBAT])
		pedestals_root.visible = (state in [GameState.MENU, GameState.GALLERY])
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
	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	var s_info := VocabData.SECTORS[act_s]
	menu_stats_lbl.text = "Stage %d of 9: %s   •   Words Learned: %d / %d" % [
		act_s + 1, s_info["name_en"], st["seen"], st["total_words"]
	]
	match srs.sector_filter:
		-1:
			sector_btn.text = "◈ Stage Mode: Guided Campaign (Stage %d: %s) — Click to Switch Stage" % [
				act_s + 1, s_info["name_en"]
			]
		-5:
			sector_btn.text = "◈ Special Arcade Mode: 3D Size, Speed & Position Challenges"
		_:
			var sel_info := VocabData.SECTORS[clampi(srs.sector_filter, 0, VocabData.SECTORS.size() - 1)]
			sector_btn.text = "◈ Selected Stage %d: %s (%s) — Click to Switch Stage" % [
				srs.sector_filter + 1, sel_info["name_en"], sel_info["name_fr"]
			]


func _on_cycle_sector() -> void:
	audio.play_sfx("click")
	var order := [-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, -5]
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
	prompt_sub_lbl.text = str(item["tip"])
	timer_bar.value = 100.0
	audio.play_voice("word_%s.ogg" % current_calib_id)


func _start_combat_wave() -> void:
	state = GameState.COMBAT
	prompt_in_wave = 0
	feedback_banner.visible = false
	player.visible = true
	player.camera.current = true
	player.controls_enabled = true
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
	var xs4 := [-6.2, -2.1, 2.1, 6.2]
	for i in range(n):
		var sx: float = xs3[i] if n == 3 else (xs4[i] if i < 4 else (float(i - 2) * 3.5))
		var sz: float = -0.5 if tier == 0 else (-2.6 if (i % 2 == 0) else -3.4)
		var height := 2.15
		var d := TargetDrone.new()
		drones_root.add_child(d)
		var mv := 0.20 if tier == 0 else (0.65 + float(mini(wave_number, 5)) * 0.06)
		d.setup(spawn_ids[i], Vector3(sx, height, sz), player.global_position, mv, 1.15)
		d.set_slot_badge(i + 1)
		if tier == 0:
			d.approach_speed = 0.0
			if spawn_ids[i] == target_id:
				var item := VocabData.get_by_id(target_id)
				d.show_calibration_card(str(item.get("fr_def", target_id)), str(item.get("en", "")), str(item.get("ipa", "")))
		else:
			d.approach_speed = 0.52 + float(mini(wave_number, 6)) * 0.06
			d.defense_z = 3.2
			d.reached_defense_line.connect(_on_drone_reached_defense_line)
		active_drones.append(d)


func _on_drone_reached_defense_line(drone: TargetDrone) -> void:
	if state != GameState.COMBAT or not prompt_active:
		return
	var target_tag := str(current_spec.get("target_id", ""))
	if drone.drone_tag == target_tag:
		prompt_clean_try = false
		combo = 0
		shield_hp = maxf(10.0, shield_hp - 15.0)
		audio.play_sfx("shield_hit", 0.01, -2.0)
		_highlight_true_target(target_tag)
		_play_slow_assist()
		var item := VocabData.get_by_id(target_tag)
		_show_feedback(
			"! Barricade hit! Shoot the gold-highlighted target: %s (%s)" % [
				item.get("fr_def", target_tag), item.get("en", "")
			],
			false
		)
		_update_stats_hud()


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
	var xs4 := [-6.2, -2.1, 2.1, 6.2]
	for i in range(n):
		var sx: float = xs4[i] if i < 4 else (float(i - 2) * 3.5)
		var sz := -2.2 if (i % 2 == 0) else -3.0
		var height := 2.18
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(spawn_ids[i], Vector3(sx, height, sz), player.global_position, 0.55, 1.15)
		d.set_slot_badge(i + 1)
		d.approach_speed = 0.45
		d.defense_z = 3.2
		d.reached_defense_line.connect(_on_drone_reached_defense_line)
		active_drones.append(d)


func _spawn_grammar_drones(spec: Dictionary) -> void:
	var opts: Array = spec["options"].duplicate()
	opts.shuffle()
	var xs := [-6.2, -2.1, 2.1, 6.2]
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
	var xs4 := [-6.2, -2.1, 2.1, 6.2]
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
			d.setup(vid, Vector3(xs3[i], 2.20, -0.5), player.global_position, 0.15, 1.15, "MOD_TARGET" if is_t else ("DECOY_%d" % i))
			d.set_slot_badge(i + 1)
			d.custom_ok_label = "+150  ✓ Au milieu (In the middle)!"
			d.custom_wrong_label = "✗ Shoot the MIDDLE one!"
			active_drones.append(d)
		return

	for i in range(4):
		var is_t := (i == target_slot)
		var tag := "MOD_TARGET" if is_t else ("DECOY_%d" % i)
		var pos := Vector3(xs4[i], 2.20, -0.5)
		var mv := 0.45
		var sc := 1.0
		var ok_lbl := "+150  ✓ Correct!"
		var err_lbl := "✗ Wrong target!"

		match layout:
			"scale_max":
				sc = 1.65 if is_t else (0.64 + float(i) * 0.08)
				mv = 0.35
				ok_lbl = "+150  ✓ La plus grande (Biggest)!"
				err_lbl = "✗ Shoot the BIGGEST one!"
			"scale_min":
				sc = 0.56 if is_t else (1.18 + float(i) * 0.10)
				mv = 0.35
				ok_lbl = "+150  ✓ Le plus petit (Smallest)!"
				err_lbl = "✗ Shoot the SMALLEST one!"
			"speed_max":
				mv = 2.60 if is_t else 0.18
				ok_lbl = "+150  ✓ Le plus vite (Fastest)!"
				err_lbl = "✗ Shoot the FASTEST one!"
			"speed_zero":
				mv = 0.0 if is_t else 1.65
				ok_lbl = "+150  ✓ Immobile (Standing still)!"
				err_lbl = "✗ Shoot the one STANDING STILL!"
			"height_max":
				pos.y = 3.85 if is_t else 1.50
				mv = 0.30
				ok_lbl = "+150  ✓ Le plus haut (Highest)!"
				err_lbl = "✗ Shoot the HIGHEST one!"
			"height_min":
				pos.y = 1.25 if is_t else 3.55
				mv = 0.30
				ok_lbl = "+150  ✓ Le plus bas (Lowest)!"
				err_lbl = "✗ Shoot the LOWEST one!"
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
				ok_lbl = "+150  ✓ Le plus proche (Closest)!"
				err_lbl = "✗ Shoot the CLOSEST one!"
			"dist_max":
				pos.z = -3.8 if is_t else 1.8
				mv = 0.30
				ok_lbl = "+150  ✓ La plus éloignée (Furthest)!"
				err_lbl = "✗ Shoot the FURTHEST one!"
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
				ok_lbl = "+150  ✓ Grand ET immobile!"
				err_lbl = "✗ Must be BOTH big and still!"

		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(vid, pos, player.global_position, mv, sc, tag)
		d.set_slot_badge(i + 1)
		d.custom_ok_label = ok_lbl
		d.custom_wrong_label = err_lbl
		active_drones.append(d)


func _refresh_prompt_hud() -> void:
	speaker_lbl.text = "♪ FRENCH AUDIO"
	mode_tag_lbl.text = str(current_spec["mode_tag"])

	var ptype := str(current_spec.get("prompt_type", "VOCAB"))
	var show_fr := bool(current_spec["show_fr_text"]) or (prompt_hint_stage >= 1)
	var show_en := bool(current_spec["show_en_text"]) or (prompt_hint_stage >= 2)

	if show_fr:
		prompt_main_lbl.text = "♪  %s" % str(current_spec["prompt_fr"])
	else:
		if ptype == "MODIFIER":
			prompt_main_lbl.text = "◉ LISTEN: Size / Speed Challenge!  ([H] Show Text • [E] Replay)"
		elif int(current_spec["tier"]) >= 3:
			prompt_main_lbl.text = "◉ LISTEN: French Clue!  ([H] Show Text • [E] Replay)"
		else:
			prompt_main_lbl.text = "◉ LISTEN & SHOOT!   ([E] Replay Audio  •  [H] Show Word)"

	if show_en:
		prompt_sub_lbl.text = str(current_spec["sub_en"])
	else:
		prompt_sub_lbl.text = "Stop the matching 3D target before it reaches your barricade!   ([H] Hint  •  [R] Slow Audio)"


# ==============================================================================
# SHOOTING, CONTRASTIVE FEEDBACK & INPUTS
# ==============================================================================

func _on_player_hovered(entity: Node) -> void:
	if entity is PedestalStation:
		var p := entity as PedestalStation
		var item := VocabData.get_by_id(p.vocab_id)
		_reticle_col = Color(0.45, 0.98, 0.58)
		hover_info_lbl.text = "[Click] Hear: %s (%s)" % [item.get("fr_def", ""), item.get("en", "")]
	elif entity is TargetDrone:
		_reticle_col = Color(1.0, 0.88, 0.24)
		var td := entity as TargetDrone
		if td.is_grammar_crystal:
			hover_info_lbl.text = "Option [%d]: %s" % [td.slot_number, td.grammar_option]
		elif state == GameState.CALIBRATION:
			var item := VocabData.get_by_id(td.vocab_id)
			hover_info_lbl.text = "%s = %s" % [item.get("fr_def", ""), item.get("en", "")]
		else:
			hover_info_lbl.text = ""
	else:
		_reticle_col = Color(0.98, 0.90, 0.65, 0.92)
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
		prompt_main_lbl.text = "♪ %s  =  %s" % [item["fr_def"], item["en"]]
		prompt_sub_lbl.text = str(item["tip"])
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
		transition_delay = 0.60
		return

	if state == GameState.COMBAT and prompt_active:
		var ptype := str(current_spec.get("prompt_type", "VOCAB"))
		var target_tag := str(current_spec["target_id"])

		if drone.drone_tag == target_tag:
			prompt_active = false
			feedback_banner.visible = false
			audio.play_sfx("hit_ok", 0.02, -1.5)
			var pts := 100
			var fast_bonus := (drone.global_position.z < 0.0 and int(current_spec.get("tier", 0)) >= 1)
			if prompt_clean_try:
				combo += 1
				wave_hits_clean += 1
				pts = (100 + combo * 25) + (50 if fast_bonus else 0)
			else:
				pts = 75
			score += pts
			if fast_bonus and prompt_clean_try and drone.custom_ok_label == "":
				var f_item := VocabData.get_by_id(target_tag)
				drone.custom_ok_label = "+%d FAST! ✓ %s (%s)" % [pts, f_item.get("fr_def", target_tag), f_item.get("en", "")]
			drone.explode_success(world_root, pts)
			active_drones.erase(drone)

			if ptype == "GRAMMAR":
				var gid := str(current_spec["grammar_id"])
				srs.record_grammar_result(gid, prompt_clean_try, prompt_used_assist)
				prompt_main_lbl.text = "✓ %s" % str(current_spec["sentence_full"])
				prompt_sub_lbl.text = str(current_spec["en"])
			elif ptype == "MODIFIER":
				srs.global_step += 1
				srs.save_progress()
				prompt_main_lbl.text = "✓ %s" % str(current_spec["prompt_fr"])
				prompt_sub_lbl.text = str(current_spec["rule"])
			else:
				srs.record_result(target_tag, prompt_clean_try, prompt_used_assist, prompt_wrong_ids)
				var t_item := VocabData.get_by_id(target_tag)
				prompt_main_lbl.text = "✓ %s  =  %s" % [t_item["fr_def"], t_item["en"]]
				prompt_sub_lbl.text = str(t_item["tip"])

			_update_stats_hud()
			transition_delay = 1.05
		else:
			# Wrong target shot: PAUSE all approaching drones & timer so the player can read and shoot the gold target at their own pace!
			prompt_clean_try = false
			combo = 0
			shield_hp = maxf(10.0, shield_hp - 12.0)
			audio.play_sfx("hit_err", 0.02, -1.0)
			audio.play_sfx("shield_hit", 0.01, -3.0)
			drone.flash_wrong_hit()

			if ptype == "GRAMMAR":
				_highlight_true_target(target_tag)
				_show_feedback(
					"✗ Not « %s »! Shoot the gold-highlighted option « %s » to continue" % [
						drone.grammar_option, target_tag
					],
					false
				)
			elif ptype == "MODIFIER":
				_highlight_true_target("MOD_TARGET")
				_show_feedback(
					"✗ %s  →  Shoot the gold-highlighted target (%s) to continue!" % [
						drone.custom_wrong_label, current_spec["prompt_fr"]
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
					"✗ That was %s (%s).  →  ★ Shoot the GOLD target: %s = %s" % [
						hit_item["fr_def"], hit_item["en"], true_item["fr_def"], true_item["en"]
					],
					false
				)
			_update_stats_hud()


func _highlight_true_target(target_tag: String) -> void:
	var item := VocabData.get_by_id(target_tag)
	for d in active_drones:
		if is_instance_valid(d) and not d.is_destroyed:
			d.approach_paused = true
			if d.drone_tag == target_tag:
				if not item.is_empty():
					d.show_repair_target_card(str(item["fr_def"]), str(item["en"]))
				else:
					d.set_beacon(true, Color(1.0, 0.85, 0.15))


func _play_slow_assist() -> void:
	prompt_used_assist = true
	var ptype := str(current_spec.get("prompt_type", "VOCAB"))
	var slow_f := str(current_spec.get("slow_audio_file", ""))
	if slow_f != "":
		audio.play_voice(slow_f)
	else:
		audio.play_voice(str(current_spec.get("audio_file", "")), 0.82)

	if ptype == "VOCAB":
		var tid := str(current_spec.get("target_id", ""))
		var item := VocabData.get_by_id(tid)
		if not item.is_empty():
			prompt_main_lbl.text = "♪ %s  =  %s" % [item["fr_def"], item["en"]]
			prompt_sub_lbl.text = str(item["tip"])
	elif ptype == "MODIFIER":
		prompt_main_lbl.text = "♪ %s" % str(current_spec["prompt_fr"])
		prompt_sub_lbl.text = str(current_spec["sub_en"])


func _show_feedback(msg: String, is_ok: bool) -> void:
	feedback_banner.visible = true
	var border_col := Color(0.42, 0.96, 0.56, 0.95) if is_ok else Color(0.98, 0.76, 0.24, 0.96)
	var bg_col := Color(0.10, 0.20, 0.12, 0.96) if is_ok else Color(0.24, 0.11, 0.08, 0.96)
	feedback_banner.add_theme_stylebox_override("panel", _make_panel_style(bg_col, border_col, 10, 2))
	feedback_lbl.text = msg
	feedback_lbl.add_theme_color_override("font_color", Color(0.75, 1.0, 0.82) if is_ok else Color(1.0, 0.92, 0.68))


func _update_stats_hud() -> void:
	wave_lbl.text = "ROUND %d  •  TARGET %d/%d" % [wave_number, prompt_in_wave, PROMPTS_PER_WAVE]
	score_lbl.text = "SCORE: %d  (STREAK x%d)" % [score, maxi(1, combo)]
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
	var act_s := srs.get_active_campaign_sector()
	var s_info := VocabData.SECTORS[act_s]
	summary_lbl.text = (
		"Round %d Complete!   •   First-Try Hits: %d / %d\n"
		+ "Score: %d   •   Best Streak: x%d\n\n"
		+ "Current Stage: Stage %d/9 (%s)\n"
		+ "Words Learned: %d / %d   •   Audio-Ready: %d"
	) % [
		wave_number, wave_hits_clean, PROMPTS_PER_WAVE,
		score, maxi(1, combo),
		act_s + 1, s_info["name_en"],
		st["seen"], st["total_words"], st["listening_ready"]
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
		_menu_orbit_angle += delta * 0.16
		_menu_cam.global_position = Vector3(sin(_menu_orbit_angle) * 13.5, 4.6, cos(_menu_orbit_angle) * 13.5 - 2.0)
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

	# Only drain the timer on Level 2+ while no mistake repair is paused!
	if state == GameState.COMBAT and prompt_active and prompt_clean_try and int(current_spec.get("tier", 0)) >= 1:
		prompt_timer -= delta
		timer_bar.value = clampf((prompt_timer / PROMPT_TIME_LIMIT) * 100.0, 0.0, 100.0)
		if prompt_timer <= 0.0:
			prompt_clean_try = false
			combo = 0
			shield_hp = maxf(10.0, shield_hp - 10.0)
			var target_tag := str(current_spec["target_id"])
			_highlight_true_target(target_tag)
			_play_slow_assist()
			_show_feedback("! Time up — shoot the gold-highlighted target to continue!", false)
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
	assert(test_srs.get_active_campaign_sector() == 0, "New campaign should start at Stage 1 (Sector 0)")
	test_srs.mark_calibrated("pomme")
	var r1 := test_srs.record_result("pomme", true, false, [])
	assert(int(r1["new_tier"]) == 1, "Clean hit should advance Level 1 -> Level 2")
	var r2 := test_srs.record_result("pomme", true, false, [])
	assert(int(r2["new_tier"]) == 2, "Clean hit should advance Level 2 -> Level 3")
	var r_err := test_srs.record_result("pomme", false, false, ["fromage"])
	assert(int(r_err["new_tier"]) == 1, "Mistake should drop Level 3 -> Level 2 and log confusion")
	print("VERIFY_OK: French Target Arcade SRS & Stage Progression verified.")

	srs.reset_progress()
	srs.sector_filter = -1
	_refresh_menu_labels()
	for i in range(4):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/01_menu.png")

	# 2. Level 1 (Tier 0): New Word Spotlight in Stage 1 showcasing the matte Apple (`pomme.blend`) & Heart (`coeur.blend`)
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
		d.setup(demo_ids[i], Vector3(demo_xs[i], 2.15, -0.5), player.global_position, 0.0, 1.18)
		d.set_slot_badge(i + 1)
		if demo_ids[i] == "pomme":
			d.show_calibration_card("la pomme", "the apple")
		active_drones.append(d)
	_refresh_prompt_hud()
	player.look_toward_point(Vector3(0.0, 2.15, -0.5))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/02_calibration_3d.png")

	# 3. Level 3 (Tier 2): Pure Listening Arcade Wave with approaching targets
	srs.sector_filter = 4
	for vid in ["avion", "train", "voiture", "velo", "valise"]:
		srs.mark_calibrated(vid)
		srs.cards[vid]["tier"] = 2
	_clear_drones()
	current_spec = srs.build_prompt_spec("avion")
	_spawn_vocab_drones(current_spec)
	for d in active_drones:
		d.approach_paused = true
		d._anchor_pos.z = -1.2
	_refresh_prompt_hud()
	player.look_toward_point(Vector3(0.0, 2.15, -1.2))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/03_combat_pure_listening.png")

	# 4. 3D Size, Speed & Position Challenge ("la plus grande !")
	_clear_drones()
	current_spec = srs.build_modifier_prompt_spec(0)
	_spawn_modifier_drones(current_spec)
	prompt_hint_stage = 2
	_refresh_prompt_hud()
	player.look_toward_point(Vector3(0.0, 2.15, -0.5))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/06_a2_spatial_modifiers.png")

	# 5. Pause-and-Learn Mistake Repair Spotlight (shows how wrong shots freeze the wave & highlight the right object)
	_clear_drones()
	srs.sector_filter = 0
	current_spec = srs.build_prompt_spec("pain")
	var err_ids := ["pomme", "pain", "bouteille"]
	for i in range(3):
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(err_ids[i], Vector3(demo_xs[i], 2.15, -0.6), player.global_position, 0.0, 1.18)
		d.set_slot_badge(i + 1)
		active_drones.append(d)
	_refresh_prompt_hud()
	active_drones[0].flash_wrong_hit()
	_highlight_true_target("pain")
	_play_slow_assist()
	_show_feedback("✗ That was la pomme (the apple).  →  ★ Shoot the GOLD target: le pain = the bread", false)
	player.look_toward_point(Vector3(0.0, 2.15, -0.6))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/07_b1_grammar_breach.png")

	# 6. 3D Practice Gallery showing Stage 4 (fleur, coeur, poisson, etoile, fusee)
	feedback_banner.visible = false
	_on_enter_gallery_pressed()
	_load_gallery_sector(3)
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/05_gallery_study.png")

	# 7. Interactive [Tab] Word Book (Stages 1–4)
	lexicon_tab = "A1"
	_toggle_lexicon(true)
	for i in range(4):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/04_srs_lexicon.png")

	# 8. Interactive [Tab] Word Book (Stages 5–7)
	lexicon_tab = "A2"
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
