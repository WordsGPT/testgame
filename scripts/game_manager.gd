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
var direction_pads_root: Node3D
var chloe_bot: Node3D
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


func _build_arena_geometry() -> void:
	var arena := Node3D.new()
	arena.name = "HolodeckArena"
	world_root.add_child(arena)

	var grass_mat := _make_mat(Color(0.32, 0.50, 0.24), 0.90, 0.0)
	_mat_floor = _make_mat(Color(0.72, 0.56, 0.44), 0.88, 0.0)
	_mat_tile = _make_mat(Color(0.80, 0.66, 0.54), 0.88, 0.0)
	_mat_pillar = _make_mat(Color(0.48, 0.28, 0.16), 0.84, 0.0)
	_mat_wall = _make_mat(Color(0.90, 0.82, 0.70), 0.86, 0.0)
	_mat_trim = _make_mat(Color(0.80, 0.22, 0.18), 0.82, 0.0)
	var leaf_mat := _make_mat(Color(0.24, 0.48, 0.22), 0.88, 0.0)
	var leaf_light := _make_mat(Color(0.32, 0.56, 0.26), 0.88, 0.0)

	# Outer grass park & inner map courtyard floor
	_add_static_box(arena, Vector3(64.0, 0.5, 64.0), Vector3(0, -0.28, 0), Vector3.ZERO, grass_mat, true)
	_add_static_box(arena, Vector3(26.0, 0.10, 28.0), Vector3(0, -0.02, -1.0), Vector3.ZERO, _mat_floor, true)

	# Alternating lane strips
	for lx in [-6.0, -2.0, 2.0, 6.0]:
		_add_static_box(arena, Vector3(2.8, 0.03, 16.0), Vector3(lx, 0.02, -0.5), Vector3.ZERO, _mat_tile, false)

	# 1. Central stone jump-pad plinth ("EN HAUT" directional jump target!)
	_add_static_box(arena, Vector3(2.8, 0.42, 2.4), Vector3(0.0, 0.21, 2.2), Vector3.ZERO, _mat_wall, true)
	_add_static_box(arena, Vector3(3.0, 0.08, 2.6), Vector3(0.0, 0.44, 2.2), Vector3.ZERO, _mat_trim, false)

	# 2. Left & Right Mid-Court Tactical Cover Pillars
	for side_x in [-4.5, 4.5]:
		_add_static_box(arena, Vector3(1.35, 1.45, 0.85), Vector3(side_x, 0.72, 2.8), Vector3.ZERO, _mat_wall, true)
		_add_static_box(arena, Vector3(1.50, 0.14, 0.98), Vector3(side_x, 1.50, 2.8), Vector3.ZERO, _mat_trim, false)

	# 3. Forward Flanking Step Blocks
	for fwd_x in [-6.8, 6.8]:
		_add_static_box(arena, Vector3(1.8, 0.55, 1.8), Vector3(fwd_x, 0.27, -0.4), Vector3.ZERO, _mat_pillar, true)
		_add_static_box(arena, Vector3(1.95, 0.10, 1.95), Vector3(fwd_x, 0.58, -0.4), Vector3.ZERO, _mat_trim, false)

	# Practice Gallery terrace at north end
	_add_static_box(arena, Vector3(20.0, 0.20, 6.0), Vector3(0, 0.10, -13.5), Vector3.ZERO, _mat_tile, true)

	# Perimeter walls & posts
	var oct_r := 18.5
	for i in range(8):
		var ang_deg := float(i) * 45.0
		var ang_rad := deg_to_rad(ang_deg)
		var wx := sin(ang_rad) * oct_r
		var wz := cos(ang_rad) * oct_r
		_add_static_box(arena, Vector3(15.8, 2.2, 0.75), Vector3(wx, 1.1, wz), Vector3(0, ang_deg, 0), _mat_wall, true)
		_add_static_box(arena, Vector3(16.0, 0.24, 0.92), Vector3(wx, 2.30, wz), Vector3(0, ang_deg, 0), _mat_trim, false)

		var c_ang := deg_to_rad(ang_deg + 22.5)
		var cx := sin(c_ang) * (oct_r - 0.3)
		var cz := cos(c_ang) * (oct_r - 0.3)
		_add_static_box(arena, Vector3(0.65, 3.4, 0.65), Vector3(cx, 1.7, cz), Vector3(0, ang_deg + 22.5, 0), _mat_pillar, true)
		_add_static_box(arena, Vector3(0.85, 0.22, 0.85), Vector3(cx, 3.5, cz), Vector3(0, ang_deg + 22.5, 0), _mat_trim, false)

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
		_add_park_tree(arena, tree_spots[idx], sc, _mat_pillar, lmat)

	# 3D Map Location Banner at the front of the courtyard
	map_banner_lbl = Label3D.new()
	map_banner_lbl.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	map_banner_lbl.text = "📍 MAP 1: AU CAFÉ PARISIEN  •  Paris Café & Food"
	map_banner_lbl.position = Vector3(0, 4.35, -8.5)
	map_banner_lbl.font_size = 44
	map_banner_lbl.modulate = Color(1.0, 0.94, 0.72)
	map_banner_lbl.outline_size = 12
	map_banner_lbl.outline_modulate = Color(0.08, 0.06, 0.04, 0.96)
	arena.add_child(map_banner_lbl)

	gallery_sign = Label3D.new()
	gallery_sign.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	gallery_sign.text = "PRACTICE GALLERY (MAPS 1–9)  •  SHOOT ANY OBJECT TO HEAR IT"
	gallery_sign.position = Vector3(0, 4.45, -15.5)
	gallery_sign.font_size = 38
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
	if map_banner_lbl:
		map_banner_lbl.text = "◈ MAP %d/9: %s  —  %s" % [
			_active_map_idx + 1,
			String(s_info["name_fr"]).to_upper(),
			str(s_info["name_en"])
		]

	if not map_props_root:
		return
	for ch in map_props_root.get_children():
		ch.queue_free()

	# Spawn Map-Specific 3D Architectural Landmarks so every Map Stage looks distinct!
	var accent_mat := _make_mat(s_info["trim_col"], 0.75, 0.0)
	var cream_mat := _make_mat(s_info["wall_col"], 0.82, 0.0)
	var post_mat := _make_mat(s_info["pillar_col"], 0.80, 0.0)

	match _active_map_idx:
		0: # Map 1: Au Café Parisien — Striped Bistro Awnings & Sidewalk Café Tables
			for sx in [-9.6, 9.6]:
				_add_static_box(map_props_root, Vector3(2.4, 0.18, 9.0), Vector3(sx, 3.1, 0.0), Vector3(0, 0, -14.0 if sx < 0 else 14.0), accent_mat, false)
				_add_static_box(map_props_root, Vector3(0.22, 3.0, 0.22), Vector3(sx, 1.5, -3.8), Vector3.ZERO, post_mat, false)
				_add_static_box(map_props_root, Vector3(0.22, 3.0, 0.22), Vector3(sx, 1.5, 3.8), Vector3.ZERO, post_mat, false)
		1: # Map 2: La Maison — Warm Apartment Archways & Cozy Rug
			_add_static_box(map_props_root, Vector3(9.5, 0.04, 6.5), Vector3(0.0, 0.04, 2.2), Vector3.ZERO, accent_mat, false)
			for sx in [-8.8, 8.8]:
				_add_static_box(map_props_root, Vector3(0.6, 3.6, 4.2), Vector3(sx, 1.8, 0.5), Vector3.ZERO, cream_mat, false)
				_add_static_box(map_props_root, Vector3(0.8, 0.35, 4.6), Vector3(sx, 3.7, 0.5), Vector3.ZERO, accent_mat, false)
		2: # Map 3: Les Sorties — Parisian Boutique Colonnade Canopies
			for sx in [-9.2, 9.2]:
				_add_static_box(map_props_root, Vector3(1.8, 0.30, 10.0), Vector3(sx, 3.4, 0.0), Vector3.ZERO, accent_mat, false)
				for pz in [-4.0, 0.0, 4.0]:
					_add_static_box(map_props_root, Vector3(0.35, 3.4, 0.35), Vector3(sx, 1.7, pz), Vector3.ZERO, cream_mat, false)
		3: # Map 4: La Gare du Nord — Overhead Railway Concourse Girders & Yellow Platform Lines
			for gz in [-4.5, 1.5]:
				_add_static_box(map_props_root, Vector3(21.0, 0.38, 0.45), Vector3(0.0, 4.8, gz), Vector3.ZERO, post_mat, false)
				_add_static_box(map_props_root, Vector3(0.45, 4.8, 0.45), Vector3(-10.2, 2.4, gz), Vector3.ZERO, post_mat, false)
				_add_static_box(map_props_root, Vector3(0.45, 4.8, 0.45), Vector3(10.2, 2.4, gz), Vector3.ZERO, post_mat, false)
			_add_static_box(map_props_root, Vector3(18.0, 0.04, 0.28), Vector3(0.0, 0.04, -4.8), Vector3.ZERO, accent_mat, false)
		4: # Map 5: Studio Musique & Tech — Concert Lighting Truss & Glowing Stage Strips
			_add_static_box(map_props_root, Vector3(18.0, 0.32, 0.32), Vector3(0.0, 4.9, -4.2), Vector3.ZERO, accent_mat, false)
			for sx in [-8.8, 8.8]:
				_add_static_box(map_props_root, Vector3(0.38, 4.9, 0.38), Vector3(sx, 2.45, -4.2), Vector3.ZERO, post_mat, false)
		5: # Map 6: En Centre-Ville — Haussmann Street Pillars & Green Pharmacy Cross
			var pharm_green := _make_mat(Color(0.15, 0.88, 0.45), 0.4, 0.0, true)
			_add_static_box(map_props_root, Vector3(1.1, 0.32, 0.18), Vector3(-8.8, 3.5, -2.5), Vector3.ZERO, pharm_green, false)
			_add_static_box(map_props_root, Vector3(0.32, 1.1, 0.18), Vector3(-8.8, 3.5, -2.5), Vector3.ZERO, pharm_green, false)
		6: # Map 7: Jardin du Luxembourg — Extra Blooming Garden Planters & Park Trees
			var leaf_m := _make_mat(Color(0.26, 0.54, 0.24), 0.85, 0.0)
			for tx in [-10.0, 10.0]:
				_add_park_tree(map_props_root, Vector3(tx, 0.0, -2.5), 0.92, post_mat, leaf_m)
				_add_park_tree(map_props_root, Vector3(tx, 0.0, 3.2), 0.88, post_mat, leaf_m)
		7: # Map 8: L'Observatoire — Solar Gold Observatory Archways
			for sx in [-9.2, 9.2]:
				_add_static_box(map_props_root, Vector3(0.5, 4.2, 0.5), Vector3(sx, 2.1, -1.5), Vector3.ZERO, accent_mat, false)
			_add_static_box(map_props_root, Vector3(18.8, 0.28, 0.4), Vector3(0.0, 4.2, -1.5), Vector3.ZERO, accent_mat, false)
		8: # Map 9: Le Château Médiéval — Castle Battlement Merlons & Royal Banners
			for bx in [-9.0, -6.0, -3.0, 3.0, 6.0, 9.0]:
				_add_static_box(map_props_root, Vector3(1.2, 0.85, 0.85), Vector3(bx, 2.7, -8.8), Vector3.ZERO, cream_mat, false)
				_add_static_box(map_props_root, Vector3(0.55, 1.8, 0.12), Vector3(bx, 1.8, -8.3), Vector3.ZERO, accent_mat, false)


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

		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.88
		tm.outer_radius = 1.08
		var rmat := StandardMaterial3D.new()
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rmat.albedo_color = Color(0.38, 0.82, 1.0, 0.85)
		tm.material = rmat
		ring.mesh = tm
		pad_root.add_child(ring)

		var lbl := Label3D.new()
		lbl.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.pixel_size = 0.0038
		lbl.font_size = 36
		lbl.outline_size = 10
		lbl.modulate = Color(1.0, 0.96, 0.82)
		lbl.outline_modulate = Color(0.05, 0.06, 0.09, 0.96)
		lbl.text = str(info["badge"])
		lbl.position = Vector3(0.0, 1.48, 0.0)
		pad_root.add_child(lbl)

		_dir_pad_nodes[dir_key] = {
			"root": pad_root,
			"ring_mat": rmat,
			"label": lbl,
		}


