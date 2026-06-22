extends SceneTree
## Regenerates editable .tscn wrappers for levels, characters, and simple models.
## Run: godot --headless --path . -s res://tools/generate_editable_scenes.gd

const HERO_BINARY := "res://assets/MainHero/hero.scn"
const HERO_TEXT := "res://assets/MainHero/hero.tscn"
const VILLAGE_MODEL := "res://assets/Stylized Japanese Market Game-Ready Env/Stylized Japanese Market Game-Ready Env.gltf"

const SCRIPTS := {
	"player": "res://scripts/player/Player.gd",
	"demon": "res://scripts/enemies/Demon.gd",
	"ice_demon": "res://scripts/enemies/IceDemon.gd",
	"game_level": "res://scripts/levels/GameLevel.gd",
	"village_level": "res://scripts/levels/VillageLevel.gd",
	"interactable": "res://scripts/levels/InteractablePoint.gd",
	"camera_rig": "res://scripts/player/CameraRig.gd",
	"dragon_spirit": "res://scripts/combat/DragonSpirit.gd",
	"main_menu": "res://scripts/ui/MainMenu.gd",
	"hud": "res://scripts/ui/HUD.gd",
	"village_hud": "res://scripts/ui/VillageHUD.gd",
	"narration_overlay": "res://scripts/ui/NarrationOverlay.gd",
}

func _init() -> void:
	_ensure_dirs()
	_convert_hero_scene()
	_save_scene(_make_katana_scene(), "res://scenes/weapons/CyberSakuraKatana.tscn")
	_save_scene(_make_player_scene(), "res://scenes/characters/Player.tscn")
	_attach_root_script("res://scenes/characters/Player.tscn", "Player",
		SCRIPTS["player"], "script_player")
	_save_scene(_make_demon_scene(), "res://scenes/characters/Demon.tscn")
	_attach_root_script("res://scenes/characters/Demon.tscn", "Demon",
		SCRIPTS["demon"], "script_demon")
	_save_scene(_make_ice_demon_scene(), "res://scenes/characters/IceDemon.tscn")
	_attach_root_script("res://scenes/characters/IceDemon.tscn", "IceDemon",
		SCRIPTS["ice_demon"], "script_ice")
	_save_scene(_make_game_level_scene(), "res://scenes/levels/GameLevel.tscn")
	_attach_root_script("res://scenes/levels/GameLevel.tscn", "GameLevel",
		SCRIPTS["game_level"], "script_game_level")
	_save_scene(_make_village_level_scene(), "res://scenes/levels/VillageLevel.tscn")
	_attach_root_script("res://scenes/levels/VillageLevel.tscn", "VillageLevel",
		SCRIPTS["village_level"], "script_village_level")
	_save_scene(_make_camera_rig_scene(), "res://scenes/player/CameraRig.tscn")
	_save_scene(_make_dragon_spirit_scene(), "res://scenes/effects/DragonSpirit.tscn")
	_save_scene(_make_main_menu_scene(), "res://scenes/ui/MainMenu.tscn")
	_save_scene(_make_canvas_ui_scene("HUD", SCRIPTS["hud"]), "res://scenes/ui/HUD.tscn")
	_save_scene(_make_canvas_ui_scene("VillageHUD", SCRIPTS["village_hud"]), "res://scenes/ui/VillageHUD.tscn")
	_save_scene(_make_narration_overlay_scene(),
		"res://scenes/ui/NarrationOverlay.tscn")
	quit(0)

func _ensure_dirs() -> void:
	for path in [
		"res://scenes/characters",
		"res://scenes/effects",
		"res://scenes/levels",
		"res://scenes/player",
		"res://scenes/ui",
		"res://scenes/weapons",
	]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

func _convert_hero_scene() -> void:
	if not ResourceLoader.exists(HERO_BINARY):
		return
	var scene := load(HERO_BINARY) as PackedScene
	if scene == null:
		push_error("Cannot load " + HERO_BINARY)
		return
	var err := ResourceSaver.save(scene, HERO_TEXT)
	if err != OK:
		push_error("Cannot save " + HERO_TEXT + ": " + error_string(err))

