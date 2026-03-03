extends Node

const PVE_MODE_SCENE := "res://PVE/scenes/pve_mode.tscn"


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_P:
		return
	if not key_event.ctrl_pressed or not key_event.shift_pressed:
		return
	var tree := get_tree()
	if tree == null:
		return
	var current_scene := tree.current_scene
	if current_scene != null and current_scene.scene_file_path == PVE_MODE_SCENE:
		return
	tree.change_scene_to_file(PVE_MODE_SCENE)
	var viewport := get_viewport()
	if viewport:
		viewport.set_input_as_handled()