func _spawn_chloe_bot() -> void:
	chloe_bot = Node3D.new()
	chloe_bot.position = Vector3(-2.3, 1.50, 2.4)
	world_root.add_child(chloe_bot)

	var drone_res := load("res://assets/models/drone.blend") as PackedScene
	if drone_res:
		var d_inst := drone_res.instantiate() as Node3D
		d_inst.scale = Vector3.ONE * 0.42
		chloe_bot.add_child(d_inst)

	var heart_res := load("res://assets/models/coeur.blend") as PackedScene
	if heart_res:
		var h_inst := heart_res.instantiate() as Node3D
		h_inst.position = Vector3(0.0, 0.28, 0.0)
		h_inst.scale = Vector3.ONE * 0.30
		chloe_bot.add_child(h_inst)

	var nametag := Label3D.new()
	nametag.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	nametag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nametag.no_depth_test = true
	nametag.pixel_size = 0.0030
	nametag.font_size = 30
	nametag.outline_size = 8
	nametag.modulate = Color(1.0, 0.88, 0.42)
	nametag.outline_modulate = Color(0.06, 0.05, 0.08, 0.95)
	nametag.text = "★ Chloé (Guide)"
	nametag.position = Vector3(0.0, 0.64, 0.0)
	chloe_bot.add_child(nametag)


