class_name VillageHUD
extends CanvasLayer
## Мирный HUD деревни: джойстик, подсказка взаимодействия и окно диалога.

signal interact_pressed
signal dialog_action_pressed

var player: Player

var _joystick: VirtualJoystick
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _interact_button: Button
var _dialog_panel: PanelContainer
var _dialog_title: Label
var _dialog_body: Label
var _dialog_action: Button
var _dialog_close: Button

func _ready() -> void:
	layer = 5
	var ui := Control.new()
	ui.name = "VillageUI"
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	_joystick = VirtualJoystick.new()
	ui.add_child(_joystick)

	var title := Label.new()
	title.text = "ДЕРЕВНЯ ОХОТНИКОВ"
	title.position = Vector2(26, 16)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.66, 0.34))
	ui.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Подготовься и отправляйся к разлому"
	subtitle.position = Vector2(26, 44)
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	ui.add_child(subtitle)

	_prompt_panel = PanelContainer.new()
	_prompt_panel.visible = false
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.offset_left = -230
	_prompt_panel.offset_right = 230
	_prompt_panel.offset_top = -112
	_prompt_panel.offset_bottom = -52
	_prompt_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.025, 0.02, 0.78)))
	ui.add_child(_prompt_panel)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.74))
	_prompt_panel.add_child(_prompt_label)

	_interact_button = Button.new()
	_interact_button.text = "ВЗАИМОДЕЙСТВИЕ"
	_interact_button.visible = false
	_interact_button.anchor_left = 1.0
	_interact_button.anchor_right = 1.0
	_interact_button.anchor_top = 1.0
	_interact_button.anchor_bottom = 1.0
	_interact_button.offset_left = -246
	_interact_button.offset_right = -26
	_interact_button.offset_top = -120
	_interact_button.offset_bottom = -62
	_interact_button.add_theme_font_size_override("font_size", 16)
	_interact_button.pressed.connect(func() -> void: interact_pressed.emit())
	ui.add_child(_interact_button)

	_build_dialog(ui)

func set_player(p: Player) -> void:
	player = p

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.move_input = _joystick.output

func set_prompt(text: String) -> void:
	var has_prompt := not text.is_empty()
	_prompt_panel.visible = has_prompt
	_interact_button.visible = has_prompt
	_prompt_label.text = text

func show_dialog(title: String, body: String, action_text := "") -> void:
	_dialog_title.text = title
	_dialog_body.text = body
	_dialog_action.visible = not action_text.is_empty()
	_dialog_action.text = action_text
	_dialog_panel.visible = true

func hide_dialog() -> void:
	_dialog_panel.visible = false

func _build_dialog(ui: Control) -> void:
	_dialog_panel = PanelContainer.new()
	_dialog_panel.visible = false
	_dialog_panel.anchor_left = 0.5
	_dialog_panel.anchor_right = 0.5
	_dialog_panel.anchor_top = 0.5
	_dialog_panel.anchor_bottom = 0.5
	_dialog_panel.offset_left = -285
	_dialog_panel.offset_right = 285
	_dialog_panel.offset_top = -150
	_dialog_panel.offset_bottom = 150
	_dialog_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.028, 0.024, 0.92)))
	ui.add_child(_dialog_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	_dialog_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	_dialog_title = Label.new()
	_dialog_title.add_theme_font_size_override("font_size", 25)
	_dialog_title.add_theme_color_override("font_color", Color(1.0, 0.66, 0.34))
	box.add_child(_dialog_title)

	_dialog_body = Label.new()
	_dialog_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_body.add_theme_font_size_override("font_size", 17)
	_dialog_body.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	_dialog_body.custom_minimum_size = Vector2(520, 126)
	box.add_child(_dialog_body)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)

	_dialog_close = Button.new()
	_dialog_close.text = "Закрыть"
	_dialog_close.custom_minimum_size = Vector2(130, 42)
	_dialog_close.pressed.connect(hide_dialog)
	buttons.add_child(_dialog_close)

	_dialog_action = Button.new()
	_dialog_action.custom_minimum_size = Vector2(150, 42)
	_dialog_action.pressed.connect(func() -> void: dialog_action_pressed.emit())
	buttons.add_child(_dialog_action)

func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(1.0, 0.66, 0.34, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
