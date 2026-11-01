class_name TargetDrone
extends Area3D

## 3D Vocabulary Display Target & Parisian Café Phrase Signboard.
## Designed for clean, unmistakable visual silhouettes, calm lane-disciplined motion,
## and zero sci-fi saucer clutter.

signal reached_defense_line(drone: TargetDrone)
signal fired_plasma(origin_pos: Vector3)

var vocab_id: String = ""
var drone_tag: String = "" # Matches against target_tag (defaults to vocab_id)
var grammar_option: String = ""
var custom_wrong_label: String = ""
var custom_ok_label: String = ""
var is_calibrated_target: bool = false
var is_grammar_crystal: bool = false
var is_portal_crystal: bool = false
var is_destroyed: bool = false
var approach_speed: float = 0.0
var defense_z: float = 3.2
var approach_paused: bool = false
var can_fire_plasma: bool = false
var slot_number: int = 0

var _anchor_pos: Vector3 = Vector3.ZERO
var _orbit_phase: float = 0.0
var _orbit_speed: float = 0.55
var _strafe_amp: float = 0.14
var _depth_amp: float = 0.06
var _strafe_dir: Vector3 = Vector3.RIGHT
var _bob_phase: float = 0.0
var _bob_amp: float = 0.05
var _fire_timer: float = 99.0

var _visual_root: Node3D
var _carrier_base: Node3D
var _vocab_holder: Node3D
var _signboard_root: Node3D
var _beacon_ring: MeshInstance3D
var _beacon_mat: StandardMaterial3D
var _badge_label: Label3D
var _concept_label: Label3D
var _badge_timer: float = 0.0
var _shake_timer: float = 0.0