func _chloe_say(msg: String, voice_file: String = "") -> void:
	if companion_lbl:
		companion_lbl.text = "★ Chloé:  " + msg
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
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	stats_panel.position = Vector2(20, 14)
	stats_panel.custom_minimum_size = Vector2(220, 84)
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(stats_panel)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	stats_panel.add_child(sv)

	wave_lbl = Label.new()
	wave_lbl.text = "WAVE 1  •  1/6"
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
	shield_bar.show_percentage = false
	shield_bar.max_value = 100.0
	shield_bar.value = 100.0
	shield_bar.custom_minimum_size = Vector2(168, 8)
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.05, 0.07, 0.10, 0.55)
	sb_bg.set_corner_radius_all(4)
	shield_bar.add_theme_stylebox_override("background", sb_bg)
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.28, 0.94, 0.52)
	sb_fill.set_corner_radius_all(4)
	shield_bar.add_theme_stylebox_override("fill", sb_fill)
	sv.add_child(shield_bar)

	# 5. Friendly Companion Chat Pill ("Chloé" — bottom-left translucent glass pill)
	companion_panel = PanelContainer.new()
	var comp_style := _make_panel_style(Color(0.06, 0.08, 0.12, 0.74), Color(1.0, 0.84, 0.36, 0.55), 20, 1)
	comp_style.content_margin_left = 16
	comp_style.content_margin_right = 16
	comp_style.content_margin_top = 7
	comp_style.content_margin_bottom = 7
	companion_panel.add_theme_stylebox_override("panel", comp_style)
	companion_panel.position = Vector2(20, 626)
	companion_panel.custom_minimum_size = Vector2(580, 38)
	companion_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(companion_panel)

	companion_lbl = Label.new()
	companion_lbl.text = "★ Chloé: Salut ! Walk into the golden portal or shoot it to start!"
	companion_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	companion_lbl.add_theme_font_size_override("font_size", 13)
	companion_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	companion_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.95))
	companion_lbl.add_theme_constant_override("outline_size", 4)
	companion_panel.add_child(companion_lbl)

	# 6. Borderless Bottom Controls Readout (Zero background box!)
	var bot_panel := PanelContainer.new()
	bot_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	bot_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bot_panel.position = Vector2(-460, -30)
	bot_panel.custom_minimum_size = Vector2(920, 26)
	bot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bot_panel)

	hotkeys_lbl = Label.new()
	hotkeys_lbl.text = "[WASD] Move & Step on Pads   •   [Shift] Dash   •   [Space] Jump   •   [Click] Shoot   •   [E] Replay   •   [Tab] Word Book"
	hotkeys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkeys_lbl.add_theme_font_size_override("font_size", 13)
	hotkeys_lbl.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 0.88))
	hotkeys_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.92))
	hotkeys_lbl.add_theme_constant_override("outline_size", 5)
	bot_panel.add_child(hotkeys_lbl)

	_build_menu_overlay()
	_build_summary_overlay()
	_build_lexicon_overlay()


