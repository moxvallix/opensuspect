extends Node

var mapdata
# Called when the node enters the scene tree for the first time.
func _ready():
	set_network_master(1)
func distribute():
	var map = File.new()
	map.open("user://maps/servermap.tscn", File.READ)
	if not map.file_exists("user://maps/servermap.tscn"):
		map.close()
		map.open("res://assets/maps/test/test.tscn", File.READ)
	mapdata = map.get_as_text()
	rpc("recieve",mapdata)
	recieve(mapdata)
	map.close()
remotesync func recieve(data):
	var localmap = File.new()
	localmap.open("user://maps/currentmap.tscn", File.WRITE)
	localmap.store_string(data)
	localmap.close()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
