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
var projectiles_root: Node3D
var pickups_root: Node3D
var map_props_root: Node3D
var _display_tables_root: Node3D
var direction_pads_root: Node3D
var chloe_bot: Node3D
var _stats_panel: PanelContainer
var map_banner_lbl: Label3D
var gallery_sign: Label3D
var pedestals: Array[PedestalStation] = []
var active_drones: Array[TargetDrone] = []
var _projectiles: Array[Dictionary] = []
var _pickups: Array[Dictionary] = []
var _damage_flash: ColorRect
var _damage_flash_timer: float = 0.0
var _portal_cooldown: float = 0.0
var _active_map_idx: int = 0
var _dir_steps: Array = []
var _dir_step_idx: int = 0
var _dir_pad_nodes: Dictionary = {}

# Dynamic Map Theme Materials
var _sky_mat: ProceduralSkyMaterial
var _mat_floor: StandardMaterial3D
var _mat_tile: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_trim: StandardMaterial3D
var _mat_pillar: StandardMaterial3D

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
var radio_panel: PanelContainer
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
var companion_panel: PanelContainer
var companion_lbl: Label
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

	projectiles_root = Node3D.new()
	projectiles_root.name = "ProjectilesRoot"
	world_root.add_child(projectiles_root)

	pickups_root = Node3D.new()
	pickups_root.name = "PickupsRoot"
	world_root.add_child(pickups_root)

	map_props_root = Node3D.new()
	map_props_root.name = "MapPropsRoot"
	world_root.add_child(map_props_root)

	direction_pads_root = Node3D.new()
	direction_pads_root.name = "DirectionPadsRoot"
	direction_pads_root.visible = false
	world_root.add_child(direction_pads_root)

	_build_environment_and_lights()
	_build_arena_geometry()
	_build_direction_pads()
	_spawn_chloe_bot()
	_spawn_player()
	_spawn_gallery_pedestals()
	_build_ui()

	_enter_menu()

	var user_args := OS.get_cmdline_user_args()
	if user_args.has("--verify-screenshots"):
		_run_automated_verification()


# ==============================================================================
# 9 DYNAMIC 3D MAPS, DIRECTIONAL PADS & FRIENDLY COMPANION CHLOÉ
# ==============================================================================

func _build_environment_and_lights() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_top_color = Color(0.46, 0.72, 0.90)
	_sky_mat.sky_horizon_color = Color(0.98, 0.86, 0.70)
	_sky_mat.ground_bottom_color = Color(0.38, 0.48, 0.28)
	_sky_mat.ground_horizon_color = Color(0.88, 0.78, 0.62)
	sky.sky_material = _sky_mat
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
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	world_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.96, 0.86, 0.72)
	fill.light_energy = 0.24
	fill.shadow_enabled = false
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
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