func _build_menu_overlay() -> void:
	# Playable 3D Hub Header — no giant center box blocking the 3D portals!
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	menu_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	menu_panel.position = Vector2(-340, 12)
	menu_panel.custom_minimum_size = Vector2(680, 96)
	menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(menu_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_child(vb)

	var title := Label.new()
	title.text = "FRANC-TIREUR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.36))
	title.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.95))
	title.add_theme_constant_override("outline_size", 8)
	vb.add_child(title)

	menu_stats_lbl = Label.new()
	menu_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_stats_lbl.add_theme_font_size_override("font_size", 15)
	menu_stats_lbl.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98))
	menu_stats_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.95))
	menu_stats_lbl.add_theme_constant_override("outline_size", 6)
	vb.add_child(menu_stats_lbl)

	sector_btn = Button.new()
	sector_btn.visible = false
	vb.add_child(sector_btn)

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
	lexicon_header_lbl.text = "FRENCH WORD BOOK (45 Words) — Click [♪] to hear native pronunciation"
	lexicon_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lexicon_header_lbl.add_theme_font_size_override("font_size", 15)
	lexicon_header_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))
	top.add_child(lexicon_header_lbl)

	for tab_spec in [
		["ALL", "All (45)"],
		["A1", "Maps 1–4 (20)"],
		["A2", "Maps 5–7 (15)"],
		["B1", "Maps 8–9 (10)"],
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
		card.custom_minimum_size = Vector2(228, 102)
		card.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color(0.11, 0.14, 0.20, 0.88), tier_cols[t_idx], 10, 1)
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
	player.look_toward_point(Vector3(0.0, 2.0, 0.4))
	player.controls_enabled = true
	hud_root.visible = true
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
	_chloe_say(str(s_info.get("chloe_intro", "Salut ! Walk into the golden portal or shoot it to start!")), "chloe_welcome.ogg")


func _spawn_menu_portals() -> void:
	_clear_drones()
	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)
	var s_info := VocabData.SECTORS[act_s]
	var sec_ids := VocabData.get_sector_ids(act_s)
	var center_vid: String = sec_ids[0] if not sec_ids.is_empty() else "pomme"

	# 1. Center Play Portal Gate (Walk into it with W or Shoot it!)
	var p_start := TargetDrone.new()
	drones_root.add_child(p_start)
	p_start.setup(center_vid, Vector3(0.0, 2.05, 0.4), player.global_position, 0.12, 1.25, "PORTAL_START")
	p_start.configure_as_portal_crystal(
		"▶ PLAY MAP %d: %s" % [act_s + 1, String(s_info["name_fr"]).to_upper()],
		"%s  •  WALK IN [W] OR SHOOT TO START" % String(s_info["name_en"]),
		Color(1.0, 0.84, 0.22)
	)
	active_drones.append(p_start)

	# 2. Left Practice Range Portal
	var p_gal := TargetDrone.new()
	drones_root.add_child(p_gal)
	p_gal.setup("couronne", Vector3(-4.8, 2.00, 1.1), player.global_position, 0.10, 1.05, "PORTAL_GALLERY")
	p_gal.configure_as_portal_crystal(
		"◈ PRACTICE RANGE",
		"WALK IN OR SHOOT",
		Color(0.28, 0.94, 0.58)
	)
	active_drones.append(p_gal)

	# 3. Right Map Switcher Portal
	var p_stg := TargetDrone.new()
	drones_root.add_child(p_stg)
	p_stg.setup("globe", Vector3(4.8, 2.00, 1.1), player.global_position, 0.10, 1.05, "PORTAL_STAGE")
	p_stg.configure_as_portal_crystal(
		"↻ SWITCH MAP (%d/9)" % [act_s + 1],
		"SHOOT TO CHANGE MAP LOCATION",
		Color(0.38, 0.82, 1.0)
	)
	active_drones.append(p_stg)


func _refresh_menu_labels() -> void:
	var st := srs.get_summary_stats()
	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	var s_info := VocabData.SECTORS[act_s]
	menu_stats_lbl.text = "◈ Map %d/9: %s (%s)  •  Words Mastered: %d/%d" % [
		act_s + 1, s_info["name_fr"], s_info["name_en"], st["seen"], st["total_words"]
	]
	if prompt_main_lbl:
		prompt_main_lbl.text = "Walk into the Golden Portal [W] or Shoot It to Play!"
	if prompt_sub_lbl:
		prompt_sub_lbl.visible = false


func _on_cycle_sector() -> void:
	audio.play_sfx("click")
	var order := [-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, -5]
	var cur_idx := order.find(srs.sector_filter)
	srs.sector_filter = order[(cur_idx + 1) % order.size()]
	srs.save_progress()
	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)
	_refresh_menu_labels()
	var s_info := VocabData.SECTORS[act_s]
	_chloe_say(str(s_info.get("chloe_intro", "")))
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
	radio_panel.visible = true
	hover_info_lbl.text = ""
	_set_gallery_visible(false)
	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)
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
	radio_panel.visible = true
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
	_apply_map_theme(gallery_sector)
	var ids := VocabData.get_sector_ids(gallery_sector)
	_refresh_gallery_pedestals(ids)
	var s_info := VocabData.SECTORS[gallery_sector]
	speaker_lbl.text = "◈ 3D PRACTICE GALLERY (%s)" % s_info["cefr"]
	mode_tag_lbl.text = "Press [1–9] to Switch Map (1–9)  •  Press [M] to Start Combat Round"
	prompt_main_lbl.text = "◈ Map %d: %s  (%s)" % [gallery_sector + 1, s_info["name_fr"], s_info["name_en"]]
	prompt_sub_lbl.text = "Pronunciation Focus: %s — Shoot any pedestal to hear native French audio!" % s_info["focus"]
	_chloe_say("Practice Range for %s! Shoot any pedestal to hear its native pronunciation, or press [1–9] to switch maps." % s_info["name_fr"])
	timer_bar.value = 100.0


