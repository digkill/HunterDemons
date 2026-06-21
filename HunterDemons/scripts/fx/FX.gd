class_name FX
## Процедурные эффекты и вспышки, цифры урона в стиле Dota 2.

const SAKURA_EFFECT_PATH := \
	"res://assets/effects/Light Effect/Light Effect.gltf"
const SAKURA_TEX_PATH := \
	"res://assets/effects/Light Effect/textures/lightdotsSmall.comb.png"
const SAKURA_DURATION := 1.5

# «Взрыв сакуры» — использует готовую GLTF-модель с исправленным материалом.
static func sakura_burst(parent: Node, pos: Vector3, scale_factor := 2.2) -> void:
	if not ResourceLoader.exists(SAKURA_EFFECT_PATH):
		burst(parent, pos, Color(1.0, 0.5, 0.8), scale_factor * 2.0, 0.4)
		return
	var packed := load(SAKURA_EFFECT_PATH) as PackedScene
	if packed == null:
		return
	var fx := packed.instantiate()
	fx.scale = Vector3.ONE * scale_factor
	parent.add_child(fx)
	fx.global_position = pos
	_apply_sakura_material(fx)
	var anim := fx.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim != null and anim.has_animation("Animation"):
		var raw_dur: float = anim.get_animation("Animation").length
		anim.play("Animation", -1.0, raw_dur / SAKURA_DURATION)
	fx.get_tree().create_timer(SAKURA_DURATION, false).timeout.connect(fx.queue_free)

# Переводим PBR-материал GLTF в unshaded-эмиссию, чтобы эффект не был тёмным.
static func _apply_sakura_material(root: Node) -> void:
	var tex: Texture2D
	if ResourceLoader.exists(SAKURA_TEX_PATH):
		tex = load(SAKURA_TEX_PATH) as Texture2D
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.35, 0.9, 0.85)
	if tex != null:
		mat.albedo_texture = tex
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 1.0)
	mat.emission_energy_multiplier = 1.2
	for node in root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = mat

static func burst(parent: Node, pos: Vector3, color: Color, radius: float,
		duration := 0.35) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color, 0.55)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	parent.add_child(instance)
	instance.global_position = pos
	instance.scale = Vector3.ONE * 0.25
	var tween := instance.create_tween()
	tween.set_parallel(true)
	tween.tween_property(instance, "scale", Vector3.ONE, duration)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(instance.queue_free)

# Всплывающие цифры урона в стиле Dota 2: вылетают вверх с разлётом,
# появляются с «пружинкой», криты — крупнее и живут дольше.
static func damage_label(parent: Node, pos: Vector3, text: String,
		color := Color.WHITE, crit := false) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 96 if crit else 56
	label.outline_size = 22 if crit else 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	parent.add_child(label)
	var spread := Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.25, 0.25))
	label.global_position = pos + spread
	label.scale = Vector3.ONE * 0.1
	var lifetime := 1.0 if crit else 0.7
	var rise := 1.9 if crit else 1.3
	var pop_scale := 1.35 if crit else 1.0
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector3.ONE * pop_scale, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rise_target := label.global_position + Vector3.UP * rise
	tween.tween_property(label, "global_position", rise_target, lifetime) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, lifetime * 0.5) \
		.set_delay(lifetime * 0.5)
	tween.chain().tween_callback(label.queue_free)
