class_name VillageLevel
extends Node3D
## Деревня-хаб: редактируемая сцена GLTF-локации, NPC и ворот к бою.

signal battle_requested(index: int)

const PlayerScene := preload("res://scenes/characters/Player.tscn")
const CameraRigScene := preload("res://scenes/player/CameraRig.tscn")
const VillageHUDScene := preload("res://scenes/ui/VillageHUD.tscn")
const INTERACT_RADIUS := 3.1

var level_index := 0
var player: Player
var hud

var _interactables: Array[Dictionary] = []
var _active: Dictionary = {}
var _pending_battle := false

func _init(index := 0) -> void:
	setup(index)

func setup(index: int) -> void:
	level_index = index

func _ready() -> void:
	_configure_scene()
	_register_scene_interactables()
	_spawn_player()
	_build_hud()
	SFX.play_music("music_menu")

func _process(_delta: float) -> void:
	_update_active_interactable()
	if Input.is_action_just_pressed("interact"):
		_interact()

func _configure_scene() -> void:
	var model := get_node_or_null("VillageModel")
	if model != null:
		_generate_collision(model)
		_fix_village_materials(model)
	_configure_day_skybox()
	_configure_portal_effect()
	var gate_label := get_node_or_null("Interactables/BattleGate/GateLevelLabel") as Label3D
	if gate_label != null:
		gate_label.text = "К бою: %s" % LevelData.LEVELS[level_index]["name"]

func _configure_portal_effect() -> void:
	var portal := get_node_or_null("Gate/PortalEffect")
	if portal == null:
		return
	var anim_player := portal.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player != null:
		var anim := anim_player.get_animation("Animation")
		if anim != null:
			anim.loop_mode = Animation.LOOP_LINEAR
		anim_player.play("Animation")
	_make_portal_unshaded(portal)

func _make_portal_unshaded(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			for surface in range(mesh_node.mesh.get_surface_count()):
				var mat := mesh_node.get_active_material(surface)
				if mat is BaseMaterial3D:
					var dup := mat.duplicate() as BaseMaterial3D
					dup.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					dup.cull_mode = BaseMaterial3D.CULL_DISABLED
					mesh_node.set_surface_override_material(surface, dup)
	for child in node.get_children():
		_make_portal_unshaded(child)

func _fix_village_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			var is_foliage := false
			for surface in range(mesh_node.mesh.get_surface_count()):
				var mat := mesh_node.get_active_material(surface)
				if mat is BaseMaterial3D:
					var bmat := mat as BaseMaterial3D
					var dup: BaseMaterial3D = null
					var changed := false

					if bmat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
						is_foliage = true
						dup = bmat.duplicate() as BaseMaterial3D
						dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
						dup.alpha_scissor_threshold = 0.4
						changed = true

					# Aggressively disable AO on the entire stylized environment model.
					# The baked AO maps are too dark and create ugly black splotches
					# that don't match the bright painted art style.
					if bmat.ao_enabled or bmat.ao_light_affect > 0.0 or bmat.ao_texture != null:
						if dup == null:
							dup = bmat.duplicate() as BaseMaterial3D
						dup.ao_enabled = false
						dup.ao_texture = null
						dup.ao_light_affect = 0.0
						changed = true

					if changed and dup != null:
						mesh_node.set_surface_override_material(surface, dup)

			if is_foliage:
				mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_fix_village_materials(child)

func _configure_day_skybox() -> void:
	var skybox := get_node_or_null("DaySkybox") as Node3D
	if skybox == null:
		return
	for node in skybox.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh_node.mesh == null:
			continue
		for surface in mesh_node.mesh.get_surface_count():
			var source := mesh_node.get_active_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as StandardMaterial3D
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh_node.set_surface_override_material(surface, material)

func _generate_collision(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			child.create_trimesh_collision()
		_generate_collision(child)

func _register_scene_interactables() -> void:
	_interactables.clear()
	var root := get_node_or_null("Interactables")
	if root == null:
		return
	for point in _collect_interactable_points(root):
		var body := point as InteractablePoint
		var text := body.text.replace("{level_name}", LevelData.LEVELS[level_index]["name"])
		_register(body.title, body.speaker, body.global_position, text, body.verb, body.battle)

func _collect_interactable_points(root: Node) -> Array[InteractablePoint]:
	var result: Array[InteractablePoint] = []
	if root is InteractablePoint:
		result.append(root)
	for child in root.get_children():
		result.append_array(_collect_interactable_points(child))
	return result

func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	player.combat_enabled = false
	add_child(player)
	player.global_position = Vector3(0, 0.5, 5.0)
	player.facing = Vector3.FORWARD
	var rig := CameraRigScene.instantiate() as CameraRig
	rig.target = player
	add_child(rig)
	player.camera_rig = rig

func _build_hud() -> void:
	hud = VillageHUDScene.instantiate() as VillageHUD
	add_child(hud)
	hud.set_player(player)
	hud.interact_pressed.connect(_interact)
	hud.dialog_action_pressed.connect(_on_dialog_action)

func _update_active_interactable() -> void:
	if player == null:
		return
	var best := INF
	var found: Dictionary = {}
	for entry in _interactables:
		var pos: Vector3 = entry["position"]
		var dist := pos.distance_to(player.global_position)
		if dist < INTERACT_RADIUS and dist < best:
			best = dist
			found = entry
	_active = found
	if found.is_empty():
		hud.set_prompt("")
	else:
		hud.set_prompt("%s: %s" % [found["verb"], found["title"]])

func _interact() -> void:
	if _active.is_empty():
		return
	_pending_battle = bool(_active.get("battle", false))
	var action := "Начать бой" if _pending_battle else ""
	hud.show_dialog(_active["speaker"], _active["text"], action)
	SFX.play("ui_tap", -4.0)

func _on_dialog_action() -> void:
	if _pending_battle:
		battle_requested.emit(level_index)

func _register(title: String, speaker: String, pos: Vector3,
		text: String, verb: String, battle := false) -> void:
	_interactables.append({
		"title": title,
		"speaker": speaker,
		"position": pos,
		"text": text,
		"verb": verb,
		"battle": battle,
	})