func _begin_wave() -> void:
	prompt_in_wave = 0
	wave_hits_clean = 0
	shield_hp = minf(100.0, shield_hp + 25.0)
	_set_gallery_visible(false)
	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)
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

	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)

	current_spec = srs.build_wave_prompt_spec(prompt_in_wave, wave_number)
	var ptype := str(current_spec.get("prompt_type", "VOCAB"))

	if ptype == "DIRECTION":
		_spawn_direction_drones(current_spec)
	elif ptype == "MODIFIER":
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

	# Have Chloé give a warm, friendly tip for the current challenge
	if ptype == "DIRECTION":
		_chloe_say(str(current_spec.get("chloe_tip", "Move onto the glowing directional pad or shoot its crystal!")))
	elif ptype == "VOCAB":
		var item := VocabData.get_by_id(str(current_spec.get("target_id", "")))
		var s_info := VocabData.SECTORS[clampi(int(item.get("sector", act_s)), 0, 8)]
		var tier := int(current_spec.get("tier", 0))
		if tier == 0:
			_chloe_say("New word in %s: « %s » (%s)! %s" % [str(s_info["name_fr"]), str(item.get("fr_def", "")), str(item.get("en", "")), str(item.get("tip", ""))])
		elif tier == 1:
			_chloe_say("Spot « %s »! %s" % [str(item.get("fr_def", "")), str(item.get("tip", ""))])
		else:
			_chloe_say("Listen closely in %s! Press [E] to replay or [H] if you want a hint from me." % str(s_info["name_fr"]))
	elif ptype == "MODIFIER":
		_chloe_say("Look at the size, speed, or position! %s" % str(current_spec.get("sub_en", "")))
	elif ptype == "SCENARIO":
		_chloe_say("Real-life phrase: %s" % str(current_spec.get("sub_en", "")))

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

	var order := ["gauche", "avant", "haut", "arriere", "droite"]
	for i in range(order.size()):
		var d_key: String = order[i]
		var d_info: Dictionary = VocabData.DIRECTION_INFO[d_key]
		var pad_pos: Vector3 = d_info["pos"]
		var drone := TargetDrone.new()
		drones_root.add_child(drone)
		var c_pos := pad_pos + Vector3(0.0, 0.85, 0.0)
		drone.setup("etoile", c_pos, player.global_position, 0.14, 0.52, "DIR_" + d_key)
		drone.set_slot_badge(i + 1)
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

	for d in active_drones:
		if is_instance_valid(d) and not d.is_destroyed and d.drone_tag.begins_with("DIR_"):
			var d_key := d.drone_tag.trim_prefix("DIR_")
			var is_cur: bool = (d_key == cur_key)
			var col: Color = Color(1.0, 0.86, 0.22) if is_cur else Color(0.38, 0.82, 1.0)
			d.set_beacon(is_cur, col)


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
		# Central Jump Plinth or jumping in place triggers "En haut !"
		if (flat_dist < 2.25 and p_pos.y > 0.42) or p_pos.y > 0.85:
			_advance_direction_step(pad_pos)
	else:
		if flat_dist < 1.95:
			_advance_direction_step(pad_pos)


func _advance_direction_step(from_pos: Vector3) -> void:
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
		_chloe_say("Bien ! Step %d/%d: now go « %s » (%s)!" % [_dir_step_idx + 1, _dir_steps.size(), str(next_info["fr"]), str(next_info["en"])])
	else:
		prompt_active = false
		feedback_banner.visible = false
		audio.play_sfx("hit_ok", 0.02, -2.0)
		combo += 1
		wave_hits_clean += 1
		var pts := 125 + _dir_steps.size() * 50
		score += pts
		_spawn_ground_pickup(from_pos + Vector3(0.0, 0.6, 0.0))
		srs.global_step += 1
		srs.save_progress()
		prompt_main_lbl.text = "✓ %s   (%s)" % [str(current_spec["prompt_fr"]), str(current_spec["prompt_en"])]
		_chloe_say("Super mouvement ! You nailed « %s » (%s)!" % [str(current_spec["prompt_fr"]), str(current_spec["prompt_en"])])
		_update_stats_hud()
		transition_delay = 1.05


func _spawn_vocab_drones(spec: Dictionary) -> void:
	var target_id := str(spec["target_id"])
	var tier := int(spec.get("tier", 0))
	var decoy_count := 2 if tier == 0 else 3
	var distractors := srs.select_distractors(target_id, decoy_count, str(spec["required_decoy"]))
	var spawn_ids: Array[String] = [target_id]
	spawn_ids.append_array(distractors)
	spawn_ids.shuffle()

	var n := spawn_ids.size()
	var xs3 := [-4.6, 0.0, 4.6]
	var xs4 := [-6.4, -2.2, 2.2, 6.4]
	for i in range(n):
		var sx: float = xs3[i] if n == 3 else (xs4[i] if i < 4 else (float(i - 2) * 3.5))
		var sz: float = -0.5 if tier == 0 else (-2.6 if (i % 2 == 0) else -3.6)
		var height := 2.15 + (0.35 if (i % 2 == 1 and tier > 0) else 0.0)
		var d := TargetDrone.new()
		drones_root.add_child(d)
		var mv := 0.25 if tier == 0 else (0.95 + float(mini(wave_number, 5)) * 0.10)
		d.setup(spawn_ids[i], Vector3(sx, height, sz), player.global_position, mv, 1.15)
		d.set_slot_badge(i + 1)
		if tier == 0:
			d.approach_speed = 0.0
			if spawn_ids[i] == target_id:
				var item := VocabData.get_by_id(target_id)
				d.show_calibration_card(str(item.get("fr_def", target_id)), str(item.get("en", "")))
		else:
			d.approach_speed = 0.56 + float(mini(wave_number, 6)) * 0.06
			d.defense_z = 3.6
			d.can_fire_plasma = true
			d.reached_defense_line.connect(_on_drone_reached_defense_line)
			d.fired_plasma.connect(_spawn_enemy_plasma)
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
		d.can_fire_plasma = true
		d.reached_defense_line.connect(_on_drone_reached_defense_line)
		d.fired_plasma.connect(_spawn_enemy_plasma)
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
		if ptype == "MODIFIER" and show_en:
			var short_en := str(current_spec.get("sub_en", "")).split("•")[0].strip_edges()
			prompt_main_lbl.text = "♪  %s   (%s)" % [str(current_spec["prompt_fr"]), short_en]
		elif ptype == "VOCAB" and prompt_hint_stage >= 2 and int(current_spec.get("tier", 0)) >= 1:
			var t_item := VocabData.get_by_id(str(current_spec.get("target_id", "")))
			prompt_main_lbl.text = "♪  %s  =  %s" % [str(current_spec["prompt_fr"]), str(t_item.get("en", ""))]
		else:
			prompt_main_lbl.text = "♪  %s" % str(current_spec["prompt_fr"])
	else:
		if ptype == "MODIFIER":
			prompt_main_lbl.text = "◉ LISTEN: Size / Speed Challenge!  [E] Replay • [H] Hint"
		elif int(current_spec["tier"]) >= 3:
			prompt_main_lbl.text = "◉ LISTEN: French Clue!  [E] Replay • [H] Hint"
		else:
			prompt_main_lbl.text = "◉ LISTEN & SHOOT!   [E] Replay  •  [H] Hint"

	prompt_sub_lbl.visible = false


