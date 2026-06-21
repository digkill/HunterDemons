class_name Demon
extends CharacterBody3D
## Базовый демон. Фракция задаётся через setup() — от неё зависят статы, цвет и слабости.

signal died(demon: Demon)

const GRAVITY := 28.0
const ATTACK_INTERVAL := 1.2
# Все текущие демоны сражаются только в ближнем бою: уменьшаем их темп сближения.
const MELEE_MOVE_SPEED_MULTIPLIER := 0.5

const PRESETS := {
	Elements.Type.FIRE: {"hp": 40.0, "speed": 4.0, "damage": 10.0, "scale": 1.0},
	Elements.Type.EARTH: {"hp": 95.0, "speed": 2.2, "damage": 15.0, "scale": 1.45},
	Elements.Type.AIR: {"hp": 26.0, "speed": 5.4, "damage": 7.0, "scale": 0.85},
	Elements.Type.WATER: {"hp": 55.0, "speed": 3.4, "damage": 9.0, "scale": 1.1},
	Elements.Type.UNDEAD: {"hp": 38.0, "speed": 2.7, "damage": 9.0, "scale": 1.0},
	Elements.Type.GHOST: {"hp": 30.0, "speed": 4.4, "damage": 8.0, "scale": 1.0},
}

var element: int = Elements.Type.FIRE
var max_hp := 40.0
var hp := 40.0
var speed := 3.0
var damage := 8.0
var attack_range := 1.8
var dead := false
var target: Player

var _attack_cd := 0.0
var _scale_factor := 1.0
var _mat: StandardMaterial3D

func setup(p_element: int) -> void:
	element = p_element
	var preset: Dictionary = PRESETS[element]
	max_hp = preset["hp"]
	hp = max_hp
	speed = preset["speed"] * MELEE_MOVE_SPEED_MULTIPLIER
	damage = preset["damage"]
	_scale_factor = preset["scale"]

func _ready() -> void:
	add_to_group("demons")
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		add_child(col)
	var capsule := col.shape as CapsuleShape3D
	if capsule == null:
		capsule = CapsuleShape3D.new()
		col.shape = capsule
	capsule.radius = 0.45 * _scale_factor
	capsule.height = 1.5 * _scale_factor
	col.position.y = 0.75 * _scale_factor
	_build_visual()

func _build_visual() -> void:
	var color: Color = Elements.COLORS[element]
	var body := get_node_or_null("Body") as MeshInstance3D
	if body == null:
		body = MeshInstance3D.new()
		body.name = "Body"
		add_child(body)
	var prism := body.mesh as PrismMesh
	if prism == null:
		prism = PrismMesh.new()
		body.mesh = prism
	prism.size = Vector3(1.0, 1.5, 0.9) * _scale_factor
	body.position.y = 0.75 * _scale_factor
	_mat = body.material_override as StandardMaterial3D
	if _mat == null:
		_mat = StandardMaterial3D.new()
		body.material_override = _mat
	_mat.albedo_color = color.darkened(0.25)
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 0.35
	if element == Elements.Type.GHOST:
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.albedo_color = Color(color, 0.5)

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
		if dist > attack_range:
			var dir := to / maxf(dist, 0.001)
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, 10.0 * delta))
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if _attack_cd <= 0.0:
				_attack_cd = ATTACK_INTERVAL
				target.take_damage(damage, element)
				SFX.play("demon_attack", -6.0, 0.2)
				var hit_pos := target.global_position + Vector3.UP
				FX.burst(get_parent(), hit_pos, Elements.COLORS[element], 0.8, 0.2)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()

# Цвета цифр (как в Dota 2): крит — оранжевый крупный, ульта — голубой,
# бонус по слабости — жёлтый, резист — серый, обычный — белый.
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
	if _mat != null:
		_mat.emission_energy_multiplier = 3.0
		var tween := create_tween()
		tween.tween_property(_mat, "emission_energy_multiplier", 0.35, 0.25)
	if hp <= 0.0:
		_die()

func _die() -> void:
	dead = true
	SFX.play("demon_death", -3.0, 0.25)
	var burst_pos := global_position + Vector3.UP * 0.8
	FX.burst(get_parent(), burst_pos, Elements.COLORS[element], 1.4 * _scale_factor, 0.4)
	died.emit(self)
	queue_free()
