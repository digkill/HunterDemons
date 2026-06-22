class_name DragonSpirit
extends Node3D
## Ульта Юкки: Тэцурю, дух дракона, проносится вперёд и сжигает всё на своём пути.
## Урон ульты игнорирует сопротивления фракций.

const SPEED := 11.0
const LIFETIME := 2.6
const TICK := 0.18
const DAMAGE := 34.0
const HIT_RADIUS := 3.6
const SEGMENTS := 7
const TRAIL_LENGTH := 64
const TRAIL_MARKERS := 5
const DRAGON_ANIMATION := &"Action" # Импортированное имя дорожки «Armature | Action».

var direction := Vector3.FORWARD

var _life := 0.0
var _tick_left := 0.0
var _trail := PackedVector3Array()
var _trail_markers: Array[MeshInstance3D] = []
var _visual_root: Node3D
var _visual_base_position := Vector3.ZERO
var _visual_base_scale := Vector3.ONE
var _ending := false
var _anim: AnimationPlayer

func _ready() -> void:
	_visual_root = get_node_or_null("ModelPivot") as Node3D
	if _visual_root == null:
		_build_fallback_dragon()
	_visual_base_position = _visual_root.position
	_visual_base_scale = _visual_root.scale
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null and _anim.has_animation(DRAGON_ANIMATION):
		_anim.play(DRAGON_ANIMATION)
	_build_trail_markers()
	_face_direction()

func _build_fallback_dragon() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "ModelPivot"
	add_child(_visual_root)
	for i in SEGMENTS:
		var t := float(i) / float(SEGMENTS - 1)
		var instance := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var r := lerpf(1.1, 0.35, t)
		sphere.radius = r
		sphere.height = r * 2.0
		instance.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.5, 0.95, 1.0).lerp(Color(1.0, 0.4, 0.8), t)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 2.2
		instance.material_override = mat
		instance.position = Vector3(0.0, sin(t * TAU) * 0.25, -t * 4.8)
		_visual_root.add_child(instance)

func _build_trail_markers() -> void:
	for i in TRAIL_MARKERS:
		var t := float(i) / float(maxi(TRAIL_MARKERS - 1, 1))
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var r := lerpf(0.75, 0.2, t)
		sphere.radius = r
		sphere.height = r * 2.0
		marker.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.45, 0.95, 1.0, lerpf(0.75, 0.15, t))
		mat.emission_enabled = true
		mat.emission = Color(0.45, 0.95, 1.0).lerp(Color(1.0, 0.35, 0.75), t)
		mat.emission_energy_multiplier = 2.4
		marker.material_override = mat
		marker.top_level = true
		add_child(marker)
		_trail_markers.append(marker)

func _physics_process(delta: float) -> void:
	if _ending:
		return
	_life += delta
	var move_dir := direction.normalized()
	if move_dir.length() <= 0.001:
		move_dir = Vector3.FORWARD
	global_position += move_dir * SPEED * delta
	_face_direction()
	_visual_root.position = _visual_base_position + Vector3.UP * sin(_life * 6.0) * 0.22
	if _trail.is_empty():
		FX.burst(get_parent(), global_position, Color(0.5, 0.95, 1.0), 2.6, 0.5)
		for i in TRAIL_LENGTH:
			_trail.append(global_position)
	_trail.insert(0, global_position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.resize(TRAIL_LENGTH)
	for i in _trail_markers.size():
		var idx := mini((i + 2) * 7, _trail.size() - 1)
		var bob := sin(_life * 7.0 - float(i) * 0.8) * 0.35
		_trail_markers[i].global_position = _trail[idx] + Vector3.UP * bob

	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = TICK
		for demon in get_tree().get_nodes_in_group("demons"):
			if not is_instance_valid(demon) or demon.dead:
				continue
			if demon.global_position.distance_to(global_position) <= HIT_RADIUS:
				demon.take_damage(DAMAGE, Elements.Type.PHYSICAL, true)

	if _life >= LIFETIME:
		_finish()

func _face_direction() -> void:
	var flat := direction
	flat.y = 0.0
	if flat.length() <= 0.001:
		return
	rotation.y = atan2(flat.x, flat.z)

func _finish() -> void:
	_ending = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual_root, "scale", _visual_base_scale * 0.01, 0.4)
	for marker in _trail_markers:
		tween.tween_property(marker, "scale", Vector3.ONE * 0.01, 0.4)
	tween.chain().tween_callback(queue_free)