# ==============================================================================
# SHOOTING, PORTAL GATES, PLASMA DODGING, GOLD PICKUPS & INPUTS
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
		if td.drone_tag.begins_with("DIR_"):
			hover_info_lbl.text = "Walk/Jump Onto Pad [WASD/Space] or Shoot [Click]"
		elif td.is_portal_crystal:
			hover_info_lbl.text = "Walk Into Portal [WASD] or Shoot [Click]"
		elif td.is_grammar_crystal:
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
		_chloe_say("« %s » (%s) — %s" % [item["fr_def"], item["en"], item["tip"]])
		return

	if not (entity is TargetDrone):
		return

	var drone := entity as TargetDrone
	if drone.is_destroyed:
		return

	# Shooting any 3D Portal Gate (except directional challenge beacons) activates or cycles it!
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
				_chloe_say("Look for the bright gold pad: « %s » (%s)!" % [exp_info.get("fr", cur_key), exp_info.get("en", "")])
				_update_stats_hud()
			return

		var target_tag := str(current_spec["target_id"])

		if drone.drone_tag == target_tag:
			prompt_active = false
			feedback_banner.visible = false
			audio.play_sfx("hit_ok", 0.02, -1.5)
			var pts := 100
			var fast_bonus := (drone.global_position.z < 0.0 and int(current_spec.get("tier", 0)) >= 1)
			var action_shot := (not player.is_on_floor()) or (player._dash_timer > 0.0) or (player.global_position.z < 2.2)
			if prompt_clean_try:
				combo += 1
				wave_hits_clean += 1
				pts = (100 + combo * 25) + (50 if fast_bonus else 0) + (50 if action_shot else 0)
			else:
				pts = 75
			score += pts
			if prompt_clean_try and drone.custom_ok_label == "":
				var f_item := VocabData.get_by_id(target_tag)
				var bonus_tag := "ACTION SHOT!" if action_shot else ("FAST!" if fast_bonus else "✓")
				drone.custom_ok_label = "+%d %s %s (%s)" % [pts, bonus_tag, f_item.get("fr_def", target_tag), f_item.get("en", "")]

			var drop_pos := drone.global_position
			drone.explode_success(world_root, pts)
			active_drones.erase(drone)
			_spawn_ground_pickup(drop_pos)

			if ptype == "GRAMMAR":
				var gid := str(current_spec["grammar_id"])
				srs.record_grammar_result(gid, prompt_clean_try, prompt_used_assist)
				prompt_main_lbl.text = "✓ %s   (%s)" % [str(current_spec["sentence_full"]), str(current_spec["en"])]
			elif ptype == "MODIFIER":
				srs.global_step += 1
				srs.save_progress()
				prompt_main_lbl.text = "✓ %s" % str(current_spec["prompt_fr"])
				_chloe_say("Bravo ! You spotted « %s »!" % str(current_spec["prompt_fr"]))
			else:
				srs.record_result(target_tag, prompt_clean_try, prompt_used_assist, prompt_wrong_ids)
				var t_item := VocabData.get_by_id(target_tag)
				prompt_main_lbl.text = "✓ %s  =  %s" % [t_item["fr_def"], t_item["en"]]
				_chloe_say("Bien joué ! « %s » = %s.  %s" % [t_item["fr_def"], t_item["en"], t_item["tip"]])

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
				_chloe_say("Pas de souci ! Look for the gold-highlighted target (%s)!" % str(current_spec["prompt_fr"]))
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
				_chloe_say("Pas de souci ! That was « %s » (%s). Shoot the gold target « %s » (%s)!" % [
					hit_item["fr_def"], hit_item["en"], true_item["fr_def"], true_item["en"]
				])
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
	wave_lbl.text = "MAP %d  •  ROUND %d  •  %d/%d" % [_active_map_idx + 1, wave_number, prompt_in_wave, PROMPTS_PER_WAVE]
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

	audio.play_sfx("wave_up")

	var prev_map: int = _active_map_idx
	var act_s := srs.get_active_campaign_sector() if srs.sector_filter < 0 else clampi(srs.sector_filter, 0, 8)
	_apply_map_theme(act_s)
	var s_info := VocabData.SECTORS[act_s]
	radio_panel.visible = true
	prompt_main_lbl.text = "★ ROUND %d CLEAR (%d/%d)!  Walk Into the Golden Portal!" % [
		wave_number, wave_hits_clean, PROMPTS_PER_WAVE
	]
	timer_bar.value = 100.0

	if act_s != prev_map:
		_chloe_say("Bravo ! New Map Unlocked: Map %d — %s (%s)!" % [act_s + 1, s_info["name_fr"], s_info["name_en"]], "chloe_map_up.ogg")
	else:
		_chloe_say("Super travail ! Round %d complete! Walk into the golden portal when you're ready for Round %d." % [wave_number, wave_number + 1], "chloe_round_clear.ogg")

	# Spawn a glowing 3D Portal Gate in the courtyard + collectible Gold Stars on the floor!
	var p_next := TargetDrone.new()
	drones_root.add_child(p_next)
	p_next.setup("etoile", Vector3(0.0, 2.05, 0.4), player.global_position, 0.18, 1.30, "PORTAL_NEXT_WAVE")
	p_next.configure_as_portal_crystal(
		"★ NEXT ROUND (ROUND %d)" % (wave_number + 1),
		"Map %d: %s (%s)  •  Walk In [WASD] or Shoot!" % [act_s + 1, s_info["name_fr"], s_info["name_en"]],
		Color(1.0, 0.84, 0.22)
	)
	active_drones.append(p_next)

	_spawn_ground_pickup(Vector3(-2.6, 0.85, 2.4))
	_spawn_ground_pickup(Vector3(2.6, 0.85, 2.4))


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


