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
	var gate_label := get_node_or_null("Interactables/BattleGate/GateLevelLabel") as Label3D
	if gate_label != null:
		gate_label.text = "К бою: %s" % LevelData.LEVELS[level_index]["name"]

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
