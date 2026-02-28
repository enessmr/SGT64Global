extends RigidBody3D

# =============================================
# SGT64 - PLAYER CONTROLLER
# BLJ system + multiplayer sync + animations
# YAHOO 🚀
# =============================================

# ---- EXPORTS ----
@export_category("References")
@export var world: Node
@export var yahoo_sfx: AudioStreamPlayer3D
@export var bar_nickname: Label
@export var bar_health: ProgressBar
@export var head: Node3D
@export var camera: Camera3D
@export var collision_shape: CollisionShape3D
@export var joystick_left: Node
@export var anim: AnimationPlayer
@export var robo: Node3D  # drag RobotArmature here

@export_category("Movement")
@export var SPEED: float = 12.0
@export var CROUCH_SPEED: float = 6.0
@export var JUMP_FORCE: float = 5.0
@export var LJ_SPEED: float = 18.0
@export var LJ_JUMP_FORCE: float = 6.0
@export var BLJ_JUMP_FORCE: float = 2.0
@export var BLJ_SPEED_PER_JUMP: float = 8.0

@export_category("Camera")
@export var mouse_sensitivity: float = 0.002
@export var camera_limit: float = 89.0
@export var keyboard_yaw_speed: float = 2.0
@export var keyboard_pitch_speed: float = 2.0

@export_category("Player Info")
@export var nickname: String = "Player":
	set(v):
		nickname = v
		emit_signal("_sync_nick")
		if bar_nickname:
			bar_nickname.text = nickname

@export var health: float = 0.0:
	set(v):
		health = v
		if hud: hud.health = v
		_update_healthbar()

@export var health_max: float = 0.0:
	set(v):
		health_max = v
		if hud: hud.health_max = v
		_update_healthbar()

# ---- SIGNALS ----
signal hud_ready
signal _sync_nick

# ---- STATE ----
var hud: CanvasLayer
var input_dir: Vector2 = Vector2.ZERO
var pitch: float = 0.0
var yaw: float = 0.0

var is_grounded: bool = false
var is_crouching: bool = false
var original_collision_height: float = 0.0
const CROUCH_HEIGHT_SCALE: float = 0.5

# BLJ
var blj_active: bool = false
var blj_speed: float = 0.0
var blj_direction: Vector3 = Vector3.ZERO

# LJ - Z held 10 frames at 30tps = 0.333s then A
const LJ_Z_HOLD_REQUIRED: float = 10.0 / 30.0
var z_hold_timer: float = 0.0
var z_held_enough: bool = false

const RESPAWN_POINT: Vector3 = Vector3(5.575, 6.042, 0.0)
const FALL_THRESHOLD: float = -90.0

# ---- ANIM ----
const BLEND := 0.12
const BLEND_FAST := 0.06
var _anim_current: String = ""
# which anims block _update_anim from overriding them
# key = anim name, value = true while playing
var _anim_locked: bool = false
var _hurt_timer: float = 0.0
var _attack_timer: float = 0.0
var _emote_timer: float = 0.0
const HURT_LOCK: float = 0.4
const ATTACK_LOCK: float = 0.5
const EMOTE_LOCK: float = 2.0


# =============================================
# INIT
# =============================================

func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())
	if is_multiplayer_authority():
		nickname = Global_self.nickname


func _ready() -> void:
	if not is_multiplayer_authority():
		_setup_remote_player()
		return
	_setup_local_player()


func _setup_remote_player() -> void:
	if collision_shape and collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate()
	if hud: hud.queue_free()
	set_physics_process(false)
	set_process_unhandled_input(false)
	if camera:
		camera.current = false
		camera.visible = false


func _setup_local_player() -> void:
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	linear_damp = 0.0
	continuous_cd = true
	max_contacts_reported = 4
	contact_monitor = true

	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.0
	physics_material_override.friction = 0.0

	if collision_shape and collision_shape.shape is CapsuleShape3D:
		collision_shape.shape = collision_shape.shape.duplicate()
		original_collision_height = collision_shape.shape.height

	if camera:
		camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	global_position = RESPAWN_POINT
	await get_tree().physics_frame
	await get_tree().physics_frame

	if not anim:
		anim = get_node_or_null("Robo/AnimationPlayer")
	if not anim:
		anim = get_node_or_null("AnimationPlayer")
	if not anim:
		for child in find_children("*", "AnimationPlayer", true, false):
			anim = child
			break
	if not anim:
		push_error("SGT64: no AnimationPlayer found 💀")
	else:
		# hook animation_finished to unlock anim when it naturally ends
		anim.animation_finished.connect(_on_animation_finished)
		_anim_play("Idle")

	_find_hud_nodes()
	if not bar_health or not bar_nickname:
		hud_ready.emit()
	await hud_ready
	health_max = 2174.0
	health = 2174.0

	print("YAHOO - SGT64 Player Ready | BLJ + LJ Online 🚀")