func _save_scene(root: Node, path: String) -> void:
	_set_owner_recursive(root, root)
	var scene := PackedScene.new()
	var pack_err := scene.pack(root)
	if pack_err != OK:
		push_error("Cannot pack " + path + ": " + error_string(pack_err))
		root.free()
		return
	var save_err := ResourceSaver.save(scene, path)
	if save_err != OK:
		push_error("Cannot save " + path + ": " + error_string(save_err))
	root.free()

func _attach_root_script(path: String, root_name: String, script_path: String,
		resource_id: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var ext_line := "[ext_resource type=\"Script\" path=\"%s\" id=\"%s\"]" % [
		script_path, resource_id]
	if not text.contains(ext_line):
		var first_line_end := text.find("\n")
		text = text.insert(first_line_end + 1, "\n" + ext_line)
	var node_marker := "[node name=\"%s\"" % root_name
	var node_start := text.find(node_marker)
	if node_start >= 0:
		var node_line_end := text.find("\n", node_start)
		var next_line_end := text.find("\n", node_line_end + 1)
		var next_line := text.substr(node_line_end + 1, next_line_end - node_line_end - 1)
		if not next_line.begins_with("script = "):
			text = text.insert(node_line_end + 1, "script = ExtResource(\"%s\")\n" % resource_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)

func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	if node != owner_node:
		node.owner = owner_node
		if node.scene_file_path != "":
			return
	for child in node.get_children():
		_set_owner_recursive(child, owner_node)

func _mat(color: Color, emission := Color.TRANSPARENT, emission_energy := 0.0,
		alpha := 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, alpha)
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat

func _make_katana_scene() -> Node3D:
	var root := Node3D.new()
	root.name = "CyberSakuraKatana"

	var handle := MeshInstance3D.new()
	handle.name = "Handle"
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.018
	handle_mesh.bottom_radius = 0.018
	handle_mesh.height = 0.26
	handle.mesh = handle_mesh
	handle.material_override = _mat(Color(0.12, 0.08, 0.1))
	root.add_child(handle)

	var guard := MeshInstance3D.new()
	guard.name = "Guard"
	var guard_mesh := CylinderMesh.new()
	guard_mesh.top_radius = 0.045
	guard_mesh.bottom_radius = 0.045
	guard_mesh.height = 0.012
	guard.mesh = guard_mesh
	guard.position.y = 0.14
	var guard_mat := _mat(Color(0.55, 0.45, 0.2))
	guard_mat.metallic = 0.8
	guard_mat.roughness = 0.35
	guard.material_override = guard_mat
	root.add_child(guard)

	var blade := MeshInstance3D.new()
	blade.name = "Blade"
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.012, 0.78, 0.035)
	blade.mesh = blade_mesh
	blade.position.y = 0.53
	var blade_mat := _mat(Color(0.85, 0.08, 0.12), Color(1.0, 0.1, 0.15), 0.5)
	blade_mat.metallic = 0.7
	blade_mat.roughness = 0.25
	blade.material_override = blade_mat
	root.add_child(blade)
	return root

func _make_player_scene() -> Node:
	var root := CharacterBody3D.new()
	root.name = "Player"

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.7
	col.shape = capsule
	col.position.y = 0.85
	root.add_child(col)

	var visual := Node3D.new()
	visual.name = "VisualRoot"
	root.add_child(visual)
	if ResourceLoader.exists(HERO_TEXT):
		var hero_scene := load(HERO_TEXT) as PackedScene
		var hero := hero_scene.instantiate()
		hero.name = "HeroModel"
		visual.add_child(hero)

	var ring := MeshInstance3D.new()
	ring.name = "UltRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 0.95
	ring.mesh = torus
	ring.position.y = 0.08
	ring.material_override = _mat(Color(0.4, 0.95, 1.0, 0.1), Color(0.4, 0.95, 1.0), 1.0, 0.1)
	root.add_child(ring)
	return root

