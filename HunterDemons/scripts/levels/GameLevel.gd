class_name GameLevel
extends Node3D
## Боевой уровень: редактируемая сцена арены + логика волн демонов.

signal completed
signal failed

const ARENA_HALF := 26.0
const PlayerScene := preload("res://scenes/characters/Player.tscn")
const IceDemonScene := preload("res://scenes/characters/IceDemon.tscn")
const TankDemonScene := preload("res://scenes/characters/TankDemon.tscn")
const CameraRigScene := preload("res://scenes/player/CameraRig.tscn")
const HUDScene := preload("res://scenes/ui/HUD.tscn")
const MEGA_CITY_COLLISION_LAYER := 1 << 1
const DEMON_SPAWN_INTERVAL := 0.28
# Видимая дорожная поверхность находится на высоте основания MegaCity.
const MEGA_CITY_FLOOR_Y := 4.144

@export var level_index := 0
var data: Dictionary = {}
var player: Player
var hud: HUD

var _wave_index := -1
var _alive := 0
var _pending_spawns := 0
var _next_wave_queued := false
var _rng := RandomNumberGenerator.new()
var _mega_city: Node3D
var _mega_city_floor: StaticBody3D
var _floor_y := 0.0

func _init(index := 0) -> void:
	setup(index)

func setup(index: int) -> void:
	level_index = index
	data = LevelData.LEVELS[index]
	_rng.seed = hash("hunter_demons_%d" % index)

func _ready() -> void:
	setup(level_index)
	_configure_environment()
	_configure_arena()
	_select_decor()
	_spawn_player()
	_build_hud()
	SFX.play_music(data.get("music", ""))
	get_tree().create_timer(1.2, false).timeout.connect(_next_wave)

func _configure_environment() -> void:
	var env := Environment.new()
	var is_city: bool = data["style"] == "city"
	if is_city:
		# Для города оставляем только однотонный ночной фон без неба.
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.01, 0.005, 0.03)
	else:
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = data["sky_top"]
		sky_mat.sky_horizon_color = data["sky_horizon"]
		sky_mat.ground_bottom_color = data["ground_color"].darkened(0.5)
		sky_mat.ground_horizon_color = data["sky_horizon"]
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_light_color = data["fog_color"]
	env.fog_density = 0.012
	env.glow_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env == null:
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		add_child(world_env)
	world_env.environment = env

	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.rotation_degrees = Vector3(-50, 35, 0)
		sun.light_energy = 1.1
		sun.shadow_enabled = true

func _configure_arena() -> void:
	var ground_mesh := get_node_or_null("Arena/Ground/GroundMesh") as MeshInstance3D
	if ground_mesh == null:
		return
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = data["ground_color"]
	ground_mesh.material_override = ground_mat

func _select_decor() -> void:
	var decor_root := get_node_or_null("DecorRoot")
	if decor_root == null:
		return
	for child in decor_root.get_children():
		if child is Node3D:
			# Первый уровень использует готовую сцену, а не старые процедурные коробки.
			child.visible = str(child.name).to_snake_case() == data["style"] and child.name != "City"
	var is_city: bool = data["style"] == "city"
	_floor_y = MEGA_CITY_FLOOR_Y if is_city else 0.0
	_set_mega_city_visible(is_city)

func _set_mega_city_visible(visible: bool) -> void:
	if _mega_city == null:
		_mega_city = get_node_or_null("MegaCity") as Node3D
		if _mega_city == null:
			push_error("В сцене уровня отсутствует MegaCity")
			return
		_build_mega_city_collisions()
		_build_mega_city_floor()
	_mega_city.visible = visible
	if _mega_city_floor != null:
		_mega_city_floor.visible = visible

# Неподвижные здания используют StaticBody3D: это корректнее и дешевле, чем
# RigidBody3D, и блокирует проход игрока/демонов через геометрию города.
func _build_mega_city_collisions() -> void:
	for node in _mega_city.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var shape := mesh_node.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var body := StaticBody3D.new()
		body.name = "PlayerMegaCityCollision"
		body.collision_layer = MEGA_CITY_COLLISION_LAYER
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		mesh_node.add_child(body)

# У glTF-улицы нет надёжной игровой поверхности; отдельный статический пол
# удерживает персонажей на уровне города, не добавляя лишнюю геометрию в кадр.
func _build_mega_city_floor() -> void:
	_mega_city_floor = StaticBody3D.new()
	_mega_city_floor.name = "MegaCityFloor"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(90.0, 0.2, 90.0)
	collision.shape = shape
	collision.position.y = MEGA_CITY_FLOOR_Y - 0.1
	_mega_city_floor.add_child(collision)
	add_child(_mega_city_floor)

func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = Vector3(0, _floor_y + 1.0, 4.0)
	player.arena_half = ARENA_HALF
	player.died.connect(_on_player_died)
	var rig := CameraRigScene.instantiate() as CameraRig
	rig.target = player
	add_child(rig)
	player.camera_rig = rig

func _build_hud() -> void:
	hud = HUDScene.instantiate() as HUD
	add_child(hud)
	hud.set_player(player)
	hud.show_title("Уровень %d — %s" % [level_index + 1, data["name"]])

func _next_wave() -> void:
	_next_wave_queued = false
	if player == null or player.hp <= 0.0:
		return
	_wave_index += 1
	if _wave_index >= data["waves"].size():
		hud.set_wave_text("Зачищено!")
		get_tree().create_timer(1.0, false).timeout.connect(func() -> void: completed.emit())
		return
	if _wave_index > 0:
		player.heal(25.0)
	hud.set_wave_text("Волна %d / %d" % [_wave_index + 1, data["waves"].size()])
	var delay := 0.0
	for entry in data["waves"][_wave_index]:
		for i in entry["count"]:
			_queue_demon_spawn(entry["element"], delay)
			delay += DEMON_SPAWN_INTERVAL

func _queue_demon_spawn(element: int, delay: float) -> void:
	_pending_spawns += 1
	get_tree().create_timer(delay, false).timeout.connect(func() -> void:
		_pending_spawns -= 1
		if player != null and is_instance_valid(player) and player.hp > 0.0:
			_spawn_demon(element)
		_try_advance_wave()
	)

func _spawn_demon(element: int) -> void:
	var demon: Demon
	if element == Elements.Type.WATER:
		demon = IceDemonScene.instantiate()
	else:
		# Базовые фракции используют анимированную модель вместо PrismMesh-пирамиды.
		demon = TankDemonScene.instantiate()
	demon.setup(element)
	demon.target = player
	add_child(demon)
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf_range(16.0, 23.0)
	demon.global_position = Vector3(cos(angle) * radius, _floor_y + 0.6, sin(angle) * radius)
	demon.died.connect(_on_demon_died)
	_alive += 1
	SFX.play("demon_spawn", -10.0, 0.3)
	FX.burst(self, demon.global_position + Vector3.UP, Elements.COLORS[element], 1.5, 0.45)

func _on_demon_died(_demon: Demon) -> void:
	_alive -= 1
	if is_instance_valid(player):
		player.add_ult(14.0)
	_try_advance_wave()

func _try_advance_wave() -> void:
	if _alive > 0 or _pending_spawns > 0 or _next_wave_queued:
		return
	_next_wave_queued = true
	get_tree().create_timer(1.6, false).timeout.connect(_next_wave)

func _on_player_died() -> void:
	get_tree().create_timer(1.2, false).timeout.connect(func() -> void: failed.emit())