static func _make_std_mat(col: Color, rough: float = 0.78, metal: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func create_vocab_visual(p_vocab_id: String, scale_f: float = 1.0) -> Node3D:
	var root := Node3D.new()
	if p_vocab_id == "dir_pad":
		return root

	if p_vocab_id == "pain":
		# Custom 3D Crusty French Baguette & Country Boule on a breadboard
		var crust_mat := _make_std_mat(Color(0.74, 0.43, 0.16), 0.82)
		var dark_crust := _make_std_mat(Color(0.58, 0.31, 0.10), 0.85)
		var slash_mat := _make_std_mat(Color(0.96, 0.86, 0.64), 0.75)
		var wrap_mat := _make_std_mat(Color(0.96, 0.94, 0.88), 0.85)
		var red_band := _make_std_mat(Color(0.78, 0.18, 0.16), 0.80)

		# 1. Round country loaf (la miche / boule)
		var boule := MeshInstance3D.new()
		var b_sph := SphereMesh.new()
		b_sph.radius = 0.36 * scale_f
		b_sph.height = 0.42 * scale_f
		boule.mesh = b_sph
		boule.material_override = crust_mat
		boule.position = Vector3(-0.18 * scale_f, -0.10 * scale_f, 0.08 * scale_f)
		root.add_child(boule)

		# 2. Iconic tilted French Baguette across the front
		var bag_root := Node3D.new()
		bag_root.position = Vector3(0.06 * scale_f, 0.02 * scale_f, -0.04 * scale_f)
		bag_root.rotation_degrees = Vector3(12.0, -18.0, 62.0)
		root.add_child(bag_root)

		var bag := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.15 * scale_f
		cap.height = 1.18 * scale_f
		bag.mesh = cap
		bag.material_override = dark_crust
		bag_root.add_child(bag)

		# 4 diagonal baker score slashes along the baguette
		for i in range(4):
			var sl := MeshInstance3D.new()
			var s_box := BoxMesh.new()
			s_box.size = Vector3(0.06 * scale_f, 0.14 * scale_f, 0.22 * scale_f)
			sl.mesh = s_box
			sl.material_override = slash_mat
			sl.position = Vector3(0.11 * scale_f, (-0.27 + float(i) * 0.18) * scale_f, 0.0)
			sl.rotation_degrees = Vector3(28.0, 0.0, 0.0)
			bag_root.add_child(sl)

		# Paper bakery wrapper around the lower middle
		var sleeve := MeshInstance3D.new()
		var s_cyl := CylinderMesh.new()
		s_cyl.top_radius = 0.162 * scale_f
		s_cyl.bottom_radius = 0.162 * scale_f
		s_cyl.height = 0.32 * scale_f
		sleeve.mesh = s_cyl
		sleeve.material_override = wrap_mat
		sleeve.position = Vector3(0.0, -0.18 * scale_f, 0.0)
		bag_root.add_child(sleeve)

		var stripe := MeshInstance3D.new()
		var st_cyl := CylinderMesh.new()
		st_cyl.top_radius = 0.166 * scale_f
		st_cyl.bottom_radius = 0.166 * scale_f
		st_cyl.height = 0.06 * scale_f
		stripe.mesh = st_cyl
		stripe.material_override = red_band
		stripe.position = Vector3(0.0, -0.18 * scale_f, 0.0)
		bag_root.add_child(stripe)
		return root

	if p_vocab_id == "fromage":
		# Custom 3D French Cheese Wheel & Cut Triangular Wedge (le fromage)
		var rind_mat := _make_std_mat(Color(0.82, 0.48, 0.16), 0.78)
		var paste_mat := _make_std_mat(Color(0.96, 0.80, 0.30), 0.72)
		var hole_mat := _make_std_mat(Color(0.78, 0.56, 0.14), 0.82)
		var label_mat := _make_std_mat(Color(0.96, 0.90, 0.76), 0.80)

		# 1. Main aged cheese wheel base
		var wheel := MeshInstance3D.new()
		var wcyl := CylinderMesh.new()
		wcyl.top_radius = 0.44 * scale_f
		wcyl.bottom_radius = 0.46 * scale_f
		wcyl.height = 0.28 * scale_f
		wheel.mesh = wcyl
		wheel.material_override = rind_mat
		wheel.position = Vector3(-0.08 * scale_f, -0.14 * scale_f, 0.06 * scale_f)
		root.add_child(wheel)

		var top_lbl := MeshInstance3D.new()
		var tcyl := CylinderMesh.new()
		tcyl.top_radius = 0.34 * scale_f
		tcyl.bottom_radius = 0.34 * scale_f
		tcyl.height = 0.02 * scale_f
		top_lbl.mesh = tcyl
		top_lbl.material_override = label_mat
		top_lbl.position = Vector3(-0.08 * scale_f, 0.01 * scale_f, 0.06 * scale_f)
		root.add_child(top_lbl)

		# 2. Prominent golden cut wedge of French cheese on top/front
		var wedge := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.left_to_right = 0.0
		pr.size = Vector3(0.52 * scale_f, 0.32 * scale_f, 0.44 * scale_f)
		wedge.mesh = pr
		wedge.material_override = paste_mat
		wedge.position = Vector3(0.12 * scale_f, 0.10 * scale_f, -0.06 * scale_f)
		wedge.rotation_degrees = Vector3(0.0, -28.0, 0.0)
		root.add_child(wedge)

		# 3. Sculpted Emmental eyes/holes on the cheese wedge
		for hpos in [
			Vector3(0.05, 0.10, -0.26),
			Vector3(0.22, 0.06, -0.22),
			Vector3(0.14, 0.18, -0.20),
		]:
			var hole := MeshInstance3D.new()
			var h_sph := SphereMesh.new()
			h_sph.radius = 0.055 * scale_f
			h_sph.height = 0.09 * scale_f
			hole.mesh = h_sph
			hole.material_override = hole_mat
			hole.position = hpos * scale_f
			root.add_child(hole)
		return root

	var model_path := "res://assets/models/%s.blend" % p_vocab_id
	if ResourceLoader.exists(model_path):
		var v_res := load(model_path) as PackedScene
		if v_res:
			var v_inst := v_res.instantiate() as Node3D
			var mult := 0.72 if p_vocab_id == "pomme" else 1.28
			v_inst.scale = Vector3.ONE * (mult * scale_f)
			if p_vocab_id == "pomme":
				v_inst.position = Vector3(0.0, 0.10 * scale_f, 0.0)
			root.add_child(v_inst)
	return root


func setup(
	p_vocab_id: String,
	spawn_pos: Vector3,
	arena_center: Vector3,
	move_scale: float = 1.0,
	model_scale: float = 1.0,
	p_drone_tag: String = ""
) -> void:
	vocab_id = p_vocab_id
	drone_tag = p_drone_tag if p_drone_tag != "" else p_vocab_id
	_anchor_pos = spawn_pos
	global_position = spawn_pos
	_orbit_phase = randf() * TAU
	_bob_phase = randf() * TAU
	# Calm, gentle motion so targets stay cleanly over their tables/lanes and never overlap!
	_orbit_speed = randf_range(0.65, 0.90) * clampf(move_scale, 0.0, 1.5)
	_strafe_amp = clampf(0.14 * move_scale, 0.0, 0.45)
	_depth_amp = clampf(0.06 * move_scale, 0.0, 0.20)
	_bob_amp = 0.0 if move_scale <= 0.01 else 0.045
	_fire_timer = 999.0

	var to_center := (arena_center - spawn_pos)
	to_center.y = 0.0
	if to_center.length_squared() < 0.01:
		to_center = Vector3.BACK
	to_center = to_center.normalized()
	_strafe_dir = to_center.cross(Vector3.UP).normalized()

	collision_layer = 2 # Layer 2: Drones / Targets
	collision_mask = 0
	monitoring = false
	monitorable = true

	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.12 * clampf(model_scale, 0.72, 1.65)
	col.shape = sph
	col.position = Vector3(0, 0.12, 0)
	add_child(col)

	_visual_root = Node3D.new()
	add_child(_visual_root)

	# 1. Warm Parisian Walnut & Brass Display Platter (replaces the old yellow flying saucer!)
	_carrier_base = Node3D.new()
	_carrier_base.position = Vector3(0, -0.34 * model_scale, 0)
	_visual_root.add_child(_carrier_base)
	if vocab_id != "dir_pad" and vocab_id != "holo_crystal":
		var platter := MeshInstance3D.new()
		var pcyl := CylinderMesh.new()
		pcyl.top_radius = 0.68 * model_scale
		pcyl.bottom_radius = 0.58 * model_scale
		pcyl.height = 0.10 * model_scale
		platter.mesh = pcyl
		platter.material_override = _make_std_mat(Color(0.32, 0.19, 0.11), 0.75)
		_carrier_base.add_child(platter)

		var brass_rim := MeshInstance3D.new()
		var b_tor := TorusMesh.new()
		b_tor.inner_radius = 0.65 * model_scale
		b_tor.outer_radius = 0.71 * model_scale
		brass_rim.mesh = b_tor
		brass_rim.position = Vector3(0, 0.03 * model_scale, 0)
		brass_rim.material_override = _make_std_mat(Color(0.84, 0.68, 0.28), 0.45, 0.35)
		_carrier_base.add_child(brass_rim)

	# 2. 3D Vocabulary Object
	_vocab_holder = Node3D.new()
	_vocab_holder.position = Vector3(0, 0.02 * model_scale, 0)
	_visual_root.add_child(_vocab_holder)

	var v_vis := create_vocab_visual(vocab_id, model_scale)
	_vocab_holder.add_child(v_vis)

	look_at(Vector3(arena_center.x, global_position.y, arena_center.z), Vector3.UP)

	# 3. Beacon highlight torus (used for New Word Intro & Active Error Repair)
	_beacon_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.74 * model_scale
	torus.outer_radius = 0.84 * model_scale
	torus.rings = 32
	torus.ring_segments = 14
	_beacon_ring.mesh = torus
	_beacon_ring.position = Vector3(0, -0.48 * model_scale, 0)
	_beacon_mat = StandardMaterial3D.new()
	_beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beacon_mat.albedo_color = Color(1.0, 0.84, 0.22, 1.0)
	_beacon_ring.material_override = _beacon_mat
	_beacon_ring.visible = false
	_visual_root.add_child(_beacon_ring)

	# 4. Top Badge Label (shows French + English during New Word Intro or Phrase Signboard)
	_badge_label = Label3D.new()
	_badge_label.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	_badge_label.position = Vector3(0, 1.08 * model_scale, 0)
	_badge_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge_label.no_depth_test = true
	_badge_label.font_size = 42
	_badge_label.outline_size = 12
	_badge_label.modulate = Color(1, 1, 1, 1)
	_badge_label.outline_modulate = Color(0.04, 0.06, 0.10, 0.95)
	_badge_label.visible = false
	_visual_root.add_child(_badge_label)

	# 5. Bottom Lane Badge ([1] [2] [3])
	_concept_label = Label3D.new()
	_concept_label.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	_concept_label.position = Vector3(0, -0.82 * model_scale, 0)
	_concept_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_concept_label.no_depth_test = true
	_concept_label.font_size = 32
	_concept_label.outline_size = 10
	_concept_label.modulate = Color(0.98, 0.92, 0.74, 0.92)
	_concept_label.outline_modulate = Color(0.10, 0.07, 0.04, 0.94)
	_concept_label.visible = false
	_visual_root.add_child(_concept_label)


func set_slot_badge(slot_num: int) -> void:
	slot_number = slot_num
	if _concept_label and slot_num > 0:
		_concept_label.text = "[%d]" % slot_num
		_concept_label.visible = true


func set_concept_tag_visible(vis: bool) -> void:
	if _concept_label:
		_concept_label.visible = vis


func configure_as_grammar_crystal(option_text: String, index_num: int) -> void:
	is_grammar_crystal = true
	grammar_option = option_text
	drone_tag = option_text
	slot_number = index_num

	# Hide object holder & build a clean Parisian Café Chalkboard Signboard!
	if _vocab_holder:
		_vocab_holder.visible = false
	if _carrier_base:
		_carrier_base.visible = false

	_signboard_root = Node3D.new()
	_visual_root.add_child(_signboard_root)

	var frame_mesh := MeshInstance3D.new()
	var f_box := BoxMesh.new()
	f_box.size = Vector3(3.15, 1.28, 0.10)
	frame_mesh.mesh = f_box
	frame_mesh.material_override = _make_std_mat(Color(0.42, 0.25, 0.14), 0.72)
	_signboard_root.add_child(frame_mesh)

	var slate_mesh := MeshInstance3D.new()
	var s_box := BoxMesh.new()
	s_box.size = Vector3(2.96, 1.10, 0.13)
	slate_mesh.mesh = s_box
	slate_mesh.material_override = _make_std_mat(Color(0.12, 0.16, 0.20), 0.88)
	_signboard_root.add_child(slate_mesh)

	_badge_label.position = Vector3(0, 0.06, 0.12)
	_badge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_badge_label.width = 520.0
	_badge_label.text = "« %s »" % option_text if option_text.length() > 10 else option_text
	_badge_label.font_size = 32 if option_text.length() > 16 else 40
	_badge_label.modulate = Color(1.0, 0.96, 0.84)
	_badge_label.visible = true
	_badge_timer = 0.0

	if _concept_label:
		_concept_label.position = Vector3(0, -0.82, 0.08)
		_concept_label.text = "[%d]  Click or Press [%d]" % [index_num, index_num]
		_concept_label.modulate = Color(1.0, 0.86, 0.36)
		_concept_label.visible = true
	set_beacon(false)


func configure_as_portal_crystal(title_text: String, subtitle_text: String, ring_col: Color = Color(1.0, 0.84, 0.22)) -> void:
	is_portal_crystal = true
	is_calibrated_target = true
	if _vocab_holder:
		_vocab_holder.visible = false
	if _carrier_base:
		_carrier_base.visible = false

	# Clean archway signboard for round completion
	var arch_board := MeshInstance3D.new()
	var abox := BoxMesh.new()
	abox.size = Vector3(4.2, 1.45, 0.14)
	arch_board.mesh = abox
	arch_board.material_override = _make_std_mat(Color(0.14, 0.18, 0.24), 0.80)
	_visual_root.add_child(arch_board)

	var border := MeshInstance3D.new()
	var bbox := BoxMesh.new()
	bbox.size = Vector3(4.36, 1.60, 0.10)
	border.mesh = bbox
	border.material_override = _make_std_mat(ring_col, 0.55)
	_visual_root.add_child(border)

	_badge_label.position = Vector3(0, 0.18, 0.14)
	_badge_label.text = title_text
	_badge_label.font_size = 42
	_badge_label.modulate = Color(1.0, 0.95, 0.55)
	_badge_label.visible = true
	_badge_timer = 0.0
	if _concept_label:
		_concept_label.position = Vector3(0, -0.32, 0.14)
		_concept_label.text = subtitle_text
		_concept_label.font_size = 28
		_concept_label.modulate = Color(0.95, 0.98, 1.0)
		_concept_label.visible = true
	set_beacon(true, ring_col)


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	_orbit_phase += delta * _orbit_speed
	_bob_phase += delta * 2.0

	var offset := _strafe_dir * (sin(_orbit_phase) * _strafe_amp)
	offset.z += cos(_orbit_phase * 0.75) * _depth_amp
	offset.y = sin(_bob_phase) * _bob_amp
	global_position = _anchor_pos + offset

	if _vocab_holder and _vocab_holder.visible:
		_vocab_holder.rotate_y(delta * 0.65)

	if _beacon_ring and _beacon_ring.visible:
		var pulse := 1.0 + 0.08 * sin(_bob_phase * 3.0)
		_beacon_ring.scale = Vector3(pulse, 1.0, pulse)

	if _shake_timer > 0.0:
		_shake_timer = maxf(0.0, _shake_timer - delta)
		_visual_root.position.x = sin(_shake_timer * 55.0) * 0.16 * (_shake_timer / 0.35)
	else:
		_visual_root.position.x = 0.0

	if _badge_timer > 0.0:
		_badge_timer -= delta
		if _badge_timer <= 0.0 and not is_calibrated_target and not is_grammar_crystal:
			_badge_label.visible = false
		elif _badge_timer <= 0.0 and is_grammar_crystal:
			_badge_label.text = "« %s »" % grammar_option if grammar_option.length() > 10 else grammar_option
			_badge_label.modulate = Color(1.0, 0.96, 0.84)


func set_beacon(enabled: bool, color: Color = Color(1.0, 0.84, 0.18)) -> void:
	if _beacon_ring:
		_beacon_ring.visible = enabled
		_beacon_mat.albedo_color = color


func show_calibration_card(fr_text: String, en_text: String, _note: String = "") -> void:
	is_calibrated_target = true
	set_beacon(true, Color(1.0, 0.84, 0.22))
	_badge_label.text = "★ %s\n(%s)" % [fr_text, en_text]
	_badge_label.modulate = Color(1.0, 0.95, 0.72)
	_badge_label.visible = true
	_badge_timer = 0.0


func show_repair_target_card(fr_text: String, en_text: String) -> void:
	is_calibrated_target = true
	set_beacon(true, Color(1.0, 0.82, 0.18))
	_badge_label.text = "★ %s\n(%s)" % [fr_text, en_text]
	_badge_label.modulate = Color(1.0, 0.90, 0.32)
	_badge_label.visible = true
	_badge_timer = 0.0


func flash_wrong_hit() -> void:
	_shake_timer = 0.35
	if is_grammar_crystal:
		_badge_label.text = "✗ « %s »" % grammar_option
		_badge_label.modulate = Color(1.0, 0.45, 0.45)
		_badge_timer = 2.2
		return
	if custom_wrong_label != "":
		_badge_label.text = custom_wrong_label
		_badge_label.modulate = Color(1.0, 0.45, 0.45)
		_badge_label.visible = true
		_badge_timer = 2.5
		return
	var item := VocabData.get_by_id(vocab_id)
	if not item.is_empty():
		_badge_label.text = "✗ %s (%s)" % [item["fr_def"], item["en"]]
		_badge_label.modulate = Color(1.0, 0.45, 0.45)
		_badge_label.visible = true
		_badge_timer = 2.8


func explode_success(parent_world: Node3D, points_earned: int = 100) -> void:
	if is_destroyed:
		return
	is_destroyed = true
	monitorable = false

	var item := VocabData.get_by_id(vocab_id)
	var popup_txt := custom_ok_label
	if popup_txt == "":
		if is_grammar_crystal:
			popup_txt = "+%d  ✓ « %s »" % [points_earned, grammar_option]
		else:
			popup_txt = "+%d  ✓ %s (%s)" % [points_earned, item.get("fr_def", vocab_id), item.get("en", "")]

	var fx_root := Node3D.new()
	fx_root.global_position = global_position + Vector3(0, 0.20, 0)
	parent_world.add_child(fx_root)

	var particles := CPUParticles3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.11, 0.11, 0.11)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(1.0, 0.88, 0.36)
	box.material = pmat
	particles.mesh = box
	particles.amount = 18
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.initial_velocity_min = 3.5
	particles.initial_velocity_max = 7.0
	particles.gravity = Vector3(0, -9.0, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	fx_root.add_child(particles)
	particles.emitting = true

	var pop := Label3D.new()
	pop.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	pop.text = popup_txt
	pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pop.no_depth_test = true
	pop.font_size = 44
	pop.outline_size = 12
	pop.modulate = Color(0.38, 1.0, 0.68)
	pop.outline_modulate = Color(0.03, 0.08, 0.06, 0.95)
	pop.position = Vector3(0, 0.50, 0)
	fx_root.add_child(pop)

	var tw := parent_world.create_tween()
	tw.tween_property(pop, "position:y", 1.65, 1.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pop, "modulate:a", 0.0, 1.25)
	tw.tween_callback(fx_root.queue_free)

	queue_free()
