class_name CameraRig
extends Node3D
## Мобильная third-person камера: левый палец двигает, правый вращает обзор.

const FOLLOW_SPEED := 12.0
const TARGET_HEIGHT := 1.15
const TOUCH_LOOK_SENSITIVITY := 0.006
const MOUSE_LOOK_SENSITIVITY := 0.003
const MIN_PITCH := deg_to_rad(-55.0)
const MAX_PITCH := deg_to_rad(-8.0)

var target: Node3D

var _yaw := 0.0
var _pitch := deg_to_rad(-18.0)
var _look_touch := -1
var _pivot: Node3D
var _camera: Camera3D
var _spring_arm: SpringArm3D

func _ready() -> void:
	_pivot = get_node_or_null("Pivot") as Node3D
	_spring_arm = get_node_or_null("Pivot/SpringArm3D") as SpringArm3D
	_camera = get_node_or_null("Pivot/SpringArm3D/Camera3D") as Camera3D
	if _camera != null:
		_camera.current = true
	_yaw = rotation.y
	if _pivot != null:
		_pitch = _pivot.rotation.x
	_apply_rotation()
	if target != null:
		if _spring_arm != null and target is CollisionObject3D:
			_spring_arm.add_excluded_object((target as CollisionObject3D).get_rid())
		global_position = target.global_position + Vector3.UP * TARGET_HEIGHT

func _physics_process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var desired := target.global_position + Vector3.UP * TARGET_HEIGHT
		global_position = global_position.lerp(desired, minf(1.0, FOLLOW_SPEED * delta))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _look_touch == -1 and _is_look_zone(event.position):
			_look_touch = event.index
		elif not event.pressed and event.index == _look_touch:
			_look_touch = -1
	elif event is InputEventScreenDrag and event.index == _look_touch:
		_rotate_look(event.relative * TOUCH_LOOK_SENSITIVITY)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		_rotate_look(event.relative * MOUSE_LOOK_SENSITIVITY)

func get_planar_forward() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()

func get_planar_right() -> Vector3:
	var right := global_transform.basis.x
	right.y = 0.0
	return right.normalized()

func get_aim_direction() -> Vector3:
	return get_planar_forward()

func _is_look_zone(point: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	# Правая верхняя часть экрана свободна от боевых кнопок и работает как свайп-зона.
	return point.x > viewport_size.x * 0.45 and point.y < viewport_size.y * 0.62

func _rotate_look(delta: Vector2) -> void:
	_yaw -= delta.x
	_pitch = clampf(_pitch - delta.y, MIN_PITCH, MAX_PITCH)
	_apply_rotation()

func _apply_rotation() -> void:
	rotation.y = _yaw
	if _pivot != null:
		_pivot.rotation.x = _pitch
