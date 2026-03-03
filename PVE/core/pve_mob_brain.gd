extends RefCounted
class_name PVEMobBrain

const PVEMobConfigScript = preload("res://PVE/core/pve_mob_config.gd")

var config: PVEMobConfigScript = PVEMobConfigScript.new()

var _rng := RandomNumberGenerator.new()
var _think_timer := 0.0
var _dash_cooldown_left := 0.0
var _jump_cooldown_left := 0.0
var _cached_decision := {
	"intent": "idle",
	"move_dir": 0.0
}


func configure(new_config: PVEMobConfigScript) -> void:
	if new_config != null:
		config = new_config
	_rng.randomize()
	reset()


func reset() -> void:
	_think_timer = 0.0
	_dash_cooldown_left = 0.0
	_jump_cooldown_left = 0.0
	_cached_decision = {
		"intent": "idle",
		"move_dir": 0.0
	}


func get_state() -> Dictionary:
	return {
		"think_timer": _think_timer,
		"dash_cooldown_left": _dash_cooldown_left,
		"jump_cooldown_left": _jump_cooldown_left,
		"cached_decision": _cached_decision.duplicate(true)
	}


func apply_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	if state.has("think_timer"):
		_think_timer = float(state["think_timer"])
	if state.has("dash_cooldown_left"):
		_dash_cooldown_left = float(state["dash_cooldown_left"])
	if state.has("jump_cooldown_left"):
		_jump_cooldown_left = float(state["jump_cooldown_left"])
	if state.has("cached_decision") and state["cached_decision"] is Dictionary:
		_cached_decision = (state["cached_decision"] as Dictionary).duplicate(true)


func step(
	delta: float,
	mob_position: Vector2,
	target_position: Vector2,
	on_floor: bool,
	is_blocked_ahead: bool
) -> Dictionary:
	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	_jump_cooldown_left = maxf(0.0, _jump_cooldown_left - delta)
	_think_timer -= delta
	if _think_timer > 0.0:
		return {
			"intent": String(_cached_decision.get("intent", "idle")),
			"move_dir": float(_cached_decision.get("move_dir", 0.0)),
			"jump": false,
			"dash": false
		}

	_think_timer = maxf(0.01, config.think_interval)
	var decision := _build_decision(mob_position, target_position, on_floor, is_blocked_ahead)
	_cached_decision = {
		"intent": String(decision.get("intent", "idle")),
		"move_dir": float(decision.get("move_dir", 0.0))
	}
	return decision


func _build_decision(
	mob_position: Vector2,
	target_position: Vector2,
	on_floor: bool,
	is_blocked_ahead: bool
) -> Dictionary:
	var delta_pos := target_position - mob_position
	var abs_x := absf(delta_pos.x)
	var abs_y := absf(delta_pos.y)
	var distance := delta_pos.length()
	if distance > config.max_target_distance:
		return {
			"intent": "idle",
			"move_dir": 0.0,
			"jump": false,
			"dash": false
		}

	var chase_score := _score_chase(distance)
	var run_score := _score_run(distance)
	var jump_score := _score_jump(abs_x, abs_y, on_floor, is_blocked_ahead)
	var dash_score := _score_dash(abs_x, abs_y)

	var intent := "chase"
	var move_dir := signf(delta_pos.x)
	if run_score > chase_score:
		intent = "run"
		move_dir = -move_dir
	if abs_x < 4.0:
		move_dir = 0.0

	var move_score := maxf(chase_score, run_score)
	var jump := on_floor and jump_score > move_score * 0.66
	var dash := dash_score > move_score * 0.68
	if dash and not config.prefer_dash_on_chase and intent != "run":
		dash = false
	if dash:
		jump = false
	if jump:
		_jump_cooldown_left = config.jump_cooldown
	if dash:
		_dash_cooldown_left = config.dash_cooldown

	return {
		"intent": intent,
		"move_dir": move_dir,
		"jump": jump,
		"dash": dash
	}


func _score_chase(distance: float) -> float:
	var score := config.chase_priority
	if distance > config.chase_trigger_distance:
		score *= 0.35
	else:
		score *= 1.15
	return _with_noise(score)


func _score_run(distance: float) -> float:
	var score := 0.0
	if distance <= config.run_trigger_distance:
		score = config.run_priority * 1.25
	elif distance <= config.chase_trigger_distance:
		score = config.run_priority * 0.45
	return _with_noise(score)


func _score_jump(abs_x: float, abs_y: float, on_floor: bool, is_blocked_ahead: bool) -> float:
	if not on_floor:
		return 0.0
	if _jump_cooldown_left > 0.0:
		return 0.0
	var score := 0.0
	if abs_x <= config.jump_trigger_distance and abs_y <= config.jump_vertical_tolerance:
		score += config.jump_priority
	if config.prefer_jump_when_blocked and is_blocked_ahead:
		score += config.jump_priority * 0.75
	return _with_noise(score)


func _score_dash(abs_x: float, abs_y: float) -> float:
	if _dash_cooldown_left > 0.0:
		return 0.0
	if abs_x > config.dash_trigger_distance:
		return 0.0
	if abs_y > config.dash_vertical_tolerance:
		return 0.0
	return _with_noise(config.dash_priority)


func _with_noise(score: float) -> float:
	if score <= 0.0:
		return score
	var noise := _rng.randf_range(-config.decision_noise, config.decision_noise)
	return maxf(0.0, score + noise)
