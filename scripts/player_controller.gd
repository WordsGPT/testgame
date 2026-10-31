class_name PlayerController
extends CharacterBody3D

## First-Person Sharpshooter Controller for FRANC-TIREUR : Opération Écho
## Features:
## - Physical WASD / Arrow movement (works automatically on both QWERTY & French AZERTY!)
## - Mouse-look + Q/E keyboard horizontal aim fallback (great for laptops / trackpads)
## - Right-Click / [V] Aim-Down-Sights (ADS) smooth zoom to inspect distant 3D Blender silhouettes
## - Custom 3D Acoustic Carbine (`blaster.blend`) with walk sway, recoil kick, and volumetric laser tracer!

signal fired_at_entity(entity: Node, hit_pos: Vector3)
signal hovered_entity_changed(entity: Node)

const WALK_SPEED := 7.6
const SPRINT_SPEED := 11.2
const JUMP_VELOCITY := 5.6
const GRAVITY := 15.5
const MOUSE_SENS := 0.0023
const KEY_TURN_SPEED := 2.15
const MAX_RAY_DIST := 70.0

var controls_enabled: bool = false
var is_aiming: bool = false

var head: Node3D
var camera: Camera3D
var gun_pivot: Node3D
var muzzle_marker: Node3D

var _pitch: float = 0.0
var _sway_time: float = 0.0
var _recoil_offset: float = 0.0
var _fire_cooldown: float = 0.0
var _last_hovered: Node = null

const GUN_HIP_POS := Vector3(0.30, -0.25, -0.44)
const GUN_ADS_POS := Vector3(0.0, -0.17, -0.34)


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.80
	col.shape = cap
	col.position = Vector3(0, 0.90, 0)
	add_child(col)

	head = Node3D.new()
	head.position = Vector3(0, 1.62, 0)
	add_child(head)

	camera = Camera3D.new()
	camera.fov = 74.0
	camera.current = true
	head.add_child(camera)

	# 1st-Person 3D Acoustic Carbine (`blaster.blend`)
	gun_pivot = Node3D.new()
	gun_pivot.position = GUN_HIP_POS
	camera.add_child(gun_pivot)

	var blaster_res := load("res://assets/models/blaster.blend") as PackedScene
	if blaster_res:
		var b_inst := blaster_res.instantiate() as Node3D
		b_inst.scale = Vector3.ONE * 0.72
		gun_pivot.add_child(b_inst)

	muzzle_marker = Node3D.new()
	muzzle_marker.position = Vector3(0, 0.02, -0.45)
	gun_pivot.add_child(muzzle_marker)


func look_toward_point(target_world: Vector3) -> void:
	var flat := Vector3(target_world.x, global_position.y, target_world.z)
	if flat.distance_squared_to(global_position) > 0.01:
		look_at(flat, Vector3.UP)
	_pitch = 0.0
	if head:
		head.rotation.x = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENS * (0.58 if is_aiming else 1.0)
		rotate_y(-event.relative.x * sens)
		_pitch = clampf(_pitch - event.relative.y * sens, deg_to_rad(-78.0), deg_to_rad(78.0))
		head.rotation.x = _pitch

	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			try_fire()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_aiming = true

	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_aiming = false

	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F:
			try_fire()
		elif event.physical_keycode == KEY_V:
			is_aiming = not is_aiming


