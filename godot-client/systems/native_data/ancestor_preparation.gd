extends RefCounted
# Bounded data-only ancestor decoding. Original 140079f90 resolves its parent
# at 14007a105 before walking nodes at 14007a301/36f. Parallelism/limits here are
# our adaptation. Hints never replace full parsing or authoritative errors.
const Binary=preload("res://systems/native_data/binary_data.gd")
const ActorSource=preload("res://systems/native_data/actor_model.gd")
static var budget_mutex:=Mutex.new()
static var active:=0
static var peak:=0
static func configured_enabled() -> bool: return not OS.get_cmdline_user_args().has("--ancestor-preparation=false")
static func configured_share() -> int: return 2 if OS.get_cmdline_user_args().has("--ancestor-share=2") else 1
static func claim() -> int:
	budget_mutex.lock(); var count:=mini(configured_share(),maxi(0,2-active)); active+=count; peak=maxi(peak,active); budget_mutex.unlock(); return count
static func release(count: int=1) -> void:
	budget_mutex.lock(); active-=count; budget_mutex.unlock()
static func snapshot() -> Dictionary:
	budget_mutex.lock(); var result:={"active":active,"peak":peak,"maximum":2,"per_root":configured_share(),"enabled":configured_enabled(),"priority_only":true}; budget_mutex.unlock(); return result
static func parent_hint(bytes: PackedByteArray) -> String:
	if bytes.size()>=4 and bytes.decode_u32(0)==0:
		if bytes.size()<244 or bytes.decode_u32(4)<232 or bytes.decode_u32(4)>bytes.size()-12: return ""
		return Binary.new(bytes).text(180,64,true).to_lower()
	# Bounded hint only; an exporter may override this later in the file. The
	# normal parser still determines the real chain, including cycles/depth.
	var text:=Binary.new(bytes).text(0,mini(bytes.size(),8192)); var regex:=RegEx.new(); regex.compile("\\s+")
	var hint:=""
	for line in text.split("\n"):
		var tokens:=Binary.ascii_tokens(line.strip_edges(),regex)
		if tokens.is_empty() or tokens[0].begins_with("#"): continue
		if tokens[0].to_lower()=="beginmodelgeom": break
		if tokens[0].to_lower()=="setsupermodel" and tokens.size()>2: hint=tokens[2].to_lower()
	return hint
static func decode_source(decoder: Callable,bytes: PackedByteArray,cache_path: String,store) -> Dictionary:
	# This task decodes exactly one source. It never inherits or submits/waits
	# for pool work, so pool saturation cannot create a nested dependency cycle.
	var began:=Time.get_ticks_usec(); var value: Dictionary=decoder.call(bytes,2002,ActorSource.SOURCE_DECODER,cache_path,store)
	var result:={"error":value.error,"memory_hit":value.get("memory_decode_hit",false),"timings":value.get("timings",{}),"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0}
	release(); return result
static func start(reader,name: String,bytes: PackedByteArray,cache_path: String,decoder: Callable) -> Dictionary:
	var began:=Time.get_ticks_usec(); var candidate:=parent_hint(bytes)
	var state:={"jobs":[],"metrics":{"enabled":true,"startup_ms":0.0,"join_ms":0.0,"sources":[],"reads":[],"held_source_bytes":0,"deferred":false,"hint_only":true}}
	if candidate in ["","null","****"]: state.metrics.startup_ms=(Time.get_ticks_usec()-began)/1000.0; return state
	var count:=claim()
	if count==0: state.metrics.deferred=true; state.metrics.startup_ms=(Time.get_ticks_usec()-began)/1000.0; return state
	var sources: Array=[]; var visited:={name.to_lower():true}; var held_bytes:=0
	for index in 15:
		if candidate in ["","null","****"] or candidate.length()>32 or visited.has(candidate) or "/" in candidate or "\\" in candidate or ":" in candidate: break
		visited[candidate]=true
		var fork=reader.fork(); var at:=Time.get_ticks_usec(); var raw: PackedByteArray=fork.get_resource(candidate,2002)
		state.metrics.reads.append({"name":candidate,"bytes":raw.size(),"ms":(Time.get_ticks_usec()-at)/1000.0,"error":fork.failure})
		if not fork.failure.is_empty() or held_bytes+raw.size()>32*1024*1024: break
		held_bytes+=raw.size(); sources.append({"bytes":raw,"name":candidate})
		candidate=parent_hint(raw)
	sources.sort_custom(func(a,b):return a.bytes.size()>b.bytes.size())
	var store=reader.decoded_cache() if reader.has_method("decoded_cache") else (reader.preparation_cache() if reader.has_method("preparation_cache") else null)
	for source in sources.slice(0,count):
		var thread:=Thread.new(); var err:=thread.start(decode_source.bind(decoder,source.bytes,cache_path,store))
		if err==OK: state.jobs.append({"thread":thread,"name":source.name})
		else: release(); state.metrics.sources.append({"name":source.name,"start_error":err})
	if sources.size()<count: release(count-sources.size())
	state.metrics.startup_ms=(Time.get_ticks_usec()-began)/1000.0; state.metrics.held_source_bytes=held_bytes
	state.metrics.jobs_started=state.jobs.size()
	return state
static func finish(state: Dictionary) -> Dictionary:
	var began:=Time.get_ticks_usec()
	for job in state.jobs:
		var result: Dictionary=job.thread.wait_to_finish(); result.name=job.name; state.metrics.sources.append(result)
	state.jobs.clear(); state.metrics.join_ms=(Time.get_ticks_usec()-began)/1000.0; state.metrics.global_budget=snapshot()
	return state.metrics
