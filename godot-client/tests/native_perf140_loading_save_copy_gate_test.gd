extends SceneTree
const Store=preload("res://systems/native_data/preparation_store.gd")
const Backend=preload("res://systems/native_data/resource_index_backend.gd")
var checks:=0
var failures: Array=[]
var observations: Array=[]
var enabled:=false
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func skips(store) -> Dictionary: return store.snapshot().get("publication_copy_gate",{})
func make_value(marker: String) -> Dictionary:
	var packed:=PackedFloat32Array([1.0,-0.0,2.5,4.0])
	var child:={"values":packed,"marker":marker}
	return {"marker":marker,"children":[child,child],"source":{"kind":"model","revision":3}}
func put(store,request: String,identity: String,value: Dictionary,expected: int,hint: int=-1,immutable: bool=false,trusted: bool=false) -> void:
	store.save_data(request,identity,value,expected,hint,immutable,trusted)
func observe(store,label: String) -> void:
	var snapshot: Dictionary=store.snapshot()
	observations.append({"label":label,"entries":snapshot.entries,"bytes":snapshot.estimated_bytes,"accounting":snapshot.accounting,"copy_gate":skips(store)})
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	enabled=OS.get_cmdline_user_args().has("--preparation-save-copy-gate=enabled")
	check(Backend.accounting_available(),"Actual native accounting is registered, not a stub")
	var store:=Store.new(); store.maximum_bytes=1024*1024; store.maximum_entries=8
	var epoch: int=store.generation(); var original:=make_value("first")
	put(store,"first-request","identity",original,epoch,-1,false,true)
	check(store.snapshot().accounting.native==1,"First publication executes original native charge")
	var charge: int=store.retained_size("first-request",epoch)
	check(charge>0 and charge<=store.maximum_bytes,"Original conservative charge and limit retained")
	original.children[0].marker="producer-mutated"; original.children[0].values[0]=99.0
	var first: Dictionary=store.load_data("first-request",epoch)
	check(first.marker=="first" and first.children[0].marker=="first" and first.children[0].values[0]==1.0,"First publication retains a private graph")
	var consumer: Dictionary=store.load_data("first-request",epoch); consumer.children[0].marker="consumer"; consumer.children[0].values[1]=7.0
	check(store.load_data("first-request",epoch).children[0].marker=="first" and is_same(store.load_data("first-request",epoch).children[0].values[1],-0.0),"Consumers remain private including packed wrappers")
	# Same content identity keeps the originally admitted value. Admission still
	# accounts the supplied graph, even though its private copy can be skipped.
	put(store,"second-request","identity",make_value("discarded"),epoch,-1,false,true)
	check(store.load_data("second-request",epoch).marker=="first","Trusted duplicate rebinds to the original retained graph")
	check(store.retained_size("second-request",epoch)==charge and store.snapshot().entries==1,"Duplicate neither recharges nor replaces retained value")
	check(store.snapshot().accounting.native==2,"Duplicate still executes original accounting")
	check(int(skips(store).get("existing_after_cost",0))==(1 if enabled else 0),"Only enabled trusted duplicate skips its discarded copy")
	observe(store,"trusted-duplicate")
	put(store,"generic-request","identity",make_value("generic-discarded"),epoch)
	check(store.load_data("generic-request",epoch).marker=="first","Generic publisher data semantics unchanged")
	check(int(skips(store).get("existing_after_cost",0))==(1 if enabled else 0),"Generic publisher never enters the copy gate")
	put(store,"hinted-request","identity",make_value("hinted"),epoch,charge,false,true)
	check(store.load_data("hinted-request",epoch).marker=="first","Existing positive hint path remains accepted")
	check(int(skips(store).get("existing_after_cost",0))==(1 if enabled else 0),"Hinted publication retains original path")
	var before_native: int=store.snapshot().accounting.native
	put(store,"negative-hint","identity",make_value("negative"),epoch,-2,false,true)
	check(store.snapshot().accounting.native==before_native+1,"Negative hint retains original full-accounting policy")
	check(store.load_data("negative-hint",epoch).marker=="first","Negative hint duplicate still keeps original data")
	for pair in [["zero",0],["oversized-hint",store.maximum_bytes+1]]:
		put(store,pair[0],"identity",make_value(pair[0]),epoch,pair[1],false,true)
		check(store.retained_size(pair[0],epoch)==0,"Rejected explicit size never rebinds existing identity: "+str(pair[0]))
	var big:=PackedByteArray(); big.resize(1024*1024)
	var unsafe:=RefCounted.new()
	put(store,"oversized-graph","identity",{"big":big,"unsafe":unsafe},epoch,-1,false,true)
	check(store.retained_size("oversized-graph",epoch)==0,"Bounded oversized graph is rejected before unsafe discarded fields or rebinding")
	unsafe=null; big=PackedByteArray()
	var immutable:=make_value("immutable")
	put(store,"immutable-first","immutable-id",immutable,epoch,-1,true,true)
	var skipped_before: int=int(skips(store).get("existing_after_cost",0))
	put(store,"immutable-next","immutable-id",make_value("not-retained"),epoch,-1,true,true)
	check(store.load_data("immutable-next",epoch).marker=="immutable","Immutable-source publication preserves retained first owner")
	check(int(skips(store).get("existing_after_cost",0))==skipped_before,"Immutable producers never need the private-copy gate")
	observe(store,"admission-and-owner-modes")
	# Clear/stale inputs still pay exactly the original charge; only their
	# provably discarded post-charge deep copy is avoided in the enabled path.
	var old: int=epoch; store.clear(); epoch=store.generation()
	before_native=store.snapshot().accounting.native
	put(store,"stale-request","identity",make_value("stale"),old,-1,false,true)
	check(store.snapshot().accounting.native==before_native+1,"Stale publication retains executed accounting counter")
	check(store.snapshot().entries==0 and store.retained_size("stale-request",epoch)==0,"Stale publication cannot recreate a current binding")
	check(int(skips(store).get("stale_after_cost",0))==(1 if enabled else 0),"Stale post-charge copy skip is explicit")
	put(store,"reused-request","identity",make_value("new-epoch"),epoch,-1,false,true)
	check(store.load_data("reused-request",epoch).marker=="new-epoch","Same identity after clear gets the new generation's value")
	check(first.marker=="first","Held detached earlier result survives clear")
	store.maximum_entries=1
	put(store,"replacement","other-id",make_value("replacement"),epoch,-1,false,true)
	check(store.retained_size("reused-request",epoch)==0 and store.snapshot().evictions==1,"Ordinary bounded eviction unchanged")
	put(store,"after-eviction","identity",make_value("after-eviction"),epoch,-1,false,true)
	check(store.load_data("after-eviction",epoch).marker=="after-eviction" and store.snapshot().entries==1,"Evicted identity is copied and admitted again, never a stale pointer hit")
	observe(store,"clear-and-eviction")
	# Actual native threads race content-addressed publishers. Which first value
	# wins is intentionally unspecified; all bindings must use that one value.
	var parallel:=Store.new(); parallel.maximum_entries=16; parallel.maximum_bytes=1024*1024
	var threads: Array=[]; var wakes: Array=[]; var parallel_epoch: int=parallel.generation()
	for index in 8:
		var wake:=Semaphore.new(); var thread:=Thread.new(); wakes.append(wake)
		var callable:=func():
			wake.wait()
			put(parallel,"r"+str(index),"shared-id",make_value("winner-"+str(index)),parallel_epoch,-1,false,true)
		check(thread.start(callable)==OK,"Actual publication worker starts: "+str(index)); threads.append(thread)
	for wake in wakes: wake.post()
	for thread in threads: thread.wait_to_finish()
	var winner: String=str(parallel.load_data("r0",parallel_epoch).get("marker",""))
	check(not winner.is_empty() and parallel.snapshot().entries==1 and parallel.snapshot().accounting.native==8,"Concurrent publishers execute eight charges and retain exactly one entry")
	for index in 8:
		var view: Dictionary=parallel.load_data("r"+str(index),parallel_epoch)
		check(view.get("marker","")==winner,"Concurrent request uses one retained identity: "+str(index))
		view.marker="private-"+str(index)
		check(parallel.load_data("r"+str(index),parallel_epoch).marker==winner,"Concurrent consumer remains isolated: "+str(index))
	observe(parallel,"concurrent")
	# Existing reference serializer remains untouched, including its counter.
	OS.set_environment("NWN_RESOURCE_ACCOUNTING","serialized")
	var reference:=Store.new(); var reference_epoch: int=reference.generation()
	put(reference,"a","id",make_value("serialized-first"),reference_epoch,-1,false,true)
	put(reference,"b","id",make_value("serialized-discarded"),reference_epoch,-1,false,true)
	OS.set_environment("NWN_RESOURCE_ACCOUNTING","")
	check(reference.snapshot().accounting.serialized==2 and reference.load_data("b",reference_epoch).marker=="serialized-first","Serialized fallback behavior and counters unchanged")
	check(int(skips(reference).get("existing_after_cost",0))==0,"Unavailable native charge never permits the gate")
	observe(reference,"serialized-fallback")
	var report:=FileAccess.open(args.report,FileAccess.WRITE)
	report.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"enabled":enabled,"observations":observations,"publicConnections":0,"scope":"Exact completed publication admission, charge, binding, generation, bound, owner, private mutation and actual concurrent lifetime checks. Diagnostic-only gate counters differ; no runtime latency or live-client claim."},"  ")); report.close()
	quit(0 if failures.is_empty() else 1)
