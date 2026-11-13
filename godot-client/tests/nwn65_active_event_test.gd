extends SceneTree
const Rigs=preload("res://systems/model_rigs.gd")
var checks:=0
var failures: Array=[]
var output:=""
class NativeOwner extends RefCounted:
	var events: Array=[]
	var calls:=0
	var gob:={"runsE0":[{"clip0":{"name":"native"},"speed8":1.0,"time14":0.0,"flagsC":0}]}
	var pose
	func advance(delta: float) -> void:
		calls+=1;gob.runsE0[0].time14+=delta
		if calls%3==0 or calls==2:events.append("native_a");events.append("native_b")
	func close() -> void:events.clear()
class LifetimeProbe extends RefCounted:
	var log: Array=[]
	func _notification(what: int) -> void:
		if what==NOTIFICATION_PREDELETE:log.append("released")
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<30:failures.append(label);push_error(label)
static func fixture(tree: SceneTree,script,eventful: bool,reentrant: bool=false) -> Dictionary:
	var host:=Node3D.new();tree.root.add_child(host)
	var rigs=script.new();host.add_child(rigs);rigs.set_process(false);rigs.use_native_skin_publisher=false
	var nodes: Array[Node3D]=[]
	for index in 3:
		var node:=Node3D.new();host.add_child(node);nodes.append(node)
	var defaults: Array=[]
	for index in 3:defaults.append({"position":[0,0,0],"quaternion":[1,0,0,0],"scale":[1,1,1]})
	var source:={"parts":[0,1,2],"defaults":defaults,"follow":true,"clip":"motion","loop":true,"speed":1.0,"time":0.0}
	var events: Array=[{"time":0.125,"name":"one"},{"time":0.25,"name":"two"},{"time":0.375,"name":"three"}] if eventful else []
	var clip:={"name":"motion","length":0.5,"transition":0.0,"events":events,"tracks":[{"part":0,"property":"position","sourceInterpolation":"linear","keys":[{"time":0.0,"value":[0,0,0]},{"time":0.5,"value":[1,2,3]}]}]}
	var asset:={"defaults":defaults,"unsupported":[],"clips":[clip]}
	var model: Dictionary=rigs._model(host,nodes,source,asset);model.asset_source=asset;model.part_source=source;model.event_source=true
	var quiet_source: Dictionary=source.duplicate(true);quiet_source.parts=[1];quiet_source.follow=false
	var quiet_asset: Dictionary=asset.duplicate(true);quiet_asset.clips[0].events=[];quiet_asset.clips[0].tracks[0].part=1
	var quiet: Dictionary=rigs._model(host,nodes,quiet_source,quiet_asset);quiet.asset_source=quiet_asset;quiet.part_source=quiet_source;quiet.event_source=false
	var native:={"native_owner":NativeOwner.new(),"player":null,"play_serial":1,"event_source":false,"clip":"native","speed":1.0,"loop":true,"last_time":0.0}
	var entry:={"root":host,"nodes":nodes,"parents":[-1,-1,-1],"models":[model,quiet,native],"animated_models":[0,1,2],"manual_poses":{},"attachments":[{"node":2,"anchor":0,"scale":[1,1,1],"flags":0}],"skins":[],"counts":{}}
	rigs.entities[1]=entry
	var log: Array=[];var state:={"nested":false,"restart":false,"event_source_changed":false}
	rigs.model_event.connect(func(id,index,name,serial):
		log.append(["model",id,index,name,serial,nodes[0].position])
		if reentrant and not state.nested:
			state.nested=true;rigs._update(0.03125)
		if reentrant and not state.restart:
			state.restart=true;rigs._play(model,"motion",true,-0.5,0.3,true)
		if reentrant and not state.event_source_changed:
			state.event_source_changed=true;model.event_source=false)
	rigs.animation_event.connect(func(id,name,serial):log.append(["animation",id,name,serial]))
	return {"host":host,"rigs":rigs,"nodes":nodes,"entry":entry,"log":log,"state":state}
static func capture(row: Dictionary) -> Dictionary:
	var models: Array=[]
	for model in row.entry.models:models.append({"clip":model.clip,"speed":model.speed,"loop":model.loop,"last_time":model.last_time,"serial":model.play_serial,"event_source":model.event_source})
	return {"transforms":row.nodes.map(func(node):return node.transform),"models":models,"events":row.log,"native_calls":row.entry.models[2].native_owner.calls,"pose_frames":row.rigs.stats.pose_frames}
static func dispose(row: Dictionary) -> void:
	row.rigs.forget_entity(1);row.host.free()
