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

var level_index := 0
var data: Dictionary = {}
var player: Player
var hud: HUD

var _wave_index := -1
var _alive := 0
var _rng := RandomNumberGenerator.new()

func _init(index := 0) -> void:
	setup(index)

func setup(index: int) -> void:
	level_index = index
	data = LevelData.LEVELS[index]
	_rng.seed = hash("hunter_demons_%d" % index)

func _ready() -> void:
	if data.is_empty():
		setup(level_index)
	_configure_environment()
	_configure_arena()
	_select_decor()
	_spawn_player()
	_build_hud()
	SFX.play_music(data.get("music", ""))
	get_tree().create_timer(1.2, false).timeout.connect(_next_wave)

func _configure_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = data["sky_top"]
	sky_mat.sky_horizon_color = data["sky_horizon"]
	sky_mat.ground_bottom_color = data["ground_color"].darkened(0.5)
	sky_mat.ground_horizon_color = data["sky_horizon"]
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
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
			child.visible = str(child.name).to_snake_case() == data["style"]

func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 1.0, 4.0)
	player.arena_half = ARENA_HALF
	player.died.connect(_on_player_died)
	var rig := CameraRigScene.instantiate() as CameraRig
	rig.target = player
	add_child(rig)

func _build_hud() -> void:
	hud = HUDScene.instantiate() as HUD
	add_child(hud)
	hud.set_player(player)
	hud.show_title("Уровень %d — %s" % [level_index + 1, data["name"]])

func _next_wave() -> void:
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
	for entry in data["waves"][_wave_index]:
		for i in entry["count"]:
			_spawn_demon(entry["element"])

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
	demon.global_position = Vector3(cos(angle) * radius, 0.6, sin(angle) * radius)
	demon.died.connect(_on_demon_died)
	_alive += 1
	SFX.play("demon_spawn", -10.0, 0.3)
	FX.burst(self, demon.global_position + Vector3.UP, Elements.COLORS[element], 1.5, 0.45)

func _on_demon_died(_demon: Demon) -> void:
	_alive -= 1
	if is_instance_valid(player):
		player.add_ult(14.0)
	if _alive <= 0:
		get_tree().create_timer(1.6, false).timeout.connect(_next_wave)

func _on_player_died() -> void:
	get_tree().create_timer(1.2, false).timeout.connect(func() -> void: failed.emit())
