class_name PedestalStation
extends Area3D

## Interactive Calibration & Free-Study Holodeck Pedestal in the North Reconnaissance Gallery.
## Shooting or pressing [E] on a pedestal plays crisp canonical native pronunciation (un/une + le/la)
## and displays gender + IPA + English-speaker pronunciation notes without time pressure!

var vocab_id: String = ""
var _vocab_holder: Node3D
var _card_label: Label3D
var _ring_mesh: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _static_body: StaticBody3D
var _pulse_timer: float = 0.0


func setup(p_vocab_id: String, pos: Vector3, face_target: Vector3) -> void:
	vocab_id = p_vocab_id
	global_position = pos

	collision_layer = 4 # Layer 3 bit (value 4): Study Pedestals
	collision_mask = 0
	monitoring = false
	monitorable = true

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.68
	cyl.height = 2.2
	col.shape = cyl
	col.position = Vector3(0, 1.1, 0)
	add_child(col)

	# Also add StaticBody3D so player doesn't walk straight through physical plinth!
	_static_body = StaticBody3D.new()
	var bcol := CollisionShape3D.new()
	var bcyl := CylinderShape3D.new()
	bcyl.radius = 0.52
	bcyl.height = 1.05
	bcol.shape = bcyl
	bcol.position = Vector3(0, 0.52, 0)
	_static_body.add_child(bcol)
	add_child(_static_body)

	var ped_res := load("res://assets/models/pedestal.blend") as PackedScene
	if ped_res:
		var p_inst := ped_res.instantiate() as Node3D
		add_child(p_inst)

	_vocab_holder = Node3D.new()
	_vocab_holder.position = Vector3(0, 1.58, 0)
	add_child(_vocab_holder)

	_ring_mesh = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.48
	_ring_mesh.mesh = tm
	_ring_mesh.position = Vector3(0, 1.06, 0)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = Color(0.18, 0.85, 1.0)
	_ring_mesh.material_override = _ring_mat
	add_child(_ring_mesh)

	_card_label = Label3D.new()
	_card_label.font = load("res://assets/fonts/DejaVuSans.ttf") as Font
	_card_label.position = Vector3(0, 2.38, 0)
	_card_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_card_label.font_size = 34
	_card_label.outline_size = 10
	_card_label.outline_modulate = Color(0.03, 0.05, 0.11, 0.95)
	add_child(_card_label)

	look_at(Vector3(face_target.x, global_position.y, face_target.z), Vector3.UP)
	set_vocab(p_vocab_id)


func set_active_station(enabled: bool) -> void:
	visible = enabled
	monitorable = enabled
	collision_layer = 4 if enabled else 0
	if _static_body:
		_static_body.collision_layer = 1 if enabled else 0


func set_vocab(new_id: String) -> void:
	vocab_id = new_id
	for ch in _vocab_holder.get_children():
		ch.queue_free()

	var model_path := "res://assets/models/%s.blend" % vocab_id
	if ResourceLoader.exists(model_path):
		var v_res := load(model_path) as PackedScene
		if v_res:
			var v_inst := v_res.instantiate() as Node3D
			v_inst.scale = Vector3.ONE * 0.78
			_vocab_holder.add_child(v_inst)

	var item := VocabData.get_by_id(vocab_id)
	if not item.is_empty():
		var g_tag := "fém." if String(item["gender"]).begins_with("f") else "masc."
		var g_col := Color(1.0, 0.68, 0.82) if g_tag == "fém." else Color(0.58, 0.86, 1.0)
		_card_label.text = "%s (%s)\n%s  •  %s" % [item["fr_def"], g_tag, item["ipa"], item["en"]]
		_card_label.modulate = g_col
		_ring_mat.albedo_color = g_col


func trigger_scan_pulse() -> void:
	_pulse_timer = 0.55
	_ring_mat.albedo_color = Color(0.30, 1.0, 0.68)


func _process(delta: float) -> void:
	if _vocab_holder:
		_vocab_holder.rotate_y(delta * 0.85)
		_vocab_holder.position.y = 1.56 + sin(Time.get_ticks_msec() * 0.0025) * 0.06
	if _pulse_timer > 0.0:
		_pulse_timer = maxf(0.0, _pulse_timer - delta)
		var sc := 1.0 + 0.35 * sin((_pulse_timer / 0.55) * PI)
		_ring_mesh.scale = Vector3(sc, 1.0, sc)
	else:
		_ring_mesh.scale = Vector3.ONE
