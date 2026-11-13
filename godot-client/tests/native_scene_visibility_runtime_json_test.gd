extends "res://tests/native_scene_visibility_runtime_test.gd"
# The same actual-owner integration gate over the real Godot JSON carrier.
# Canonical UI/World owners normalize dictionary keys, just as the client does.
func wire(value: Dictionary) -> Dictionary:return JSON.parse_string(JSON.stringify(value))
func birth(id: int,physical: String,ownership: String="new",certified: bool=true) -> Dictionary:return wire(super.birth(id,physical,ownership,certified))
func source(id: int,physical: String,life: int=1,area: int=9) -> Dictionary:return wire(super.source(id,physical,life,area))
func data(client: Client,objects: Array,removed: Array=[]) -> Dictionary:
	var value:=super.data(client,objects,removed)
	value.ui={"gameMasterPermission":{"permission":0,"field114":null,"parameter":null,"source":"native_connection_start_16"}}
	return wire(value)
func tile(serial: int,actor_row: Dictionary,generation: int=3,area: int=9,state: int=1) -> Dictionary:return wire(super.tile(serial,actor_row,generation,area,state))
func admit(client: Client,row: Dictionary) -> void:
	var id:=int(row.id);client.gameplay_ui.text.objects[id]=row;client.world.desired[id]={"object":row,"key":"model/"+str(id)+"/"+str(row.nativeLifetime)}