func attach_lifetime_probe(row: Dictionary,log: Array) -> void:
	var probe:=LifetimeProbe.new();probe.log=log;row.entry.models[0].lifetime_probe=probe
func run() -> void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var original=load("res://.cache/nwn65/active-baseline-a/systems/model_rigs.gd")
	var counts: Array=[]
	for eventful in [false,true]:
		for reentrant in [false,true]:
			var before:=fixture(self,original,eventful,reentrant);var after:=fixture(self,Rigs,eventful,reentrant)
			for frame in 48:
				for row in [before,after]:
					if frame==8:row.host.hide()
					if frame==14:row.host.show()
					if frame==16:row.rigs._play(row.entry.models[0],"motion",true,-1.0,0.4,true)
					if frame==22:row.rigs._play(row.entry.models[0],"motion",false,1.0,0.0,true)
					if frame==30:row.rigs._play(row.entry.models[0],"motion",true,1.0,0.1,true)
					if frame in [3,11,25]:row.entry.manual_poses[1]={"position":Vector3(frame,2,3),"quaternion":Quaternion.IDENTITY,"scale":Vector3.ONE}
					if frame==18:row.entry.attachments[0].flags=3
					if frame==28:row.entry.attachments[0].flags=0
					row.rigs._update(0.125)
				check(var_to_bytes(capture(before))==var_to_bytes(capture(after)),"active clock/events/manual/attachment parity eventful%s reentrant%s frame%s"%[eventful,reentrant,frame])
			var info: Dictionary=after.rigs.event_batch_snapshot()
			check(info.retained_batches<=4 and info.allocated<=2,"event scratch is bounded and nested calls borrow independent arrays")
			if reentrant:check(info.allocated==2,"nested callback actually emits events into a separate scratch batch")
			check(info.empty_models>0 and info.reused>0,"active empty-event models skip interval work and event batches reuse storage")
			for batch in after.rigs._event_batches:check(batch.is_empty(),"returned scratch retains no model/entity identity")
			counts.append({"eventful":eventful,"reentrant":reentrant,"counts":info})
			dispose(before);dispose(after)
	# Event lookup remains after AnimationPlayer.advance. Its immediate native
	# mixer signal can replace event metadata before the interval is selected.
	var before:=fixture(self,original,false);var after:=fixture(self,Rigs,false)
	for row in [before,after]:
		var model: Dictionary=row.entry.models[0]
		check(model.player.has_signal("mixer_applied"),"actual AnimationPlayer supplies a synchronous after-advance mutation boundary")
		model.player.mixer_applied.connect(func():model.events.motion=[{"time":0.125,"name":"late_metadata"}])
	for frame in 8:
		before.rigs._update(0.125);after.rigs._update(0.125)
		check(var_to_bytes(capture(before))==var_to_bytes(capture(after)),"after-advance event metadata replacement remains visible"+str(frame))
	check(after.log.any(func(row):return row[0]=="model" and row[3]=="late_metadata"),"late event replacement is actually exercised")
	dispose(before);dispose(after)
	# A skin force callback can replace the model list. The pending event
	# batch must retain the prior model identity through that callback.
	var lifetimes: Array=[[],[]]
	for which in 2:
		var row:=fixture(self,original if which==0 else Rigs,true)
		for signal_name in ["model_event","animation_event"]:
			for binding in row.rigs.get_signal_connection_list(signal_name):row.rigs.disconnect(signal_name,binding.callable)
		attach_lifetime_probe(row,lifetimes[which])
		var skeleton:=Skeleton3D.new();row.host.add_child(skeleton);skeleton.add_bone("skin")
		row.entry.skins=[{"part":0,"bones":[1],"skeleton":skeleton}]
		row.entry.manual_poses[1]={"position":Vector3(9,8,7),"quaternion":Quaternion.IDENTITY,"scale":Vector3.ONE}
		skeleton.pose_updated.connect(func():
			lifetimes[which].append("skin-before")
			row.entry.models=[]
			lifetimes[which].append("skin-after"))
		row.rigs._update(0.25)
		check(lifetimes[which].slice(0,2)==["skin-before","skin-after"],"replaced model identity survives skin force notification")
		check(lifetimes[which].has("released"),"replaced event model identity is released after publication")
		dispose(row)
	check(lifetimes[0]==lifetimes[1],"original/candidate model-reference release order matches through skin callbacks")
	await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"cases":counts,"scope":"Actual AnimationPlayer active clocks/loops/reverse/nonloop/visibility/manual/attachment/event metadata callbacks plus authored native owner; no asset scene, GPU, FPS or live eligibility claim"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