func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if controls_enabled:
		# Keyboard camera turn fallback (Q / E)
		var turn_axis := 0.0
		if Input.is_physical_key_pressed(KEY_Q):
			turn_axis += 1.0
		if Input.is_physical_key_pressed(KEY_E):
			turn_axis -= 1.0
		if absf(turn_axis) > 0.01:
			rotate_y(turn_axis * KEY_TURN_SPEED * delta)

		if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
			velocity.y = JUMP_VELOCITY

		var in_vec := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			in_vec.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			in_vec.y += 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			in_vec.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			in_vec.x += 1.0
		if in_vec.length_squared() > 1.0:
			in_vec = in_vec.normalized()

		var spd := SPRINT_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) and not is_aiming else WALK_SPEED
		if is_aiming:
			spd *= 0.68

		var move_dir := (transform.basis * Vector3(in_vec.x, 0.0, in_vec.y))
		if move_dir.length_squared() > 0.001:
			velocity.x = move_dir.x * spd
			velocity.z = move_dir.z * spd
			_sway_time += delta * (10.5 if spd > WALK_SPEED else 7.5)
		else:
			velocity.x = move_toward(velocity.x, 0.0, spd * 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, spd * 10.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)

	move_and_slide()

	# Keep inside arena safety radius
	if global_position.y < -5.0:
		global_position = Vector3(0, 0.5, 6.0)

	# Smooth ADS FOV & weapon procedural sway + recoil recovery
	var target_fov := 46.0 if (is_aiming and controls_enabled) else 74.0
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 12.0, 0.0, 1.0))

	_recoil_offset = move_toward(_recoil_offset, 0.0, delta * 0.65)
	var base_gun := GUN_ADS_POS if (is_aiming and controls_enabled) else GUN_HIP_POS
	var horiz_spd := Vector2(velocity.x, velocity.z).length()
	var sway_amt := clampf(horiz_spd / WALK_SPEED, 0.0, 1.0) * (0.004 if is_aiming else 0.014)
	var target_gun := base_gun + Vector3(
		sin(_sway_time) * sway_amt,
		absf(cos(_sway_time)) * sway_amt * -0.8,
		_recoil_offset
	)
	gun_pivot.position = gun_pivot.position.lerp(target_gun, clampf(delta * 16.0, 0.0, 1.0))
	gun_pivot.rotation.x = _recoil_offset * 1.35

	_update_hover_ray()


func _cast_center_ray() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var from_pt := camera.global_position
	var to_pt := from_pt + (-camera.global_transform.basis.z) * MAX_RAY_DIST
	var query := PhysicsRayQueryParameters3D.create(from_pt, to_pt)
	query.exclude = [get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 1 | 2 | 4 # World + Drones + Pedestals
	return space.intersect_ray(query)


func _update_hover_ray() -> void:
	var hit := _cast_center_ray()
	var collider: Node = hit.get("collider", null) if not hit.is_empty() else null
	if collider != _last_hovered:
		_last_hovered = collider
		hovered_entity_changed.emit(collider)


func try_fire() -> void:
	if _fire_cooldown > 0.0:
		return
	_fire_cooldown = 0.17
	_recoil_offset = 0.095

	var hit := _cast_center_ray()
	var end_pt: Vector3
	var entity: Node = null
	if not hit.is_empty():
		end_pt = hit["position"]
		entity = hit["collider"]
	else:
		end_pt = camera.global_position + (-camera.global_transform.basis.z) * 45.0

	_spawn_laser_beam(muzzle_marker.global_position, end_pt, entity)
	fired_at_entity.emit(entity, end_pt)


func _spawn_laser_beam(start_pt: Vector3, end_pt: Vector3, hit_entity: Node) -> void:
	var dist := start_pt.distance_to(end_pt)
	if dist < 0.05:
		return
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.026
	cyl.height = dist
	cyl.radial_segments = 8
	beam.mesh = cyl

	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if hit_entity is PedestalStation:
		bmat.albedo_color = Color(0.25, 0.95, 1.0)
	elif hit_entity is TargetDrone:
		bmat.albedo_color = Color(1.0, 0.88, 0.25)
	else:
		bmat.albedo_color = Color(0.22, 0.85, 1.0)
	beam.material_override = bmat

	get_parent().add_child(beam)
	var mid := (start_pt + end_pt) * 0.5
	beam.global_position = mid
	# Align cylinder Y-axis along (end_pt - start_pt)
	var dir := (end_pt - start_pt).normalized()
	var up_ref := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var x_axis := up_ref.cross(dir).normalized()
	var z_axis := dir.cross(x_axis).normalized()
	beam.global_transform.basis = Basis(x_axis, dir, z_axis)

	var tw := get_parent().create_tween()
	tw.tween_property(beam, "scale", Vector3(0.05, 1.0, 0.05), 0.14)
	tw.tween_callback(beam.queue_free)