func _find_hud_nodes() -> void:
	var info = get_node_or_null("Info")
	if not info: return
	if not bar_nickname:
		bar_nickname = info.get_node_or_null("Nick")
	if not bar_health:
		bar_health = info.get_node_or_null("ProgressBar")
	if bar_nickname and bar_health:
		bar_nickname.text = nickname
		bar_health.max_value = health_max
		bar_health.value = health
		_update_healthbar()
		hud_ready.emit()


func _update_healthbar() -> void:
	if not bar_health: return
	bar_health.value = health
	bar_health.max_value = health_max
	var label = bar_health.get_node_or_null("Label")
	if label:
		label.text = "%s / %s" % [int(health), int(health_max)]


func _on_animation_finished(anim_name: String) -> void:
	# unlock when any locked anim finishes naturally
	if _anim_locked and _anim_current == anim_name:
		_anim_locked = false


# =============================================
# PHYSICS LOOP
# =============================================

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return

	is_grounded = _check_ground()
	if is_grounded:
		# unlock anim and kill blj on landing
		_anim_locked = false
		if blj_active and not Input.is_action_just_pressed("player_a_btn"):
			blj_active = false
			blj_speed = 0.0
			blj_direction = Vector3.ZERO

	_tick_z_hold(delta)
	_capture_input(delta)
	_handle_crouch()
	_apply_camera_rotation()
	_handle_movement(delta)
	_handle_jump()
	_sync_rotation.rpc(yaw)


func _process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	_tick_anim_timers(delta)
	_update_anim()


func _tick_z_hold(delta: float) -> void:
	if Input.is_action_pressed("player_crouch"):
		z_hold_timer += delta
		z_held_enough = z_hold_timer >= LJ_Z_HOLD_REQUIRED
	else:
		z_hold_timer = 0.0
		z_held_enough = false


# =============================================
# INPUT
# =============================================

func _capture_input(delta: float) -> void:
	if joystick_left and joystick_left.has_method("get_output"):
		input_dir = joystick_left.output
	else:
		input_dir = Input.get_vector("player_left", "player_right", "player_up", "player_dovn")

	if Global_self.input_blocked:
		input_dir = Vector2.ZERO

	var key_yaw = Input.get_action_strength("cam_left") - Input.get_action_strength("cam_right")
	var key_pitch = Input.get_action_strength("cam_up") - Input.get_action_strength("cam_down")
	yaw += key_yaw * keyboard_yaw_speed * delta
	pitch += key_pitch * keyboard_pitch_speed * delta
	pitch = clamp(pitch, deg_to_rad(-camera_limit), deg_to_rad(camera_limit))


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	if Global_self.input_blocked: return

	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(-camera_limit), deg_to_rad(camera_limit))

	if event.is_action_pressed("player_attack"):
		_anim_trigger_attack()
	elif event.is_action_pressed("player_kick"):
		_anim_trigger_kick()
	elif event.is_action_pressed("player_emote1"):
		_anim_trigger_emote(1)
	elif event.is_action_pressed("player_emote2"):
		_anim_trigger_emote(2)


