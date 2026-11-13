extends SceneTree
const References=preload("res://systems/native_render/reference_assets.gd")
class FakeCatalog:
	extends RefCounted
	func has_resource(name: String,_type: int) -> bool: return name=="known" or name=="failed"
class FakeAssets:
	extends Node
	var catalog=FakeCatalog.new()
	var pending: Array=[]
	var running: Dictionary={}
	var maximum_pending:=8
	var maximum_workers:=2
	var serial:=0
	var failure:=""
	func request(_name: String,_type: int,_decoder: String,_options: Dictionary={}) -> int:
		serial+=1; return serial
	func prioritize(_ids: Array) -> void: pass
	func close() -> void: pass
class FakePool:
	extends Node
	func can_publish() -> bool: return true
	func publication_finished(_began: int) -> void: pass
class Owner:
	extends Node3D
	var generation:=-1
	var retired:=false
	var hub
	var next_owner
	var installed:=0
	var rejected:=0
	func install_bundle(_bundle: Dictionary,_generation: int) -> bool:
		installed+=1
		if next_owner!=null:hub.request_bundle(next_owner,"known");next_owner=null
		return true
	func reject(_reason: String) -> void:
		rejected+=1
		if next_owner!=null:hub.request_bundle(next_owner,"known");next_owner=null
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var pool:=FakePool.new();root.add_child(pool)
	var hub:=References.new();root.add_child(hub)
	var assets:=FakeAssets.new();root.add_child(assets)
	hub.assets=assets;hub.pool=pool;hub._refresh_processing()
	check(not hub.is_processing(),"Empty owner starts idle")
	hub.set_priority_origin(Vector3(3,0,4))
	check(not hub.is_processing(),"Priority update alone does not schedule empty owner")
	var missing:=Owner.new();root.add_child(missing);missing.hub=hub
	hub.request_bundle(missing,"absent")
	check(missing.rejected==1 and not hub.is_processing(),"Missing root rejects without idle callback")
	var canceled:=Owner.new();root.add_child(canceled);canceled.hub=hub
	hub.request_bundle(canceled,"known")
	check(hub.is_processing() and hub.waiting.size()==1,"New wait wakes owner")
	hub.cancel_reference(canceled)
	check(not hub.is_processing() and hub.waiting.is_empty(),"Cancel of last waiter sleeps owner")
	var first:=Owner.new();root.add_child(first);first.hub=hub
	var second:=Owner.new();root.add_child(second);second.hub=hub
	var third:=Owner.new();root.add_child(third);third.hub=hub
	hub.request_bundle(first,"known");hub.request_bundle(second,"known")
	hub._profile_process(0)
	check(hub.is_processing() and hub.jobs.size()==1 and assets.serial==1,"Deduplicated worker remains scheduled")
	hub.completed(1,{"error":"","worker_ms":0.0,"authored":true})
	check(hub.is_processing() and hub.publication.size()==2,"Completion keeps publication awake")
	first.next_owner=third
	hub._profile_process(0)
	check(hub.is_processing() and hub.publication.size()==1 and first.installed==1 and second.installed==1,"Synchronous publication re-enqueue remains scheduled")
	hub._profile_process(0)
	check(not hub.is_processing() and third.installed==1 and hub.ready(),"Drained cache hit sleeps owner")
	var failure:=Owner.new();root.add_child(failure);failure.hub=hub
	var recovery:=Owner.new();root.add_child(recovery);recovery.hub=hub
	hub.request_bundle(failure,"failed");hub._profile_process(0)
	failure.next_owner=recovery
	hub.completed(2,{"error":"Read failed","worker_ms":0.0})
	check(hub.is_processing() and failure.rejected==1 and hub.publication.size()==1,"Failure callback re-enqueue wakes owner")
	hub._profile_process(0)
	check(not hub.is_processing() and recovery.installed==1,"Failure recovery drains then sleeps")
	hub.request_bundle(canceled,"known")
	check(hub.is_processing(),"Later cache hit wakes settled owner")
	hub.close()
	check(not hub.is_processing() and hub.ready(),"Close clears work and disables processing")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"work_removed":"one empty ReferenceAssets process callback per frame while settled","scope":"Focused scheduling and synchronous callback re-entry; no FPS or GPU claim"}
	print("NWN73_REFERENCE_IDLE ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
