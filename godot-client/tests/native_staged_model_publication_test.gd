extends SceneTree
# Exact pre-change construction and PackedScene oracle; never admits partial
# graphs or invokes worker scene/GPU operations. Run later with recipe mode.
const BeforeInstance=preload("res://tests/fixtures/native_model_instance_before_publication.gd")
const BeforeTemplate=preload("res://tests/fixtures/native_model_template_before_publication.gd")
const Instance=preload("res://systems/native_render/model_instance.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Ascii=preload("res://systems/native_data/ascii_model.gd")
const Preparation=preload("res://systems/native_data/mesh_preparation.gd")
const Objects=preload("res://systems/native_render/object_stream.gd")
const Area=preload("res://systems/native_render/area_stream.gd")
var checks:=0
var failures: Array=[]
var maximum_returned_units:=0
class LocalPool extends Pool:
	func material(part: Dictionary,raster: Dictionary={}) -> Material:
		var value: Material=super.material(part,raster)
		if value!=null:value.resource_local_to_scene=true
		return value
class CapturePool extends Pool:
	var captured: Array=[]
	var ended: Array=[]
	var wrong: Array=[]
	func begin_native_model(bundle: Dictionary) -> Dictionary:
		var context:={"source":str(bundle.sha256)};native_draw_captures.append(context);return context
	func capture_native_geometry(source_sha: String,index: int,_rigid: bool,_mesh: ArrayMesh) -> void:
		for context in native_draw_captures:
			if context.source!=source_sha:wrong.append([source_sha,context.source])
		captured.append([source_sha,index,native_draw_captures.size()])
	func end_native_model(context: Dictionary) -> void:
		native_draw_captures.erase(context);ended.append(context.source)
class LegacyPool extends RefCounted:
	var inner:=Pool.new()
	var compact_static_parts:=false
	var native_lighting:=false
	var unshaded:=false
	var begins:=0
	var ends:=0
	func begin_native_model(_bundle: Dictionary) -> Dictionary:begins+=1;return {"legacy":true}
	func end_native_model(_context: Dictionary) -> void:ends+=1
	func geometry(sha: String,index: int,data: Dictionary,rigid: bool=false):return inner.geometry(sha,index,data,rigid)
	func hidden_geometry(sha: String,index: int,data: Dictionary):return inner.hidden_geometry(sha,index,data)
	func material(part: Dictionary,raster: Dictionary={}):return inner.material(part,raster)
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func bundle(sha: String="a") -> Dictionary:
	var source:="newmodel staged\nclassification tile\nbeginmodelgeom staged\nnode dummy root\nparent NULL\nposition 1 2 3\nendnode\nnode trimesh body\nparent root\nbitmap NULL\nrender 1\nshadow 1\nverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 0 0 0\nendnode\nnode dummy sparks\nparent root\nendnode\nnode dummy first_link\nparent sparks\nendnode\nnode dummy second_link\nparent sparks\nendnode\nendmodelgeom staged\ndonemodel staged\n"
	var parser:=Ascii.new();var model:=parser.parse(source);check(parser.failure.is_empty(),"Independent original model parser builds fixture")
	model.nodes[2].features=["emitter"]
	model.nodes[2].emitter={"update":"Fountain","render":"Normal","blend":"Normal","flags":0,"texture":"NULL","birthrate":0.0,"lifeexp":1.0,"velocity":0.1,"sizestart":0.1,"sizeend":0.1,"alphastart":1.0,"alphaend":1.0,"xgrid":1,"ygrid":1,"colorstart":[1.0,0.5,0.2]}
	for index in [3,4]:model.nodes[index].reference={"model":"child_"+str(index),"reattachable":1};model.nodes[index].features=["reference"]
	var prepared:=Preparation.model(model);check(str(prepared.error).is_empty(),"Worker upload preparation stays authoritative")
	return {"sha256":sha.repeat(64),"resource_name":"staged","value":model,"textures":{}}
func node_rows(root_node: Node) -> Array:
	var result: Array=[];var pending: Array=[]
	for child in root_node.get_children():pending.append(child)
	while not pending.is_empty():
		var node: Node=pending.pop_front();var metadata: Dictionary={}
		for key in node.get_meta_list():metadata[key]=node.get_meta(key)
		var row:={"path":str(root_node.get_path_to(node)),"class":node.get_class(),"transform":node.transform,"visible":node.visible,"metadata":metadata}
		if node is MeshInstance3D:row.mesh=node.mesh;row.material=node.material_override;row.shadow=node.cast_shadow;row.layers=node.layers
		if node.get_script()==preload("res://systems/native_render/particle_emitter.gd"):
			row.emitter=[node.original_properties,node.physical_part,node.source_path,node.reference_paths,node.channel_asset]
		if node.get_script()==preload("res://systems/native_render/model_reference.gd"):row.reference=[node.original_header,node.origin_resource]
		result.append(row);pending.append_array(node.get_children())
	return result
func instance_checks(input: Dictionary) -> void:
	for compact in [false,true]:
		var pool:=Pool.new();pool.compact_static_parts=compact
		var before:=BeforeInstance.new();check(before.install(input,pool),"Exact before ModelInstance installs")
		var target:=Instance.new();check(target.begin_install(input,pool),"Detached staged installation begins")
		check(not target.installed and not target.is_inside_tree(),"Begin does not publish readiness or enter tree")
		var turns:=0
		while not target.installed and turns<256:
			var step:=target.install_step(1,1);turns+=1;maximum_returned_units=maxi(maximum_returned_units,int(step.units))
			check(step.status!="failed" and int(step.units)<=1 and not target.is_inside_tree(),"Each install yield respects unit cap and detached ownership")
			if step.status=="failed":break
		check(target.installed and node_rows(before)==node_rows(target),"Staged nodes/materials/resources/metadata/reference paths equal exact pre-change transcript")
		check(target.parts[2].get_node("native_emitter").reference_paths==before.parts[2].get_node("native_emitter").reference_paths,"Source-order reference linking equals original quadratic traversal")
		before.free();target.free();pool.clear()
	var legacy:=LegacyPool.new();var synchronous:=Instance.new();check(synchronous.install(input,legacy) and legacy.begins==1 and legacy.ends==1,"Legacy synchronous begin/end-only pool bracket remains intact")
	var declined:=Instance.new();check(not declined.begin_install(input,legacy) and declined.failure=="Pool does not support cooperative native capture" and declined.get_child_count()==0,"Cooperative API explicitly rejects an unsuspendable legacy capture pool")
	synchronous.free();declined.free();legacy.inner.clear()
func capture_scope_checks() -> void:
	var pool:=CapturePool.new();var a:=Instance.new();var b:=Instance.new()
	check(a.begin_install(bundle("b"),pool) and b.begin_install(bundle("c"),pool) and pool.native_draw_captures.is_empty(),"Interleaved builders retain tickets but no active capture across yields")
	for turn in 32:
		if not a.installed:a.install_step(1,1)
		if turn<3:b.install_step(1,1)
		elif turn==3:b.cancel_install()
		check(pool.native_draw_captures.is_empty(),"Capture scope is empty after every step/cancel")
	check(a.installed and b.get_child_count()==0 and pool.wrong.is_empty(),"Interleaved source identities cannot capture each other's geometry; cancelled graph is released")
	check(pool.ended.count("b".repeat(64))==1 and pool.ended.count("c".repeat(64))==1,"Complete and cancelled captures each end exactly once")
	a.free();b.free();pool.clear()
func template_checks(input: Dictionary) -> void:
	var pool:=Pool.new();var before:=BeforeTemplate.new();check(before.build(input,pool) and before.recipe==null and before.scene!=null,"Independent pre-change template builds actual PackedScene oracle")
	var target:=Template.new();check(target.begin_staged_build(input,pool),"Selected recipe mode starts cooperative template")
	var turns:=0
	while turns<512:
		var state:=target.staged_build_step(1,1);turns+=1;maximum_returned_units=maxi(maximum_returned_units,int(state.units))
		check(int(state.units)<=1,"Template step returns at most one requested construction unit")
		if state.status=="ready":break
		check(state.status=="pending" and target.create()==null and not target.construction_snapshot().ready,"Partial template cannot create/admit a placement")
		if state.status=="failed":break
	check(target.recipe!=null and target.scene==null and target.recipe_capture_successes==1,"Supported graph commits known-node recipe without PackedScene packing")
	var original:=target._first_root;var pending: Dictionary={};var first: Dictionary=target.create_step(pending,1,1)
	check(first.status=="ready" and first.instance.get_child(0)==original and target.first_instance_reuses==1,"First placement transfers original untouched root exactly once")
	if first.status!="ready":pool.clear();return
	var oracle=before.create();check(node_rows(first.instance.get_child(0))==node_rows(oracle.get_child(0)),"Staged first graph equals independent packed constructor/resource ownership")
	var immutable:=node_rows(first.instance.get_child(0));first.instance.parts[1].position.x+=99
	var clone: Dictionary={};turns=0
	while turns<512:
		clone=target.create_step(pending,1,1);turns+=1
		if clone.status!="pending":break
		check(not pending.job.nodes.is_empty() and not pending.job.nodes[0].is_inside_tree(),"Partial clone stays detached")
	check(clone.status=="ready" and node_rows(clone.instance.get_child(0))==immutable,"Later incremental clone uses immutable captured state despite first-placement mutation")
	if clone.status!="ready":first.instance.retire();oracle.retire();pool.clear();return
	var packed_clone=before.create();check(node_rows(clone.instance.get_child(0))==node_rows(packed_clone.get_child(0)),"Incremental clone equals true PackedScene clone with shared immutable Resources")
	var cancelled: Dictionary={};var part:=target.create_step(cancelled,1,1);check(part.status=="pending","Cancellation fixture pauses during cloning")
	var weak:=weakref(cancelled.job.nodes[0]);Template.cancel_creation(cancelled);check(weak.get_ref()==null and cancelled.is_empty(),"Cancelling clone frees only its private detached graph")
	for instance in [first.instance,oracle,clone.instance,packed_clone]:instance.retire()
	var request: Dictionary={};var queued:=pool.model_template_step(input,request,1,1);check(queued.status=="pending" and request.has("template"),"Stream request API retains bounded caller-owned preparation")
	var source_weak:=weakref(request.template._build_progress.source);pool.cancel_template_step(request)
	check(request.is_empty() and source_weak.get_ref()==null and pool.native_draw_captures.is_empty(),"Stream retirement cancels preparation before CPU payload detachment")
	pool.clear()
func fallback_checks(input: Dictionary) -> void:
	var pool:=LocalPool.new();var template:=Template.new();check(template.begin_staged_build(input,pool),"Unsupported recipe fallback starts from ordinary owned source")
	var state: Dictionary={};var turns:=0
	while turns<512:
		state=template.staged_build_step(1,1);turns+=1
		if state.status!="pending":break
	check(state.status=="ready" and template.recipe==null and template.scene!=null and template.recipe_fallback_reason=="recipe-local-resource","Local-to-scene resources preserve explicit real PackedScene fallback")
	if state.status=="ready":
		var first=template.create();var second=template.create()
		check(first!=null and second!=null and first.meshes[0].material_override!=second.meshes[0].material_override,"Fallback preserves private local-to-scene material cloning")
		if first!=null:first.retire()
		if second!=null:second.retire()
	pool.clear()
func source_association_checks() -> void:
	var pool:=Pool.new();var bad:=bundle("d");var good:=bundle("e")
	bad.value.nodes[1].mesh.textures=["not-prepared"]
	var pending: Dictionary={};check(pool.model_template_step(bad,pending,1,1).status=="pending","Source A can fail after yielding rather than at begin")
	var active=pending.template;var key:=Template.identity(bad,pool)
	var reordered:=pool.model_template_step(good,pending,1,1)
	check(reordered.status=="pending" and reordered.active_key==key and pending.template==active,"Request B cannot receive pending A's future failure")
	var objects:=Objects.new();objects.pool=pool
	var row_a:={"model":"bad","bundle":bad,"placement":{"id":1}};var row_b:={"model":"good","bundle":good,"placement":{"id":2}}
	objects.queue=[row_b,row_a];objects._template_pending=pending;objects._template_entry=row_a
	check(objects.park_wave().is_empty() and pending.has("template") and pending.template==active,"Rejected park is side-effect free and retains staged progress")
	objects._resume_clone_head();check(is_same(objects.queue[0],row_a),"Object reprioritization pins the exact pending-template source row")
	var outcome: Dictionary={};var turns:=0
	while turns<512:
		outcome=pool.model_template_step(bad,pending,1,1);turns+=1
		if outcome.status!="pending":break
	check(outcome.status=="failed" and outcome.key==key and pending.is_empty(),"Delayed A failure remains associated with A after B priority reorder")
	objects._cancel_staged_publication();objects.queue.clear();objects.free()
	var next: Dictionary={};check(pool.model_template_step(good,next,1,1).status=="pending","B remains eligible after A failed")
	var area:=Area.new();area.pool=pool;var tile_a:={"model":"other","index":1};var tile_b:={"model":"good","index":2}
	area.publish_queue=[tile_a,tile_b];area._template_pending=next;area._template_entry=tile_b;area._resume_clone_head()
	check(is_same(area.publish_queue[0],tile_b),"Terrain reprioritization also pins the pending-template source row")
	area._cancel_staged_publication();area.publish_queue.clear();area.free();pool.clear()
func duplicate_request_checks(input: Dictionary) -> void:
	var pool:=Pool.new();var a: Dictionary={};var b: Dictionary={}
	check(pool.model_template_step(input,a,1,1).status=="pending" and pool.model_template_step(input,b,1,1).status=="pending" and a.template!=b.template,"Two independent streams can initially request the same uncached identity")
	pool.model_template_step(input,b,1,1);var redundant_source:=weakref(b.template._build_progress.source)
	var ready: Dictionary={};var turns:=0
	while turns<512:
		ready=pool.model_template_step(input,a,1,1);turns+=1
		if ready.status!="pending":break
	check(ready.status=="ready","First request publishes one complete cached template")
	var reused:=pool.model_template_step(input,b,1,1);var key:=Template.identity(input,pool)
	check(reused.status=="ready" and reused.template==ready.template and b.is_empty() and redundant_source.get_ref()==null,"Second yielded builder cancels private work and reuses the committed identity")
	check(pool.templates.size()==1 and pool.template_order.count(key)==1 and int(pool.stats.templates_created)==1 and pool.native_draw_captures.is_empty(),"Concurrent request completion preserves one cache binding, one LRU entry and no active capture")
	pool.clear()
func clone_retry_checks(input: Dictionary) -> void:
	var pool:=Pool.new();var a:=Template.new();var b:=Template.new()
	check(a.build(input,pool) and b.build(bundle("f"),pool),"Two immutable clone-owner fixtures build independently")
	var first=a.create();check(first!=null,"A transfers its first root before an incremental repeat")
	if first==null:pool.clear();return
	var wrong: Dictionary={};check(a.create_step(wrong,1,1).status=="pending","A clone can pause before B is requested")
	var weak:=weakref(wrong.job.nodes[0]);var original_b:=b._first_root
	var rejected:=b.create_step(wrong,1,1)
	check(rejected.status=="failed" and rejected.reason=="Native staged clone template changed" and wrong.is_empty() and weak.get_ref()==null,"Template B rejects and cancels A's foreign clone rather than wrapping its graph")
	check(b._first_root==original_b and b.first_instance_reuses==0,"Foreign pending work cannot consume B's first root")
	var objects:=Objects.new();objects.pool=pool
	var row_a:={"model":"a","base_template_hit":true,"placement":{"id":1}};var row_b:={"model":"b","placement":{"id":2}}
	objects.queue=[row_a,row_b];objects._clone_entry=row_a
	check(a.create_step(objects._clone_pending,1,1).status=="pending","Eviction/retry fixture retains private A clone")
	var retry_weak:=weakref(objects._clone_pending.job.nodes[0])
	# The stale-base-template branch invokes this before requesting retry and
	# continuing the same publication loop with a different queued object.
	objects._cancel_publication_row(row_a);objects.queue.pop_front()
	check(objects._clone_pending.is_empty() and objects._clone_entry.is_empty() and retry_weak.get_ref()==null,"Dropping/retrying A releases its private clone before the loop advances")
	var good:=b.create_step(objects._clone_pending,1,1)
	check(good.status=="ready" and good.instance.get_child(0)==original_b,"B consumes only its own correct first root after A's cache binding retry")
	if good.status=="ready":good.instance.retire()
	objects.queue.clear();objects._cancel_staged_publication();objects.free();first.retire();pool.clear()
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	check(Template.configured_recipe(),"Fixture explicitly selects existing recipe mode; ordinary packed default is unchanged")
	if failures.is_empty():
		var input:=bundle();instance_checks(input);capture_scope_checks();template_checks(input);fallback_checks(input);source_association_checks();duplicate_request_checks(input);clone_retry_checks(input)
	await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"maximum_returned_units":maximum_returned_units,"scope":"Prepared exact-before ModelInstance/PackedScene equivalence, private incremental graph ownership, capture interleaving and cancellation. Soft per-step scheduling cannot preempt one engine/GPU operation. No graphical/FPS claim."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close();print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
