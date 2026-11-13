extends SceneTree
# Exercise the real request/admission owner with an actual ordered catalog.
# Worker/payload/model publication is deliberately outside this focused gate.
const References=preload("res://systems/native_render/reference_assets.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
class FakeAssets:
	extends Node
	var catalog
	var pending: Array=[]
	var running: Dictionary={}
	var maximum_pending:=64
	var maximum_workers:=2
	var calls: Array=[]
	var serial:=0
	var failure:=""
	func request(resource: String,type: int,decoder: String,options: Dictionary={}) -> int:
		serial+=1; calls.append([resource,type,decoder,options]); return serial
	func prioritize(_ids: Array) -> void: pass
	func close() -> void: pass
class Owner:
	extends Node3D
	var generation:=-1
	var retired:=false
	var reasons: Array=[]
	func reject(reason: String) -> void: reasons.append(reason)
var checks:=0
var failures: Array=[]
var observations: Dictionary={}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func make_owner() -> Owner:
	var owner:=Owner.new(); root.add_child(owner); return owner
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("fixture") or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Catalog.new()
	check(catalog.mount_directory(args.fixture),"Actual loose catalog mounts the authored root binding")
	check(catalog.has_resource("known",2002) and not catalog.has_resource("absent",2002),"Actual catalog distinguishes present and absent model roots")
	var service:=FakeAssets.new(); service.catalog=catalog; root.add_child(service)
	var hub:=References.new(); root.add_child(hub); hub.assets=service
	hub.set_process(false)
	var owners: Array=[]
	for index in 224:
		var owner:=make_owner(); owners.append(owner)
		if index%2==0: hub.request_reference(owner,"absent")
		else: hub.request_bundle(owner,"absent")
	check(service.calls.is_empty() and hub.waiting.is_empty() and hub.jobs.is_empty() and hub.requests.is_empty(),"Repeated absent references and chunks create no worker admission or retained waiters")
	check(owners.all(func(owner):return owner.reasons.size()==1 and str(owner.reasons[0]).contains("Resource not found: absent:2002")),"Every absent physical owner receives one explicit unavailable error")
	check(hub.ready() and owners.all(func(owner):return owner.generation==hub.generation),"Missing roots do not leave readiness or owner generation pending")
	check(int(hub.stats.missing_root_requests)==224 and int(hub.stats.jobs)==0,"Missing-root bypass counters distinguish avoided jobs")
	var first:=make_owner(); var second:=make_owner(); owners.append_array([first,second])
	hub.request_reference(first,"known"); hub.request_bundle(second,"known")
	check(hub.waiting.size()==1 and hub.requests.known.size()==2 and service.calls.is_empty(),"Present model owners retain existing shared admission")
	hub._profile_process(0)
	check(service.calls.size()==1 and hub.jobs.size()==1 and hub.requests.known.size()==2,"One present binding creates exactly one ordinary asset job")
	hub.completed(1,{"error":"Authored read failure","worker_ms":0.0})
	check(first.reasons==["Original referenced model unavailable: known: Authored read failure"] and first.reasons==second.reasons,"Present-resource preparation failures keep their existing delivery path")
	var retry:=make_owner(); owners.append(retry); hub.request_reference(retry,"known"); hub._profile_process(0)
	check(service.calls.size()==2 and hub.jobs.has(2),"Transient failures of a present root are not negative-cached")
	hub.completed(2,{"error":"","worker_ms":0.0,"value":{"authored":true}})
	var cached:=make_owner(); owners.append(cached); hub.request_reference(cached,"known")
	check(service.calls.size()==2 and hub.publication.size()==2 and hub.prepared.has("known"),"Successful roots retain existing cache reuse and private publication requests")
	check(hub.publication[0].request.node.get_ref()!=hub.publication[1].request.node.get_ref(),"Shared prepared data still has distinct physical owner requests")
	# The preflight reads the current catalog, without a persistent miss tombstone.
	var file:=FileAccess.open(str(args.fixture).path_join("absent.mdl"),FileAccess.WRITE)
	file.store_string("# newly mounted authored resource; no decoder invoked\n"); file.close()
	check(catalog.mount_directory(args.fixture,20000000),"A later actual binding mount succeeds in the same catalog")
	var later:=make_owner(); owners.append(later); hub.request_bundle(later,"absent")
	check(later.reasons.is_empty() and hub.waiting.has("absent") and hub.requests.absent.size()==1,"A formerly absent root becomes available immediately after mount")
	hub.publication.clear(); hub._profile_process(0)
	check(service.calls.size()==3 and hub.jobs.has(3) and service.calls[2][0]=="absent","Later availability reaches the ordinary worker path")
	var retired:=make_owner(); owners.append(retired); hub.request_reference(retired,"other_missing")
	retired.retired=true; hub.cancel_reference(retired)
	check(hub.requests.get("other_missing",[]).is_empty(),"Missing roots retain no owner that can survive cancellation")
	observations={"physicalMissingOwners":224,"avoidedJobs":hub.stats.missing_root_requests,"ordinaryJobs":service.calls.size(),"errorSamples":hub.stats.errors.size(),"catalogMounts":catalog.layers.size()}
	hub.close(); hub.free(); service.free()
	for owner in owners: owner.free()
	await process_frame; await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"serverConnections":0,"gpu":false,"scope":"Actual reference request/admission owner and actual mounted ResourceCatalog; worker/model/pixel and gameplay performance acceptance are not covered"}
	var report:=FileAccess.open(args.report,FileAccess.WRITE); report.store_string(JSON.stringify(result,"  ")+"\n"); report.close()
	quit(0 if failures.is_empty() else 1)