func _make_demon_scene() -> Node:
	var root := CharacterBody3D.new()
	root.name = "Demon"
	_add_demon_collision_and_body(root)
	return root

func _make_ice_demon_scene() -> Node:
	var root := CharacterBody3D.new()
	root.name = "IceDemon"
	_add_demon_collision_and_body(root, false)
	if ResourceLoader.exists("res://assets/demons/icedemon/source/icedemon.glb"):
		var model_scene := load("res://assets/demons/icedemon/source/icedemon.glb") as PackedScene
		var model := model_scene.instantiate()
		model.name = "ModelRoot"
		root.add_child(model)
	return root

func _add_demon_collision_and_body(root: Node, add_body := true) -> void:
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.5
	col.shape = capsule
	col.position.y = 0.75
	root.add_child(col)
	if not add_body:
		return
	var body := MeshInstance3D.new()
	body.name = "Body"
	var prism := PrismMesh.new()
	prism.size = Vector3(1.0, 1.5, 0.9)
	body.mesh = prism
	body.position.y = 0.75
	body.material_override = _mat(Color(0.7, 0.15, 0.1), Color(1.0, 0.2, 0.15), 0.35)
	root.add_child(body)

func _make_game_level_scene() -> Node3D:
	var root := Node3D.new()
	root.name = "GameLevel"

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	root.add_child(sun)

	var arena := Node3D.new()
	arena.name = "Arena"
	root.add_child(arena)
	_add_ground(arena)
	_add_walls(arena)

	var decor_root := Node3D.new()
	decor_root.name = "DecorRoot"
	root.add_child(decor_root)
	decor_root.add_child(_make_city_decor())
	decor_root.add_child(_make_forest_decor())
	decor_root.add_child(_make_temple_decor())
	return root

func _add_ground(parent: Node) -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	parent.add_child(ground)

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(90, 1, 90)
	col.shape = box
	col.position.y = -0.5
	ground.add_child(col)

	var mesh := MeshInstance3D.new()
	mesh.name = "GroundMesh"
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 90)
	mesh.mesh = plane
	mesh.material_override = _mat(Color(0.12, 0.11, 0.16))
	ground.add_child(mesh)

func _add_walls(parent: Node) -> void:
	var walls_root := Node3D.new()
	walls_root.name = "Walls"
	parent.add_child(walls_root)
	var walls := [
		["NorthWall", Vector3(0, 3, -26), Vector3(52, 6, 1)],
		["SouthWall", Vector3(0, 3, 26), Vector3(52, 6, 1)],
		["WestWall", Vector3(-26, 3, 0), Vector3(1, 6, 52)],
		["EastWall", Vector3(26, 3, 0), Vector3(1, 6, 52)],
	]
	for wall_data in walls:
		var wall := StaticBody3D.new()
		wall.name = wall_data[0]
		wall.position = wall_data[1]
		walls_root.add_child(wall)
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = wall_data[2]
		col.shape = shape
		wall.add_child(col)

func _make_city_decor() -> Node3D:
	var root := Node3D.new()
	root.name = "City"
	var rng := RandomNumberGenerator.new()
	rng.seed = 1001
	var neon := [Color(1.0, 0.2, 0.7), Color(0.2, 0.9, 1.0), Color(0.7, 0.4, 1.0)]
	for i in range(26):
		var angle := TAU * i / 26.0 + rng.randf_range(-0.06, 0.06)
		var radius := rng.randf_range(30.0, 40.0)
		var mesh := MeshInstance3D.new()
		mesh.name = "Building%02d" % i
		var box := BoxMesh.new()
		box.size = Vector3(rng.randf_range(3.0, 7.0), rng.randf_range(7.0, 22.0), rng.randf_range(3.0, 7.0))
		mesh.mesh = box
		var mat := _mat(Color(0.09, 0.09, 0.13))
		if rng.randf() < 0.3:
			var c: Color = neon[rng.randi() % neon.size()]
			mat.emission_enabled = true
			mat.emission = c
			mat.emission_energy_multiplier = 0.9
		mesh.material_override = mat
		mesh.position = Vector3(cos(angle) * radius, box.size.y * 0.5, sin(angle) * radius)
		root.add_child(mesh)
	return root

