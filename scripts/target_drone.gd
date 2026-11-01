class_name TargetDrone
extends Area3D

## Hovering 3D Anti-Grav Target Drone carrying a sculpted Blender 3D Vocabulary Model or Data-Crystal.
## Designed for crystal-clear visual readability at mid-range (6.5m–8.5m), generous hitboxes,
## lane-disciplined hover motion (no overlapping targets), and juicy arcade destruction feedback.

signal reached_defense_line(drone: TargetDrone)

var vocab_id: String = ""
var drone_tag: String = "" # Matches against target_tag (defaults to vocab_id)
var grammar_option: String = ""
var custom_wrong_label: String = ""
var custom_ok_label: String = ""
var is_calibrated_target: bool = false
var is_grammar_crystal: bool = false
var is_destroyed: bool = false
var approach_speed: float = 0.0
var defense_z: float = 3.2
var approach_paused: bool = false
var slot_number: int = 0

var _anchor_pos: Vector3 = Vector3.ZERO
var _orbit_phase: float = 0.0
var _orbit_speed: float = 0.65
var _strafe_amp: float = 0.35
var _strafe_dir: Vector3 = Vector3.RIGHT
var _bob_phase: float = 0.0
var _bob_amp: float = 0.08

var _visual_root: Node3D
var _vocab_holder: Node3D
var _beacon_ring: MeshInstance3D
var _beacon_mat: StandardMaterial3D
var _badge_label: Label3D
var _concept_label: Label3D
var _badge_timer: float = 0.0
var _shake_timer: float = 0.0


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
	# Keep motion smooth and strictly inside each drone's lane so targets never overlap!
	_orbit_speed = randf_range(0.65, 0.90) * move_scale
	_strafe_amp = clampf(0.32 * move_scale, 0.0, 0.95)
	_bob_amp = 0.0 if move_scale <= 0.01 else 0.08

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

	# 1. Drone carrier base (drone.blend)
	var drone_res := load("res://assets/models/drone.blend") as PackedScene
	if drone_res:
		var d_inst := drone_res.instantiate() as Node3D
		d_inst.position = Vector3(0, -0.74 * model_scale, 0)
		d_inst.scale = Vector3.ONE * (1.02 * clampf(model_scale, 0.70, 1.50))
		_visual_root.add_child(d_inst)

	# 2. Custom 3D Blender Vocabulary Object (<id>.blend) — scaled up for unmistakable silhouette
	_vocab_holder = Node3D.new()
	_vocab_holder.position = Vector3(0, 0.18 * model_scale, 0)
	_visual_root.add_child(_vocab_holder)

	var model_path := "res://assets/models/%s.blend" % vocab_id
	if ResourceLoader.exists(model_path):
		var v_res := load(model_path) as PackedScene
		if v_res:
			var v_inst := v_res.instantiate() as Node3D
			v_inst.scale = Vector3.ONE * (1.42 * model_scale)
			_vocab_holder.add_child(v_inst)

	look_at(Vector3(arena_center.x, global_position.y, arena_center.z), Vector3.UP)

	# 3. Beacon highlight torus (used for Tier 0 New Word Intro & Active Error Repair!)
	_beacon_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82 * model_scale
	torus.outer_radius = 0.92 * model_scale
	torus.rings = 32
	torus.ring_segments = 14
	_beacon_ring.mesh = torus
	_beacon_ring.position = Vector3(0, -0.56 * model_scale, 0)
	_beacon_mat = StandardMaterial3D.new()
	_beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beacon_mat.albedo_color = Color(0.20, 0.95, 0.65, 1.0)
	_beacon_ring.material_override = _beacon_mat
	_beacon_ring.visible = false
	_visual_root.add_child(_beacon_ring)

	# 4. Top Badge Label (shows French + English during Tier 0 Intro, Grammar Crystal options, or Error Feedback)
	_badge_label = Label3D.new()
	_badge_label.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	_badge_label.position = Vector3(0, 1.18 * model_scale, 0)
	_badge_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge_label.no_depth_test = true
	_badge_label.font_size = 44
	_badge_label.outline_size = 12
	_badge_label.modulate = Color(1, 1, 1, 1)
	_badge_label.outline_modulate = Color(0.04, 0.06, 0.12, 0.95)
	_badge_label.visible = false
	_visual_root.add_child(_badge_label)

	# 5. Bottom Lane Badge (clean [1] [2] [3] [4] arcade lane indicator — no English spoilers!)
	_concept_label = Label3D.new()
	_concept_label.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	_concept_label.position = Vector3(0, -1.02 * model_scale, 0)
	_concept_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_concept_label.no_depth_test = true
	_concept_label.font_size = 32
	_concept_label.outline_size = 10
	_concept_label.modulate = Color(0.98, 0.92, 0.74, 0.90)
	_concept_label.outline_modulate = Color(0.14, 0.09, 0.05, 0.92)
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
	_badge_label.text = "[%d]  %s" % [index_num, option_text]
	_badge_label.font_size = 52
	_badge_label.modulate = Color(1.0, 0.92, 0.38)
	_badge_label.visible = true
	_badge_timer = 0.0
	if _concept_label:
		_concept_label.text = "PRESS [%d] OR SHOOT" % index_num
		_concept_label.visible = true
	set_beacon(true, Color(0.62, 0.38, 1.0))


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	_orbit_phase += delta * _orbit_speed
	_bob_phase += delta * 2.0

	if approach_speed > 0.0 and not approach_paused:
		_anchor_pos.z += approach_speed * delta
		if _anchor_pos.z >= defense_z:
			_anchor_pos.z = -3.8
			reached_defense_line.emit(self)

	var offset := _strafe_dir * (sin(_orbit_phase) * _strafe_amp)
	offset.y = sin(_bob_phase) * _bob_amp
	global_position = _anchor_pos + offset

	if _vocab_holder:
		_vocab_holder.rotate_y(delta * 0.85)

	if _beacon_ring and _beacon_ring.visible:
		var pulse := 1.0 + 0.10 * sin(_bob_phase * 3.2)
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
			_badge_label.modulate = Color(1.0, 0.92, 0.38)