func _add_cyl(parent: Node3D, top_r: float, bot_r: float, h: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _add_bistro_table(parent: Node3D, pos: Vector3, top_mat: Material, leg_mat: Material, rim_mat: Material) -> void:
	var t := Node3D.new()
	t.position = pos
	parent.add_child(t)
	_add_cyl(t, 0.34, 0.42, 0.08, Vector3(0, 0.04, 0), leg_mat)
	_add_cyl(t, 0.07, 0.09, 1.12, Vector3(0, 0.60, 0), leg_mat)
	_add_cyl(t, 0.78, 0.76, 0.07, Vector3(0, 1.18, 0), top_mat)
	_add_cyl(t, 0.80, 0.80, 0.04, Vector3(0, 1.18, 0), rim_mat)


func _add_streetlamp(parent: Node3D, pos: Vector3, iron_mat: Material, glow_mat: Material) -> void:
	var l := Node3D.new()
	l.position = pos
	parent.add_child(l)
	_add_cyl(l, 0.16, 0.24, 0.45, Vector3(0, 0.22, 0), iron_mat)
	_add_cyl(l, 0.06, 0.09, 3.6, Vector3(0, 2.0, 0), iron_mat)
	var globe := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	globe.mesh = sm
	globe.material_override = glow_mat
	globe.position = Vector3(0, 3.95, 0)
	l.add_child(globe)


func _build_arena_geometry() -> void:
	var arena := Node3D.new()
	arena.name = "HolodeckArena"
	world_root.add_child(arena)

	_mat_floor = _make_mat(Color(0.52, 0.48, 0.44), 0.88, 0.0)
	_mat_tile = _make_mat(Color(0.84, 0.78, 0.68), 0.86, 0.0)
	_mat_pillar = _make_mat(Color(0.42, 0.26, 0.16), 0.84, 0.0)
	_mat_wall = _make_mat(Color(0.92, 0.86, 0.76), 0.86, 0.0)
	_mat_trim = _make_mat(Color(0.78, 0.20, 0.16), 0.82, 0.0)

	# Base physics floor so the player can walk smoothly anywhere
	_add_static_box(arena, Vector3(64.0, 0.5, 64.0), Vector3(0, -0.26, 0), Vector3.ZERO, _mat_floor, true)

	# Invisible perimeter physics bounds so the player never walks off the edge
	_add_static_box(arena, Vector3(24.0, 4.0, 0.6), Vector3(0, 2.0, 10.5), Vector3.ZERO, _mat_wall, true)
	for sx in [-10.5, 10.5]:
		_add_static_box(arena, Vector3(0.6, 4.0, 28.0), Vector3(sx, 2.0, -2.0), Vector3.ZERO, _mat_wall, true)

	# Practice Gallery terrace at north end (only visible in Gallery state)
	_add_static_box(arena, Vector3(20.0, 0.12, 6.0), Vector3(0, 0.06, -13.5), Vector3.ZERO, _mat_tile, true)

	gallery_sign = Label3D.new()
	gallery_sign.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	gallery_sign.text = "PRACTICE GALLERY (MAPS 1–9)  •  CLICK ANY OBJECT TO HEAR ITS PHRASE"
	gallery_sign.position = Vector3(0, 4.25, -15.2)
	gallery_sign.font_size = 36
	gallery_sign.modulate = Color(0.99, 0.94, 0.78)
	gallery_sign.outline_size = 12
	gallery_sign.outline_modulate = Color(0.18, 0.11, 0.06, 0.95)
	gallery_sign.visible = false
	arena.add_child(gallery_sign)

	_apply_map_theme(0)


func _apply_map_theme(map_idx: int) -> void:
	_active_map_idx = clampi(map_idx, 0, VocabData.SECTORS.size() - 1)
	var s_info: Dictionary = VocabData.SECTORS[_active_map_idx]
	if _mat_floor:
		_mat_floor.albedo_color = s_info["floor_col"]
	if _mat_tile:
		_mat_tile.albedo_color = s_info["tile_col"]
	if _mat_wall:
		_mat_wall.albedo_color = s_info["wall_col"]
	if _mat_trim:
		_mat_trim.albedo_color = s_info["trim_col"]
	if _mat_pillar:
		_mat_pillar.albedo_color = s_info["pillar_col"]
	if _sky_mat:
		_sky_mat.sky_top_color = s_info["sky_top"]
		_sky_mat.sky_horizon_color = s_info["sky_horizon"]

	if not map_props_root:
		return
	for ch in map_props_root.get_children():
		ch.queue_free()

	_display_tables_root = Node3D.new()
	_display_tables_root.name = "DisplayTablesRoot"
	map_props_root.add_child(_display_tables_root)

	var iron_mat := _make_mat(Color(0.14, 0.16, 0.19), 0.65, 0.35)
	var brass_mat := _make_mat(Color(0.86, 0.68, 0.26), 0.45, 0.35)
	var warm_glow := _make_mat(Color(1.0, 0.88, 0.56), 0.2, 0.0, true)
	var glass_blue := _make_mat(Color(0.56, 0.78, 0.94), 0.25, 0.1)
	var wood_dark := _make_mat(Color(0.36, 0.22, 0.13), 0.78)
	var wood_warm := _make_mat(Color(0.62, 0.40, 0.22), 0.78)
	var marble_top := _make_mat(Color(0.95, 0.92, 0.86), 0.55)

	# Build a completely distinct, recognizable 3D place for each map stage!
	if _active_map_idx in [0, 8]:
		# === LOCATION: AU CAFÉ PARISIEN (Haussmann Facade, Striped Café Awning, Bistro Terrace) ===
		var cobble_mat := _make_mat(Color(0.46, 0.43, 0.40), 0.90)
		var terrace_mat := _make_mat(Color(0.84, 0.77, 0.66), 0.85)
		var stone_facade := _make_mat(Color(0.93, 0.87, 0.76), 0.84)
		var burgundy_mat := _make_mat(Color(0.50, 0.13, 0.15), 0.75)
		var red_stripe := _make_mat(Color(0.80, 0.18, 0.16), 0.78)
		var cream_stripe := _make_mat(Color(0.97, 0.94, 0.86), 0.78)

		_add_static_box(map_props_root, Vector3(24.0, 0.04, 18.0), Vector3(0, 0.01, 1.0), Vector3.ZERO, cobble_mat, false)
		_add_static_box(map_props_root, Vector3(17.5, 0.10, 6.2), Vector3(0, 0.05, -2.5), Vector3.ZERO, terrace_mat, false)

		# Haussmann building facade at z = -5.8
		_add_static_box(map_props_root, Vector3(22.0, 8.8, 0.7), Vector3(0, 4.4, -5.8), Vector3.ZERO, stone_facade, true)
		_add_static_box(map_props_root, Vector3(22.2, 3.8, 0.78), Vector3(0, 1.9, -5.75), Vector3.ZERO, burgundy_mat, false)
		_add_static_box(map_props_root, Vector3(22.4, 0.26, 0.92), Vector3(0, 3.9, -5.65), Vector3.ZERO, brass_mat, false)

		# 3 Warm Illuminated Café Windows on the ground floor + 3 Upper Apartment Windows with Balconies
		for wx in [-5.2, 0.0, 5.2]:
			_add_static_box(map_props_root, Vector3(2.8, 2.3, 0.84), Vector3(wx, 2.1, -5.72), Vector3.ZERO, wood_dark, false)
			_add_static_box(map_props_root, Vector3(2.5, 2.0, 0.88), Vector3(wx, 2.1, -5.70), Vector3.ZERO, warm_glow, false)
			# Upper floor window + wrought-iron balcony
			_add_static_box(map_props_root, Vector3(2.2, 2.4, 0.80), Vector3(wx, 6.0, -5.72), Vector3.ZERO, wood_dark, false)
			_add_static_box(map_props_root, Vector3(1.9, 2.1, 0.84), Vector3(wx, 6.0, -5.70), Vector3.ZERO, glass_blue, false)
			_add_static_box(map_props_root, Vector3(2.6, 0.75, 0.45), Vector3(wx, 5.05, -5.35), Vector3.ZERO, iron_mat, false)

		# Iconic Sloped Red-and-Cream Striped Parisian Café Awning
		for s_i in range(11):
			var sx := -7.5 + float(s_i) * 1.5
			var smat := red_stripe if (s_i % 2 == 0) else cream_stripe
			_add_static_box(map_props_root, Vector3(1.48, 0.14, 2.9), Vector3(sx, 3.55, -4.3), Vector3(18.0, 0, 0), smat, false)

		# Parisian Streetlamps & Side Planters
		for lx in [-7.2, 7.2]:
			_add_streetlamp(map_props_root, Vector3(lx, 0.0, -1.8), iron_mat, warm_glow)

		# 3 Round Parisian Bistro Tables where the 3 café items sit!
		for tx in [-4.2, 0.0, 4.2]:
			_add_bistro_table(_display_tables_root, Vector3(tx, 0.0, -0.6), marble_top, iron_mat, brass_mat)

	elif _active_map_idx == 1:
		# === LOCATION: LA MAISON (Cozy Wood-Floored Parisian Apartment Interior) ===
		var parquet_mat := _make_mat(Color(0.66, 0.45, 0.28), 0.78)
		var rug_mat := _make_mat(Color(0.72, 0.28, 0.22), 0.88)
		var rug_border := _make_mat(Color(0.92, 0.84, 0.68), 0.86)
		var apt_wall := _make_mat(Color(0.95, 0.90, 0.82), 0.85)
		var marble_fp := _make_mat(Color(0.94, 0.92, 0.88), 0.60)

		_add_static_box(map_props_root, Vector3(20.0, 0.05, 16.0), Vector3(0, 0.02, 1.0), Vector3.ZERO, parquet_mat, false)
		_add_static_box(map_props_root, Vector3(9.6, 0.06, 5.6), Vector3(0, 0.03, 1.8), Vector3.ZERO, rug_border, false)
		_add_static_box(map_props_root, Vector3(8.8, 0.07, 4.8), Vector3(0, 0.035, 1.8), Vector3.ZERO, rug_mat, false)

		# Back & Side Apartment Walls + Wainscoting
		_add_static_box(map_props_root, Vector3(19.6, 7.2, 0.6), Vector3(0, 3.6, -5.6), Vector3.ZERO, apt_wall, true)
		_add_static_box(map_props_root, Vector3(19.6, 1.3, 0.68), Vector3(0, 0.65, -5.56), Vector3.ZERO, wood_dark, false)
		for swx in [-9.4, 9.4]:
			_add_static_box(map_props_root, Vector3(0.6, 7.2, 16.0), Vector3(swx, 3.6, 1.5), Vector3.ZERO, apt_wall, false)
			_add_static_box(map_props_root, Vector3(0.68, 1.3, 16.0), Vector3(swx, 0.65, 1.5), Vector3.ZERO, wood_dark, false)

		# Center Marble Fireplace Mantel & Framed Painting above it
		_add_static_box(map_props_root, Vector3(2.8, 2.2, 0.85), Vector3(0, 1.1, -5.2), Vector3.ZERO, marble_fp, false)
		_add_static_box(map_props_root, Vector3(1.6, 1.4, 0.90), Vector3(0, 0.7, -5.18), Vector3.ZERO, warm_glow, false)
		_add_static_box(map_props_root, Vector3(2.4, 1.5, 0.14), Vector3(0, 4.1, -5.25), Vector3.ZERO, brass_mat, false)
		_add_static_box(map_props_root, Vector3(2.1, 1.2, 0.18), Vector3(0, 4.1, -5.23), Vector3.ZERO, glass_blue, false)

		# Tall French Windows on Left & Right + Wooden Bookshelves
		for wx in [-4.5, 4.5]:
			_add_static_box(map_props_root, Vector3(2.4, 3.4, 0.70), Vector3(wx, 3.1, -5.50), Vector3.ZERO, marble_fp, false)
			_add_static_box(map_props_root, Vector3(2.0, 3.0, 0.74), Vector3(wx, 3.1, -5.48), Vector3.ZERO, glass_blue, false)
		for bx in [-7.6, 7.6]:
			_add_static_box(map_props_root, Vector3(1.8, 3.8, 0.75), Vector3(bx, 1.9, -5.1), Vector3.ZERO, wood_dark, false)

		# 3 Warm Walnut Apartment Side Tables for the 3 targets
		for tx in [-4.2, 0.0, 4.2]:
			_add_bistro_table(_display_tables_root, Vector3(tx, 0.0, -0.6), wood_warm, wood_dark, brass_mat)

	elif _active_map_idx in [2, 5]:
		# === LOCATION: LE MARCHÉ & CENTRE-VILLE (Parisian Boutiques, Pharmacy Cross & Market Stalls) ===
		var square_mat := _make_mat(Color(0.54, 0.52, 0.49), 0.88)
		var shop_wall := _make_mat(Color(0.92, 0.88, 0.80), 0.85)
		var navy_shop := _make_mat(Color(0.16, 0.28, 0.48), 0.75)
		var green_shop := _make_mat(Color(0.16, 0.48, 0.34), 0.75)
		var ochre_shop := _make_mat(Color(0.76, 0.48, 0.18), 0.75)
		var neon_green := _make_mat(Color(0.20, 0.95, 0.48), 0.2, 0.0, true)

		_add_static_box(map_props_root, Vector3(24.0, 0.05, 18.0), Vector3(0, 0.02, 1.0), Vector3.ZERO, square_mat, false)
		_add_static_box(map_props_root, Vector3(22.0, 8.2, 0.7), Vector3(0, 4.1, -5.8), Vector3.ZERO, shop_wall, true)

		# 3 Distinct Storefronts: Left Boutique, Center Pharmacie, Right Boulangerie
		_add_static_box(map_props_root, Vector3(6.6, 3.8, 0.82), Vector3(-6.8, 1.9, -5.72), Vector3.ZERO, navy_shop, false)
		_add_static_box(map_props_root, Vector3(6.6, 3.8, 0.82), Vector3(0.0, 1.9, -5.72), Vector3.ZERO, green_shop, false)
		_add_static_box(map_props_root, Vector3(6.6, 3.8, 0.82), Vector3(6.8, 1.9, -5.72), Vector3.ZERO, ochre_shop, false)

		for sx in [-6.8, 0.0, 6.8]:
			_add_static_box(map_props_root, Vector3(4.6, 2.2, 0.88), Vector3(sx, 1.8, -5.68), Vector3.ZERO, warm_glow, false)
			_add_static_box(map_props_root, Vector3(5.8, 0.18, 2.2), Vector3(sx, 3.45, -4.6), Vector3(14.0, 0, 0), brass_mat, false)

		# Glowing Green French Pharmacy Cross on the building
		_add_static_box(map_props_root, Vector3(1.1, 0.34, 0.20), Vector3(0.0, 4.55, -5.35), Vector3.ZERO, neon_green, false)
		_add_static_box(map_props_root, Vector3(0.34, 1.1, 0.20), Vector3(0.0, 4.55, -5.35), Vector3.ZERO, neon_green, false)

		for tx in [-4.2, 0.0, 4.2]:
			_add_bistro_table(_display_tables_root, Vector3(tx, 0.0, -0.6), wood_warm, iron_mat, brass_mat)

	elif _active_map_idx in [3, 7]:
		# === LOCATION: LA GARE DU NORD (Slate Platform, Yellow Safety Line, Steel Hall & TGV Train!) ===
		var platform_mat := _make_mat(Color(0.32, 0.35, 0.40), 0.82)
		var safety_yellow := _make_mat(Color(0.96, 0.78, 0.14), 0.65)
		var steel_mat := _make_mat(Color(0.22, 0.28, 0.36), 0.55, 0.40)
		var tgv_silver := _make_mat(Color(0.84, 0.87, 0.92), 0.40, 0.35)
		var tgv_blue := _make_mat(Color(0.14, 0.36, 0.76), 0.45, 0.25)
		var tgv_win := _make_mat(Color(0.12, 0.16, 0.22), 0.25, 0.50)

		_add_static_box(map_props_root, Vector3(24.0, 0.06, 18.0), Vector3(0, 0.03, 1.0), Vector3.ZERO, platform_mat, false)
		_add_static_box(map_props_root, Vector3(20.0, 0.08, 0.32), Vector3(0, 0.04, -2.8), Vector3.ZERO, safety_yellow, false)

		# Steel Station Hall Columns & Overhead Concourse Trusses
		for gz in [-4.8, 0.5]:
			_add_static_box(map_props_root, Vector3(20.4, 0.42, 0.48), Vector3(0, 5.2, gz), Vector3.ZERO, steel_mat, false)
			for cx in [-8.6, 8.6]:
				_add_static_box(map_props_root, Vector3(0.48, 5.2, 0.48), Vector3(cx, 2.6, gz), Vector3.ZERO, steel_mat, false)

		# High-Speed TGV Train parked on the railway tracks at z = -4.9!
		_add_static_box(map_props_root, Vector3(21.0, 3.1, 2.2), Vector3(0, 1.75, -5.1), Vector3.ZERO, tgv_silver, true)
		_add_static_box(map_props_root, Vector3(21.1, 0.55, 2.26), Vector3(0, 1.55, -5.08), Vector3.ZERO, tgv_blue, false)
		for wx in [-7.2, -3.6, 0.0, 3.6, 7.2]:
			_add_static_box(map_props_root, Vector3(2.4, 0.78, 2.30), Vector3(wx, 2.25, -5.06), Vector3.ZERO, tgv_win, false)

		# Station Departure Board high above
		_add_static_box(map_props_root, Vector3(8.4, 0.95, 0.22), Vector3(0, 4.45, -3.8), Vector3.ZERO, tgv_blue, false)
		var dep_lbl := Label3D.new()
		dep_lbl.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
		dep_lbl.text = "GARE DU NORD  •  QUAI 1  •  TGV PARIS – LYON"
		dep_lbl.position = Vector3(0, 4.45, -3.65)
		dep_lbl.font_size = 34
		dep_lbl.modulate = Color(1.0, 0.92, 0.36)
		dep_lbl.outline_size = 8
		map_props_root.add_child(dep_lbl)

		for tx in [-4.2, 0.0, 4.2]:
			_add_bistro_table(_display_tables_root, Vector3(tx, 0.0, -0.6), tgv_silver, steel_mat, safety_yellow)

	else:
		# === LOCATION: LE JARDIN DU LUXEMBOURG (Lush Park Lawn, Gravel Path, Fountain & Trees) ===
		var grass_m := _make_mat(Color(0.30, 0.54, 0.24), 0.90)
		var gravel_m := _make_mat(Color(0.86, 0.78, 0.64), 0.88)
		var stone_m := _make_mat(Color(0.90, 0.87, 0.80), 0.84)
		var water_m := _make_mat(Color(0.24, 0.74, 0.90), 0.25, 0.1, true)
		var leaf_dark := _make_mat(Color(0.24, 0.48, 0.22), 0.88)
		var leaf_bright := _make_mat(Color(0.32, 0.58, 0.26), 0.88)

		_add_static_box(map_props_root, Vector3(26.0, 0.04, 20.0), Vector3(0, 0.01, 1.0), Vector3.ZERO, grass_m, false)
		_add_static_box(map_props_root, Vector3(13.5, 0.06, 16.0), Vector3(0, 0.03, 1.0), Vector3.ZERO, gravel_m, false)

		# Stone Balustrade & Central Park Fountain Basin
		_add_static_box(map_props_root, Vector3(20.0, 1.15, 0.55), Vector3(0, 0.58, -5.8), Vector3.ZERO, stone_m, true)
		_add_cyl(map_props_root, 2.2, 2.3, 0.48, Vector3(0, 0.24, -3.6), stone_m)
		_add_cyl(map_props_root, 1.9, 1.9, 0.52, Vector3(0, 0.26, -3.6), water_m)

		# Perimeter Park Trees (placed out to the sides/back so center sightlines stay clear)
		for t_pos in [
			Vector3(-8.2, 0, -6.8), Vector3(-4.2, 0, -7.4), Vector3(4.2, 0, -7.4), Vector3(8.2, 0, -6.8),
			Vector3(-8.8, 0, -1.5), Vector3(8.8, 0, -1.5),
		]:
			_add_park_tree(map_props_root, t_pos, 1.05, wood_dark, leaf_dark if t_pos.x < 0 else leaf_bright)

		for tx in [-4.2, 0.0, 4.2]:
			_add_bistro_table(_display_tables_root, Vector3(tx, 0.0, -0.6), stone_m, stone_m, brass_mat)


func _build_direction_pads() -> void:
	_dir_pad_nodes.clear()
	for ch in direction_pads_root.get_children():
		ch.queue_free()

	for dir_key in VocabData.DIRECTION_INFO.keys():
		var info: Dictionary = VocabData.DIRECTION_INFO[dir_key]
		var pos: Vector3 = info["pos"]
		var pad_root := Node3D.new()
		pad_root.position = pos
		direction_pads_root.add_child(pad_root)

		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.82
		cm.bottom_radius = 0.86
		cm.height = 0.05
		disc.mesh = cm
		disc.material_override = _make_mat(Color(0.14, 0.20, 0.28), 0.75)
		pad_root.add_child(disc)

		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.78
		tm.outer_radius = 0.94
		var rmat := StandardMaterial3D.new()
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rmat.albedo_color = Color(0.38, 0.82, 1.0, 0.88)
		tm.material = rmat
		ring.mesh = tm
		ring.position = Vector3(0, 0.03, 0)
		pad_root.add_child(ring)

		var lbl := Label3D.new()
		lbl.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.pixel_size = 0.0036
		lbl.font_size = 32
		lbl.outline_size = 10
		lbl.modulate = Color(1.0, 0.96, 0.82)
		lbl.outline_modulate = Color(0.05, 0.06, 0.09, 0.96)
		lbl.text = str(info["badge"])
		lbl.position = Vector3(0.0, 0.68, 0.0)
		pad_root.add_child(lbl)

		_dir_pad_nodes[dir_key] = {
			"root": pad_root,
			"ring_mat": rmat,
			"label": lbl,
		}


func _spawn_chloe_bot() -> void:
	# Build Chloé as a charming 3D French Guide Character wearing a crimson beret & scarf!
	# Positioned warmly on the left of the terrace (x = -5.1, z = 1.4), completely out of target sightlines.
	chloe_bot = Node3D.new()
	chloe_bot.position = Vector3(-5.1, 0.0, 1.4)
	chloe_bot.rotation_degrees = Vector3(0, 32.0, 0)
	world_root.add_child(chloe_bot)

	var coat_mat := _make_mat(Color(0.16, 0.24, 0.42), 0.78)
	var red_mat := _make_mat(Color(0.82, 0.16, 0.18), 0.72)
	var skin_mat := _make_mat(Color(0.96, 0.80, 0.68), 0.75)
	var hair_mat := _make_mat(Color(0.24, 0.15, 0.10), 0.82)
	var dark_mat := _make_mat(Color(0.08, 0.08, 0.10), 0.50)

	# Coat torso & base
	_add_cyl(chloe_bot, 0.22, 0.32, 1.15, Vector3(0, 0.58, 0), coat_mat)
	# Red Parisian silk scarf
	var scarf := MeshInstance3D.new()
	var st := TorusMesh.new()
	st.inner_radius = 0.14
	st.outer_radius = 0.24
	scarf.mesh = st
	scarf.position = Vector3(0, 1.16, 0)
	scarf.material_override = red_mat
	chloe_bot.add_child(scarf)

	# Head & Hair
	var head := MeshInstance3D.new()
	var h_sph := SphereMesh.new()
	h_sph.radius = 0.23
	h_sph.height = 0.46
	head.mesh = h_sph
	head.position = Vector3(0, 1.42, 0)
	head.material_override = skin_mat
	chloe_bot.add_child(head)

	var hair := MeshInstance3D.new()
	var hr_sph := SphereMesh.new()
	hr_sph.radius = 0.24
	hr_sph.height = 0.42
	hair.mesh = hr_sph
	hair.position = Vector3(0, 1.45, -0.05)
	hair.material_override = hair_mat
	chloe_bot.add_child(hair)

	# Expressive Eyes
	for ex in [-0.08, 0.08]:
		var eye := MeshInstance3D.new()
		var e_sph := SphereMesh.new()
		e_sph.radius = 0.032
		e_sph.height = 0.064
		eye.mesh = e_sph
		eye.position = Vector3(ex, 1.44, 0.20)
		eye.material_override = dark_mat
		chloe_bot.add_child(eye)

	# Classic tilted crimson French Beret (le béret)
	var beret := MeshInstance3D.new()
	var b_cyl := CylinderMesh.new()
	b_cyl.top_radius = 0.26
	b_cyl.bottom_radius = 0.22
	b_cyl.height = 0.09
	beret.mesh = b_cyl
	beret.position = Vector3(-0.03, 1.63, 0.0)
	beret.rotation_degrees = Vector3(6.0, 0.0, 14.0)
	beret.material_override = red_mat
	chloe_bot.add_child(beret)

	var nametag := Label3D.new()
	nametag.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	nametag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nametag.no_depth_test = true
	nametag.pixel_size = 0.0032
	nametag.font_size = 28
	nametag.outline_size = 8
	nametag.modulate = Color(1.0, 0.90, 0.48)
	nametag.outline_modulate = Color(0.06, 0.05, 0.08, 0.95)
	nametag.text = "★ Chloé"
	nametag.position = Vector3(0.0, 1.92, 0.0)
	chloe_bot.add_child(nametag)


func _chloe_say(msg: String, voice_file: String = "") -> void:
	if companion_lbl:
		companion_lbl.text = "★ Chloé :  " + msg
	if companion_panel:
		companion_panel.visible = (msg != "")
	if voice_file != "" and audio:
		audio.play_companion(voice_file)


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
	var xs := [-4.8, -2.4, 0.0, 2.4, 4.8]
	for i in range(5):
		var ped := PedestalStation.new()
		pedestals_root.add_child(ped)
		var pos := Vector3(xs[i], 0.16, -0.6)
		ped.setup(sec_ids[i], pos, Vector3(0, 0.2, 6.6))
		pedestals.append(ped)


func _set_gallery_visible(enabled: bool) -> void:
	pedestals_root.visible = enabled
	if gallery_sign:
		gallery_sign.visible = false
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

	# Subtle screen-edge flash when hit by an enemy plasma orb
	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.color = Color(0.95, 0.18, 0.12, 0.0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(_damage_flash)

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
	hover_info_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.92))
	hover_info_lbl.add_theme_constant_override("outline_size", 6)
	hover_info_lbl.set_anchors_preset(Control.PRESET_CENTER)
	hover_info_lbl.position = Vector2(-280, -212)
	hover_info_lbl.size = Vector2(560, 32)
	hud_root.add_child(hover_info_lbl)

	# 2. Sleek Translucent Top-Center Callout Pill (Zero giant boxes, zero wall of text!)
	radio_panel = PanelContainer.new()
	var pill_style := _make_panel_style(Color(0.06, 0.08, 0.11, 0.62), Color(1.0, 0.88, 0.45, 0.35), 28, 1)
	pill_style.content_margin_left = 22
	pill_style.content_margin_right = 22
	pill_style.content_margin_top = 8
	pill_style.content_margin_bottom = 8
	radio_panel.add_theme_stylebox_override("panel", pill_style)
	radio_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	radio_panel.position = Vector2(-280, 12)
	radio_panel.custom_minimum_size = Vector2(560, 48)
	radio_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(radio_panel)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 3)
	radio_panel.add_child(rv)

	# Keep speaker_lbl & mode_tag_lbl as internal state holders (not cluttering the pill)
	speaker_lbl = Label.new()
	speaker_lbl.visible = false
	rv.add_child(speaker_lbl)

	mode_tag_lbl = Label.new()
	mode_tag_lbl.visible = false
	rv.add_child(mode_tag_lbl)

	wave_bars.clear()

	prompt_main_lbl = Label.new()
	prompt_main_lbl.text = "Ready"
	prompt_main_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_main_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_main_lbl.add_theme_font_size_override("font_size", 22)
	prompt_main_lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	prompt_main_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.95))
	prompt_main_lbl.add_theme_constant_override("outline_size", 6)
	rv.add_child(prompt_main_lbl)

	prompt_sub_lbl = Label.new()
	prompt_sub_lbl.text = ""
	prompt_sub_lbl.visible = false
	prompt_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_sub_lbl.add_theme_font_size_override("font_size", 13)
	prompt_sub_lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 0.58))
	rv.add_child(prompt_sub_lbl)

	timer_bar = ProgressBar.new()
	timer_bar.show_percentage = false
	timer_bar.min_value = 0.0
	timer_bar.max_value = 100.0
	timer_bar.value = 100.0
	timer_bar.custom_minimum_size = Vector2(0, 4)
	var tb_bg := StyleBoxFlat.new()
	tb_bg.bg_color = Color(1.0, 1.0, 1.0, 0.12)
	tb_bg.set_corner_radius_all(2)
	timer_bar.add_theme_stylebox_override("background", tb_bg)
	var tb_fill := StyleBoxFlat.new()
	tb_fill.bg_color = Color(1.0, 0.80, 0.24)
	tb_fill.set_corner_radius_all(2)
	timer_bar.add_theme_stylebox_override("fill", tb_fill)
	rv.add_child(timer_bar)

	# 3. Compact Mistake Callout Pill (Only shown when paused on a mistake)
	feedback_banner = PanelContainer.new()
	feedback_banner.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.08, 0.06, 0.06, 0.78), Color(1.0, 0.78, 0.24, 0.85), 20, 1)
	)
	feedback_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	feedback_banner.position = Vector2(-270, 74)
	feedback_banner.custom_minimum_size = Vector2(540, 34)
	feedback_banner.visible = false
	feedback_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(feedback_banner)

	feedback_lbl = Label.new()
	feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_lbl.add_theme_font_size_override("font_size", 14)
	feedback_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 0.95))
	feedback_lbl.add_theme_constant_override("outline_size", 4)
	feedback_banner.add_child(feedback_lbl)

	# 4. Borderless Floating Top-Left Status (Zero background box!)
	_stats_panel = PanelContainer.new()
	_stats_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_stats_panel.position = Vector2(20, 14)
	_stats_panel.custom_minimum_size = Vector2(220, 84)
	_stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(_stats_panel)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	_stats_panel.add_child(sv)

	wave_lbl = Label.new()
	wave_lbl.text = "MAP 1  •  STEP 1/6"
	wave_lbl.add_theme_font_size_override("font_size", 14)
	wave_lbl.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	wave_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.92))
	wave_lbl.add_theme_constant_override("outline_size", 5)
	sv.add_child(wave_lbl)

	score_lbl = Label.new()
	score_lbl.text = "★ 0   STREAK x1"
	score_lbl.add_theme_font_size_override("font_size", 18)
	score_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
	score_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.95))
	score_lbl.add_theme_constant_override("outline_size", 6)
	sv.add_child(score_lbl)

	shield_bar = ProgressBar.new()
	shield_bar.visible = false
	sv.add_child(shield_bar)

	# 5. Friendly Companion Chat Pill ("Chloé" — bottom-left translucent glass pill)
	companion_panel = PanelContainer.new()
	var comp_style := _make_panel_style(Color(0.06, 0.08, 0.12, 0.82), Color(1.0, 0.84, 0.36, 0.65), 18, 1)
	comp_style.content_margin_left = 16
	comp_style.content_margin_right = 16
	comp_style.content_margin_top = 8
	comp_style.content_margin_bottom = 8
	companion_panel.add_theme_stylebox_override("panel", comp_style)
	companion_panel.position = Vector2(20, 618)
	companion_panel.custom_minimum_size = Vector2(640, 44)
	companion_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(companion_panel)

	companion_lbl = Label.new()
	companion_lbl.text = "★ Chloé : « Bonjour ! Bienvenue au café parisien. Commençons ensemble ! »"
	companion_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	companion_lbl.add_theme_font_size_override("font_size", 13)
	companion_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.84))
	companion_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.95))
	companion_lbl.add_theme_constant_override("outline_size", 4)
	companion_panel.add_child(companion_lbl)

	# 6. Borderless Bottom Controls Readout (Zero background box!)
	var bot_panel := PanelContainer.new()
	bot_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	bot_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bot_panel.position = Vector2(-460, -28)
	bot_panel.custom_minimum_size = Vector2(920, 24)
	bot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bot_panel)

	hotkeys_lbl = Label.new()
	hotkeys_lbl.text = "[Click / 1–3] Choose Target   •   [WASD] Move   •   [E] Replay Audio   •   [H] Hint   •   [Tab] Word & Phrase Book"
	hotkeys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkeys_lbl.add_theme_font_size_override("font_size", 13)
	hotkeys_lbl.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 0.90))
	hotkeys_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.92))
	hotkeys_lbl.add_theme_constant_override("outline_size", 5)
	bot_panel.add_child(hotkeys_lbl)

	_build_menu_overlay()
	_build_summary_overlay()
	_build_lexicon_overlay()