func _spawn_enemy_plasma(origin_pos: Vector3) -> void:
	if state != GameState.COMBAT or not prompt_active or not is_instance_valid(player):
		return
	if _projectiles.size() >= 4:
		return

	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.24
	sm.height = 0.48
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.36, 0.18)
	sm.material = mat
	orb.mesh = sm

	var halo := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.42
	hm.height = 0.84
	var hmat := StandardMaterial3D.new()
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.albedo_color = Color(1.0, 0.65, 0.20, 0.38)
	hm.material = hmat
	halo.mesh = hm
	orb.add_child(halo)

	projectiles_root.add_child(orb)
	orb.global_position = origin_pos + Vector3(0.0, 0.1, 0.45)

	var aim_pos := player.global_position + Vector3(0.0, 1.25, 0.0)
	var dir := (aim_pos - orb.global_position).normalized()
	_projectiles.append({
		"node": orb,
		"vel": dir * 7.8,
		"life": 4.2,
		"dodged_awarded": false
	})


func _update_projectiles(delta: float) -> void:
	if _projectiles.is_empty():
		return
	var dt := minf(delta, 0.04)
	var space_state := get_world_3d().direct_space_state
	var p_center := player.global_position + Vector3(0.0, 1.2, 0.0)

	for i in range(_projectiles.size() - 1, -1, -1):
		var p: Dictionary = _projectiles[i]
		var node: Node3D = p["node"]
		if not is_instance_valid(node):
			_projectiles.remove_at(i)
			continue

		var old_pos := node.global_position
		var vel: Vector3 = p["vel"]
		var next_pos := old_pos + vel * dt
		p["life"] = float(p["life"]) - dt

		# Check if blocked by stone cover pillars/walls (collision mask 1)
		var q := PhysicsRayQueryParameters3D.create(old_pos, next_pos, 1)
		var hit := space_state.intersect_ray(q)
		if not hit.is_empty():
			node.queue_free()
			_projectiles.remove_at(i)
			continue

		node.global_position = next_pos
		var dist := next_pos.distance_to(p_center)
		if dist < 0.88:
			# Hit player!
			shield_hp = maxf(10.0, shield_hp - 8.0)
			_damage_flash_timer = 0.35
			audio.play_sfx("shield_hit", 0.02, -3.0)
			_update_stats_hud()
			node.queue_free()
			_projectiles.remove_at(i)
			continue
		elif not bool(p["dodged_awarded"]) and next_pos.z > p_center.z + 0.6 and dist < 3.6:
			p["dodged_awarded"] = true
			score += 25
			_update_stats_hud()

		if float(p["life"]) <= 0.0 or next_pos.z > 12.0 or absf(next_pos.x) > 15.0:
			node.queue_free()
			_projectiles.remove_at(i)


func _spawn_ground_pickup(world_pos: Vector3) -> void:
	if not pickups_root:
		return
	var root := Node3D.new()
	pickups_root.add_child(root)
	var gz := clampf(world_pos.z, -2.5, 5.5)
	var gx := clampf(world_pos.x, -6.5, 6.5)
	root.global_position = Vector3(gx, 0.85, gz)

	var star_model := Node3D.new()
	var star_scene := load("res://assets/models/etoile.blend") as PackedScene
	if star_scene:
		var inst := star_scene.instantiate() as Node3D
		if inst:
			star_model.add_child(inst)
	star_model.scale = Vector3.ONE * 0.72
	root.add_child(star_model)

	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.48
	tm.outer_radius = 0.56
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(1.0, 0.86, 0.22)
	tm.material = rmat
	ring.mesh = tm
	ring.position = Vector3(0.0, -0.45, 0.0)
	root.add_child(ring)

	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.0042
	lbl.font_size = 36
	lbl.outline_size = 10
	lbl.modulate = Color(1.0, 0.92, 0.32)
	lbl.outline_modulate = Color(0.08, 0.05, 0.02, 0.96)
	lbl.text = "★ +75"
	lbl.position = Vector3(0.0, 0.72, 0.0)
	root.add_child(lbl)

	_pickups.append({
		"node": root,
		"model": star_model,
		"life": 14.0,
		"phase": randf() * TAU
	})


