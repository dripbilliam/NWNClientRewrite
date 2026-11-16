extends SceneTree
const Placed=preload("res://systems/native_data/native_placed_sounds.gd")

class FakeStream extends RefCounted:
	func get_length()->float:return 0.25

class FakeAudio extends Node:
	var voices: Dictionary={}
	var resources: Dictionary={}
	var next_id:=0
	var starts:=0
	var stops:=0
	func create_sound(name: String,effect_id: int=0)->int:
		next_id+=1;voices[next_id]={"name":name,"effectId":effect_id,"profile":{"volume":127},"resourceId":next_id,"stage":"created"};resources[next_id]={"stream":FakeStream.new()};return next_id
	func setting(_id: int,_key: String,_value: int)->void:pass
	func move(id: int,point: Array,_height: float=0)->void:voices[id].position=point.duplicate()
	func play(id: int)->void:starts+=1;voices[id].stage="playing"
	func stop(_id: int)->void:stops+=1
	func destroy(id: int)->void:voices.erase(id)

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_sound_fixture.json"))
	if not fixture is Dictionary:fail("Original sound fixture unavailable");return
	var create: Dictionary={}
	for row in fixture.cases:
		if int(row.expected.operation)==6:create=row.expected;break
	if create.is_empty():fail("Original sound create unavailable");return
	var audio:=FakeAudio.new();root.add_child(audio)
	var owner:=Placed.new();root.add_child(owner)
	owner.configure(audio,func()->Dictionary:return {"hour":31,"timeOfDay":1})
	var area: Dictionary={"id":create.areaId,"width":10,"height":10,"tiles":[]}
	for _index in range(100):area.tiles.append({"fields":{"18":0}})
	var record: Dictionary={"id":create.objectId,"objectType":16,"areaId":create.areaId,"state":create.sound.duplicate(true)}
	owner.attach(area,{int(create.objectId):record},audio)
	if owner.owners.size()!=1 or int(owner.owners[int(create.objectId)].active)!=0:fail("Initial placed sound was not attached without speculative playback");return
	owner.command({"objectId":create.objectId,"operation":2},record)
	owner.advance(Time.get_ticks_msec(),{"hour":31,"timeOfDay":1})
	if audio.starts!=1 or owner.owners[int(create.objectId)].voice<0:fail("Original play did not start a Godot voice");return
	owner.advance(Time.get_ticks_msec()+1,{"hour":31,"timeOfDay":1})
	if owner.owners[int(create.objectId)].pending:fail("Ready audio did not resolve the pending voice");return
	owner.command({"objectId":create.objectId,"operation":4,"volume":63},record)
	var voice:=int(owner.owners[int(create.objectId)].voice)
	if int(audio.voices[voice].profile.volume)!=63:fail("Volume command did not reach current voice");return
	var changed: Dictionary=record.duplicate(true);changed.state.position=[4.0,5.0,6.0]
	owner.command({"objectId":create.objectId,"operation":5},changed)
	if audio.voices[voice].position!=[4.0,5.0,6.0]:fail("Move command did not reach current voice");return
	owner.command({"objectId":create.objectId,"operation":3},changed)
	if audio.stops<1 or int(owner.owners[int(create.objectId)].active)!=0 or owner.owners[int(create.objectId)].voice!=-1:fail("Stop retained an active voice");return
	owner.command({"objectId":create.objectId,"operation":7})
	if not owner.owners.is_empty():fail("Destroy retained a placed owner");return
	owner.attach(area,{int(create.objectId):record},audio);owner.detach()
	if not owner.owners.is_empty() or not owner.area.is_empty():fail("Area detach retained placed sounds");return
	if Placed.interval(100,0,0)!=100 or Placed.interval(0,3,4)!=null:fail("Native interval baseline differs");return
	owner.close();audio.queue_free()
	print("NWN79 Godot placed sound PASS: attach, admitted play, ready voice, volume, move, stop, destroy, area detach")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot placed sound failed: "+reason)
	quit(1)
