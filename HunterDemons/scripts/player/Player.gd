class_name Player
extends CharacterBody3D
## Юкка — охотница на демонов с клинком «Кибер-Сакура».

signal hp_changed(hp: float, max_hp: float)
signal ult_charge_changed(value: float)
signal died

# Редактируемая героиня с анимациями (tools/bake_hero.gd). Если файла нет — капсула.
const HERO_SCENE_PATH := "res://assets/MainHero/hero.tscn"
const HERO_SCENE_FALLBACK_PATH := "res://assets/MainHero/hero.scn"
# Поставь 180.0, если модель бежит спиной вперёд.
const MODEL_YAW_DEG := 0.0

# Редактируемая сцена катаны; если файла нет — строится процедурная.
const KATANA_SCENE_PATH := "res://scenes/weapons/CyberSakuraKatana.tscn"
const HAND_BONE := "RightHand"

const ATTACK_ANIMS := ["slash", "slash_5", "attack"]
const DRAGON_SPIRIT_SCENE := preload("res://scenes/effects/DragonSpirit.tscn")

const SPEED := 6.5
const GRAVITY := 28.0
const ENVIRONMENT_COLLISION_MASK := 1 | (1 << 1)
const JUMP_VELOCITY := 10.0
const JUMP_ATTACK_DIVE_SPEED := 15.0
const JUMP_ATTACK_DAMAGE := 32.0
const JUMP_ATTACK_RADIUS := 3.0
const DRAGON_SPAWN_HEIGHT := 3.2

const ATTACK_COOLDOWN := 0.45
const ATTACK_RANGE := 2.6
const ATTACK_DAMAGE := 22.0

const SKILL1_COOLDOWN := 6.0 # «Вихрь сакуры» — лепестки вокруг (стихия воздуха)
const SKILL1_RADIUS := 4.5
const SKILL1_DAMAGE := 40.0

const SKILL2_COOLDOWN := 4.0 # «Кибер-рывок» — плазменный рывок (стихия огня)
const SKILL2_DAMAGE := 30.0
const DASH_SPEED := 22.0
const DASH_TIME := 0.22

const ULT_MAX := 100.0

const CRIT_CHANCE := 0.18
const CRIT_MULT := 2.2

var max_hp := 120.0
var hp := max_hp
var ult_charge := 0.0
var move_input := Vector2.ZERO # задаёт виртуальный джойстик HUD
var facing := Vector3.FORWARD
var combat_enabled := true
var arena_half := 0.0 # 0 = без ограничений; задаётся уровнем
var camera_rig: CameraRig

var attack_cd := 0.0
var skill1_cd := 0.0
var skill2_cd := 0.0

var _dash_left := 0.0
var _dash_dir := Vector3.ZERO
var _dash_hit: Array = []
var _visual: Node3D
var _ult_ring_mat: StandardMaterial3D
var _anim: AnimationPlayer
var _action_playing := false
var _attack_index := 0
var _jump_attack_active := false

func _ready() -> void:
	add_to_group("player")
	# Слой 2 — детальные коллайдеры зданий города. Мобы его не используют.
	collision_mask = ENVIRONMENT_COLLISION_MASK
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		add_child(col)
	var capsule := col.shape as CapsuleShape3D
	if capsule == null:
		capsule = CapsuleShape3D.new()
		col.shape = capsule
	capsule.radius = 0.42
	capsule.height = 1.7
	col.position.y = 0.85
	_build_visual()

func _build_visual() -> void:
	_visual = get_node_or_null("VisualRoot") as Node3D
	if _visual == null:
		_visual = Node3D.new()
		_visual.name = "VisualRoot"
		add_child(_visual)
	var model := _visual.get_node_or_null("HeroModel") as Node3D
	var hero_path := HERO_SCENE_PATH if ResourceLoader.exists(HERO_SCENE_PATH) else HERO_SCENE_FALLBACK_PATH
	if model == null and ResourceLoader.exists(hero_path):
		var packed: PackedScene = load(hero_path)
		model = packed.instantiate()
		model.name = "HeroModel"
		model.rotation_degrees.y = MODEL_YAW_DEG
		_visual.add_child(model)
	if model != null:
		model.rotation_degrees.y = MODEL_YAW_DEG
		_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if _anim != null:
			if not _anim.animation_finished.is_connected(_on_action_finished):
				_anim.animation_finished.connect(_on_action_finished)
			_anim.play("idle")
		_attach_katana(model)
	else:
		_build_placeholder()
	# Кольцо у ног — индикатор заряда ульты.
	var ring := get_node_or_null("UltRing") as MeshInstance3D
	if ring == null:
		ring = MeshInstance3D.new()
		ring.name = "UltRing"
		add_child(ring)
	var torus := ring.mesh as TorusMesh
	if torus == null:
		torus = TorusMesh.new()
		ring.mesh = torus
	torus.inner_radius = 0.8
	torus.outer_radius = 0.95
	ring.position.y = 0.08
	_ult_ring_mat = StandardMaterial3D.new()
	_ult_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ult_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ult_ring_mat.albedo_color = Color(0.4, 0.95, 1.0, 0.1)
	_ult_ring_mat.emission_enabled = true
	_ult_ring_mat.emission = Color(0.4, 0.95, 1.0)
	ring.material_override = _ult_ring_mat