func set_beacon(enabled: bool, color: Color = Color(1.0, 0.84, 0.18)) -> void:
	if _beacon_ring:
		_beacon_ring.visible = enabled
		_beacon_mat.albedo_color = color


func show_calibration_card(fr_text: String, en_text: String, _note: String = "") -> void:
	is_calibrated_target = true
	set_beacon(true, Color(0.22, 0.94, 0.52))
	_badge_label.text = "★ %s\n(%s)" % [fr_text, en_text]
	_badge_label.modulate = Color(0.98, 0.95, 0.78)
	_badge_label.visible = true
	_badge_timer = 0.0


func show_repair_target_card(fr_text: String, en_text: String) -> void:
	is_calibrated_target = true
	set_beacon(true, Color(1.0, 0.82, 0.18))
	_badge_label.text = "SHOOT ME: %s\n(%s)" % [fr_text, en_text]
	_badge_label.modulate = Color(1.0, 0.90, 0.32)
	_badge_label.visible = true
	_badge_timer = 0.0


func flash_wrong_hit() -> void:
	_shake_timer = 0.35
	if is_grammar_crystal:
		_badge_label.text = "✗ Not « %s »" % grammar_option
		_badge_label.modulate = Color(1.0, 0.42, 0.42)
		_badge_timer = 2.5
		return
	if custom_wrong_label != "":
		_badge_label.text = custom_wrong_label
		_badge_label.modulate = Color(1.0, 0.42, 0.42)
		_badge_label.visible = true
		_badge_timer = 3.0
		return
	var item := VocabData.get_by_id(vocab_id)
	if not item.is_empty():
		_badge_label.text = "✗ That's %s\n(%s)" % [item["fr_def"], item["en"]]
		_badge_label.modulate = Color(1.0, 0.42, 0.42)
		_badge_label.visible = true
		_badge_timer = 3.2


func explode_success(parent_world: Node3D, points_earned: int = 100) -> void:
	if is_destroyed:
		return
	is_destroyed = true
	monitorable = false

	var item := VocabData.get_by_id(vocab_id)
	var popup_txt := custom_ok_label
	if popup_txt == "":
		if is_grammar_crystal:
			popup_txt = "+%d  ✓ « %s » !" % [points_earned, grammar_option]
		else:
			popup_txt = "+%d  ✓ %s (%s)" % [points_earned, item.get("fr_def", vocab_id), item.get("en", "")]

	var fx_root := Node3D.new()
	fx_root.global_position = global_position + Vector3(0, 0.20, 0)
	parent_world.add_child(fx_root)

	var particles := CPUParticles3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.13, 0.13, 0.13)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(0.25, 1.0, 0.68)
	box.material = pmat
	particles.mesh = box
	particles.amount = 24
	particles.lifetime = 0.65
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 8.5
	particles.gravity = Vector3(0, -9.0, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.3
	fx_root.add_child(particles)
	particles.emitting = true

	var pop := Label3D.new()
	pop.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	pop.text = popup_txt
	pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pop.no_depth_test = true
	pop.font_size = 50
	pop.outline_size = 12
	pop.modulate = Color(0.32, 1.0, 0.68)
	pop.outline_modulate = Color(0.03, 0.08, 0.06, 0.95)
	pop.position = Vector3(0, 0.55, 0)
	fx_root.add_child(pop)

	var tw := parent_world.create_tween()
	tw.tween_property(pop, "position:y", 1.85, 1.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pop, "modulate:a", 0.0, 1.35)
	tw.tween_callback(fx_root.queue_free)

	queue_free()
