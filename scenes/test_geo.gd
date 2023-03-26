extends Node3D

const SPAWN_RANDOM := 5.0


func _ready():
	if not multiplayer.is_server():
		return
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(del_player)
	
	for id in multiplayer.get_peers():
		add_player(id)
	
	if not OS.has_feature("dedicated_server"):
		add_player(1)


func _exit_tree():
	if not multiplayer.is_server():
		return
	multiplayer.peer_connected.disconnect(add_player)
	multiplayer.peer_disconnected.disconnect(del_player)


func add_player(id: int):
	var character = preload("res://scenes/Player.tscn").instantiate()
	character.player_id = id
	var camera = preload("res://scenes/camera_rig.tscn").instantiate()
	
	var pos := Vector2.from_angle(randf() * 2 * PI)
	character.position = Vector3(pos.x * SPAWN_RANDOM * randf(), 0, pos.y * SPAWN_RANDOM * randf())
	
	character.name = str(id)
	camera.name = str(id)
	character.camera_path = NodePath("../../CameraHandler/" + str(id))
	camera.target_path = NodePath("../../PlayerHandler/" + str(id))
	
	# NEED TO HANDLE SYNCING THESE, COULD USE AWAIT MAYBE?
	$PlayerHandler.add_child(character, true)
	$CameraHandler.add_child(camera, true)


func del_player(id: int):
	if not $PlayerHandler.has_node(str(id)):
		return
	$PlayerHandler.get_node(str(id)).queue_free()
	$CameraHandler.get_node(str(id)).queue_free()