func _build_placeholder() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	body.mesh = capsule
	body.position.y = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.78, 0.88)
	body.material_override = mat
	_visual.add_child(body)

	var visor := MeshInstance3D.new()
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.34, 0.09, 0.06)
	visor.mesh = visor_mesh
	visor.position = Vector3(0, 1.32, 0.36)
	var visor_mat := StandardMaterial3D.new()
	visor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visor_mat.albedo_color = Color(0.3, 1.0, 1.0)
	visor_mat.emission_enabled = true
	visor_mat.emission = Color(0.3, 1.0, 1.0)
	visor.material_override = visor_mat
	_visual.add_child(visor)

	var sword := MeshInstance3D.new()
	var sword_mesh := BoxMesh.new()
	sword_mesh.size = Vector3(0.07, 0.04, 1.15)
	sword.mesh = sword_mesh
	sword.position = Vector3(0.48, 0.95, 0.25)
	var sword_mat := StandardMaterial3D.new()
	sword_mat.albedo_color = Color(1.0, 0.45, 0.75)
	sword_mat.emission_enabled = true
	sword_mat.emission = Color(1.0, 0.35, 0.7)
	sword_mat.emission_energy_multiplier = 1.6
	sword.material_override = sword_mat
	_visual.add_child(sword)

func _attach_katana(model: Node3D) -> void:
	var skel: Skeleton3D = model.get_node_or_null("Armature/Skeleton3D")
	if skel == null or skel.find_bone(HAND_BONE) < 0:
		return
	var attach := skel.get_node_or_null("CyberSakuraAttachment") as BoneAttachment3D
	if attach == null:
		attach = BoneAttachment3D.new()
		attach.name = "CyberSakuraAttachment"
		skel.add_child(attach)
	attach.bone_name = HAND_BONE
	if attach.get_node_or_null("CyberSakuraKatana") != null:
		return
	var katana: Node3D
	if ResourceLoader.exists(KATANA_SCENE_PATH):
		var packed: PackedScene = load(KATANA_SCENE_PATH)
		katana = packed.instantiate()
	else:
		katana = _make_katana()
	katana.name = "CyberSakuraKatana"
	attach.add_child(katana)
	# Модель героини отмасштабирована в hero.tscn — катана задана в метрах, компенсируем.
	var model_scale := model.scale.x
	katana.scale = Vector3.ONE / model_scale
	katana.position = Vector3(0.0, 0.045, 0.025) / model_scale
	katana.rotation_degrees = Vector3(0, -30, 90)

# Процедурная «Кибер-Сакура»: красный клинок вдоль +Y, хват в начале координат.
func _make_katana() -> Node3D:
	var katana := Node3D.new()
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.018
	handle_mesh.bottom_radius = 0.018
	handle_mesh.height = 0.26
	handle.mesh = handle_mesh
	var handle_mat := StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.12, 0.08, 0.1)
	handle.material_override = handle_mat
	katana.add_child(handle)

	var guard := MeshInstance3D.new()
	var guard_mesh := CylinderMesh.new()
	guard_mesh.top_radius = 0.045
	guard_mesh.bottom_radius = 0.045
	guard_mesh.height = 0.012
	guard.mesh = guard_mesh
	guard.position.y = 0.14
	var guard_mat := StandardMaterial3D.new()
	guard_mat.albedo_color = Color(0.55, 0.45, 0.2)
	guard_mat.metallic = 0.8
	guard_mat.roughness = 0.35
	guard.material_override = guard_mat
	katana.add_child(guard)

	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.012, 0.78, 0.035)
	blade.mesh = blade_mesh
	blade.position.y = 0.53
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.85, 0.08, 0.12)
	blade_mat.metallic = 0.7
	blade_mat.roughness = 0.25
	blade_mat.emission_enabled = true
	blade_mat.emission = Color(1.0, 0.1, 0.15)
	blade_mat.emission_energy_multiplier = 0.5
	blade.material_override = blade_mat
	katana.add_child(blade)
	return katana