func _build_menu_overlay() -> void:
	# Clean Parisian Title Card & Action Buttons
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.07, 0.09, 0.14, 0.82), Color(1.0, 0.84, 0.36, 0.65), 18, 1)
	)
	menu_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	menu_panel.position = Vector2(-360, 14)
	menu_panel.custom_minimum_size = Vector2(720, 118)
	ui_layer.add_child(menu_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	menu_panel.add_child(vb)

	var title := Label.new()
	title.text = "FRANC-TIREUR  •  BONJOUR PARIS !"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.36))
	title.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.95))
	title.add_theme_constant_override("outline_size", 6)
	vb.add_child(title)

	menu_stats_lbl = Label.new()
	menu_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_stats_lbl.add_theme_font_size_override("font_size", 14)
	menu_stats_lbl.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	vb.add_child(menu_stats_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vb.add_child(btn_row)

	var start_b := Button.new()
	start_b.text = "▶ Commencer / Start [Space]"
	start_b.custom_minimum_size = Vector2(220, 34)
	start_b.add_theme_font_size_override("font_size", 14)
	start_b.pressed.connect(_on_start_mission_pressed)
	btn_row.add_child(start_b)

	sector_btn = Button.new()
	sector_btn.text = "↻ Change Place (Map 1/9)"
	sector_btn.custom_minimum_size = Vector2(195, 34)
	sector_btn.add_theme_font_size_override("font_size", 13)
	sector_btn.pressed.connect(_on_cycle_sector)
	btn_row.add_child(sector_btn)

	var book_b := Button.new()
	book_b.text = "♪ Word & Phrase Book [Tab]"
	book_b.custom_minimum_size = Vector2(195, 34)
	book_b.add_theme_font_size_override("font_size", 13)
	book_b.pressed.connect(func(): _toggle_lexicon(true))
	btn_row.add_child(book_b)

	l1_btn = Button.new()
	l1_btn.visible = false
	vb.add_child(l1_btn)


func _build_summary_overlay() -> void:
	# Kept hidden — wave transitions happen 100% physically in 3D via the Golden Portal Gate!
	summary_panel = PanelContainer.new()
	summary_panel.visible = false
	ui_layer.add_child(summary_panel)
	summary_lbl = Label.new()
	summary_panel.add_child(summary_lbl)


func _continue_to_next_round() -> void:
	audio.play_sfx("click")
	summary_panel.visible = false
	hud_root.visible = true
	wave_number += 1
	player.visible = true
	player.camera.current = true
	if player.position.z < 3.0:
		player.position = Vector3(0.0, 0.30, 6.2)
		player.look_toward_point(Vector3(0.0, 2.0, -1.0))
	player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_begin_wave()


func _build_lexicon_overlay() -> void:
	lexicon_panel = PanelContainer.new()
	lexicon_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.06, 0.08, 0.12, 0.90), Color(1.0, 0.84, 0.35, 0.55), 16, 1)
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
	lexicon_header_lbl.text = "FRENCH WORD & PHRASE BOOK — Click [♪] to hear native words & everyday phrases"
	lexicon_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lexicon_header_lbl.add_theme_font_size_override("font_size", 15)
	lexicon_header_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))
	top.add_child(lexicon_header_lbl)

	for tab_spec in [
		["ALL", "All Words (45)"],
		["PHRASES", "★ Phrases (18)"],
		["A1", "Maps 1–4 (20)"],
		["A2", "Maps 5–7 (15)"],
		["B1", "Maps 8–9 (10)"],
	]:
		var tb := Button.new()
		var t_code: String = tab_spec[0]
		tb.text = tab_spec[1]
		tb.custom_minimum_size = Vector2(108, 30)
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

	if lexicon_tab == "PHRASES":
		lexicon_grid.columns = 2
		for dp in VocabData.DAILY_PHRASES:
			var pcard := PanelContainer.new()
			pcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pcard.custom_minimum_size = Vector2(540, 108)
			pcard.add_theme_stylebox_override(
				"panel",
				_make_panel_style(Color(0.11, 0.15, 0.22, 0.92), Color(1.0, 0.84, 0.36, 0.78), 10, 1)
			)
			lexicon_grid.add_child(pcard)

			var pvb := VBoxContainer.new()
			pvb.add_theme_constant_override("separation", 3)
			pcard.add_child(pvb)

			var pr1 := HBoxContainer.new()
			pvb.add_child(pr1)
			var map_i := clampi(int(dp["sector"]), 0, 8)
			var sit_lbl := Label.new()
			sit_lbl.text = "★ Map %d (%s)  •  %s" % [map_i + 1, VocabData.SECTORS[map_i]["name_fr"], str(dp["situation_en"])]
			sit_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sit_lbl.clip_text = true
			sit_lbl.add_theme_font_size_override("font_size", 12)
			sit_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.42))
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
			fr_lbl.clip_text = true
			fr_lbl.add_theme_font_size_override("font_size", 14)
			fr_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90))
			pvb.add_child(fr_lbl)

			var tip_l := Label.new()
			tip_l.text = "Chloé: %s" % str(dp["chloe_tip"])
			tip_l.clip_text = true
			tip_l.add_theme_font_size_override("font_size", 11)
			tip_l.add_theme_color_override("font_color", Color(0.68, 0.94, 0.78))
			pvb.add_child(tip_l)
		return

	var tier_names := ["Level 1: New", "Level 2: Phrase + Text", "Level 3: Listen Phrase", "Level 4: Spoken", "★ Mastered"]
	var tier_cols := [
		Color(0.75, 0.68, 0.58),
		Color(0.98, 0.82, 0.36),
		Color(0.98, 0.64, 0.28),
		Color(0.62, 0.92, 0.48),
		Color(0.36, 0.98, 0.58),
	]

	lexicon_grid.columns = 4
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
		card.custom_minimum_size = Vector2(228, 108)
		card.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color(0.11, 0.14, 0.20, 0.88), tier_cols[t_idx], 10, 1)
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
		w_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
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
		phr_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.46))
		cv.add_child(phr_lbl)

		var st_lbl := Label.new()
		var ok_n := int(c["correct"])
		var map_idx := clampi(int(item["sector"]), 0, 8)
		st_lbl.text = "Map %d: %s  •  %s (✓%d)" % [map_idx + 1, VocabData.SECTORS[map_idx]["name_fr"], tier_names[t_idx] if bool(c["seen"]) else "Unseen", ok_n]
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
		drones_root.visible = true
		pedestals_root.visible = (state == GameState.GALLERY)
		if state == GameState.MENU:
			menu_panel.visible = true
			hud_root.visible = true
			player.controls_enabled = true
		elif state == GameState.WAVE_SUMMARY:
			hud_root.visible = true
			player.controls_enabled = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif state in [GameState.CALIBRATION, GameState.COMBAT, GameState.GALLERY]:
			hud_root.visible = true
			player.controls_enabled = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ==============================================================================
