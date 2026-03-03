extends CharacterBody2D
class_name PVEMobBase

const PVEMobConfigScript = preload("res://PVE/core/pve_mob_config.gd")
const PVEMobBrainScript = preload("res://PVE/core/pve_mob_brain.gd")

signal took_damage(amount: float, current_health: float)
signal died(mob)
signal decision_updated(intent: String, decision: Dictionary)

@export var config: PVEMobConfigScript
@export var auto_find_target := true
@export var target_path: NodePath

var brain := PVEMobBrainScript.new()
var current_target: Node2D = null
var current_health := 0.0
var _dash_time_left := 0.0
var _dash_direction := 0.0
var _last_decision: Dictionary = {
	"intent": "idle",
	"move_dir": 0.0,
	"jump": false,
	"dash": false
}
var _gravity := 980.0

@onready var collision_shape := get_node_or_null("CollisionShape2D")
@onready var visual := get_node_or_null("Visual")


func _ready() -> void:
	if config == null:
		config = PVEMobConfigScript.new()
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	brain.configure(config)
	current_health = config.max_health
	_apply_config_visuals()
	_resolve_target()


func _physics_process(delta: float) -> void:
	if current_health <= 0.0:
		return
	_refresh_target_if_needed()
	var decision := _compute_decision(delta)
	_last_decision = decision.duplicate(true)
	emit_signal("decision_updated", String(decision.get("intent", "idle")), decision)
	_apply_vertical_motion(delta, decision)
	_apply_horizontal_motion(delta, decision)
	move_and_slide()


func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	emit_signal("took_damage", amount, current_health)
	if current_health <= 0.0:
		die()


func heal(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = minf(config.max_health, current_health + amount)


func die() -> void:
	if current_health > 0.0:
		current_health = 0.0
	velocity = Vector2.ZERO
	set_physics_process(false)
	emit_signal("died", self)


func reset_mob(reset_position: Vector2 = global_position) -> void:
	global_position = reset_position
	velocity = Vector2.ZERO
	current_health = config.max_health
	_dash_time_left = 0.0
	_dash_direction = 0.0
	brain.reset()
	set_physics_process(true)


func set_target(node: Node2D) -> void:
	current_target = node


func get_state() -> Dictionary:
	return {
		"global_position": global_position,
		"velocity": velocity,
		"current_health": current_health,
		"dash_time_left": _dash_time_left,
		"dash_direction": _dash_direction,
		"last_decision": _last_decision.duplicate(true),
		"brain": brain.get_state()
	}


func apply_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	if state.has("global_position"):
		global_position = state["global_position"]
	if state.has("velocity"):
		velocity = state["velocity"]
	if state.has("current_health"):
		current_health = float(state["current_health"])
	if state.has("dash_time_left"):
		_dash_time_left = float(state["dash_time_left"])
	if state.has("dash_direction"):
		_dash_direction = float(state["dash_direction"])
	if state.has("last_decision") and state["last_decision"] is Dictionary:
		_last_decision = (state["last_decision"] as Dictionary).duplicate(true)
	if state.has("brain") and state["brain"] is Dictionary:
		brain.apply_state(state["brain"])
	set_physics_process(current_health > 0.0)


func _compute_decision(delta: float) -> Dictionary:
	if current_target == null or not is_instance_valid(current_target):
		return {
			"intent": "idle",
			"move_dir": 0.0,
			"jump": false,
			"dash": false
		}
	return brain.step(
		delta,
		global_position,
		current_target.global_position,
		is_on_floor(),
		is_on_wall()
	)


func _apply_vertical_motion(delta: float, decision: Dictionary) -> void:
	var gravity_strength := _gravity * config.gravity_scale
	if not is_on_floor():
		velocity.y += gravity_strength * delta
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0
		if bool(decision.get("jump", false)):
			velocity.y = config.jump_velocity


func _apply_horizontal_motion(delta: float, decision: Dictionary) -> void:
	if _dash_time_left > 0.0:
		_dash_time_left = maxf(0.0, _dash_time_left - delta)
		velocity.x = _dash_direction * config.dash_speed
		return

	var move_dir := clampf(float(decision.get("move_dir", 0.0)), -1.0, 1.0)
	var intent := String(decision.get("intent", "idle"))
	var target_speed := 0.0
	if intent == "chase":
		target_speed = move_dir * config.chase_speed
	elif intent == "run":
		target_speed = move_dir * config.run_speed
	velocity.x = move_toward(velocity.x, target_speed, config.acceleration * delta)

	if bool(decision.get("dash", false)) and absf(move_dir) > 0.0:
		_dash_direction = signf(move_dir)
		_dash_time_left = config.dash_duration
		velocity.x = _dash_direction * config.dash_speed


func _refresh_target_if_needed() -> void:
	if current_target == null or not is_instance_valid(current_target):
		_resolve_target()
		return
	if current_target.global_position.distance_to(global_position) > config.disengage_distance:
		current_target = null
		_resolve_target()


func _resolve_target() -> void:
	if not target_path.is_empty():
		var node := get_node_or_null(target_path)
		if node is Node2D:
			current_target = node as Node2D
			return
	if auto_find_target:
		current_target = _find_nearest_target()


func _find_nearest_target() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var best: Node2D = null
	var best_dist := config.max_target_distance
	for node in tree.get_nodes_in_group(config.target_group):
		if not (node is Node2D):
			continue
		var node2d: Node2D = node as Node2D
		var distance := global_position.distance_to(node2d.global_position)
		if distance < best_dist:
			best_dist = distance
			best = node2d
	return best


func _apply_config_visuals() -> void:
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
		rect_shape.size = config.hitbox_size
	if visual is Polygon2D:
		var polygon_node := visual as Polygon2D
		polygon_node.color = config.visual_color
		polygon_node.polygon = _square_polygon(config.visual_size)


func _square_polygon(size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])
