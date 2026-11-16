extends SceneTree
const World=preload("res://systems/native_data/native_network_world.gd")

func _initialize()->void:
	var world=World.new();var id:=0xffffffff
	world.area_id=0x80000009
	if not world.stage_object(world.registry,id,5,{"areaId":world.area_id,"replicationRemoved":false}):fail("Original received actor creation failed");return
	var first: Dictionary=world.registry[id]
	if int(first.nativeLifetime)<1 or first.nativeLifetime!=first.clientKnownLifetime:fail("First Godot receive lifetime unavailable");return
	if not world.stage_object(world.registry,id,5,{"replicated":{"position":[1,2,3]}}) or world.registry[id].nativeLifetime!=first.nativeLifetime:fail("Ordinary update changed actor lifetime");return
	if not world.apply_updates({"complete":true,"records":[{"action":"delete","id":id,"objectType":5,"remove":1}]}):fail("Actor deletion failed");return
	if not bool(world.registry[id].replicationRemoved):fail("Actor deletion did not retire identity");return
	if not world.apply_updates({"complete":true,"records":[{"action":"create","id":id,"objectType":5,"state":{}}]}):fail("Actor replacement failed");return
	var second: Dictionary=world.registry[id]
	if int(second.nativeLifetime)<=int(first.nativeLifetime) or second.nativeLifetime!=second.clientKnownLifetime or bool(second.replicationRemoved):fail("Same-ID replacement reused an old receive lifetime");return
	print("NWN79 Godot receive lifetime PASS: birth, stable update, deletion and same-ID replacement")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot receive lifetime failed: "+reason)
	quit(1)