# STATE TRANSITIONS & 3D PORTAL HUB
# ==============================================================================

func _enter_menu() -> void:
	state = GameState.MENU
	prompt_active = false
	_clear_drones()
	_clear_projectiles_and_pickups()
	_set_gallery_visible(false)
	player.visible = true
	player.camera.current = true
	player.position = Vector3(0.0, 0.30, 6.4)
	player.look_toward_point(Vector3(0.0, 1.9, -0.6))
	player.controls_enabled = true
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
	_portal_cooldown = 0.65
	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)
	_refresh_menu_labels()
	_spawn_menu_portals()
	var s_info := VocabData.SECTORS[act_s]
	_chloe_say(str(s_info.get("chloe_intro", "« Bonjour ! Bienvenue au café parisien ! »")), "chloe_welcome_%d.ogg" % act_s)


func _spawn_menu_portals() -> void:
	_clear_drones()
	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)
	if _display_tables_root:
		_display_tables_root.visible = true
	var sec_ids := VocabData.get_sector_ids(act_s)
	var xs := [-4.2, 0.0, 4.2]
	for i in range(mini(3, sec_ids.size())):
		var vid: String = sec_ids[i]
		var item := VocabData.get_by_id(vid)
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(vid, Vector3(xs[i], 1.82, -0.6), player.global_position, 0.08, 1.15, "PORTAL_START")
		d.is_portal_crystal = true
		d.show_calibration_card(str(item.get("fr_def", vid)), str(item.get("en", "")))
		active_drones.append(d)


