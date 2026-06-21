class_name VirtualJoystick
extends Control
## Плавающий виртуальный джойстик: появляется там, где палец коснулся
## левой нижней зоны экрана. Работает с мультитачем (свой индекс касания).

const RADIUS := 90.0
const KNOB := 36.0

var output := Vector2.ZERO

var _touch_index := -1
var _base := Vector2.ZERO
var _knob_pos := Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and _in_zone(event.position):
			_touch_index = event.index
			_base = event.position
			_knob_pos = _base
			queue_redraw()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			output = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		var offset: Vector2 = (event.position - _base).limit_length(RADIUS)
		_knob_pos = _base + offset
		output = offset / RADIUS
		queue_redraw()

func _in_zone(point: Vector2) -> bool:
	var s := get_viewport().get_visible_rect().size
	return point.x < s.x * 0.45 and point.y > s.y * 0.3

func _draw() -> void:
	if _touch_index == -1:
		var s := get_viewport().get_visible_rect().size
		var hint := Vector2(s.x * 0.16, s.y * 0.78)
		draw_circle(hint, RADIUS * 0.8, Color(1, 1, 1, 0.04))
		draw_arc(hint, RADIUS * 0.8, 0, TAU, 48, Color(1, 1, 1, 0.1), 2.0)
		return
	draw_circle(_base, RADIUS, Color(1, 1, 1, 0.06))
	draw_arc(_base, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.18), 2.0)
	draw_circle(_knob_pos, KNOB, Color(1.0, 0.45, 0.7, 0.35))
	draw_circle(_knob_pos, KNOB * 0.55, Color(1.0, 0.6, 0.8, 0.5))