func _make_forest_decor() -> Node3D:
	var root := Node3D.new()
	root.name = "Forest"
	root.visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 2002
	for i in range(44):
		var angle := TAU * i / 44.0 + rng.randf_range(-0.1, 0.1)
		var radius := rng.randf_range(28.0, 40.0)
		var mesh := MeshInstance3D.new()
		mesh.name = "Bamboo%02d" % i
		var bamboo := CylinderMesh.new()
		bamboo.top_radius = 0.22
		bamboo.bottom_radius = 0.3
		bamboo.height = rng.randf_range(7.0, 13.0)
		mesh.mesh = bamboo
		mesh.material_override = _mat(Color(0.25, 0.55, 0.2).lightened(rng.randf_range(0.0, 0.25)))
		mesh.position = Vector3(cos(angle) * radius, bamboo.height * 0.5, sin(angle) * radius)
		root.add_child(mesh)
	return root

func _make_temple_decor() -> Node3D:
	var root := Node3D.new()
	root.name = "Temple"
	root.visible = false
	for i in range(14):
		var angle := TAU * i / 14.0
		var mesh := MeshInstance3D.new()
		mesh.name = "Pillar%02d" % i
		var pillar := CylinderMesh.new()
		pillar.top_radius = 0.7
		pillar.bottom_radius = 0.85
		pillar.height = 7.0
		mesh.mesh = pillar
		mesh.material_override = _mat(Color(0.5, 0.1, 0.12))
		mesh.position = Vector3(cos(angle) * 29.0, 3.5, sin(angle) * 29.0)
		root.add_child(mesh)
	var shrine := MeshInstance3D.new()
	shrine.name = "Shrine"
	var box := BoxMesh.new()
	box.size = Vector3(16, 9, 8)
	shrine.mesh = box
	shrine.material_override = _mat(Color(0.4, 0.08, 0.1), Color(0.2, 0.8, 0.9), 0.25)
	shrine.position = Vector3(0, 4.5, -36)
	root.add_child(shrine)
	return root

func _make_camera_rig_scene() -> Node3D:
	var root := Node3D.new()
	root.name = "CameraRig"
	root.set_script(load(SCRIPTS["camera_rig"]))

	var pivot := Node3D.new()
	pivot.name = "Pivot"
	pivot.rotation_degrees.x = -18.0
	root.add_child(pivot)

	var spring_arm := SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = 7.0
	spring_arm.margin = 0.2
	spring_arm.collision_mask = 0
	pivot.add_child(spring_arm)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 65.0
	camera.current = true
	spring_arm.add_child(camera)
	return root

func _make_dragon_spirit_scene() -> Node3D:
	var root := Node3D.new()
	root.name = "DragonSpirit"
	root.set_script(load(SCRIPTS["dragon_spirit"]))

	var pivot := Node3D.new()
	pivot.name = "ModelPivot"
	pivot.scale = Vector3.ONE * 0.018
	root.add_child(pivot)
	if ResourceLoader.exists("res://assets/Chinese Dragon Lantern/Chinese Dragon Lantern.gltf"):
		var dragon_scene := load("res://assets/Chinese Dragon Lantern/Chinese Dragon Lantern.gltf") as PackedScene
		var model := dragon_scene.instantiate()
		model.name = "DragonModel"
		pivot.add_child(model)

	var light := OmniLight3D.new()
	light.name = "DragonLight"
	light.light_color = Color(0.55, 0.95, 1.0)
	light.light_energy = 2.4
	light.omni_range = 7.0
	root.add_child(light)
	return root