func _refresh_menu_labels() -> void:
	var st := srs.get_summary_stats()
	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	var s_info := VocabData.SECTORS[act_s]
	menu_stats_lbl.text = "◈ Place %d/9 : %s (%s)   •   Words Learned: %d/%d" % [
		act_s + 1, s_info["name_fr"], s_info["name_en"], st["seen"], st["total_words"]
	]
	if sector_btn:
		sector_btn.text = "↻ Change Place (%d/9)" % [act_s + 1]
	if prompt_main_lbl:
		prompt_main_lbl.text = "Click [▶ Commencer / Start] or Press [Space] to Begin!"
	if prompt_sub_lbl:
		prompt_sub_lbl.visible = false


func _on_cycle_sector() -> void:
	audio.play_sfx("click")
	var order := [0, 1, 2, 3, 4, 5, 6, 7, 8]
	var act_cur := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	var next_s := (act_cur + 1) % order.size()
	srs.sector_filter = next_s
	srs.save_progress()
	_apply_map_theme(next_s)
	_refresh_menu_labels()
	var s_info := VocabData.SECTORS[next_s]
	_chloe_say(str(s_info.get("chloe_intro", "")), "chloe_welcome_%d.ogg" % next_s)
	if state == GameState.MENU:
		_spawn_menu_portals()


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
	if _stats_panel:
		_stats_panel.visible = true
	radio_panel.visible = true
	hover_info_lbl.text = ""
	_set_gallery_visible(false)
	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)
	player.visible = true
	player.camera.current = true
	player.position = Vector3(0.0, 0.30, 6.6)
	player.look_toward_point(Vector3(0.0, 1.9, -0.6))
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
	if _display_tables_root:
		_display_tables_root.visible = false
	_set_gallery_visible(true)
	menu_panel.visible = false
	summary_panel.visible = false
	lexicon_panel.visible = false
	hud_root.visible = true
	if _stats_panel:
		_stats_panel.visible = true
	radio_panel.visible = true
	feedback_banner.visible = false
	player.visible = true
	player.camera.current = true
	player.position = Vector3(0.0, 0.30, 6.6)
	player.look_toward_point(Vector3(0.0, 1.6, -0.6))
	player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if srs.sector_filter >= 0:
		gallery_sector = srs.sector_filter
	elif srs.sector_filter == -1:
		gallery_sector = srs.get_active_campaign_sector()
	else:
		gallery_sector = 0
	_load_gallery_sector(gallery_sector)


func _load_gallery_sector(sec_idx: int) -> void:
	gallery_sector = clampi(sec_idx, 0, VocabData.SECTORS.size() - 1)
	_apply_map_theme(gallery_sector)
	if _display_tables_root:
		_display_tables_root.visible = false
	var ids := VocabData.get_sector_ids(gallery_sector)
	_refresh_gallery_pedestals(ids)
	var s_info := VocabData.SECTORS[gallery_sector]
	speaker_lbl.text = "◈ 3D WORD EXHIBITION (%s)" % s_info["cefr"]
	mode_tag_lbl.text = "Press [1–9] to Switch Place  •  Press [M] to Play Round"
	prompt_main_lbl.text = "◈ %s  (%s)" % [s_info["name_fr"], s_info["name_en"]]
	prompt_sub_lbl.text = ""
	_update_stats_hud()
	_chloe_say("« Voici %s ! Tirez sur un objet pour écouter la phrase. » (Shoot any pedestal to hear its spoken French phrase!)" % s_info["name_fr"], "chloe_welcome_%d.ogg" % gallery_sector)
	timer_bar.value = 100.0


func _begin_wave() -> void:
	prompt_in_wave = 0
	wave_hits_clean = 0
	shield_hp = minf(100.0, shield_hp + 25.0)
	_set_gallery_visible(false)
	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)
	_update_stats_hud()
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
		var pos := Vector3(spread, 1.82, -0.6)
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(vid, pos, player.global_position, 0.12, 1.15)
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

	speaker_lbl.text = "♪ CHLOÉ (STAGE INTRO %s)" % item.get("cefr", "A1")
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

	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)

	current_spec = srs.build_wave_prompt_spec(prompt_in_wave, wave_number)
	var ptype := str(current_spec.get("prompt_type", "VOCAB"))

	if _display_tables_root:
		_display_tables_root.visible = (ptype in ["VOCAB", "SCENARIO", "MODIFIER"])

	if ptype == "DIRECTION":
		_spawn_direction_drones(current_spec)
	elif ptype == "MODIFIER":
		_spawn_modifier_drones(current_spec)
	elif ptype == "SCENARIO":
		_spawn_scenario_drones(current_spec)
	elif ptype in ["GRAMMAR", "DAILY_PHRASE"]:
		_spawn_grammar_drones(current_spec)
	else:
		_spawn_vocab_drones(current_spec)

	prompt_timer = PROMPT_TIME_LIMIT
	prompt_active = true
	prompt_clean_try = true
	prompt_used_assist = false
	prompt_hint_stage = 0
	prompt_wrong_ids.clear()

	# Chloé speaks French-first with concise English context
	if ptype == "DIRECTION":
		_chloe_say(str(current_spec.get("chloe_tip", "« Suivez les directions au sol ! » (Follow the glowing floor pads!)")))
	elif ptype == "DAILY_PHRASE":
		_chloe_say("« En France (%s) : » %s" % [
			str(current_spec.get("situation_en", "Everyday French")),
			str(current_spec.get("chloe_tip", ""))
		])
	elif ptype == "VOCAB":
		var item := VocabData.get_by_id(str(current_spec.get("target_id", "")))
		var tier := int(current_spec.get("tier", 0))
		if tier == 0:
			_chloe_say("« Voici %s ! » (%s) — Phrase : « %s »" % [
				str(item.get("fr_def", "")),
				str(item.get("en", "")),
				str(item.get("phrase_fr", ""))
			])
		elif tier == 1:
			_chloe_say("« %s » (%s)" % [
				str(item.get("phrase_fr", "")),
				str(item.get("phrase_en", ""))
			])
		else:
			_chloe_say("« Écoutez bien la phrase ! » (Listen to the spoken French phrase! [E] Replay • [H] Hint)")
	elif ptype == "MODIFIER":
		_chloe_say("« Observez bien ! » %s" % str(current_spec.get("sub_en", "")))
	elif ptype == "SCENARIO":
		_chloe_say("« Phrase utile : » %s" % str(current_spec.get("sub_en", "")))

	_refresh_prompt_hud()
	_update_stats_hud()
	audio.play_voice(str(current_spec["audio_file"]))


func _spawn_direction_drones(spec: Dictionary) -> void:
	_dir_steps.clear()
	for s in spec.get("steps", []):
		_dir_steps.append(str(s))
	_dir_step_idx = 0
	if direction_pads_root:
		direction_pads_root.visible = true
	if _display_tables_root:
		_display_tables_root.visible = false

	var order := ["gauche", "avant", "haut", "arriere", "droite"]
	for i in range(order.size()):
		var d_key: String = order[i]
		var d_info: Dictionary = VocabData.DIRECTION_INFO[d_key]
		var pad_pos: Vector3 = d_info["pos"]
		var drone := TargetDrone.new()
		drones_root.add_child(drone)
		var c_pos := pad_pos + Vector3(0.0, 0.55, 0.0)
		drone.setup("dir_pad", c_pos, player.global_position, 0.0, 0.50, "DIR_" + d_key)
		active_drones.append(drone)

	_update_direction_pads_visuals()


