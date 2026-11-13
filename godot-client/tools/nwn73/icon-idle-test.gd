extends SceneTree
const Icons=preload("res://systems/native_item_icons.gd")
class FakeAssets:
	extends RefCounted
	var pending: Array=[]
	var running: Dictionary={}
	var maximum_pending:=1
	var failure:=""
	var next_id:=0
	var calls: Array=[]
	var owner
	var inject: Dictionary={}
	var closed:=false
	func request(name: String,kind: int,decoder: String,options: Dictionary) -> int:
		next_id+=1;pending.append(next_id);calls.append([name,kind,decoder,options])
		if not inject.is_empty():owner.deferred_models.append(inject);inject={}
		return next_id
	func close() -> void:closed=true

var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func job(name: String) -> Dictionary:
	return {"name":name,"overrides":{},"key":name,"clip":"up","turn":0,"texture_layer":"","poses":[],"render_region":Rect2()}
func run() -> void:
	var idle:=Icons.new();root.add_child(idle)
	check(not idle.is_processing(),"new icon owner has no idle frame callback")
	idle.configure(RefCounted.new(),"")
	check(not idle.is_processing(),"configure keeps an empty icon owner asleep")
	idle.close();check(not idle.is_processing(),"close leaves configured icon owner asleep")
	idle.queue_free()

	var owner:=Icons.new();root.add_child(owner)
	var fake:=FakeAssets.new();fake.owner=owner;owner.assets=fake
	owner.deferred_models.append(job("first"));owner.pump_models()
	check(fake.calls.size()==1 and owner.requests.has(1),"available worker receives first model in order")
	check(owner.deferred_models.is_empty() and not owner.is_processing(),"drained queue disables owner callback")
	owner.deferred_models.append(job("second"));owner.pump_models()
	check(owner.is_processing() and owner.deferred_models.size()==1,"full worker queue keeps owner callback enabled")
	fake.pending.clear();fake.inject=job("third");owner._profile_process(0.0)
	check(fake.calls.size()==2 and owner.requests.has(2),"freed worker slot admits deferred model")
	check(owner.is_processing() and owner.deferred_models.size()==1,"reentrant enqueue remains scheduled")
	fake.pending.clear();owner._profile_process(0.0)
	check(fake.calls.size()==3 and owner.requests.has(3),"reentrant model admits after next slot frees")
	check(not owner.is_processing() and owner.deferred_models.is_empty(),"final drain disables callback")
	owner.prepared(3,{"error":"","value":{}})
	check(owner.queue.size()==1 and owner.is_processing(),"completed worker wakes queued draw publication")
	owner.queue.clear();owner.active=true;owner._refresh_processing()
	check(not owner.is_processing(),"viewport wait needs no owner polling when draw queue is empty")
	owner.queue.append({"key":"next"});owner._refresh_processing()
	check(owner.is_processing(),"follow-on draw queue keeps owner callback enabled during active viewport wait")
	owner.close();check(fake.closed and not owner.is_processing(),"close stops callback and closes worker owner")
	owner.queue_free()
	print(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
