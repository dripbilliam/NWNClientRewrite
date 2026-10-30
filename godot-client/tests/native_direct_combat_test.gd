extends SceneTree
const Presentation=preload("res://systems/native_render/combat_presentation.gd")
const Actor=preload("res://systems/native_data/combat_actor.gd")
const LiveWorld=preload("res://systems/native_render/live_world.gd")
var checks:=0
var failures: Array=[]
class Rig extends Node:
	signal animation_event(id: int,name: String,serial: int)
	var entities: Dictionary={}
	var played: Array=[]
	func clip_length(_id: int,_animation: int,_side: int=-1) -> float: return 1.0
	func clip_name(_id: int,animation: int,_side: int=-1) -> String: return str(animation)
	func set_animation(id: int,animation: int,speed: float) -> void: set_playback(id,animation,speed,true,false,0)
	func set_playback(id: int,animation: int,speed: float,loop: bool,restart: bool,side: int) -> void: played.append({"id":id,"animation":animation,"speed":speed,"loop":loop,"restart":restart,"side":side})
class Creature extends Node3D:
	var rigs
	func _ready() -> void:
		rigs=Rig.new(); add_child(rigs)
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var tables:={"appearance":{"orderedRows":[{"HITDIST":"0.5","PREFATCKDIST":"2.0","WEAPONSCALE":"1.0","TARGETHEIGHT":"M","ABORTONPARRY":"0"}]},"baseitems":{"orderedRows":[]}}
	var source:={"id":1,"nativeLifetime":10,"objectType":5,"appearance":{"appearance":0},"replicated":{"stats":{"classes":[{"id":10}]},"hitPoints":{"current":10}}}
	var metadata:=Actor.project(source,tables)
	check(metadata.preferredDistance==2.0 and metadata.hitDistance==0.5 and metadata.monk==false,"Combat metadata projects active native appearance/classes")
	var alternate: Dictionary=tables.duplicate(true); alternate.appearance.orderedRows[0].PREFATCKDIST="3.5"
	check(Actor.project(source,alternate).preferredDistance==3.5,"Active server table overrides alter the selector metadata")
	check(Actor.project({"id":2,"objectType":5},tables).preferredDistance==null,"Missing replicated appearance stays unavailable")
	var numeric:={"defaultValue":" 7suffix","orderedRows":[{"value":"0xFFFFFFFFtail"},{"VALUE":" -12suffix"},{"value":"****"},{"value":" 0x10"},{"other":"2"}]}
	check(Actor.integer(numeric,0,"VALUE")==-1 and Actor.integer(numeric,1,"value")==-12,"Combat table integers retain hexadecimal, prefix and signed 32-bit semantics")
	check(Actor.integer(numeric,2,"value")==0 and Actor.integer(numeric,3,"value")==0 and Actor.integer(numeric,4,"value")==7 and Actor.integer(numeric,7,"value")==7,"Combat table empty cells and missing rows retain original default semantics")
	var owner:=Presentation.new(); root.add_child(owner); owner.set_process(false)
	var instance:=Creature.new(); root.add_child(instance)
	instance.rigs.entities[1]={"root":instance,"context":{"fieldDE":1,"fieldDD":1,"fieldDF":2,"fieldE0":0},"body_type":1,"loop_map":{}}
	instance.set_meta("native_combat_actor",metadata)
	var desired:={1:{"object":source}}
	owner.receive({"serial":1,"events":[{"id":1,"lifetime":10,"action":"cast-animation","animation":17,"record":{"type":4},"ageMs":0}]})
	owner.update(0,desired); check(owner.pending.size()==1,"Cues wait while their complete model is still streaming")
	owner.sync(1,source,instance); owner.base_frame(1,0,1); owner.update(0,desired)
	check(owner.engine.stats.casts==1 and int(instance.rigs.played[-1].animation)==17,"Streamed actor receives queued original cast playback")
	for index in 4: owner.base_frame(1,0,1)
	check(int(instance.rigs.played[-1].animation)==17,"Movement idle updates cannot overwrite an active cast")
	owner.receive({"serial":1,"events":[{"id":1,"lifetime":10,"action":"cast-animation","animation":17,"record":{"type":4},"ageMs":0}]})
	owner.update(0,desired); check(owner.engine.stats.casts==1,"Duplicate transport frame cannot replay a cast")
	owner.engine.update(0,owner.engine.last_ms+501)
	check(int(instance.rigs.played[-1].animation)==250,"Cast countdown returns to the original release base")
	owner.forget(1,true); source.nativeLifetime=11; desired[1].object=source
	owner.sync(1,source,instance); owner.base_frame(1,0,1)
	owner.receive({"serial":2,"events":[{"id":1,"lifetime":10,"action":"cast-animation","animation":17,"record":{"type":4},"ageMs":0}]})
	owner.update(0,desired); check(owner.engine.stats.casts==1 and owner.stats.stale>=2,"An old source lifetime cannot drive a recreated object")
	owner.receive({"serial":3,"events":[{"id":1,"lifetime":11,"action":"cast-animation","animation":17,"record":{"type":4},"ageMs":0}]})
	owner.forget(1); owner.update(0,desired)
	check(owner.pending.size()==1 and owner.rigs.targets.is_empty(),"A physical-model replacement waits for its new rig without losing pending server cues")
	owner.sync(1,source,instance); owner.base_frame(1,0,1); owner.update(0,desired)
	check(owner.pending.is_empty() and owner.engine.stats.casts==2,"The replacement rig receives its retained cue")
	owner.forget(1,true); owner.receive({"serial":4,"events":[{"id":1,"lifetime":11,"action":"cast-animation","animation":17,"record":{"type":4},"ageMs":0}]}); owner.forget(1,true)
	check(owner.pending.is_empty(),"A removed source releases deferred cues even without an installed rig")
	owner.close(); check(owner.pending.is_empty() and owner.rigs.targets.is_empty() and owner.engine.states.is_empty(),"Closing releases queue, rig event bindings and source owners")
	owner.free(); instance.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Authored native cue delivery/queue/ownership checks; real model/server acceptance separate"},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
