extends Node2D

const MAIN_SCENE = preload("res://engine/scenes/Main.tscn")
const MOB_SCENE = preload("res://PVE/scenes/pve_mob_basic.tscn")

var main_runtime: Node = null


func _ready() -> void:
	main_runtime = MAIN_SCENE.instantiate()
	main_runtime.name = "MainRuntime"
	add_child(main_runtime)
	call_deferred("_spawn_mob")


func _spawn_mob() -> void:
	if main_runtime == null:
		return
	var mob := MOB_SCENE.instantiate()
	mob.name = "PVEMob"
	main_runtime.add_child(mob)
	if not (mob is Node2D):
		return
	var mob2d := mob as Node2D
	var player_one := main_runtime.get_node_or_null("Player1")
	var player_two := main_runtime.get_node_or_null("Player2")
	if player_one is Node2D and player_two is Node2D:
		var p1 := player_one as Node2D
		var p2 := player_two as Node2D
		mob2d.global_position = (p1.global_position + p2.global_position) * 0.5 + Vector2(0.0, -140.0)
		return
	if player_one is Node2D:
		var p1_only := player_one as Node2D
		mob2d.global_position = p1_only.global_position + Vector2(200.0, -120.0)
