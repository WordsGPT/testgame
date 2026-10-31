class_name TargetDrone
extends Area3D

## Hovering 3D Anti-Grav Drone carrying a custom Blender 3D Vocabulary Model or Holographic Data-Crystal.
## Supports:
## - Audio-first Dual-Coding 3D vocabulary objects (zero text labels during standard combat!)
## - Dynamic A2 3D Spatial/Comparative Modifier scaling & motion speeds (le plus grand, immobile, etc.)
## - A2–B1 Grammar Breach Holographic Data-Crystals (`holo_crystal.blend`) with floating choice banners

var vocab_id: String = ""
var drone_tag: String = "" # Matches against target_tag (defaults to vocab_id)
var grammar_option: String = ""
var custom_wrong_label: String = ""
var custom_ok_label: String = ""
var is_calibrated_target: bool = false
var is_grammar_crystal: bool = false
var is_destroyed: bool = false

var _anchor_pos: Vector3 = Vector3.ZERO
var _orbit_phase: float = 0.0
var _orbit_speed: float = 0.85
var _strafe_amp: float = 1.35
var _strafe_dir: Vector3 = Vector3.RIGHT
var _bob_phase: float = 0.0
var _bob_amp: float = 0.16

var _visual_root: Node3D
var _vocab_holder: Node3D
var _beacon_ring: MeshInstance3D
var _beacon_mat: StandardMaterial3D
var _badge_label: Label3D
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
	_orbit_speed = randf_range(0.70, 1.05) * move_scale
	_strafe_amp = randf_range(0.95, 1.60) * move_scale
	_bob_amp = 0.0 if move_scale <= 0.01 else 0.16

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
	sph.radius = 0.92 * clampf(model_scale, 0.72, 1.55)
	col.shape = sph
	col.position = Vector3(0, 0.08, 0)
	add_child(col)

	_visual_root = Node3D.new()
	add_child(_visual_root)

	# 1. Drone carrier base (drone.blend)
	var drone_res := load("res://assets/models/drone.blend") as PackedScene
	if drone_res:
		var d_inst := drone_res.instantiate() as Node3D
		d_inst.position = Vector3(0, -0.68 * model_scale, 0)
		d_inst.scale = Vector3.ONE * (0.95 * clampf(model_scale, 0.70, 1.45))
		_visual_root.add_child(d_inst)

	# 2. Custom 3D Blender Vocabulary Object (<id>.blend)
	_vocab_holder = Node3D.new()
	_vocab_holder.position = Vector3(0, 0.14 * model_scale, 0)
	_visual_root.add_child(_vocab_holder)

	var model_path := "res://assets/models/%s.blend" % vocab_id
	if ResourceLoader.exists(model_path):
		var v_res := load(model_path) as PackedScene
		if v_res:
			var v_inst := v_res.instantiate() as Node3D
			v_inst.scale = Vector3.ONE * (1.08 * model_scale)
			_vocab_holder.add_child(v_inst)

	look_at(Vector3(arena_center.x, global_position.y, arena_center.z), Vector3.UP)

	# 3. Beacon highlight torus (used for Calibration & Active Error Repair!)
	_beacon_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.72 * model_scale
	torus.outer_radius = 0.80 * model_scale
	torus.rings = 28
	torus.ring_segments = 12
	_beacon_ring.mesh = torus
	_beacon_ring.position = Vector3(0, -0.52 * model_scale, 0)
	_beacon_mat = StandardMaterial3D.new()
	_beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beacon_mat.albedo_color = Color(1.0, 0.82, 0.20, 1.0)
	_beacon_ring.material_override = _beacon_mat
	_beacon_ring.visible = false
	_visual_root.add_child(_beacon_ring)

	# 4. Feedback / Calibration / Grammar Crystal 3D Label (HIDDEN during standard vocab combat!)
	_badge_label = Label3D.new()
	_badge_label.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	_badge_label.position = Vector3(0, 1.08 * model_scale, 0)
	_badge_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge_label.no_depth_test = true
	_badge_label.font_size = 42
	_badge_label.outline_size = 12
	_badge_label.modulate = Color(1, 1, 1, 1)
	_badge_label.outline_modulate = Color(0.04, 0.06, 0.12, 0.95)
	_badge_label.visible = false
	_visual_root.add_child(_badge_label)


