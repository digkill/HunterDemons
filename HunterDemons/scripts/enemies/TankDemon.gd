class_name TankDemon
extends Demon
## Земляной демон-танк ближнего боя.
## Модель содержит собственный риг и клипы Idle/Run/Attack/Damage/Die.

const MODEL_PATH := "res://assets/demons/Demon/Demon.gltf"
# Уменьшено вдвое относительно предыдущего масштаба 0.024.
const MODEL_SCALE := 0.012
# После переворота нижняя граница модели почти совпадает с корнем.
const MODEL_GROUND_OFFSET := 0.006
const MODEL_YAW_DEG := 0.0

const IDLE_ANIM := "Idle"
const RUN_ANIM := "Run"
const ATTACK_ANIMS := ["Attack_1", "Attack_2", "Attack_3"]
const HIT_ANIMS := ["Damage_Light", "Damage_Heavy"]
const DEATH_ANIM := "Die"
const HIT_TIME_RATIO := 0.52

var _model: Node3D
var _anim: AnimationPlayer
var _moving := false
var _is_attacking := false
var _is_reacting := false
var _attack_index := -1
var _pending_hit_time := -1.0

func setup(p_element: int) -> void:
	super.setup(p_element)
	# У крупной модели радиус удара больше, но это всё ещё только ближний бой.
	attack_range = 2.35

func _ready() -> void:
	super._ready()
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	var capsule := col.shape as CapsuleShape3D if col != null else null
	if capsule != null:
		capsule.radius = 0.85
		capsule.height = 2.4
		col.position.y = capsule.height * 0.5

func _build_visual() -> void:
	_model = get_node_or_null("ModelRoot") as Node3D
	if _model == null:
		var packed := load(MODEL_PATH) as PackedScene
		if packed == null:
			super._build_visual()
			return
		_model = packed.instantiate() as Node3D
		_model.name = "ModelRoot"
		add_child(_model)
	_model.scale = Vector3.ONE * MODEL_SCALE
	_model.position.y = MODEL_GROUND_OFFSET
	_model.rotation_degrees = Vector3(180.0, MODEL_YAW_DEG, 0.0)
	_brighten_model_materials()

	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		return
	if not _anim.animation_finished.is_connected(_on_animation_finished):
		_anim.animation_finished.connect(_on_animation_finished)
	_strip_root_motion()
	_set_loop(IDLE_ANIM)
	_set_loop(RUN_ANIM)
	_play_loop(IDLE_ANIM)

func _brighten_model_materials() -> void:
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for surface in mesh_node.mesh.get_surface_count():
			var source := mesh_node.get_active_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as StandardMaterial3D
			material.albedo_color = Color(1.35, 1.25, 1.15)
			material.emission_enabled = true
			material.emission = Color(0.32, 0.18, 0.08)
			material.emission_energy_multiplier = 0.55
			mesh_node.set_surface_override_material(surface, material)

# Контроллер двигает CharacterBody3D сам. Смещение кости Demon_01 в клипах
# оставлять нельзя: при каждом зацикливании модель возвращается в начало рывком.
func _strip_root_motion() -> void:
	for anim_name in _anim.get_animation_list():
		var animation := _anim.get_animation(anim_name)
		for track in animation.get_track_count():
			if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
				continue
			if not str(animation.track_get_path(track)).contains("Demon_01"):
				continue
			var key_count := animation.track_get_key_count(track)
			if key_count < 2:
				continue
			var first: Vector3 = animation.track_get_key_value(track, 0)
			for key in key_count:
				animation.track_set_key_value(track, key, first)

func _set_loop(anim_name: String) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

func _play_loop(anim_name: String) -> void:
	if _anim != null and _anim.has_animation(anim_name) and _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.12)

func _on_animation_finished(anim_name: StringName) -> void:
	if dead:
		return
	if str(anim_name) in ATTACK_ANIMS:
		_is_attacking = false
	elif str(anim_name) in HIT_ANIMS:
		_is_reacting = false
	else:
		return
	_play_loop(RUN_ANIM if _moving else IDLE_ANIM)

func _physics_process(delta: float) -> void:
	if dead:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_update_pending_hit(delta)
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
			var direction := to / maxf(dist, 0.001)
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(1.0, 8.0 * delta))
			if not _moving:
				_moving = true
				_play_loop(RUN_ANIM)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if _moving:
				_moving = false
				if not _is_attacking:
					_play_loop(IDLE_ANIM)
			if _attack_cd <= 0.0 and not _is_attacking and not _is_reacting:
				_start_attack()
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if _moving:
			_moving = false
			if not _is_attacking:
				_play_loop(IDLE_ANIM)
	move_and_slide()

func _start_attack() -> void:
	_attack_cd = ATTACK_INTERVAL
	_is_attacking = true
	_attack_index = (_attack_index + 1) % ATTACK_ANIMS.size()
	var anim_name: String = ATTACK_ANIMS[_attack_index]
	var duration := 0.0
	if _anim != null and _anim.has_animation(anim_name):
		duration = _anim.get_animation(anim_name).length
		_anim.play(anim_name, 0.08)
	else:
		_is_attacking = false
	_pending_hit_time = maxf(0.0, duration * HIT_TIME_RATIO)

func _update_pending_hit(delta: float) -> void:
	if _pending_hit_time < 0.0:
		return
	_pending_hit_time -= delta
	if _pending_hit_time > 0.0:
		return
	_pending_hit_time = -1.0
	if target == null or not is_instance_valid(target) or target.hp <= 0.0:
		return
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.length() > attack_range + 0.7:
		return
	target.take_damage(damage, element)
	SFX.play("demon_attack", -6.0, 0.2)
	FX.burst(get_parent(), target.global_position + Vector3.UP, Elements.COLORS[element], 0.9, 0.2)

func take_damage(amount: float, attack_element: int = Elements.Type.PHYSICAL,
		pierce := false, crit := false) -> void:
	super.take_damage(amount, attack_element, pierce, crit)
	if dead or _is_attacking or _is_reacting or _anim == null:
		return
	var anim_name: String = HIT_ANIMS.pick_random()
	if _anim.has_animation(anim_name):
		_is_reacting = true
		_anim.play(anim_name, 0.05)

func _die() -> void:
	dead = true
	_pending_hit_time = -1.0
	velocity = Vector3.ZERO
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		col.set_deferred("disabled", true)
	SFX.play("demon_death", -3.0, 0.25)
	FX.burst(get_parent(), global_position + Vector3.UP * 1.1, Elements.COLORS[element], 2.0, 0.45)
	died.emit(self)
	if _anim != null and _anim.has_animation(DEATH_ANIM):
		_anim.play(DEATH_ANIM, 0.05)
		get_tree().create_timer(_anim.get_animation(DEATH_ANIM).length, false).timeout.connect(queue_free)
	else:
		queue_free()