func _update_pickups(delta: float) -> void:
	if _pickups.is_empty() or not is_instance_valid(player):
		return
	var p_pos := player.global_position
	for i in range(_pickups.size() - 1, -1, -1):
		var pk: Dictionary = _pickups[i]
		var node: Node3D = pk["node"]
		if not is_instance_valid(node):
			_pickups.remove_at(i)
			continue
		pk["life"] = float(pk["life"]) - delta
		var ph := float(pk["phase"]) + delta * 3.4
		pk["phase"] = ph
		var mdl: Node3D = pk["model"]
		if is_instance_valid(mdl):
			mdl.rotation.y += delta * 2.6
			mdl.position.y = sin(ph) * 0.14

		var flat_dist := Vector2(node.global_position.x - p_pos.x, node.global_position.z - p_pos.z).length()
		if flat_dist < 1.85:
			score += 75
			shield_hp = minf(100.0, shield_hp + 15.0)
			audio.play_sfx("hit_ok", 0.04, -2.5)
			_update_stats_hud()
			node.queue_free()
			_pickups.remove_at(i)
			continue

		if float(pk["life"]) <= 0.0:
			node.queue_free()
			_pickups.remove_at(i)


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
		if kc in [KEY_ENTER, KEY_KP_ENTER, KEY_1]:
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
		chloe_bot.position.y = 1.50 + sin(t_sec * 2.6) * 0.08
		chloe_bot.rotation.y = 0.55 + sin(t_sec * 1.4) * 0.18

	if crosshair_reticle and player:
		var hit_flash := _reticle_col if _damage_flash_timer <= 0.0 else Color(1.0, 0.25, 0.18)
		crosshair_reticle.set_state(hit_flash, player.is_aiming)
	if _damage_flash_timer > 0.0:
		_damage_flash_timer = maxf(0.0, _damage_flash_timer - delta)
		if _damage_flash:
			_damage_flash.color = Color(1.0, 0.22, 0.14, _damage_flash_timer * 0.45)
	elif _damage_flash and _damage_flash.color.a > 0.0:
		_damage_flash.color = Color(1.0, 0.22, 0.14, 0.0)

	_update_projectiles(delta)
	_update_pickups(delta)
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

	# Only drain the timer on Level 2+ while no mistake repair is paused!
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
	print("VERIFY_OK: French Target Arcade Maps, Direction Sequences & SRS verified.")

	# 1. Playable 3D Hub Menu in Map 1 (Au Café Parisien) with Chloé Companion & 3D Map Portals
	srs.reset_progress()
	srs.sector_filter = -1
	_enter_menu()
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/01_menu.png")

	# 2. Map 1 (Au Café Parisien): New Word Spotlight ("la tasse") with café props & Chloé conversational tip
	srs.reset_progress()
	srs.sector_filter = 0
	_on_start_mission_pressed()
	_clear_drones()
	current_spec = srs.build_prompt_spec("tasse")
	var demo_ids := ["pain", "tasse", "fromage"]
	var demo_xs := [-4.4, 0.0, 4.4]
	for i in range(3):
		var d := TargetDrone.new()
		drones_root.add_child(d)
		d.setup(demo_ids[i], Vector3(demo_xs[i], 2.15, -0.5), player.global_position, 0.0, 1.18)
		d.set_slot_badge(i + 1)
		if demo_ids[i] == "tasse":
			d.show_calibration_card("la tasse", "the cup / mug")
		active_drones.append(d)
	_spawn_ground_pickup(Vector3(1.8, 0.85, 3.2))
	var tasse_item := VocabData.get_by_id("tasse")
	_chloe_say("New word in Au Café Parisien: « la tasse » (the cup / mug)! %s" % str(tasse_item["tip"]))
	_refresh_prompt_hud()
	player.look_toward_point(Vector3(0.0, 2.0, -0.5))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/02_calibration_3d.png")

	# 3. Map 4 (La Gare du Nord): Pure Listening Action Wave with incoming Plasma Orbs & Gold Star Pickup
	srs.sector_filter = 3
	_apply_map_theme(3)
	for vid in ["train", "avion", "voiture", "velo", "valise"]:
		srs.mark_calibrated(vid)
		srs.cards[vid]["tier"] = 2
	_clear_drones()
	_clear_projectiles_and_pickups()
	current_spec = srs.build_prompt_spec("train")
	_spawn_vocab_drones(current_spec)
	for d in active_drones:
		d.approach_paused = true
		d._anchor_pos.z = -1.2
	_spawn_enemy_plasma(Vector3(-1.4, 1.85, 1.2))
	_spawn_enemy_plasma(Vector3(1.6, 1.80, 0.6))
	_spawn_ground_pickup(Vector3(-1.5, 0.85, 3.4))
	_chloe_say("Listen closely in La Gare du Nord! Dodge the plasma orbs and shoot « le train »!")
	_refresh_prompt_hud()
	_update_stats_hud()
	player.look_toward_point(Vector3(0.0, 2.0, -1.2))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/03_combat_pure_listening.png")

	# 4. 3D Direction Sequence ("À gauche, puis en haut !") in Map 2 (La Maison)
	srs.sector_filter = 1
	_apply_map_theme(1)
	_clear_drones()
	_clear_projectiles_and_pickups()
	current_spec = srs.build_direction_prompt_spec(2, 5)
	_spawn_direction_drones(current_spec)
	_chloe_say(str(current_spec["chloe_tip"]))
	_refresh_prompt_hud()
	_update_stats_hud()
	player.position = Vector3(0.0, 0.30, 6.6)
	player.look_toward_point(Vector3(0.0, 1.45, 1.8))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/06_a2_spatial_modifiers.png")

	# 5. In-World 3D Portal Wave Transition unlocking Map 2 (La Maison) with Chloé cheering!
	_finish_wave()
	player.position = Vector3(0.0, 0.30, 6.4)
	player.look_toward_point(Vector3(0.0, 1.9, 0.4))
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/07_b1_grammar_breach.png")

	# 6. 3D Practice Gallery in Map 7 (Jardin du Luxembourg)
	_clear_projectiles_and_pickups()
	feedback_banner.visible = false
	_on_enter_gallery_pressed()
	_load_gallery_sector(6)
	for i in range(6):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/05_gallery_study.png")

	# 7. Interactive [Tab] Word Book (Maps 1–4)
	lexicon_tab = "A1"
	_toggle_lexicon(true)
	for i in range(4):
		await get_tree().process_frame
	await _save_viewport_png(out_dir + "/04_srs_lexicon.png")

	# 8. Interactive [Tab] Word Book (Maps 5–7)
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