func configure_as_grammar_crystal(option_text: String, index_num: int) -> void:
	is_grammar_crystal = true
	grammar_option = option_text
	drone_tag = option_text
	_badge_label.text = "[%d]  « %s »" % [index_num, option_text]
	_badge_label.font_size = 48
	_badge_label.modulate = Color(0.82, 0.68, 1.0)
	_badge_label.visible = true
	_badge_timer = 0.0
	set_beacon(true, Color(0.58, 0.35, 1.0))


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	_orbit_phase += delta * _orbit_speed
	_bob_phase += delta * 2.1

	var offset := _strafe_dir * (sin(_orbit_phase) * _strafe_amp)
	offset.y = sin(_bob_phase) * _bob_amp
	global_position = _anchor_pos + offset

	if _vocab_holder:
		_vocab_holder.rotate_y(delta * 0.95)

	if _beacon_ring and _beacon_ring.visible:
		var pulse := 1.0 + 0.10 * sin(_bob_phase * 3.0)
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
			_badge_label.modulate = Color(0.82, 0.68, 1.0)


func set_beacon(enabled: bool, color: Color = Color(1.0, 0.84, 0.18)) -> void:
	if _beacon_ring:
		_beacon_ring.visible = enabled
		_beacon_mat.albedo_color = color


func show_calibration_card(fr_text: String, en_text: String) -> void:
	is_calibrated_target = true
	set_beacon(true, Color(0.20, 0.92, 1.0))
	_badge_label.text = "%s\n(%s)" % [fr_text, en_text]
	_badge_label.modulate = Color(0.55, 0.96, 1.0)
	_badge_label.visible = true
	_badge_timer = 0.0


func flash_wrong_hit() -> void:
	_shake_timer = 0.35
	if is_grammar_crystal:
		_badge_label.text = "✗ « %s »" % grammar_option
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
		_badge_label.text = "✗ %s\n(%s)" % [item["fr_def"], item["en"]]
		_badge_label.modulate = Color(1.0, 0.42, 0.42)
		_badge_label.visible = true
		_badge_timer = 3.2


func explode_success(parent_world: Node3D) -> void:
	if is_destroyed:
		return
	is_destroyed = true
	monitorable = false

	var item := VocabData.get_by_id(vocab_id)
	var popup_txt := custom_ok_label
	if popup_txt == "":
		if is_grammar_crystal:
			popup_txt = "✓ « %s » !" % grammar_option
		else:
			popup_txt = "✓ %s !" % item.get("fr_def", vocab_id)

	var fx_root := Node3D.new()
	fx_root.global_position = global_position + Vector3(0, 0.15, 0)
	parent_world.add_child(fx_root)

	var particles := CPUParticles3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.11, 0.11, 0.11)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(0.25, 1.0, 0.68)
	box.material = pmat
	particles.mesh = box
	particles.amount = 22
	particles.lifetime = 0.62
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.initial_velocity_min = 3.5
	particles.initial_velocity_max = 7.5
	particles.gravity = Vector3(0, -9.0, 0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.2
	fx_root.add_child(particles)
	particles.emitting = true

	var pop := Label3D.new()
	pop.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	pop.text = popup_txt
	pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pop.no_depth_test = true
	pop.font_size = 48
	pop.outline_size = 12
	pop.modulate = Color(0.32, 1.0, 0.68)
	pop.outline_modulate = Color(0.03, 0.08, 0.06, 0.95)
	pop.position = Vector3(0, 0.55, 0)
	fx_root.add_child(pop)

	var tw := parent_world.create_tween()
	tw.tween_property(pop, "position:y", 1.55, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pop, "modulate:a", 0.0, 0.85)
	tw.tween_callback(fx_root.queue_free)

	queue_free()
