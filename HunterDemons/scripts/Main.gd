extends Node
## Точка входа: меню -> деревня -> сюжет -> уровень -> сюжет -> следующая деревня.
## Запуск с аргументом `-- --smoke` сразу стартует уровень 1 (для автотестов).

const VillageLevelScene := preload("res://scenes/levels/VillageLevel.tscn")
const GameLevelScene := preload("res://scenes/levels/GameLevel.tscn")
const MainMenuScene := preload("res://scenes/ui/MainMenu.tscn")
const NarrationOverlayScene := preload("res://scenes/ui/NarrationOverlay.tscn")

var _smoke := false
var _village: Node
var _level: GameLevel
var _level_index := 0

func _ready() -> void:
	_smoke = OS.get_cmdline_user_args().has("--smoke")
	if _smoke:
		_start_level(0)
		var attack_timer := Timer.new()
		attack_timer.wait_time = 0.5
		attack_timer.autostart = true
		attack_timer.timeout.connect(_smoke_attack)
		add_child(attack_timer)
		if OS.get_cmdline_user_args().has("--screenshot"):
			var delay := 2.0 if OS.get_cmdline_user_args().has("--closeup") else 5.5
			get_tree().create_timer(delay).timeout.connect(_smoke_screenshot)
	else:
		_show_menu()

func _smoke_attack() -> void:
	if _level == null or not is_instance_valid(_level.player):
		return
	var player := _level.player
	var nearest: Node3D = null
	var best := INF
	for demon in get_tree().get_nodes_in_group("demons"):
		if not is_instance_valid(demon) or demon.dead:
			continue
		var dist: float = demon.global_position.distance_to(player.global_position)
		if dist < best:
			best = dist
			nearest = demon
	if nearest:
		var to := nearest.global_position - player.global_position
		to.y = 0.0
		if to.length() > 0.1:
			player.facing = to.normalized()
	player.try_attack()

func _smoke_screenshot() -> void:
	if OS.get_cmdline_user_args().has("--closeup"):
		var player := get_tree().get_first_node_in_group("player")
		var cam := get_viewport().get_camera_3d()
		if player and cam:
			cam.global_position = player.global_position + Vector3(1.4, 1.3, 1.9)
			cam.look_at(player.global_position + Vector3.UP * 0.9)
			await get_tree().process_frame
			await get_tree().process_frame
			print("SMOKE: player=", player.global_position, " cam=", cam.global_position)
	var image := get_viewport().get_texture().get_image()
	image.save_png("/tmp/hunterdemons_smoke.png")
	print("SMOKE: screenshot saved")
	get_tree().quit()

func _show_menu() -> void:
	_clear()
	var menu := MainMenuScene.instantiate() as MainMenu
	add_child(menu)
	menu.level_selected.connect(_start_village)

func _clear() -> void:
	get_tree().paused = false
	for child in get_children():
		child.queue_free()
	_village = null
	_level = null

func _start_village(index: int) -> void:
	_clear()
	_level_index = index
	_village = VillageLevelScene.instantiate()
	if _village.has_method("setup"):
		_village.setup(index)
	add_child(_village)
	_village.battle_requested.connect(_start_level)

func _start_level(index: int) -> void:
	_clear()
	_level_index = index
	_level = GameLevelScene.instantiate()
	_level.setup(index)
	add_child(_level)
	_level.completed.connect(_on_level_completed)
	_level.failed.connect(_on_level_failed)
	if _smoke:
		return
	get_tree().paused = true
	_narrate(LevelData.LEVELS[index]["intro"], _unpause)

func _unpause() -> void:
	get_tree().paused = false

func _on_level_completed() -> void:
	GameState.unlock_level(_level_index + 1)
	SFX.play("victory")
	if _smoke:
		print("SMOKE: level completed")
		return
	get_tree().paused = true
	_narrate(LevelData.LEVELS[_level_index]["outro"], _after_outro)

func _after_outro() -> void:
	var next := _level_index + 1
	if next < LevelData.LEVELS.size():
		_start_village(next)
	else:
		_show_menu()

func _on_level_failed() -> void:
	SFX.play("defeat")
	if _smoke:
		print("SMOKE: level failed")
		return
	get_tree().paused = true
	var line := {"name": "Тэцурю", "text": "Вставай, Юкка… Город всё ещё ждёт свою охотницу."}
	_narrate([line], _retry_from_village)

func _retry_from_village() -> void:
	_start_village(_level_index)

func _narrate(lines: Array, then: Callable) -> void:
	var overlay := NarrationOverlayScene.instantiate() as NarrationOverlay
	add_child(overlay)
	overlay.show_lines(lines)
	overlay.finished.connect(then, CONNECT_ONE_SHOT)
