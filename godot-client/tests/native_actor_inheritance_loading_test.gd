extends SceneTree
const Assets=preload("res://systems/native_data/asset_service.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Keys=preload("res://systems/native_data/packed_animation_keys.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
class EagerAssets:
	extends Assets
	func decode(bytes: PackedByteArray,type: int,decoder: String,cache_path: String,store=null,immutable_source: bool=false) -> Dictionary:
		return super.decode(bytes,type,"mdl-actor-v2" if decoder in ["mdl-actor-packed-v2","mdl-actor-packed-v3"] else decoder,cache_path,store,immutable_source)
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func same(a: Variant,b: Variant) -> bool: return Cache.digest(var_to_bytes(a))==Cache.digest(var_to_bytes(b))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("catalog") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Recorded.new(); check(catalog.mount(args.catalog),"Strict original corpus mounts without fallback")
	var eager:=EagerAssets.new(); var packed:=Assets.new(); root.add_child(eager); root.add_child(packed)
	var samples: Array=[]
	for name in ["pme0","c_nulltail","pme0_chest025"]:
		var bytes:=catalog.get_resource(name,2002)
		var a:=eager.actor_data(catalog.fork(),name,bytes,"",[],{})
		var b:=packed.actor_data(catalog.fork(),name,bytes,"",[],{})
		check(catalog.failure.is_empty() and str(a.error).is_empty() and str(b.error).is_empty(),"Both full inheritance pipelines prepare exact original piece: "+name)
		if not str(a.error).is_empty() or not str(b.error).is_empty(): continue
		check(same(a.value.nodes,b.value.nodes) and same(a.animation_sources,b.animation_sources),"Geometry/skins/physical ordering and source identities remain exact: "+name)
		var metadata: bool=a.value.animations.size()==b.value.animations.size(); var frames_ok: bool=metadata; var tracks:=0; var frames:=0
		if metadata:
			for index in a.value.animations.size():
				var old: Dictionary=a.value.animations[index]; var next: Dictionary=b.value.animations[index]
				for field in ["name","length","transition","root","events","inheritedFrom","unsupported"]:
					if old.get(field)!=next.get(field): metadata=false
				for field in ["tracks","emitter_tracks"]:
					if old[field].size()!=next[field].size(): frames_ok=false; continue
					for track in old[field].size():
						var x: Dictionary=old[field][track]; var y: Dictionary=next[field][track]
						if x.node!=y.node or x.property!=y.property or x.interpolation!=y.interpolation or not same(x.frames,Keys.frames(y)): frames_ok=false
						tracks+=1; frames+=x.frames.size()
		check(metadata,"Inherited override selection, events and clocks remain exact: "+name)
		check(frames_ok,"Relevant-node filtering, root aliases and scaled inherited keys match eager path: "+name)
		var old_rig:=Actor.new().rig_asset(a.value); var next_rig:=Actor.new().rig_asset(b.value); var rigs_ok: bool=same(old_rig.defaults,next_rig.defaults) and same(old_rig.controlled,next_rig.controlled) and old_rig.clips.size()==next_rig.clips.size()
		if rigs_ok:
			for index in old_rig.clips.size():
				var old: Dictionary=old_rig.clips[index]; var next: Dictionary=next_rig.clips[index]
				if old.name!=next.name or old.tracks.size()!=next.tracks.size() or not same(old.emitterTracks,next.emitterTracks): rigs_ok=false; continue
				for track in old.tracks.size():
					if not same(Keys.keys(old.tracks[track]),Keys.keys(next.tracks[track])): rigs_ok=false
		check(rigs_ok,"Actual final composed rig channels remain exact: "+name)
		samples.append({"name":name,"clips":a.value.animations.size(),"tracks":tracks,"frames":frames,"source_chain":a.animation_sources})
	eager.close(); packed.close(); eager.queue_free(); packed.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"publicConnections":0,"scope":"Actual native actor_data inheritance and composed rigs, eager versus packed decoding of recorded originals; no original executable timing/FPS acceptance"},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