func _apply_camera_rotation() -> void:
	if not head: return
	head.rotation_order = EULER_ORDER_YXZ
	head.rotation.y = yaw
	head.rotation.x = pitch

	if not robo: return
	if input_dir.length() > 0.1:
		var move_world = (Basis(Vector3.UP, yaw) * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
		robo.rotation.y = lerp_angle(robo.rotation.y, atan2(-move_world.x, -move_world.z), 0.18)
	else:
		robo.rotation.y = lerp_angle(robo.rotation.y, yaw, 0.12)


# =============================================
# MOVEMENT
# =============================================

func _handle_movement(delta: float) -> void:
	if blj_active and not is_grounded: return

	var hvel = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var target_speed = CROUCH_SPEED if is_crouching else SPEED

	if input_dir.length() > 0.1:
		var cam_basis = Basis(Vector3.UP, yaw)
		var world_dir = (cam_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
		var target_vel = world_dir * target_speed * input_dir.length()
		apply_central_force((target_vel - hvel) * mass * 20.0)
	else:
		apply_central_force(-hvel * mass * 10.0)


func _handle_crouch() -> void:
	if blj_active and not is_grounded:
		if is_crouching:
			is_crouching = false
			_sync_crouch.rpc(false)
			_set_crouch_shape(false)
		return

	var crouching = Input.is_action_pressed("player_crouch")
	if crouching and not is_crouching:
		is_crouching = true
		_sync_crouch.rpc(true)
		_set_crouch_shape(true)
	elif not crouching and is_crouching:
		is_crouching = false
		_sync_crouch.rpc(false)
		_set_crouch_shape(false)


func _set_crouch_shape(crouching: bool) -> void:
	if not collision_shape or not collision_shape.shape is CapsuleShape3D: return
	if crouching:
		collision_shape.shape.height = original_collision_height * CROUCH_HEIGHT_SCALE
		collision_shape.position.y = -original_collision_height * (1.0 - CROUCH_HEIGHT_SCALE) * 0.5
	else:
		collision_shape.shape.height = original_collision_height
		collision_shape.position.y = 0.0


# =============================================
# JUMP + BLJ + LJ
# =============================================

func _check_ground() -> bool:
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3.DOWN * 1.2
	)
	query.exclude = [self]
	query.collision_mask = 1
	return space.intersect_ray(query).size() > 0


func _handle_jump() -> void:
	if not Input.is_action_just_pressed("player_a_btn"): return
	if not is_grounded: return

	var mario_facing: Vector3 = (Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, -1.0)).normalized()
	var stick_world := Vector3.ZERO
	if input_dir.length() > 0.1:
		stick_world = (Basis(Vector3.UP, yaw) * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var dot = stick_world.dot(mario_facing)
	print("=== JUMP DEBUG ===")
	print("is_crouching: ", is_crouching)
	print("z_held_enough: ", z_held_enough, " (timer: ", z_hold_timer, ")")
	print("blj_active: ", blj_active)
	print("stick dot mario_facing: ", dot)
	print("mario_facing: ", mario_facing)
	print("stick_world: ", stick_world)

	# BLJ: crouching + stick pushing SAME dir as mario facing
	if is_crouching:
		if dot > 0.3 or blj_active:
			print(">>> DOING BLJ")
			_perform_blj(mario_facing)
			return
		else:
			print(">>> CROUCHING BUT DOT TOO LOW, doing normal jump")

	# LJ: Z held >= 10f, not crouching
	if z_held_enough and not is_crouching:
		print(">>> DOING LJ")
		_perform_long_jump()
		return

	print(">>> DOING NORMAL JUMP")
	_perform_normal_jump()


func _perform_normal_jump() -> void:
	blj_active = false
	blj_speed = 0.0
	blj_direction = Vector3.ZERO
	var hvel = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	linear_velocity = Vector3(hvel.x * 0.8, JUMP_FORCE, hvel.z * 0.8)
	_anim_play_force("Jump", BLEND_FAST, false)
	_sync_jump.rpc(linear_velocity)


func _perform_long_jump() -> void:
	blj_active = false
	blj_speed = 0.0
	blj_direction = Vector3.ZERO
	var fwd: Vector3
	if input_dir.length() > 0.1:
		fwd = (Basis(Vector3.UP, yaw) * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	else:
		fwd = -Basis(Vector3.UP, yaw).z
	linear_velocity = Vector3(fwd.x * LJ_SPEED, LJ_JUMP_FORCE, fwd.z * LJ_SPEED)
	# lock = true so _update_anim cant cancel it mid air
	_anim_play_force("LongJump", BLEND_FAST, true)
	print("LONG JUMP 🦘")
	_sync_lj.rpc(linear_velocity)


func _perform_blj(mario_facing: Vector3) -> void:
	if not blj_active or blj_direction == Vector3.ZERO:
		blj_direction = mario_facing
		blj_speed = SPEED

	blj_active = true
	blj_speed += BLJ_SPEED_PER_JUMP

	if yahoo_sfx:
		yahoo_sfx.stop()
		yahoo_sfx.play()

	linear_velocity = Vector3(
		blj_direction.x * blj_speed,
		BLJ_JUMP_FORCE,
		blj_direction.z * blj_speed
	)

	# lock = true so _update_anim cant cancel it mid air
	_anim_play_force("LongJump", BLEND_FAST, true)
	print("BLJ! Speed: %.1f m/s 🚀" % blj_speed)
	_sync_blj.rpc(blj_speed, blj_direction, linear_velocity)


# =============================================
# PHYSICS - RESPAWN ON FALL
# =============================================

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if state.transform.origin.y > FALL_THRESHOLD: return
	var t = state.transform
	t.origin = RESPAWN_POINT
	state.transform = t
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	blj_active = false
	blj_speed = 0.0
	blj_direction = Vector3.ZERO
	_anim_locked = false
	_sync_respawn.rpc(RESPAWN_POINT)


# =============================================
# ANIMATION SYSTEM
# =============================================

func _tick_anim_timers(delta: float) -> void:
	if _hurt_timer > 0.0: _hurt_timer -= delta
	if _attack_timer > 0.0: _attack_timer -= delta
	if _emote_timer > 0.0: _emote_timer -= delta


func _update_anim() -> void:
	if not anim: return
	# locked anims play fully without interruption
	if _anim_locked: return
	if _hurt_timer > 0.0 or _attack_timer > 0.0 or _emote_timer > 0.0: return

	var vel: Vector3 = linear_velocity
	var hspeed: float = Vector2(vel.x, vel.z).length()

	# BLJ airborne
	if blj_active and not is_grounded:
		_anim_play("LongJump")
		return

	# airborne
	if not is_grounded:
		_anim_play("Jump" if vel.y > 1.5 else "Fall")
		return

	# wall states finish themselves
	if _anim_current == "WallJump" or _anim_current == "WallSlide":
		return

	# grounded
	if is_crouching and not blj_active:
		_anim_play("Dive" if hspeed > 2.0 else "Crouch")
		return

	if hspeed > 20.0:
		_anim_play("Sprint")
	elif hspeed > 0.4:
		_anim_play("Run")
	else:
		_anim_play("Idle")


# ---- public anim triggers ----

func _anim_trigger_hurt() -> void:
	_anim_play_force("Hurt", BLEND_FAST, false)
	_hurt_timer = HURT_LOCK

func _anim_trigger_attack() -> void:
	_anim_play_force("Attack1", BLEND_FAST, false)
	_attack_timer = ATTACK_LOCK

func _anim_trigger_kick() -> void:
	_anim_play_force("Kick", BLEND_FAST, false)
	_attack_timer = ATTACK_LOCK

func _anim_trigger_wall_jump() -> void:
	_anim_play_force("WallJump", BLEND_FAST, false)

func _anim_trigger_wall_slide() -> void:
	if _anim_current != "WallSlide":
		_anim_play_force("WallSlide", BLEND, false)

func _anim_trigger_emote(index: int = 1) -> void:
	_anim_play_force("Emote%d" % index, BLEND, false)
	_emote_timer = EMOTE_LOCK

func _anim_trigger_tpose() -> void:
	_anim_play_force("T-pose", BLEND, false)


# ---- internal anim helpers ----

func _anim_play(anim_name: String) -> void:
	if not anim or _anim_current == anim_name: return
	# never let _anim_play override a locked anim 💀
	if _anim_locked: return
	if not anim.has_animation(anim_name):
		push_warning("SGT64 Anim: missing '%s'" % anim_name)
		return
	_anim_current = anim_name
	anim.play(anim_name, BLEND)


# lock param: if true, _update_anim cant override this anim until it finishes naturally
func _anim_play_force(anim_name: String, blend: float, lock: bool) -> void:
	if not anim: return
	if not anim.has_animation(anim_name):
		push_warning("SGT64 Anim: missing '%s'" % anim_name)
		return
	_anim_current = anim_name
	_anim_locked = lock
	anim.play(anim_name, blend)


# =============================================
# MULTIPLAYER SYNC RPCS
# =============================================

@rpc("any_peer", "unreliable")
func _sync_rotation(p_yaw: float) -> void:
	if is_multiplayer_authority(): return
	yaw = p_yaw
	if head:
		head.rotation_order = EULER_ORDER_YXZ
		head.rotation.y = yaw
	if robo:
		robo.rotation.y = lerp_angle(robo.rotation.y, yaw, 0.18)


@rpc("any_peer", "call_remote")
func _sync_crouch(crouching: bool) -> void:
	if is_multiplayer_authority(): return
	is_crouching = crouching
	_set_crouch_shape(crouching)


@rpc("any_peer", "call_remote")
func _sync_jump(velocity: Vector3) -> void:
	if str(multiplayer.get_remote_sender_id()) != name: return
	linear_velocity = velocity
	_anim_play_force("Jump", BLEND_FAST, false)


@rpc("any_peer", "call_remote")
func _sync_lj(velocity: Vector3) -> void:
	if str(multiplayer.get_remote_sender_id()) != name: return
	linear_velocity = velocity
	_anim_play_force("LongJump", BLEND_FAST, true)


@rpc("any_peer", "call_remote")
func _sync_blj(speed: float, direction: Vector3, velocity: Vector3) -> void:
	if str(multiplayer.get_remote_sender_id()) != name: return
	blj_active = true
	blj_speed = speed
	blj_direction = direction
	linear_velocity = velocity
	if yahoo_sfx:
		yahoo_sfx.stop()
		yahoo_sfx.play()
	_anim_play_force("LongJump", BLEND_FAST, true)


@rpc("any_peer", "call_remote")
func _sync_respawn(position: Vector3) -> void:
	if str(multiplayer.get_remote_sender_id()) != name: return
	global_position = position
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	blj_active = false
	blj_speed = 0.0
	blj_direction = Vector3.ZERO
	_anim_locked = false


@rpc("any_peer", "call_local")
func sync(new_nick: String) -> void:
	nickname = new_nick
