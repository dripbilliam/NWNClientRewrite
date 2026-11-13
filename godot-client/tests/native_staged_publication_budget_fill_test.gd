extends SceneTree
# Execute the real stream loops with deterministic eight-node preparation jobs.
# Existing graph/ownership fixtures separately exercise actual scene assembly.
const Objects=preload("res://systems/native_render/object_stream.gd")
const Area=preload("res://systems/native_render/area_stream.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const RealPool=preload("res://systems/native_render/resource_pool.gd")
class Placement extends Node3D:
	var limitations: Array=[]
	var parts: Array=[]
	var meshes: Array=[]
	func retire() -> void:queue_free()
class ChunkTemplate extends RefCounted:
	var limitations: Array=[]
	var clone_units:=64
	var clone_calls:=0
	var placements:=0
	func create_step(pending: Dictionary,_maximum: int=8,_budget: int=1500) -> Dictionary:
		clone_calls+=1;pending.cursor=int(pending.get("cursor",0))+8
		if int(pending.cursor)<clone_units:return {"status":"pending","units":8}
		pending.clear();placements+=1;return {"status":"ready","instance":Placement.new()}
class Jobs extends RefCounted:
	var stats:={"templates_created":0}
	var template_units:=64
	var clone_units:=64
	var calls:=0
	var delay_us:=0
	var templates: Array=[]
	func model_template_step(_bundle: Dictionary,pending: Dictionary) -> Dictionary:
		calls+=1
		if delay_us>0:OS.delay_usec(delay_us)
		pending.cursor=int(pending.get("cursor",0))+8
		if int(pending.cursor)<template_units:return {"status":"pending","units":8}
		pending.clear();stats.templates_created+=1
		var template:=ChunkTemplate.new();template.clone_units=clone_units;templates.append(template)
		return {"status":"ready","template":template,"created":true}
	func cancel_template_step(pending: Dictionary) -> void:pending.clear()
class SharedJobs extends Jobs:
	var charged:=0
	var cost_us:=100
	var used_us:=0
	func can_publish(_priority: bool=false) -> bool:return charged<16 and used_us<3000
	func publication_finished(_began: int,_priority: bool=false) -> void:charged+=1;used_us+=cost_us
class AssetStub extends Node:
	var pending: Dictionary={}
	var running: Dictionary={}
	var maximum_pending:=4
	var maximum_workers:=1
	var closed:=false
	func close() -> void:closed=true
	func retire_scope() -> void:pass
class CollisionStub extends RefCounted:
	func put(_node: Node3D) -> void:pass
	func clear() -> void:pass
	func snapshot() -> Dictionary:return {}
var checks:=0
var failures: Array=[]
var observations: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func objects(pool,count: int=2) -> Objects:
	var owner:=Objects.new();owner.pool=pool;owner.assets=AssetStub.new();owner.add_child(owner.assets);root.add_child(owner);owner.set_process(false)
	for index in count:
		var name:="model_"+str(index);var placement:={"id":index+1,"position":Vector3.ZERO,"rotation":0.0,"object":{"objectType":9,"replicated":{"animation":0}}}
		owner.queue.append({"model":name,"bundle":{"key":name},"placement":placement});owner.groups[name]=[placement]
	return owner
func terrain(pool,count: int=2) -> Area:
	var owner:=Area.new();owner.pool=pool;owner.assets=AssetStub.new();owner.add_child(owner.assets);owner.collision_index=CollisionStub.new();root.add_child(owner);owner.set_process(false)
	owner.definition={"tiles":[]};owner.light_table={"orderedRows":[]};owner.load_started=Time.get_ticks_usec()
	owner.diagnostics={"errors":[],"templates_built":0,"templates_reused":0,"template_ms":0.0,"clone_ms":0.0,"attach_ms":0.0,"tile_lights":[],"limitations":[],"max_tile_publish_ms":0.0,"publish_frames":0,"publish_ms":0.0,"max_publish_ms":0.0}
	for index in count:
		var name:="model_"+str(index);owner.definition.tiles.append({"position":Vector3.ZERO,"rotation_y":0.0,"main_lights":[]})
		owner.publish_queue.append({"model":name,"index":index});owner.template_keys[name]=name;owner.bundles[name]={"key":name};owner.publication_remaining[name]=1
	return owner
func release(owner) -> void:
	owner.close();owner.free()
func fill_checks() -> void:
	for kind in ["objects","terrain"]:
		var pool:=SharedJobs.new();var owner=objects(pool) if kind=="objects" else terrain(pool)
		owner._profile_process(0.0)
		var clones:=0
		for template in pool.templates:clones+=template.clone_calls
		check(pool.calls>1 and clones>1,kind+": cheap eight-node preparation and clone jobs advance repeatedly in one actual stream callback")
		check(pool.charged==16 and pool.used_us==1600,kind+": shared sixteen-attempt budget stops work without filling the3ms clock budget")
		check(owner.instances.size()==1 and pool.templates[0].placements==1,kind+": only the complete first placement is atomically published")
		check((owner.queue.size() if kind=="objects" else owner.publish_queue.size())==1,kind+": incomplete second placement stays queued")
		observations.append({"kind":kind,"template_calls":pool.calls,"clone_calls":clones,"charged":pool.charged,"published":owner.instances.size()})
		release(owner)
func fallback_checks() -> void:
	for kind in ["objects","terrain"]:
		var pool:=Jobs.new();pool.template_units=100000
		var owner=objects(pool,1) if kind=="objects" else terrain(pool,1)
		owner._profile_process(0.0)
		check(pool.calls==16 and owner.instances.is_empty(),kind+": pools without a shared budget cannot spin beyond sixteen cheap pending attempts")
		release(owner)
		var slow:=Jobs.new();slow.template_units=100000;slow.delay_us=4000
		owner=objects(slow,1) if kind=="objects" else terrain(slow,1)
		owner._profile_process(0.0)
		check(slow.calls==1 and owner.instances.is_empty(),kind+": per-owner elapsed guard also counts pending attempts after one indivisible slow call")
		release(owner)
func cap_checks() -> void:
	for kind in ["objects","terrain"]:
		var pool:=SharedJobs.new();pool.template_units=8;pool.clone_units=8
		var owner=objects(pool) if kind=="objects" else terrain(pool)
		if kind=="objects":owner.maximum_objects_per_frame=1
		else:owner.maximum_tiles_per_frame=1
		owner._profile_process(0.0)
		check(owner.instances.size()==1 and pool.charged==1,kind+": positive completed-object cap remains authoritative")
		release(owner)
	var real:=RealPool.new();real.publication_frame=Engine.get_process_frames();real.publications=16;real.publication_us=5000
	check(not real.can_publish() and real.can_publish(true),"Existing shared gate still reserves the first priority publication for the controlled actor")
	real.publication_finished(Time.get_ticks_usec(),true);check(not real.can_publish(true),"Priority bypass remains once per frame")
	real.clear()
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	check(Template.configured_recipe(),"Existing explicit recipe mode selects cooperative publication")
	if failures.is_empty():fill_checks();fallback_checks();cap_checks()
	await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"scope":"Actual object/terrain stream callback loops with deterministic eight-node job seams, shared/fallback/time/completed-object gates and atomic readiness. No graphical/loading/FPS claim; real graph equivalence covered separately."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close();print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
