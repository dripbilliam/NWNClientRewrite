extends SceneTree
const Snapshot=preload("res://systems/native_entity_snapshot.gd")
const Inspector=preload("res://systems/native_entity_inspector.gd")
class World:
	extends Node3D
	var desired: Dictionary={}
	var instances: Dictionary={}
	var generation:=4
	var area_id:=40
	var closed:=false
	var retiring:=false
class Rigs:
	extends Node
	var entities: Dictionary={}
	var stats:={"missing_requested_clips":["17/1/cwalk"],"failures":[],"pose_frames":6}
	func clip_name(_id: int,_animation: int) -> String: return "cwalk"
class Actor:
	extends Node3D
	var rigs
	var model_names: Array=["authored_gnoll"]
	var source_dependencies: Array=[{"name":"authored_ancestor","sha256":"authored"}]
	var failure:=""
var checks:=0
var failures: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL ",reason)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var world:=World.new(); root.add_child(world)
	world.desired={17:{"object":{"id":17,"objectType":5,"appearance":{"name":{"text":"Authored Gnoll"},"appearance":388},"replicated":{"animation":1,"position":[1,2,3],"animationSpeed":1.0,"private_unrelated_field":"excluded"}}},18:{"object":{"id":18,"objectType":10,"appearance":{},"replicated":{"animation":0}}}}
	var actor:=Actor.new(); world.add_child(actor); world.instances[17]=actor
	var rigs:=Rigs.new(); actor.add_child(rigs); actor.rigs=rigs
	var player:=AnimationPlayer.new(); actor.add_child(player)
	rigs.entities[17]={"animation":1,"side":0,"body_type":0,"context":{"fieldDE":0},"authored_names":["root","body"],"models":[{"player":player,"follow":true,"clip":"","last_time":0.75,"speed":1.0,"names":{},"asset_source":{"clips":[{"name":"walk"},{"name":"pause1"}]}}]}
	var value:=Snapshot.capture(world,17,"Authored Gnoll")
	check(value.id==17 and value.area_id==40 and value.generation==4 and value.rendered,"Snapshot retains exact entity/world identity")
	check(value.replicated.animation==1 and value.rig.animation==1 and value.rig.context.fieldDE==0,"Wire and requested rig states are separately retained")
	check(value.models[0].requested_clip=="cwalk" and not value.models[0].requested_available and value.models[0].available_clips==["pause1","walk"],"Missing requested clip and actual available family are exposed")
	check(value.models[0].active_clip=="" and value.models[0].time==0.75 and value.rig.missing_requested_clips==["17/1/cwalk"],"Empty active playback and existing failures remain visible")
	check(not value.replicated.has("private_unrelated_field") and not JSON.stringify(value).contains("<Object"),"Export is curated data without unrelated fields or scene objects")
	value.appearance.appearance=0; value.replicated.position[0]=99
	check(world.desired[17].object.appearance.appearance==388 and world.desired[17].object.replicated.position[0]==1,"Export owns copies and cannot mutate canonical received state")
	check(rigs.entities[17].models[0].last_time==0.75 and rigs.entities[17].models[0].names.is_empty() and not player.is_playing(),"Snapshot neither starts playback nor builds deferred clips")
	var door:=Node3D.new(); world.add_child(door); world.instances[18]=door
	check(Snapshot.capture(world,18).models.is_empty(),"Non-actor entity inspection requires no animation properties")
	check(Snapshot.capture(world,999).has("error"),"Removed entity is rejected")
	world.retiring=true; check(Snapshot.capture(world,17).has("error"),"Retired world is rejected"); world.retiring=false
	var scope:={"world":world,"generation":4}
	var inspector:=Inspector.new(); root.add_child(inspector)
	inspector.setup(func():return scope,func(source):return "Authored Gnoll" if int(source.get("id",0))==17 else "Authored Door",output.trim_suffix(".json"),"")
	inspector.open(); await process_frame
	check(inspector.ids==[17] and inspector.visible,"Inspector opens with creatures-only selection")
	inspector.select_entity(0)
	check(not inspector.export_button.disabled and inspector.detail.text.contains("cwalk"),"Selecting an entity renders animation diagnostics")
	check(inspector.blocks_pointer(inspector.global_position+Vector2(10,10)) and not inspector.blocks_pointer(inspector.global_position-Vector2(10,10)),"Only the actual inspector rectangle blocks world pointer input")
	inspector.export_selected()
	check(not inspector.last_export.is_empty() and FileAccess.file_exists(inspector.last_export),"User export writes a unique local entity receipt")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(inspector.last_export))
	check(saved.id==17 and saved.name=="Authored Gnoll" and saved.models[0].requested_available==false,"Exported JSON retains name and failing animation evidence")
	var old_export:=inspector.last_export; scope.generation=5; inspector.export_selected()
	check(inspector.last_export==old_export and inspector.export_button.disabled and inspector.status.text.contains("World changed"),"Stale selection cannot export across generation reuse")
	scope.generation=4; inspector.refresh_entities(); inspector.select_entity(0)
	world.desired.erase(17); inspector.export_selected()
	check(inspector.status.text.contains("left the world") and inspector.export_button.disabled,"Entity departure invalidates export")
	inspector.creature_only.button_pressed=false; inspector.refresh_entities()
	check(inspector.ids==[18],"All-entity mode exposes doors without creature assumptions")
	inspector.filter.text="not present"; inspector.refresh_entities(); check(inspector.ids.is_empty(),"Search filters names and IDs")
	inspector.reset(); check(not inspector.visible and inspector.selected_id==-1 and inspector.ids.is_empty(),"Reset drops stale selection and closes the panel")
	inspector.queue_free(); world.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"export":old_export,"game_network_connections":0,"scope":"Authored local entity/rig fixture: read-only snapshots, private clock preservation, real inspector selection/export, generation and lifetime rejection; no real NPC or visual/playability acceptance"},"  ")); file.close(); quit(0 if failures.is_empty() else 1)
