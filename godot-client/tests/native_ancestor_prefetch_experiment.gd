extends SceneTree
# Standalone experiment only: no production scheduling change. Child threads
# decode one immutable source each, never inherit, publish GPU state or recurse.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
class PrefetchAssets:
	extends Assets
	static func parent_hint(bytes: PackedByteArray) -> String:
		if bytes.size()>=4 and bytes.decode_u32(0)==0:
			if bytes.size()<244 or bytes.decode_u32(4)<232 or bytes.decode_u32(4)>bytes.size()-12: return ""
			return Binary.new(bytes).text(180,64,true).to_lower()
		var text:=Binary.new(bytes).text(0,mini(bytes.size(),8192)); var regex:=RegEx.new(); regex.compile("\\s+")
		var hint:=""
		for line in text.split("\n"):
			var tokens:=Binary.ascii_tokens(line.strip_edges(),regex)
			if tokens.is_empty() or tokens[0].begins_with("#"): continue
			if tokens[0].to_lower()=="beginmodelgeom": break
			if tokens[0].to_lower()=="setsupermodel" and tokens.size()>2: hint=tokens[2].to_lower()
		return hint
	func one_source(bytes: PackedByteArray,reader) -> Dictionary:
		var began:=Time.get_ticks_usec(); var result:=decode(bytes,2002,"mdl-actor-packed-v3","",decoded_store(reader))
		return {"error":result.error,"memory_hit":result.get("memory_decode_hit",false),"timings":result.get("timings",{}),"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0}
	func actor_data(reader,name: String,bytes: PackedByteArray,cache_path: String,ancestors: Array,relevant_nodes: Variant=null) -> Dictionary:
		if not ancestors.is_empty(): return super.actor_data(reader,name,bytes,cache_path,ancestors,relevant_nodes)
		var jobs: Array=[]; var sources: Array=[]; var held_bytes:=0; var visited:={name.to_lower():true}; var candidate:=parent_hint(bytes); var began:=Time.get_ticks_usec()
		for index in 15:
			if candidate in ["","null","****"] or candidate.length()>32 or visited.has(candidate) or "/" in candidate or "\\" in candidate or ":" in candidate: break
			visited[candidate]=true
			var fork=reader.fork(); var at:=Time.get_ticks_usec(); var raw: PackedByteArray=fork.get_resource(candidate,2002)
			if not fork.failure.is_empty(): break # A hint never replaces authoritative parsing/errors.
			if held_bytes+raw.size()>32*1024*1024: break
			held_bytes+=raw.size(); sources.append({"bytes":raw,"reader":fork,"name":candidate,"read_ms":(Time.get_ticks_usec()-at)/1000.0})
			candidate=parent_hint(raw)
		# Standalone alternate experiment: prioritize the largest independent
		# source parses rather than occupying both helpers with cheap ancestors.
		sources.sort_custom(func(a,b):return a.bytes.size()>b.bytes.size())
		for source in sources.slice(0,2):
			var thread:=Thread.new(); var err:=thread.start(one_source.bind(source.bytes,source.reader))
			if err==OK: jobs.append({"thread":thread,"name":source.name,"read_ms":source.read_ms})
		var startup_ms:=(Time.get_ticks_usec()-began)/1000.0
		var result:=super.actor_data(reader,name,bytes,cache_path,ancestors,relevant_nodes)
		var samples: Array=[]; began=Time.get_ticks_usec()
		for job in jobs:
			var value: Dictionary=job.thread.wait_to_finish(); value.name=job.name; value.read_ms=job.read_ms; samples.append(value)
		result.experimental_prefetch={"sources":samples,"startup_ms":startup_ms,"join_ms":(Time.get_ticks_usec()-began)/1000.0,"production_enabled":false}
		return result
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("catalog") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var samples: Array=[]
	for name in ["pme0","pme0_chest025","c_nulltail"]:
		var catalog:=Recorded.new(); check(catalog.mount(args.catalog),"Serial frozen corpus mounts: "+name)
		var service:=Assets.new(); root.add_child(service); service.set_process(false)
		var bytes:=catalog.get_resource(name,2002); var began:=Time.get_ticks_usec(); var reference:=service.actor_data(catalog.fork(),name,bytes,"",[],{})
		var reference_ms:=(Time.get_ticks_usec()-began)/1000.0
		service.close(); service.free(); catalog=null
		var next_catalog:=Recorded.new(); check(next_catalog.mount(args.catalog),"Independent cold decoder cache mounts: "+name)
		var parallel:=PrefetchAssets.new(); root.add_child(parallel); parallel.set_process(false); bytes=next_catalog.get_resource(name,2002)
		began=Time.get_ticks_usec(); var candidate:=parallel.actor_data(next_catalog.fork(),name,bytes,"",[],{}); var candidate_ms:=(Time.get_ticks_usec()-began)/1000.0
		check(str(reference.error).is_empty() and str(candidate.error).is_empty(),"Both original-byte inheritance paths succeed: "+name)
		check(Cache.digest(var_to_bytes(reference.value))==Cache.digest(var_to_bytes(candidate.value)) and reference.animation_sources==candidate.animation_sources,"Complete composed hierarchy, animations, keys and source identities remain exact: "+name)
		check(next_catalog.decoder_store.snapshot().inflight==0,"Every prefetched single-flight source has joined/drained: "+name)
		samples.append({"name":name,"serial_ms":reference_ms,"candidate_ms":candidate_ms,"source_chain":candidate.animation_sources,"prefetch":candidate.experimental_prefetch})
		parallel.close(); parallel.free()
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"publicConnections":0,"productionEnabled":false,"scope":"Single-observation data-only ancestor overlap experiment; cold decoded cache, no disk cache; actual whole-world scheduling, global worker limits and lifetime stress remain unvalidated"},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