func _update_direction_pads_visuals() -> void:
	var cur_key: String = str(_dir_steps[_dir_step_idx]) if _dir_step_idx < _dir_steps.size() else ""
	for d_key_v in _dir_pad_nodes.keys():
		var d_key: String = str(d_key_v)
		var p_data: Dictionary = _dir_pad_nodes[d_key]
		var d_info: Dictionary = VocabData.DIRECTION_INFO[d_key]
		var is_cur: bool = (d_key == cur_key)
		var is_done: bool = false
		for idx in range(_dir_step_idx):
			if str(_dir_steps[idx]) == d_key:
				is_done = true
		var rmat: StandardMaterial3D = p_data["ring_mat"]
		var lbl: Label3D = p_data["label"]
		if is_cur:
			rmat.albedo_color = Color(1.0, 0.88, 0.22)
			lbl.modulate = Color(1.0, 0.95, 0.42)
			lbl.text = "★ " + str(d_info["badge"]) + " ★"
		elif is_done:
			rmat.albedo_color = Color(0.28, 0.96, 0.54)
			lbl.modulate = Color(0.55, 1.0, 0.72)
			lbl.text = "✓ " + str(d_info["fr"])
		else:
			rmat.albedo_color = Color(0.38, 0.82, 1.0, 0.78)
			lbl.modulate = Color(0.88, 0.94, 1.0)
			lbl.text = str(d_info["badge"])


func _check_direction_progress() -> void:
	if state != GameState.COMBAT or not prompt_active or not is_instance_valid(player):
		return
	if str(current_spec.get("prompt_type", "")) != "DIRECTION":
		return
	if _dir_step_idx >= _dir_steps.size():
		return
	var cur_key: String = str(_dir_steps[_dir_step_idx])
	var d_info: Dictionary = VocabData.DIRECTION_INFO[cur_key]
	var pad_pos: Vector3 = d_info["pos"]
	var p_pos := player.global_position
	var flat_dist := Vector2(p_pos.x - pad_pos.x, p_pos.z - pad_pos.z).length()
	if cur_key == "haut":
		if (flat_dist < 2.25 and p_pos.y > 0.42) or p_pos.y > 0.85:
			_advance_direction_step(pad_pos)
	else:
		if flat_dist < 1.95:
			_advance_direction_step(pad_pos)


func _advance_direction_step(_from_pos: Vector3) -> void:
	if _dir_step_idx + 1 < _dir_steps.size():
		_dir_step_idx += 1
		score += 75
		audio.play_sfx("scan", 0.02, -3.0)
		var next_key: String = str(_dir_steps[_dir_step_idx])
		var next_info: Dictionary = VocabData.DIRECTION_INFO[next_key]
		audio.play_voice(str(next_info["audio"]))
		_update_direction_pads_visuals()
		_refresh_prompt_hud()
		_update_stats_hud()
		_chloe_say("« Très bien ! Maintenant : %s ! » (%s)" % [str(next_info["fr"]), str(next_info["en"])])
	else:
		prompt_active = false
		feedback_banner.visible = false
		audio.play_sfx("hit_ok", 0.02, -2.0)
		combo += 1
		wave_hits_clean += 1
		var pts := 125 + _dir_steps.size() * 50
		score += pts
		srs.global_step += 1
		srs.save_progress()
		prompt_main_lbl.text = "✓ %s   (%s)" % [str(current_spec["prompt_fr"]), str(current_spec["prompt_en"])]
		_chloe_say("« Bravo ! %s ! » (%s)" % [str(current_spec["prompt_fr"]), str(current_spec["prompt_en"])], "chloe_bravo_%d.ogg" % ((combo % 3) + 1))
		_update_stats_hud()
		transition_delay = 1.05


func _spawn_vocab_drones(spec: Dictionary) -> void:
	if _display_tables_root:
		_display_tables_root.visible = true
	var target_id := str(spec["target_id"])
	var tier := int(spec.get("tier", 0))
	var distractors := srs.select_distractors(target_id, 2, str(spec["required_decoy"]))
	var spawn_ids: Array[String] = [target_id]
	spawn_ids.append_array(distractors)
	spawn_ids.shuffle()

	var n := mini(3, spawn_ids.size())
	var xs3 := [-4.2, 0.0, 4.2]
	for i in range(n):
		var sx: float = xs3[i]
		var sz: float = -0.6
		var height := 1.82
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(spawn_ids[i], Vector3(sx, height, sz), player.global_position, 0.10, 1.16)
		d.set_slot_badge(i + 1)
		d.approach_speed = 0.0
		d.can_fire_plasma = false
		if tier == 0 and spawn_ids[i] == target_id:
			var item := VocabData.get_by_id(target_id)
			d.show_calibration_card(str(item.get("fr_def", target_id)), str(item.get("en", "")))
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
			"! Shoot the gold-highlighted target: %s (%s)" % [
				item.get("fr_def", target_tag), item.get("en", "")
			],
			false
		)
		_update_stats_hud()


func _spawn_scenario_drones(spec: Dictionary) -> void:
	if _display_tables_root:
		_display_tables_root.visible = true
	var target_id := str(spec["target_id"])
	var decoys: Array = spec.get("decoys", [])
	var spawn_ids: Array[String] = [target_id]
	for dec in decoys:
		var ds := str(dec)
		if ds != target_id and not spawn_ids.has(ds) and spawn_ids.size() < 3:
			spawn_ids.append(ds)
	spawn_ids.shuffle()

	var n := mini(3, spawn_ids.size())
	var xs3 := [-4.2, 0.0, 4.2]
	for i in range(n):
		var sx: float = xs3[i]
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(spawn_ids[i], Vector3(sx, 1.82, -0.6), player.global_position, 0.10, 1.16)
		d.set_slot_badge(i + 1)
		d.approach_speed = 0.0
		d.can_fire_plasma = false
		active_drones.append(d)


func _spawn_grammar_drones(spec: Dictionary) -> void:
	if _display_tables_root:
		_display_tables_root.visible = false
	var opts: Array = spec["options"].duplicate()
	opts.shuffle()
	var xs3 := [-4.3, 0.0, 4.3]
	var xs4 := [-5.6, -1.9, 1.9, 5.6]
	var n := opts.size()
	for i in range(n):
		var opt_txt := str(opts[i])
		var sx: float = xs3[i] if n == 3 else (xs4[i] if i < 4 else 0.0)
		var pos := Vector3(sx, 2.05, -0.6)
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup("holo_crystal", pos, player.global_position, 0.08, 1.08, opt_txt)
		d.configure_as_grammar_crystal(opt_txt, i + 1)
		active_drones.append(d)


func _spawn_modifier_drones(spec: Dictionary) -> void:
	if _display_tables_root:
		_display_tables_root.visible = true
	var layout := str(spec["layout"])
	var vid := str(spec["base_vocab_id"])
	var xs3 := [-4.2, 0.0, 4.2]
	var target_slot := randi() % 3

	if layout == "pos_left":
		target_slot = 0
	elif layout == "pos_right":
		target_slot = 2
	elif layout == "pos_middle":
		target_slot = 1

	for i in range(3):
		var is_t := (i == target_slot)
		var tag := "MOD_TARGET" if is_t else ("DECOY_%d" % i)
		var pos := Vector3(xs3[i], 1.82, -0.6)
		var mv := 0.12
		var sc := 1.0
		var ok_lbl := "+150  ✓ Correct!"
		var err_lbl := "✗ Wrong target!"

		match layout:
			"scale_max":
				sc = 1.55 if is_t else (0.68 + float(i) * 0.08)
				ok_lbl = "+150  ✓ La plus grande (Biggest)!"
				err_lbl = "✗ Shoot the BIGGEST one!"
			"scale_min":
				sc = 0.58 if is_t else (1.22 + float(i) * 0.08)
				ok_lbl = "+150  ✓ Le plus petit (Smallest)!"
				err_lbl = "✗ Shoot the SMALLEST one!"
			"speed_max":
				mv = 2.20 if is_t else 0.12
				ok_lbl = "+150  ✓ Le plus vite (Fastest)!"
				err_lbl = "✗ Shoot the FASTEST one!"
			"speed_zero":
				mv = 0.0 if is_t else 1.55
				ok_lbl = "+150  ✓ Immobile (Standing still)!"
				err_lbl = "✗ Shoot the one STANDING STILL!"
			"height_max":
				pos.y = 3.20 if is_t else 1.65
				ok_lbl = "+150  ✓ Le plus haut (Highest)!"
				err_lbl = "✗ Shoot the HIGHEST one!"
			"height_min":
				pos.y = 1.45 if is_t else 3.05
				ok_lbl = "+150  ✓ Le plus bas (Lowest)!"
				err_lbl = "✗ Shoot the LOWEST one!"
			"pos_left":
				ok_lbl = "+150  ✓ À gauche (Left)!"
				err_lbl = "✗ Shoot the LEFT one!"
			"pos_right":
				ok_lbl = "+150  ✓ À droite (Right)!"
				err_lbl = "✗ Shoot the RIGHT one!"
			"pos_middle":
				ok_lbl = "+150  ✓ Au milieu (Middle)!"
				err_lbl = "✗ Shoot the MIDDLE one!"
			"dist_min":
				pos.z = 1.4 if is_t else -1.8
				ok_lbl = "+150  ✓ Le plus proche (Closest)!"
				err_lbl = "✗ Shoot the CLOSEST one!"
			"dist_max":
				pos.z = -2.4 if is_t else 1.2
				ok_lbl = "+150  ✓ La plus éloignée (Furthest)!"
				err_lbl = "✗ Shoot the FURTHEST one!"
			"big_stationary":
				if is_t:
					sc = 1.52
					mv = 0.0
				elif i % 2 == 0:
					sc = 1.52
					mv = 1.60
				else:
					sc = 0.65
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

	if ptype == "DIRECTION":
		var parts: Array[String] = []
		for idx in range(_dir_steps.size()):
			var d_key: String = _dir_steps[idx]
			var d_fr: String = str(VocabData.DIRECTION_INFO[d_key]["fr"])
			if idx < _dir_step_idx:
				parts.append("✓ " + d_fr)
			elif idx == _dir_step_idx:
				parts.append("▶ " + d_fr.to_upper())
			else:
				parts.append(d_fr)
		var seq_str := "   →   ".join(parts)
		if show_en:
			prompt_main_lbl.text = "◈  %s   (%s)" % [seq_str, str(current_spec.get("prompt_en", ""))]
		else:
			prompt_main_lbl.text = "◈  %s" % seq_str
		prompt_sub_lbl.visible = false
		return

	if show_fr:
		if ptype == "DAILY_PHRASE":
			prompt_main_lbl.text = "♪  %s" % str(current_spec["prompt_fr"])
		elif ptype == "MODIFIER" and show_en:
			var short_en := str(current_spec.get("sub_en", "")).split("•")[0].strip_edges()
			prompt_main_lbl.text = "♪  %s   (%s)" % [str(current_spec["prompt_fr"]), short_en]
		elif ptype == "VOCAB" and prompt_hint_stage >= 2 and int(current_spec.get("tier", 0)) >= 1:
			var t_item := VocabData.get_by_id(str(current_spec.get("target_id", "")))
			prompt_main_lbl.text = "♪  %s   (%s)" % [str(current_spec["prompt_fr"]), str(t_item.get("phrase_en", t_item.get("en", "")))]
		else:
			prompt_main_lbl.text = "♪  %s" % str(current_spec["prompt_fr"])
	else:
		if ptype == "MODIFIER":
			prompt_main_lbl.text = "◉ ÉCOUTEZ : Size / Speed Challenge!  [E] Replay • [H] Hint"
		elif int(current_spec["tier"]) >= 3:
			prompt_main_lbl.text = "◉ ÉCOUTEZ : Spoken French Phrase!  [E] Replay • [H] Hint"
		else:
			prompt_main_lbl.text = "◉ ÉCOUTEZ LA PHRASE & TIREZ !   [E] Replay  •  [H] Hint"

	prompt_sub_lbl.visible = false


