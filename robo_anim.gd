extends Node

# =============================================
# SGT64 - ANIMATION CONTROLLER
# hooks into inherited robot AnimationPlayer
# YAHOO 🚀
# =============================================

@export var player: RigidBody3D
@export var anim: AnimationPlayer

# ---- blend times ----
const BLEND := 0.12
const BLEND_FAST := 0.06

# ---- state tracking ----
var _current: String = ""
var _prev_grounded: bool = false
var _prev_blj: bool = false
var _hurt_timer: float = 0.0
var _attack_timer: float = 0.0
var _emote_timer: float = 0.0

const HURT_LOCK: float = 0.4
const ATTACK_LOCK: float = 0.5
const EMOTE_LOCK: float = 2.0


func _ready() -> void:
	if not anim:
		# try finding it on the player (inherited robot scene)
		anim = player.get_node_or_null("AnimationPlayer")
	if not anim:
		push_error("SGT64 Animator: no AnimationPlayer found 💀")
		return
	_play("Idle")


func _process(delta: float) -> void:
	if not player or not anim: return
	if not player.is_multiplayer_authority(): return

	# tick locked timers
	if _hurt_timer > 0.0:
		_hurt_timer -= delta
		return
	if _attack_timer > 0.0:
		_attack_timer -= delta
		return
	if _emote_timer > 0.0:
		_emote_timer -= delta
		return

	_update_anim()


func _update_anim() -> void:
	var vel: Vector3 = player.linear_velocity
	var hspeed: float = Vector2(vel.x, vel.z).length()
	var is_grounded: bool = player.is_grounded
	var is_crouching: bool = player.is_crouching
	var blj_active: bool = player.blj_active
	var blj_count: int = player.blj_count

	# ---- BLJ overrides everything mid-air ----
	if blj_active and not is_grounded:
		if blj_count >= 3:
			_play("LongJump")
		else:
			_play("Jump2")  # double jump style for chained BLJ
		return

	# ---- airborne ----
	if not is_grounded:
		if vel.y > 1.5:
			_play("Jump")
		elif vel.y < -2.0:
			_play("Fall")
		else:
			_play("Fall2")  # apex of jump / floating
		return

	# ---- wall interactions ----
	if _current == "WallJump" or _current == "WallSlide":
		return  # let those finish via trigger

	# ---- grounded ----
	if is_crouching:
		if hspeed > 2.0:
			_play("GroundSlide")
		else:
			_play("Crouch")
		return

	if hspeed > 9.0:
		_play("Sprint")
	elif hspeed > 3.0:
		_play("Run")
	elif hspeed > 0.4:
		_play("Run")  # could swap for a walk anim if u add one
	else:
		_play("Idle")


# =============================================
# PUBLIC TRIGGERS - call these from player.gd
# =============================================

## call from _perform_normal_jump()
func trigger_jump() -> void:
	_play_force("Jump", BLEND_FAST)

## call from _perform_blj()
func trigger_blj(count: int) -> void:
	if count >= 3:
		_play_force("LongJump", BLEND_FAST)
	elif count == 2:
		_play_force("Jump2", BLEND_FAST)
	else:
		_play_force("Jump3", BLEND_FAST)  # first BLJ - Jump3 selected in ur list 👀

## call when player takes damage
func trigger_hurt() -> void:
	_play_force("Hurt", BLEND_FAST)
	_hurt_timer = HURT_LOCK

## call for Attack1
func trigger_attack() -> void:
	_play_force("Attack1", BLEND_FAST)
	_attack_timer = ATTACK_LOCK

## call for Kick
func trigger_kick() -> void:
	_play_force("Kick", BLEND_FAST)
	_attack_timer = ATTACK_LOCK

## call for wall jump
func trigger_wall_jump() -> void:
	_play_force("WallJump", BLEND_FAST)

## call when sliding on wall
func trigger_wall_slide() -> void:
	if _current != "WallSlide":
		_play_force("WallSlide", BLEND)

## call for emotes
func trigger_emote(index: int = 1) -> void:
	var e = "Emote%d" % index
	_play_force(e, BLEND)
	_emote_timer = EMOTE_LOCK

## call for T-pose (debug or lobby)
func trigger_tpose() -> void:
	_play_force("T-pose", BLEND)


# =============================================
# INTERNAL
# =============================================

func _play(anim_name: String) -> void:
	if _current == anim_name: return
	if not anim.has_animation(anim_name):
		push_warning("SGT64 Animator: missing anim '%s'" % anim_name)
		return
	_current = anim_name
	anim.play(anim_name, BLEND)


func _play_force(anim_name: String, blend: float = BLEND) -> void:
	if not anim.has_animation(anim_name):
		push_warning("SGT64 Animator: missing anim '%s'" % anim_name)
		return
	_current = anim_name
	anim.play(anim_name, blend)