func _make_main_menu_scene() -> Control:
	var root := Control.new()
	root.name = "MainMenu"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load(SCRIPTS["main_menu"]))
	return root

func _make_canvas_ui_scene(node_name: String, script_path: String) -> CanvasLayer:
	var root := CanvasLayer.new()
	root.name = node_name
	root.set_script(load(script_path))
	return root

func _make_narration_overlay_scene() -> CanvasLayer:
	var root := CanvasLayer.new()
	root.name = "NarrationOverlay"
	root.layer = 20
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_script(load(SCRIPTS["narration_overlay"]))
	return root

func _make_village_level_scene() -> Node3D:
	var root := Node3D.new()
	root.name = "VillageLevel"
	_add_village_environment(root)
	_add_village_ground(root)
	_add_village_model(root)
	_add_village_gate(root)
	_add_village_interactables(root)
	return root

func _add_village_environment(root: Node) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.55, 0.72, 0.9)
	sky_mat.sky_horizon_color = Color(0.9, 0.82, 0.72)
	sky_mat.ground_bottom_color = Color(0.18, 0.22, 0.14)
	sky_mat.ground_horizon_color = Color(0.62, 0.55, 0.4)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.65, 0.55)
	env.fog_density = 0.006
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-42, 20, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-25, -160, 0)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	root.add_child(fill)

func _add_village_ground(root: Node) -> void:
	var ground := StaticBody3D.new()
	ground.name = "GroundCollision"
	root.add_child(ground)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	col.shape = box
	col.position.y = -0.5
	ground.add_child(col)

func _add_village_model(root: Node) -> void:
	if not ResourceLoader.exists(VILLAGE_MODEL):
		return
	var scene := load(VILLAGE_MODEL) as PackedScene
	var model := scene.instantiate()
	model.name = "VillageModel"
	model.scale = Vector3.ONE * 80.0
	root.add_child(model)

func _add_village_gate(root: Node) -> void:
	var gate := Node3D.new()
	gate.name = "Gate"
	root.add_child(gate)
	const GATE_Z := -7.5
	var left := _make_post("LeftPost")
	left.position = Vector3(-2.0, 1.75, GATE_Z)
	gate.add_child(left)
	var right := _make_post("RightPost")
	right.position = Vector3(2.0, 1.75, GATE_Z)
	gate.add_child(right)

	var arch := MeshInstance3D.new()
	arch.name = "Arch"
	var arch_mesh := BoxMesh.new()
	arch_mesh.size = Vector3(5.2, 0.45, 0.7)
	arch.mesh = arch_mesh
	arch.position = Vector3(0, 3.4, GATE_Z)
	arch.material_override = _mat(Color(0.18, 0.07, 0.05))
	gate.add_child(arch)

	var portal := MeshInstance3D.new()
	portal.name = "Portal"
	var portal_mesh := PlaneMesh.new()
	portal_mesh.size = Vector2(3.8, 2.8)
	portal.mesh = portal_mesh
	portal.position = Vector3(0, 1.65, GATE_Z + 0.2)
	portal.rotation_degrees.x = 90.0
	portal.material_override = _mat(Color(0.9, 0.18, 0.26), Color(1.0, 0.16, 0.22), 0.7, 0.62)
	gate.add_child(portal)

func _make_post(name: String) -> MeshInstance3D:
	var post := MeshInstance3D.new()
	post.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.28
	mesh.height = 3.5
	post.mesh = mesh
	post.material_override = _mat(Color(0.18, 0.07, 0.05))
	return post