# ==============================================================================
# SHOOTING, PORTAL GATES & INPUTS
# ==============================================================================

func _on_player_hovered(entity: Node) -> void:
	if entity is PedestalStation:
		_reticle_col = Color(0.45, 0.98, 0.58)
		hover_info_lbl.text = ""
	elif entity is TargetDrone:
		_reticle_col = Color(1.0, 0.88, 0.24)
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
		audio.play_voice("phrase_%s.ogg" % ped.vocab_id)
		srs.mark_calibrated(ped.vocab_id)
		var item := VocabData.get_by_id(ped.vocab_id)
		prompt_main_lbl.text = "♪ %s (%s)  —  « %s »" % [item["fr_def"], item["en"], item.get("phrase_fr", "")]
		_chloe_say("« %s » (%s) — %s" % [item.get("phrase_fr", item["fr_def"]), item.get("phrase_en", item["en"]), item["tip"]])
		return

	if not (entity is TargetDrone):
		return

	var drone := entity as TargetDrone
	if drone.is_destroyed:
		return

	if drone.is_portal_crystal and not drone.drone_tag.begins_with("DIR_"):
		_trigger_portal_tag(drone.drone_tag, true)
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

		if ptype == "DIRECTION":
			var cur_key: String = str(_dir_steps[_dir_step_idx]) if _dir_step_idx < _dir_steps.size() else ""
			var expected_tag := "DIR_" + cur_key
			if drone.drone_tag == expected_tag:
				_advance_direction_step(drone.global_position)
			else:
				prompt_clean_try = false
				combo = 0
				audio.play_sfx("hit_err", 0.02, -2.0)
				drone.flash_wrong_hit()
				var exp_info: Dictionary = VocabData.DIRECTION_INFO.get(cur_key, {})
				_show_feedback(
					"✗ Move to or shoot the GOLD pad: %s (%s)!" % [
						exp_info.get("fr", cur_key), exp_info.get("en", "")
					],
					false
				)
				_chloe_say("« Pas de souci ! Cherchez : %s » (%s)" % [exp_info.get("fr", cur_key), exp_info.get("en", "")], "chloe_try_again.ogg")
				_update_stats_hud()
			return

		var target_tag := str(current_spec["target_id"])

		if drone.drone_tag == target_tag:
			prompt_active = false
			feedback_banner.visible = false
			audio.play_sfx("hit_ok", 0.02, -1.5)
			var pts := 100
			if prompt_clean_try:
				combo += 1
				wave_hits_clean += 1
				pts = 100 + combo * 25
			else:
				pts = 75
			score += pts
			if prompt_clean_try and drone.custom_ok_label == "" and not drone.is_grammar_crystal:
				var f_item := VocabData.get_by_id(target_tag)
				drone.custom_ok_label = "+%d ✓ %s (%s)" % [pts, f_item.get("fr_def", target_tag), f_item.get("en", "")]

			drone.explode_success(world_root, pts)
			active_drones.erase(drone)
			var bravo_voice := "chloe_bravo_%d.ogg" % ((combo % 3) + 1)

			if ptype == "DAILY_PHRASE":
				srs.global_step += 1
				srs.save_progress()
				prompt_main_lbl.text = "✓ « %s »  =  %s" % [str(current_spec["phrase_fr"]), str(current_spec["phrase_en"])]
				_chloe_say("« Parfait ! %s » (%s)" % [str(current_spec["phrase_fr"]), str(current_spec["phrase_en"])], bravo_voice)
			elif ptype == "GRAMMAR":
				var gid := str(current_spec["grammar_id"])
				srs.record_grammar_result(gid, prompt_clean_try, prompt_used_assist)
				prompt_main_lbl.text = "✓ %s   (%s)" % [str(current_spec["sentence_full"]), str(current_spec["en"])]
				_chloe_say("« Très bien ! %s »" % str(current_spec["sentence_full"]), bravo_voice)
			elif ptype == "MODIFIER":
				srs.global_step += 1
				srs.save_progress()
				prompt_main_lbl.text = "✓ %s" % str(current_spec["prompt_fr"])
				_chloe_say("« Bravo ! %s ! »" % str(current_spec["prompt_fr"]), bravo_voice)
			else:
				srs.record_result(target_tag, prompt_clean_try, prompt_used_assist, prompt_wrong_ids)
				var t_item := VocabData.get_by_id(target_tag)
				prompt_main_lbl.text = "✓ %s (%s)  —  « %s »" % [t_item["fr_def"], t_item["en"], t_item.get("phrase_fr", "")]
				_chloe_say("« Très bien ! %s » (%s)" % [t_item.get("phrase_fr", t_item["fr_def"]), t_item.get("phrase_en", t_item["en"])], bravo_voice)

			_update_stats_hud()
			transition_delay = 1.05
		else:
			prompt_clean_try = false
			combo = 0
			shield_hp = maxf(10.0, shield_hp - 12.0)
			audio.play_sfx("hit_err", 0.02, -1.0)
			audio.play_sfx("shield_hit", 0.01, -3.0)
			drone.flash_wrong_hit()

			if ptype in ["GRAMMAR", "DAILY_PHRASE"]:
				_highlight_true_target(target_tag)
				_play_slow_assist()
				_show_feedback(
					"✗ Not « %s »! Shoot the gold signboard: « %s »" % [
						drone.grammar_option, target_tag
					],
					false
				)
				_chloe_say("« Pas de souci ! Choisissez : %s » (%s)" % [target_tag, str(current_spec.get("phrase_en", ""))], "chloe_try_again.ogg")
			elif ptype == "MODIFIER":
				_highlight_true_target("MOD_TARGET")
				_show_feedback(
					"✗ %s  →  Shoot the gold-highlighted target (%s) to continue!" % [
						drone.custom_wrong_label, current_spec["prompt_fr"]
					],
					false
				)
				_chloe_say("« Essayez encore ! Cherchez : %s »" % str(current_spec["prompt_fr"]), "chloe_try_again.ogg")
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
				_chloe_say("« Pas de souci ! Ça, c'est %s (%s). Tirez sur %s (%s) ! »" % [
					hit_item["fr_def"], hit_item["en"], true_item["fr_def"], true_item["en"]
				], "chloe_try_again.ogg")
			_update_stats_hud()


func _trigger_portal_tag(ptag: String, from_shot: bool = false) -> void:
	if _portal_cooldown > 0.0:
		return
	_portal_cooldown = 0.55
	match ptag:
		"PORTAL_START":
			_on_start_mission_pressed()
		"PORTAL_GALLERY":
			_on_enter_gallery_pressed()
		"PORTAL_STAGE":
			_on_cycle_sector()
		"PORTAL_NEXT_WAVE":
			if from_shot or state == GameState.WAVE_SUMMARY:
				_continue_to_next_round()


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
		audio.play_voice(str(current_spec.get("audio_file", "")), 4.5, 0.82)

	if ptype == "VOCAB":
		var tid := str(current_spec.get("target_id", ""))
		var item := VocabData.get_by_id(tid)
		if not item.is_empty():
			prompt_main_lbl.text = "♪ %s  =  %s" % [item["fr_def"], item["en"]]
	elif ptype == "MODIFIER" or ptype == "DIRECTION":
		prompt_main_lbl.text = "♪ %s" % str(current_spec["prompt_fr"])


func _show_feedback(msg: String, is_ok: bool) -> void:
	feedback_banner.visible = true
	var border_col := Color(0.42, 0.96, 0.56, 0.95) if is_ok else Color(0.98, 0.76, 0.24, 0.96)
	var bg_col := Color(0.10, 0.20, 0.12, 0.88) if is_ok else Color(0.24, 0.11, 0.08, 0.88)
	feedback_banner.add_theme_stylebox_override("panel", _make_panel_style(bg_col, border_col, 10, 2))
	feedback_lbl.text = msg
	feedback_lbl.add_theme_color_override("font_color", Color(0.75, 1.0, 0.82) if is_ok else Color(1.0, 0.92, 0.68))


func _update_stats_hud() -> void:
	var s_info := VocabData.SECTORS[clampi(_active_map_idx, 0, 8)]
	wave_lbl.text = "%s  •  STEP %d/%d" % [String(s_info["name_fr"]).to_upper(), prompt_in_wave, PROMPTS_PER_WAVE]
	score_lbl.text = "SCORE: %d  (STREAK x%d)" % [score, maxi(1, combo)]
	shield_bar.value = shield_hp


func _finish_wave() -> void:
	state = GameState.WAVE_SUMMARY
	prompt_active = false
	_clear_drones()
	feedback_banner.visible = false
	summary_panel.visible = false
	hud_root.visible = true
	player.controls_enabled = true
	if _display_tables_root:
		_display_tables_root.visible = true

	audio.play_sfx("wave_up")

	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)
	var s_info := VocabData.SECTORS[act_s]
	radio_panel.visible = true
	prompt_main_lbl.text = "★ MANCHE %d TERMINÉE (%d/%d) !   Press [Space] or Shoot Star to Continue!" % [
		wave_number, wave_hits_clean, PROMPTS_PER_WAVE
	]
	timer_bar.value = 100.0

	_chloe_say("« Félicitations ! Manche terminée ! On continue ? » (Round %d complete! Press [Space] or shoot the star for Round %d!)" % [wave_number, wave_number + 1], "chloe_round_done.ogg")

	var p_next := TargetDrone.new()
	drones_root.add_child(p_next)
	p_next.setup("etoile", Vector3(0.0, 1.82, -0.6), player.global_position, 0.14, 1.25, "PORTAL_NEXT_WAVE")
	p_next.is_portal_crystal = true
	p_next.show_calibration_card("★ MANCHE %d" % (wave_number + 1), "%s (%s) • [Space] / Shoot" % [s_info["name_fr"], s_info["name_en"]])
	active_drones.append(p_next)


