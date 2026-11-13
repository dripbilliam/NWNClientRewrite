extends SceneTree
# Read-only original event arrays and native inheritance. The two-model event
# owner exercise uses authored empty pose bindings; it is not a pixel oracle.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Rigs=preload("res://systems/model_rigs.gd")
var checks:=0
var failures: Array=[]
var observations: Array=[]
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value: failures.append(label)
	return value
func _initialize() -> void: call_deferred("run")
func physical(bytes: PackedByteArray,wanted: String) -> Dictionary:
	if bytes.size()<244 or bytes.decode_u32(0)!=0: return {}
	var reader:=Binary.new(bytes); var array:=12+reader.u32(132); var count:=reader.u32(136)
	if not reader.contains(array,count*4): return {}
	for index in count:
		var at:=12+reader.u32(array+index*4)
		if not reader.contains(at,196): return {}
		if reader.text(at+8,64,true).to_lower()!=wanted: continue
		var entries:=12+reader.u32(at+184); var total:=reader.u32(at+188)
		if not reader.contains(entries,total*36): return {}
		var events: Array=[]
		for event in total: events.append({"time":reader.f32(entries+event*36),"name":reader.text(entries+event*36+4,32,true)})
		return {"events":events,"headerOffset":at,"eventOffset":entries,"length":reader.f32(at+112)}
	return {}
func emission(clip: Dictionary) -> Dictionary:
	var pivot:=Node3D.new(); root.add_child(pivot)
	var rigs:=Rigs.new(); root.add_child(rigs)
	var asset:={"defaults":[],"controlled":{},"unsupported":[],"clips":[{"name":clip.name,"length":clip.length,"transition":0.0,"events":clip.events.duplicate(true),"tracks":[]}]}
	var binding:={"asset":0,"parts":[],"follow":true,"clip":clip.name,"loop":false}
	var source:={"id":42,"nodes":[],"models":[binding.duplicate(),binding.duplicate()],"clipMap":{"205":clip.name},"animationSource":0}
	rigs.configure({"meshes_by_name":{}},{42:pivot},{"rigs":{"version":1,"assets":[asset],"entities":[source]},"meshes":[]}); rigs.set_process(false)
	var model_events: Array=[]; var actor_events: Array=[]
	rigs.model_event.connect(func(_id,index,name,_serial):model_events.append({"model":index,"name":name}))
	rigs.animation_event.connect(func(_id,name,_serial):actor_events.append(name))
	rigs.set_playback(42,205,1.0,false,true); rigs._update(float(clip.length))
	var expected: Array=[]
	for event in clip.events:
		if float(event.time)>0.0 and float(event.time)<=float(clip.length): expected.append(str(event.name))
	check(rigs.stats.failures.is_empty(),"Actual two-part event owner installs without geometry or GPU")
	check(actor_events==expected,"One animationSource forwards every physical event exactly once, preserving duplicate entries")
	check(model_events.size()==expected.size()*2,"Both following parts retain physical model events independently")
	var result:={"actorEvents":actor_events.duplicate(),"modelEvents":model_events.duplicate(true),"expected":expected,"binding":"Authored two-part empty-pose rig with one actual animationSource; real original clip length/event arrays"}
	rigs.free(); pivot.free(); return result
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("install") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Catalog.new(); var service:=Assets.new(); root.add_child(service)
	service.high_priority=false; service.ancestor_preparation_enabled=false
	if check(catalog.mount_install(args.install),"Read-only original installed catalog mounts"):
		for request in [["pme0","nwreach"],["pmh0","nwreach"],["pmh0","1hslashr"]]:
			var name:=str(request[0]); var wanted:=str(request[1]); var bytes:=catalog.get_resource(name,2002)
			var data: Dictionary=service.actor_data(catalog,name,bytes,"",[],{})
			if not check(str(data.get("error","")).is_empty(),"Original native model/ancestors parse: "+name): continue
			var selected: Array=data.value.animations.filter(func(clip):return clip.name==wanted)
			if not check(selected.size()==1,"Native inheritance selects exactly one original clip: "+name+":"+wanted): continue
			var clip: Dictionary=selected[0]; var owner:=""; var raw: Dictionary={}; var sha:=""
			for source in data.animation_sources:
				var original: PackedByteArray=catalog.get_resource(str(source.name),2002); var found:=physical(original,wanted)
				if not found.is_empty(): owner=str(source.name); raw=found; sha=str(source.sha256); break
			if not check(not raw.is_empty() and raw.events==clip.events,"Native inherited events equal exact physical MDL entries, including multiplicity: "+name+":"+wanted): continue
			observations.append({"model":name,"clip":wanted,"owner":owner,"ownerSha256":sha,"chain":data.animation_sources.duplicate(true),"physical":raw,"nativeEmission":emission(clip)})
	service.close(); service.free(); await process_frame
	var output:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"serverConnections":0,"gpu":false,"fullCombat":false,"scope":"Native original installed inheritance vs physical MDL event array and actual two-part event ownership with empty authored pose bindings. Multiplicity/timestamps retained; no original loader/event callback execution, live graph, pixel or audio parity claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(output,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
