@tool
extends Node
class_name Rotator2D

## A node that you attach to other nodes to manage its rotation.

@export var on: bool = true ## if disabled, will turn off all rotation
@export_range(0,360) var max_rotation: float = 0 ## sets a max for the rotation. Rotation will never go above this value.
@export_range(0, 360) var min_rotation: float = 0 ## sets a min for the rotation. Rotation will never go below this value
@export_range(0, 360) var target_rotation: float = 0: ## sets the target rotation from 0 to 360 for the parent object
	set(value):
		if not _accepting_network_state and is_inside_tree() and not get_parent().is_multiplayer_authority():
			return
		target_rotation = value
@export_enum("IMMIDIATE","LERP","CURVE") var rotation_mode : int = 1;

@export var lerp_speed : float = 7
@export var rotation_curve: Curve = null ## Lets you adjust the speed and the way in which the parent object will move towards the target rotation

@export var prev_target_rotation : float = target_rotation;
@export var real_rotation : float = target_rotation;

var _accepting_network_state: bool = false

var _curve_t: float = 0.0
var _curve_start_rotation: float = 0.0
var _prev_real_rotation: float = real_rotation

func _process(delta: float) -> void:
	if get_parent().is_multiplayer_authority():
		_rotating(delta)
		_sync_rotation.rpc(target_rotation, real_rotation, prev_target_rotation)
	else:
		_apply_rotation(delta)

func _rotating(delta: float) -> void:
	_limit_target_rotation()
	_apply_rotation(delta)

func _apply_rotation(delta: float) -> void:
	if not on:
		return
	match rotation_mode:
		0: # Immidiate
			get_parent().rotation_degrees = real_rotation
		1: # Lerp
			get_parent().rotation_degrees = lerp(get_parent().rotation_degrees, real_rotation, lerp_speed * delta)
		2: # Curve
			if rotation_curve != null:
				if real_rotation != _prev_real_rotation:
					_curve_t = 0.0
					_curve_start_rotation = get_parent().rotation_degrees
					_prev_real_rotation = real_rotation
				_curve_t = minf(_curve_t + lerp_speed * delta, 1.0)
				get_parent().rotation_degrees = lerp(_curve_start_rotation, real_rotation, rotation_curve.sample(_curve_t))
			else:
				get_parent().rotation_degrees = lerp(get_parent().rotation_degrees, real_rotation, lerp_speed * delta)

@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_rotation(t_rot: float, r_rot: float, prev_t_rot: float) -> void:
	_accepting_network_state = true
	target_rotation = t_rot
	_accepting_network_state = false
	real_rotation = r_rot
	prev_target_rotation = prev_t_rot

func _increase_target_rotation_by(rotation: float) -> void:
	if not is_inside_tree() or not get_parent().is_multiplayer_authority():
		return
	target_rotation += rotation

func _set_target_rotation_by_direction(direction: Vector2) -> void:
	if not is_inside_tree() or not get_parent().is_multiplayer_authority():
		return
	target_rotation = fposmod(rad_to_deg(direction.angle()), 360.0)

func _limit_target_rotation() -> void:
	var delta = target_rotation - prev_target_rotation
	if delta < -180.0:
		delta += 360.0
	elif delta > 180.0:
		delta -= 360.0
	real_rotation += delta
	target_rotation = fposmod(target_rotation, 360.0)
	prev_target_rotation = target_rotation
	if max_rotation > min_rotation:
		if max_rotation < target_rotation:
			target_rotation = max_rotation;
		if min_rotation > target_rotation:
			target_rotation = min_rotation;
	if min_rotation > max_rotation:
		if target_rotation < min_rotation and not target_rotation < max_rotation + (min_rotation-max_rotation)*0.5:
			target_rotation = min_rotation;
		if target_rotation > max_rotation and not target_rotation > min_rotation - (min_rotation-max_rotation)*0.5:
			target_rotation = max_rotation
