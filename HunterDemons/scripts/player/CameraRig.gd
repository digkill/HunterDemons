class_name CameraRig
extends Node3D
## Камера сверху-сзади, плавно следует за целью.

var target: Node3D

func _ready() -> void:
	var cam := get_node_or_null("Camera3D") as Camera3D
	if cam != null:
		cam.current = true
	if target:
		global_position = target.global_position

func _physics_process(delta: float) -> void:
	if target and is_instance_valid(target):
		global_position = global_position.lerp(target.global_position, minf(1.0, 8.0 * delta))
