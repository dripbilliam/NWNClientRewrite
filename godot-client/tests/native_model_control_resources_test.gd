extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const NativeAnimation=preload("res://systems/model_native_animation.gd")
var checks:=0
var failures: Array=[]
var evidence: Array=[]
func configure_pose_candidate(_animation,_compiled: bool) -> void: pass
func resource_evidence(_reference: Dictionary,_candidate: Dictionary) -> Dictionary: return {}
func resource_scope() -> String:
	return "Eleven actual installed Heal/duration/creature resources: exact scripted-versus-compiled Part storage, published physical local transforms, real clip run/events/loop/reverse/manual gates and retirement across all admitted original clips. Original sampling instruction corpora are separate; actual mesh/particle pixels, multiplayer and performance require separate full scenes."
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<24: failures.append(label)
func owner(asset: Dictionary,source_nodes: Array,compiled: bool) -> Dictionary:
	var host:=Node3D.new(); root.add_child(host); var nodes: Array=[]; var parts: Array=[]
	for index in source_nodes.size():
		var node:=Node3D.new(); var parent:=int(source_nodes[index].parent)
		(host if parent<0 else nodes[parent]).add_child(node); nodes.append(node); parts.append(index)
	var entry:={"nodes":nodes,"manual_poses":{}}
	var animation:=NativeAnimation.new(); animation.pose.compiled_controls=compiled; configure_pose_candidate(animation,compiled); animation.configure(asset,{"parts":parts},entry)
	return {"host":host,"nodes":nodes,"animation":animation,"entry":entry}
func compare(a: Dictionary,b: Dictionary,label: String) -> void:
	check(a.animation.events==b.animation.events,label+" exact native run events")
	check(a.animation.gob.runsE0.size()==b.animation.gob.runsE0.size(),label+" run lifetime")
	for index in a.animation.pose.parts.size():
		check(a.animation.pose.parts[index].view==b.animation.pose.parts[index].view,label+" exact Part bytes "+str(index))
		check(a.nodes[index].transform==b.nodes[index].transform,label+" exact published local transform "+str(index))
func exercise(name: String,result: Dictionary) -> void:
	var asset: Dictionary=result.value.get("rig_asset",{})
	if not asset.has("nativeAnimation"): check(false,name+" actual original native controller graph exists"); return
	var a:=owner(asset,result.value.nodes,false); var b:=owner(asset,result.value.nodes,true)
	var clips:=0; var frames:=0; compare(a,b,name+"/static")
	for clip in asset.clips:
		if not asset.nativeAnimation.clips.get(str(clip.name),{}).has("root"): continue
		var length:=maxf(0.0,float(clip.length))
		for variant_index in 3:
			var speed: float=[1.0,0.5,-1.0][variant_index]
			var at:=length if speed<0 else 0.0
			var accepted_a: bool=a.animation.play(str(clip.name),speed,1,at)
			var accepted_b: bool=b.animation.play(str(clip.name),speed,1,at)
			check(accepted_a==accepted_b and accepted_b,name+" starts original clip "+str(clip.name))
			for frame in 8:
				# Manual-part writes and scopes use the same retained production
				# provider; both cases share immutable original input assets only.
				var delta:=maxf(length/5.0,0.023)
				if frame in [2,3] and not a.nodes.is_empty():
					for value in [a,b]:
						value.entry.manual_poses[0]={"position":Vector3(0.3,0.7,-0.2),"quaternion":Quaternion.IDENTITY,"scale":Vector3.ONE}
				else:
					a.entry.manual_poses.clear(); b.entry.manual_poses.clear()
				a.animation.advance(delta); b.animation.advance(delta)
				compare(a,b,name+"/"+str(clip.name)+"/"+str(variant_index)+"/"+str(frame)); frames+=1
				a.animation.events.clear(); b.animation.events.clear()
		clips+=1
	check(b.animation.pose.compiled_control_calls>0 and b.animation.pose.compiled_control_failures==0,name+" uses compiled controls without rejected original fields")
	check(a.animation.diagnostics==b.animation.diagnostics and a.animation.pose.diagnostics==b.animation.pose.diagnostics,name+" introduces no diagnostic or provider change")
	var row:={"resource":name,"sha256":result.sha256,"parts":a.nodes.size(),"clips":clips,"frames":frames,"compiled_calls":b.animation.pose.compiled_control_calls,"compiled_failures":b.animation.pose.compiled_control_failures,"existing_diagnostics":a.animation.pose.diagnostics.duplicate()}
	row.merge(resource_evidence(a,b)); evidence.append(row)
	a.animation.close(); b.animation.close(); a.host.free(); b.host.free()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Read-only original installation mounts")
	var assets:=Assets.new(); root.add_child(assets); assets.configure(catalog)
	var results: Dictionary={}; assets.completed.connect(func(id,result):results[id]=result)
	var jobs: Dictionary={}
	for name in ["vim_heal01","vim_heal02","vdr_freemove","vdr_mindhelp","vpm_circfrost","vdr_eleshield","vdr_protelem","vdr_magsee","vdr_spellres","vdr_bardsong","c_golstone"]: jobs[assets.request(name,2002,"actor-model")]=name
	var deadline:=Time.get_ticks_msec()+30000
	while results.size()<jobs.size() and Time.get_ticks_msec()<deadline: await process_frame
	check(results.size()==jobs.size(),"Every original model prepares")
	for id in jobs:
		if not results.has(id): continue
		var result: Dictionary=results[id]
		check(str(result.error).is_empty(),str(jobs[id])+" original data decodes")
		if str(result.error).is_empty(): exercise(str(jobs[id]),result)
	assets.close(); assets.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"resources":evidence,"public_connections":0,"gpu_execution":false,"scope":resource_scope()},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