func _clear_drones() -> void:
	active_drones.clear()
	for ch in drones_root.get_children():
		ch.queue_free()
	if direction_pads_root:
		direction_pads_root.visible = false
	if projectiles_root:
		_projectiles.clear()
		for ch in projectiles_root.get_children():
			ch.queue_free()


func _clear_projectiles_and_pickups() -> void:
	_projectiles.clear()
	if projectiles_root:
		for ch in projectiles_root.get_children():
			ch.queue_free()
	_pickups.clear()
	if pickups_root:
		for ch in pickups_root.get_children():
			ch.queue_free()


func _spawn_enemy_plasma(_origin_pos: Vector3) -> void:
	return


func _update_projectiles(_delta: float) -> void:
	return


func _spawn_ground_pickup(_world_pos: Vector3) -> void:
	return


func _update_pickups(_delta: float) -> void:
	return


func _check_portal_collisions() -> void:
	if _portal_cooldown > 0.0 or not is_instance_valid(player):
		return
	var p_pos := player.global_position
	for d in active_drones:
		if is_instance_valid(d) and not d.is_destroyed and d.is_portal_crystal and not d.drone_tag.begins_with("DIR_"):
			var flat_dist := Vector2(d.global_position.x - p_pos.x, d.global_position.z - p_pos.z).length()
			if flat_dist < 1.95:
				_trigger_portal_tag(d.drone_tag, false)
				return


## Allows pressing [1]..[5] during Combat to quick-shoot the Nth target from left to right!
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

	if lexicon_open:
		return

	if state == GameState.MENU:
		if kc in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_1]:
			_on_start_mission_pressed()
		elif kc == KEY_G:
			_on_enter_gallery_pressed()
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
		elif kc >= KEY_1 and kc <= KEY_5:
			_quick_shoot_slot(int(kc - KEY_1))


func _process(delta: float) -> void:
	if _portal_cooldown > 0.0:
		_portal_cooldown = maxf(0.0, _portal_cooldown - delta)

	if chloe_bot:
		var t_sec := Time.get_ticks_msec() * 0.001
		chloe_bot.position.y = sin(t_sec * 2.2) * 0.025
		chloe_bot.rotation.y = 0.42 + sin(t_sec * 1.1) * 0.08

	if crosshair_reticle and player:
		var hit_flash := _reticle_col if _damage_flash_timer <= 0.0 else Color(1.0, 0.25, 0.18)
		crosshair_reticle.set_state(hit_flash, player.is_aiming)
	if _damage_flash_timer > 0.0:
		_damage_flash_timer = maxf(0.0, _damage_flash_timer - delta)
		if _damage_flash:
			_damage_flash.color = Color(1.0, 0.22, 0.14, _damage_flash_timer * 0.45)
	elif _damage_flash and _damage_flash.color.a > 0.0:
		_damage_flash.color = Color(1.0, 0.22, 0.14, 0.0)

	if state in [GameState.MENU, GameState.WAVE_SUMMARY]:
		_check_portal_collisions()
	elif state == GameState.COMBAT and prompt_active:
		_check_direction_progress()

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

	if state == GameState.COMBAT and prompt_active and prompt_clean_try and int(current_spec.get("tier", 0)) >= 1:
		prompt_timer -= delta
		timer_bar.value = clampf((prompt_timer / PROMPT_TIME_LIMIT) * 100.0, 0.0, 100.0)
		if prompt_timer <= 0.0:
			prompt_clean_try = false
			combo = 0
			shield_hp = maxf(10.0, shield_hp - 10.0)
			var ptype := str(current_spec.get("prompt_type", "VOCAB"))
			if ptype == "DIRECTION":
				var cur_key: String = str(_dir_steps[_dir_step_idx]) if _dir_step_idx < _dir_steps.size() else "gauche"
				var d_info: Dictionary = VocabData.DIRECTION_INFO.get(cur_key, {})
				_show_feedback("! Time up — walk onto or shoot the gold pad: %s (%s)!" % [d_info.get("fr", ""), d_info.get("en", "")], false)
			else:
				var target_tag := str(current_spec["target_id"])
				_highlight_true_target(target_tag)
			_play_slow_assist()
			if ptype != "DIRECTION":
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
	assert(test_srs.get_active_campaign_sector() == 0, "New campaign should start at Map 1 (Sector 0)")
	var map1_pool := test_srs.get_candidate_pool()
	assert(map1_pool.size() == 5 and map1_pool.has("tasse") and map1_pool.has("pain"), "Map 1 candidate pool should strictly match Map 1's 5 Café words")
	test_srs.mark_calibrated("tasse")
	var r1 := test_srs.record_result("tasse", true, false, [])
	assert(int(r1["new_tier"]) == 1, "Clean hit should advance Level 1 -> Level 2")
	var r2 := test_srs.record_result("tasse", true, false, [])
	assert(int(r2["new_tier"]) == 2, "Clean hit should advance Level 2 -> Level 3")
	var r_err := test_srs.record_result("tasse", false, false, ["fromage"])
	assert(int(r_err["new_tier"]) == 1, "Mistake should drop Level 3 -> Level 2 and log confusion")
	var dir_spec := test_srs.build_direction_prompt_spec(2, 5)
	assert(str(dir_spec["prompt_type"]) == "DIRECTION" and dir_spec["steps"].size() == 2, "Direction sequence spec should have 2 steps")
	var dp_spec := test_srs.build_daily_phrase_prompt_spec(0, 1)
	assert(str(dp_spec["prompt_type"]) == "DAILY_PHRASE" and str(dp_spec["target_id"]) == "Excusez-moi, l'addition, s'il vous plaît !", "Everyday phrase spec should match Excusez-moi, l'addition, s'il vous plaît !")
	print("VERIFY_OK: Recognizable 3D Places, French-Speaking Chloé, Everyday Phrases & Direction Pads verified.")

	# 1. Title Screen in Au Café Parisien: Bistro tables, Haussmann facade, striped awning, Chloé speaking French
	srs.reset_progress()
	srs.sector_filter = 0
	_enter_menu()
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/01_menu.png")

	# 2. Step 1 in Au Café Parisien: New Word Spotlight ("la tasse") + custom 3D Baguette ("le pain") + Cheese Wheel ("le fromage") on Café Bistro Tables
	srs.reset_progress()
	srs.sector_filter = 0
	_on_start_mission_pressed()
	_clear_drones()
	if _display_tables_root:
		_display_tables_root.visible = true
	current_spec = srs.build_prompt_spec("tasse")
	var demo_ids := ["pain", "tasse", "fromage"]
	var demo_xs := [-4.2, 0.0, 4.2]
	for i in range(3):
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(demo_ids[i], Vector3(demo_xs[i], 1.82, -0.6), player.global_position, 0.0, 1.18)
		d.set_slot_badge(i + 1)
		if demo_ids[i] == "tasse":
			d.show_calibration_card("la tasse", "the cup / mug")
		active_drones.append(d)
	var tasse_item := VocabData.get_by_id("tasse")
	_chloe_say("« Voici la tasse ! » (the cup / mug) — Phrase : « %s »" % str(tasse_item["phrase_fr"]))
	_refresh_prompt_hud()
	player.look_toward_point(Vector3(0.0, 1.9, -0.6))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/02_calibration_3d.png")

	# 3. Step 2 in La Gare du Nord (Train Station Platform with parked TGV high-speed train): Spoken Everyday Phrase ("À quelle heure part le train pour Lyon ?")
	srs.sector_filter = 3
	_apply_map_theme(3)
	if _display_tables_root:
		_display_tables_root.visible = true
	for vid in ["train", "avion", "voiture", "velo", "valise"]:
		srs.mark_calibrated(vid)
		srs.cards[vid]["tier"] = 1
	_clear_drones()
	current_spec = srs.build_prompt_spec("train")
	var station_ids := ["valise", "train", "velo"]
	for i in range(3):
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(station_ids[i], Vector3(demo_xs[i], 1.82, -0.6), player.global_position, 0.0, 1.16)
		d.set_slot_badge(i + 1)
		active_drones.append(d)
	_chloe_say("« À quelle heure part le train pour Lyon ? » (What time does the train for Lyon leave?)")
	_refresh_prompt_hud()
	_update_stats_hud()
	player.look_toward_point(Vector3(0.0, 1.9, -0.6))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/03_combat_pure_listening.png")

	# 4. Step 5 in La Maison (Parisian Apartment with parquet floor, fireplace & bookshelves): Clean non-overlapping 3D Direction Pads ("À gauche, puis en haut !")
	srs.sector_filter = 1
	_apply_map_theme(1)
	_clear_drones()
	current_spec = srs.build_direction_prompt_spec(2, 5)
	_spawn_direction_drones(current_spec)
	_chloe_say(str(current_spec["chloe_tip"]))
	_refresh_prompt_hud()
	_update_stats_hud()
	player.position = Vector3(0.0, 0.30, 6.6)
	player.look_toward_point(Vector3(0.0, 1.25, 1.6))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/06_a2_spatial_modifiers.png")

	# 5. Step 4 in Au Café Parisien: 3 Parisian Café Chalkboard Signboards ("Excusez-moi, l'addition, s'il vous plaît !")
	srs.sector_filter = 0
	_apply_map_theme(0)
	_clear_drones()
	current_spec = srs.build_daily_phrase_prompt_spec(0, 1)
	_spawn_grammar_drones(current_spec)
	_chloe_say("« En France (%s) : » %s" % [str(current_spec["situation_en"]), str(current_spec["chloe_tip"])])
	_refresh_prompt_hud()
	_update_stats_hud()
	player.position = Vector3(0.0, 0.30, 6.6)
	player.look_toward_point(Vector3(0.0, 1.95, -0.6))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/07_b1_grammar_breach.png")

	# 6. 3D Practice Gallery in Jardin du Luxembourg (Fountain & Park)
	feedback_banner.visible = false
	_on_enter_gallery_pressed()
	_load_gallery_sector(6)
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/05_gallery_study.png")

	# 7. Interactive [Tab] Word & Phrase Book — Words with [♪ Phrase] buttons
	lexicon_tab = "A1"
	_toggle_lexicon(true)
	for i in range(4):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/04_srs_lexicon.png")

	# 8. Interactive [Tab] Word & Phrase Book — ★ Phrases (18) Day-to-Day Conversational French Tab
	lexicon_tab = "PHRASES"
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