func _add_village_interactables(root: Node) -> void:
	var interactables := Node3D.new()
	interactables.name = "Interactables"
	root.add_child(interactables)
	_add_shop(interactables, "Кузница", Vector3(-3.5, 0, -1.5), "Кузнец Кэндзи",
		Color(0.9, 0.28, 0.16),
		"Кэндзи проверяет клинок «Кибер-Сакура», подтягивает крепления и ворчит, что сталь любит тишину перед боем.")
	_add_shop(interactables, "Лавка лекаря", Vector3(3.0, 0, -2.0), "Лекарь Мина",
		Color(0.35, 0.95, 0.45),
		"Мина даёт Юкке горький настой. Перед боем здоровье восстановлено, а раны перевязаны.")
	_add_shop(interactables, "Магическая лавка", Vector3(4.5, 0, 1.5), "Чародей Рэн",
		Color(0.45, 0.85, 1.0),
		"Рэн настраивает амулет дракона. Воздух звенит, и печати на рукояти вспыхивают голубым светом.")
	_add_shop(interactables, "Святилище мико", Vector3(-3.0, 0, 3.0), "Мико Кагура",
		Color(0.95, 0.72, 0.25),
		"Кагура слушает духов и шепчет маршрут: демоны ждут у старой дороги, но их строй ещё не сомкнулся.")
	_add_npc(interactables, "Староста", Vector3(0.5, 0, 1.0), Color(0.65, 0.55, 0.42),
		"Староста кланяется: «Мы укрыли детей в подвалах. Вернись живой, Юкка»")
	_add_npc(interactables, "Стражница ворот", Vector3(0.0, 0, -5.0), Color(0.55, 0.2, 0.24),
		"Стражница показывает на север: «Путь к разлому открыт. Я удержу ворота, сколько смогу»")
	_add_npc(interactables, "Ученица мико", Vector3(-1.5, 0, -0.5), Color(0.35, 0.25, 0.58),
		"Ученица протягивает оберег: «Он не остановит демона, но напомнит, ради кого ты сражаешься»")

	var gate := _new_interactable("BattleGate", "Дорога к разлому", "Путь к бою",
		Vector3(0, 0, -5.5),
		"За воротами начинается уровень «{level_name}». Когда закончишь дела в деревне, выходи на охоту.",
		"К бою", true)
	interactables.add_child(gate)
	var gate_label := _make_label("GateLevelLabel", "К бою", Vector3(0, 2.4, 0), Color(1.0, 0.82, 0.62), 28, 8)
	gate.add_child(gate_label)

func _add_shop(parent: Node, title: String, pos: Vector3, npc_name: String,
		npc_color: Color, text: String) -> void:
	var point := _new_interactable(title, title, npc_name, pos, text, "Войти", false)
	parent.add_child(point)
	point.add_child(_make_label("ShopLabel", title, Vector3(0, 3.2, 0), Color(1.0, 0.92, 0.62), 28, 8))
	_add_actor(point, npc_name, npc_color)

func _add_npc(parent: Node, npc_name: String, pos: Vector3, color: Color, text: String) -> void:
	var point := _new_interactable(npc_name, npc_name, npc_name, pos, text, "Говорить", false)
	parent.add_child(point)
	_add_actor(point, npc_name, color)

func _new_interactable(node_name: String, title: String, speaker: String, pos: Vector3,
		text: String, verb: String, battle: bool) -> Marker3D:
	var point := Marker3D.new()
	point.name = node_name.replace(" ", "")
	point.set_script(load(SCRIPTS["interactable"]))
	point.title = title
	point.speaker = speaker
	point.text = text
	point.verb = verb
	point.battle = battle
	point.position = pos
	return point

func _add_actor(parent: Node, actor_name: String, color: Color) -> void:
	var body := MeshInstance3D.new()
	body.name = "Body"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.45
	body.mesh = capsule
	body.position.y = 0.75
	body.material_override = _mat(color)
	parent.add_child(body)
	parent.add_child(_make_label("NameLabel", actor_name, Vector3(0, 1.9, 0), Color(1, 1, 1, 0.9), 24, 6))

func _make_label(name: String, text: String, pos: Vector3, color: Color,
		font_size: int, outline_size: int) -> Label3D:
	var label := Label3D.new()
	label.name = name
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	label.modulate = color
	label.font_size = font_size
	label.outline_size = outline_size
	return label
