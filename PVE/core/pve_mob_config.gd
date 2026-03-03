extends Resource
class_name PVEMobConfig

@export var mob_id := "pve_mob_basic"
@export var display_name := "PVE Mob Basic"

@export_group("Identity")
@export var max_health := 100.0
@export var hitbox_size := Vector2(48.0, 48.0)
@export var visual_size := Vector2(48.0, 48.0)
@export var visual_color := Color(0.38, 0.86, 0.48, 1.0)

@export_group("Targeting")
@export var target_group := "players"
@export var max_target_distance := 1800.0
@export var disengage_distance := 2200.0
@export var think_interval := 0.12
@export var decision_noise := 0.06

@export_group("Movement")
@export var run_speed := 170.0
@export var chase_speed := 235.0
@export var acceleration := 1800.0
@export var jump_velocity := -440.0
@export var jump_cooldown := 0.85
@export var dash_speed := 520.0
@export var dash_duration := 0.16
@export var dash_cooldown := 1.1
@export var gravity_scale := 1.0

@export_group("Decision Priorities")
@export var chase_priority := 1.0
@export var run_priority := 0.85
@export var jump_priority := 0.7
@export var dash_priority := 0.95

@export_group("Decision Distances")
@export var run_trigger_distance := 100.0
@export var chase_trigger_distance := 900.0
@export var jump_trigger_distance := 165.0
@export var jump_vertical_tolerance := 40.0
@export var dash_trigger_distance := 360.0
@export var dash_vertical_tolerance := 56.0

@export_group("Behavior Toggles")
@export var prefer_jump_when_blocked := true
@export var prefer_dash_on_chase := true
