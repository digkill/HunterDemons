class_name IceDemon
extends Demon
## Ледяной демон — элементаль воды. Загружает GLB-модель из assets/demons/icedemon/.

const MODEL_PATH := "res://assets/demons/icedemon/source/icedemon.glb"
const ANIM_PREFIX := "thamuz_lord_of_wraith_in_game_"

var _anim: AnimationPlayer
var _attack_cycle := 0
var _is_attacking := false
var _moving := false

func _ready() -> void:
	super._ready()

func _build_visual() -> void:
	var model := get_node_or_null("ModelRoot") as Node3D
	if model == null:
		var packed := load(MODEL_PATH) as PackedScene
		if packed == null:
			super._build_visual()
			return
		model = packed.instantiate()
		model.name = "ModelRoot"
		add_child(model)
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		if not _anim.animation_finished.is_connected(_on_anim_finished):
			_anim.animation_finished.connect(_on_anim_finished)
		_anim.play(ANIM_PREFIX + "fight_idle")

func _on_anim_finished(anim_name: StringName) -> void:
	if dead:
		return
	if _is_attacking and str(anim_name).contains("attack"):
		_is_attacking = false
		if _moving:
			_anim.play(ANIM_PREFIX + "run")
		else:
			_anim.play(ANIM_PREFIX + "fight_idle")
		return
	if _moving:
		_anim.play(ANIM_PREFIX + "run")
	else:
		_anim.play(ANIM_PREFIX + "fight_idle")

func _physics_process(delta: float) -> void:
	if dead:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta

	var has_target := target != null and is_instance_valid(target) and target.hp > 0.0
	if has_target:
		var to := target.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > attack_range and not _is_attacking:
			var dir := to / maxf(dist, 0.001)
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			rotation.y = lerp_angle(
				rotation.y, atan2(dir.x, dir.z), minf(1.0, 10.0 * delta))
			if not _moving and _anim != null:
				_moving = true
				_anim.play(ANIM_PREFIX + "run")
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if _moving:
				_moving = false
				if _anim != null and not _is_attacking:
					_anim.play(ANIM_PREFIX + "fight_idle")
			if _attack_cd <= 0.0 and not _is_attacking:
				_attack_cd = ATTACK_INTERVAL
				_do_attack()
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if _moving:
			_moving = false
			if _anim != null and not _is_attacking:
				_anim.play(ANIM_PREFIX + "fight_idle")
	move_and_slide()

func _do_attack() -> void:
	_is_attacking = true
	_attack_cycle = (_attack_cycle + 1) % 5
	var atk := "attack%d" % (_attack_cycle + 1)
	if _anim != null and _anim.has_animation(ANIM_PREFIX + atk):
		_anim.play(ANIM_PREFIX + atk)
	else:
		_is_attacking = false
	if target != null and is_instance_valid(target):
		target.take_damage(damage, element)
		SFX.play("demon_attack", -6.0, 0.2)
		var hit_pos := target.global_position + Vector3.UP
		FX.burst(get_parent(), hit_pos, Elements.COLORS[element], 0.8, 0.2)

func take_damage(amount: float, attack_element: int = Elements.Type.PHYSICAL,
		pierce := false, crit := false) -> void:
	if dead:
		return
	var mult := 1.0 if pierce else Elements.damage_multiplier(attack_element, element)
	var total := amount * mult
	hp -= total
	var label_color := Color.WHITE
	if crit:
		label_color = Color(1.0, 0.45, 0.1)
	elif pierce:
		label_color = Color(0.45, 0.9, 1.0)
	elif mult > 1.01:
		label_color = Color(1.0, 0.85, 0.3)
	elif mult < 0.99:
		label_color = Color(0.6, 0.6, 0.7)
	var label_pos := global_position + Vector3.UP * (1.8 * _scale_factor)
	FX.damage_label(get_parent(), label_pos, str(roundi(total)), label_color, crit)
	SFX.play("crit" if crit else "hit", -4.0, 0.2)
	if hp <= 0.0:
		_die()

func _die() -> void:
	dead = true
	SFX.play("demon_death", -3.0, 0.25)
	var burst_pos := global_position + Vector3.UP * 0.8
	FX.burst(get_parent(), burst_pos, Elements.COLORS[element], 1.4 * _scale_factor, 0.4)
	died.emit(self)
	if _anim != null and _anim.has_animation(ANIM_PREFIX + "dead"):
		_anim.play(ANIM_PREFIX + "dead")
		var anim_res := _anim.get_animation(ANIM_PREFIX + "dead")
		get_tree().create_timer(anim_res.length, false).timeout.connect(queue_free)
	else:
		queue_free()