func _physics_process(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	skill1_cd = maxf(0.0, skill1_cd - delta)
	skill2_cd = maxf(0.0, skill2_cd - delta)
	_ult_ring_mat.albedo_color.a = 0.08 + 0.45 * (ult_charge / ULT_MAX)
	if hp <= 0.0:
		return

	if combat_enabled and Input.is_action_pressed("attack"):
		try_attack()
	if Input.is_action_just_pressed("jump"):
		try_jump()
	if combat_enabled and Input.is_action_just_pressed("skill_1"):
		try_skill1()
	if combat_enabled and Input.is_action_just_pressed("skill_2"):
		try_skill2()
	if combat_enabled and Input.is_action_just_pressed("ult"):
		try_ult()

	var input_2d := move_input
	if input_2d.length() < 0.15:
		input_2d = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := _camera_relative_direction(input_2d)
	if camera_rig != null and is_instance_valid(camera_rig):
		facing = camera_rig.get_aim_direction()

	if _dash_left > 0.0:
		_dash_left -= delta
		velocity.x = _dash_dir.x * DASH_SPEED
		velocity.z = _dash_dir.z * DASH_SPEED
		for demon in _demons_in_range(1.9):
			if _dash_hit.has(demon):
				continue
			_dash_hit.append(demon)
			var crit := randf() < CRIT_CHANCE
			var damage := SKILL2_DAMAGE * (CRIT_MULT if crit else 1.0)
			demon.take_damage(damage, Elements.Type.FIRE, false, crit)
			add_ult(4.0)
	else:
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED

	var was_on_floor := is_on_floor()
	# Не сбрасываем положительную скорость в кадр нажатия прыжка.
	# Иначе проигрывается только анимация, а тело остаётся на земле.
	if was_on_floor and velocity.y <= 0.0:
		velocity.y = -0.5
	elif not was_on_floor:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if _jump_attack_active and not was_on_floor and is_on_floor():
		_land_jump_attack()
	if arena_half > 0.0:
		global_position.x = clampf(global_position.x, -arena_half, arena_half)
		global_position.z = clampf(global_position.z, -arena_half, arena_half)
	rotation.y = lerp_angle(rotation.y, atan2(facing.x, facing.z), minf(1.0, 14.0 * delta))
	_update_locomotion()

func _camera_relative_direction(input_2d: Vector2) -> Vector3:
	if input_2d.length() > 1.0:
		input_2d = input_2d.normalized()
	if camera_rig == null or not is_instance_valid(camera_rig):
		return Vector3(input_2d.x, 0.0, input_2d.y)
	# Вверх на левом стике = движение туда, куда смотрит камера.
	return (camera_rig.get_planar_right() * input_2d.x
		+ camera_rig.get_planar_forward() * -input_2d.y).normalized()

func _update_locomotion() -> void:
	if _anim == null or _action_playing or hp <= 0.0:
		return
	var want := "run" if Vector2(velocity.x, velocity.z).length() > 0.8 else "idle"
	if _anim.current_animation != want:
		_anim.play(want, 0.2)

# One-shot анимация, ужатая до длительности действия (скорость подгоняется).
func _play_action(anim_name: String, duration: float) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	var length := _anim.get_animation(anim_name).length
	_action_playing = true
	_anim.play(anim_name, 0.1, length / maxf(duration, 0.05))

func _on_action_finished(_anim_name: StringName) -> void:
	_action_playing = false

func try_attack() -> void:
	if not combat_enabled or hp <= 0.0 or attack_cd > 0.0:
		return
	if not is_on_floor():
		try_jump_attack()
		return
	attack_cd = ATTACK_COOLDOWN
	_play_action(ATTACK_ANIMS[_attack_index % ATTACK_ANIMS.size()], 0.5)
	_attack_index += 1
	SFX.play("swing", -2.0, 0.12)
	var slash_pos := global_position + facing * 1.5 + Vector3.UP
	FX.burst(get_parent(), slash_pos, Color(1.0, 0.75, 0.9), 1.1, 0.18)
	for demon in _demons_in_range(ATTACK_RANGE, 0.2):
		var crit := randf() < CRIT_CHANCE
		var damage := ATTACK_DAMAGE * (CRIT_MULT if crit else 1.0)
		demon.take_damage(damage, Elements.Type.PHYSICAL, false, crit)
		add_ult(3.0)

func try_jump() -> void:
	if hp <= 0.0 or not is_on_floor() or _dash_left > 0.0:
		return
	velocity.y = JUMP_VELOCITY
	_play_action("jump", 0.5)

func try_jump_attack() -> void:
	if not combat_enabled or hp <= 0.0 or _jump_attack_active or attack_cd > 0.0:
		return
	_jump_attack_active = true
	attack_cd = 0.7
	velocity.y = -JUMP_ATTACK_DIVE_SPEED
	_play_action("jump_attack", 0.65)
	SFX.play("swing", -1.0, 0.08)

func _land_jump_attack() -> void:
	_jump_attack_active = false
	SFX.play("skill_sakura", -3.0, 0.1)
	var impact_pos := global_position + Vector3.UP * 0.15
	FX.burst(get_parent(), impact_pos, Color(1.0, 0.55, 0.22), 2.1, 0.3)
	for demon in _demons_in_range(JUMP_ATTACK_RADIUS):
		var crit := randf() < CRIT_CHANCE
		var damage := JUMP_ATTACK_DAMAGE * (CRIT_MULT if crit else 1.0)
		demon.take_damage(damage, Elements.Type.PHYSICAL, false, crit)
		add_ult(5.0)

func try_skill1() -> void:
	if not combat_enabled or hp <= 0.0 or skill1_cd > 0.0:
		return
	skill1_cd = SKILL1_COOLDOWN
	_play_action("high_spin_attack", FX.SAKURA_DURATION)
	SFX.play("skill_sakura", 0.0, 0.08)
	var burst_pos := global_position + Vector3.UP * 0.8
	FX.sakura_burst(get_parent(), burst_pos, 2.2)
	for demon in _demons_in_range(SKILL1_RADIUS):
		var crit := randf() < CRIT_CHANCE
		var damage := SKILL1_DAMAGE * (CRIT_MULT if crit else 1.0)
		demon.take_damage(damage, Elements.Type.AIR, false, crit)
		add_ult(4.0)

func try_skill2() -> void:
	if not combat_enabled or hp <= 0.0 or skill2_cd > 0.0:
		return
	skill2_cd = SKILL2_COOLDOWN
	_dash_left = DASH_TIME
	_dash_dir = facing
	_dash_hit.clear()
	_play_action("slide_attack", 0.45)
	SFX.play("skill_dash", 0.0, 0.1)
	FX.burst(get_parent(), global_position + Vector3.UP * 0.8, Color(1.0, 0.7, 0.3), 1.4, 0.25)

func try_ult() -> void:
	if not combat_enabled or hp <= 0.0 or ult_charge < ULT_MAX:
		return
	ult_charge = 0.0
	ult_charge_changed.emit(ult_charge)
	_play_action("spell_cast", 1.0)
	SFX.play("ult_dragon")
	var dragon := DRAGON_SPIRIT_SCENE.instantiate() as DragonSpirit
	dragon.direction = facing
	get_parent().add_child(dragon)
	# Дух летит над полем боя, не пересекается с землёй и персонажами.
	dragon.global_position = global_position + Vector3.UP * DRAGON_SPAWN_HEIGHT + facing * 1.0

func take_damage(amount: float, _element: int = Elements.Type.PHYSICAL) -> void:
	if hp <= 0.0 or _dash_left > 0.0: # во время рывка — неуязвимость
		return
	hp = maxf(0.0, hp - amount)
	hp_changed.emit(hp, max_hp)
	var label_pos := global_position + Vector3.UP * 1.9
	FX.damage_label(get_parent(), label_pos, str(roundi(amount)), Color(1.0, 0.25, 0.25))
	SFX.play("hero_hurt", -2.0, 0.15)
	if hp <= 0.0:
		_die()

func heal(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)
	var label_pos := global_position + Vector3.UP * 1.9
	FX.damage_label(get_parent(), label_pos, "+%d" % roundi(amount), Color(0.35, 1.0, 0.45))
	SFX.play("heal")

func add_ult(amount: float) -> void:
	if hp <= 0.0:
		return
	ult_charge = clampf(ult_charge + amount, 0.0, ULT_MAX)
	ult_charge_changed.emit(ult_charge)

func _die() -> void:
	died.emit()
	SFX.play("hero_death")
	if _anim and _anim.has_animation("death"):
		_action_playing = true
		_anim.play("death", 0.2)
	else:
		var tween := create_tween()
		tween.tween_property(_visual, "rotation_degrees:x", -90.0, 0.5)

func _demons_in_range(radius: float, dot_min := -2.0) -> Array:
	var result: Array = []
	for demon in get_tree().get_nodes_in_group("demons"):
		if not is_instance_valid(demon) or demon.dead:
			continue
		var to: Vector3 = demon.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > radius:
			continue
		if dot_min > -2.0 and dist > 0.01 and facing.dot(to / dist) < dot_min:
			continue
		result.append(demon)
	return result
