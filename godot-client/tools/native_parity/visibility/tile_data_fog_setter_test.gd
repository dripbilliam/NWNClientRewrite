extends SceneTree
const Resolver=preload("res://tools/native_parity/visibility/tile_data_fog_setter.gd")
const Math=preload("res://tools/native_parity/visibility/bsp_collector.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<40:failures.append(label);print("FAIL ",label)
func visit(nodes: Array,node: int,order: Array) -> void:
	if node<0:return
	order.append(node);visit(nodes,int(nodes[node].negative),order);visit(nodes,int(nodes[node].positive),order)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var report:="";var oracle:="";var missing:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		elif arg.begins_with("--oracle="):oracle=arg.substr(9)
		elif arg=="--kernel-absent":missing=true
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var scope:={"connection":"setter-one","area":"original-area","physical":"original-physical-area"};var owner:=Resolver.new()
	if missing:
		check(not owner.configure(scope,func(_scope):return true,2,2,1,10).available,"Missing kernel cannot establish authentic shared tree ownership")
		check(not owner.resolve_fog_setter([5,5,0]).available,"Missing source/kernel stays unavailable/default1")
		owner.close();finish(report,{"missing_kernel":true});return
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle))
	if corpus.get("binary_sha256")!="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a":quit(3);return
	check(owner.configure(scope,func(_scope):return true,2,2,1,10).available,"Successor uses frozen physical resolver and existing approved kernel")
	var empty:=owner.resolve_fog_setter([5,5,0])
	check(not empty.available and empty.default_factor==1.,"Empty physical membership has no invented setter target")
	var reference:=Math.new();reference.build(2,2,1,10);var tree:=reference.export_tree();var order: Array=[];visit(tree.nodes,tree.root,order);var map: Dictionary={}
	for index in order.size():map[order[index]]=index
	var lifetimes: Dictionary={}
	for index in corpus.placements.size():
		var original: Dictionary=corpus.placements[index];var result: Dictionary
		if index<2:result=owner.register_canonical(index,0,1,["original",original.key])
		else:result=owner.register_spawn(original.key,["original",original.key],"border",original.point,func(_context):return true)
		check(result.available and result.tile_token==int(original.expected.token),"Original controlled setter Scene physical TileData allocation order")
		check(map[result.node]==int(original.expected.node),"Independent native GetTileData placement node remains unchanged")
		lifetimes[result.tile_token]=result.tile_lifetime.duplicate()
	var native_setters:=0
	for sample in corpus.setter_cases:
		for operation in sample.trace:
			if operation.kind!="set_fogged":continue
			var target:=owner.resolve_fog_setter(operation.position)
			check(target.available,"Actual full native AuroraSetTileFoggedByWar input resolves")
			check(target.tile_token==int(operation.target_token),"Original native BSPSearch/predicate physical target pointer equivalence")
			check(map[target.node]==int(operation.target_node),"Original native setter target node, independently of radius0 fit")
			check(target.tile_lifetime==lifetimes[target.tile_token],"Search returns existing physical TileData lifetime, never a new target allocation")
			check(target.search=="BSPSearch229980/predicate0a5100" and target.visited_nodes>0,"Authentic search provenance remains explicit")
			check(owner.setter_target_current(target.setter_lease),"Fresh setter target lease validates exact current scope/membership")
			native_setters+=1
	var equality:=owner.resolve_fog_setter([10,5,0]);var radius0:=owner.register_spawn("equality-spawn",[1],"static",[10,5,0],func(_context):return true)
	check(equality.tile_token==2 and radius0.tile_token==1,"Native positive-equality setter search remains separate from negative-equality radius0 placement")
	check(owner.resolve_fog_setter([5,15,0]).tile_token==1,"Native missing-near TileData searches far subtree in exact order")
	check(owner.resolve_fog_setter([-10,5,0]).tile_token==3,"Original outside search result is not clamped to a canonical index")
	var initial_tiles: int=owner.snapshot().tiles.size();var saved_life: Array=lifetimes[1].duplicate()
	check(owner.retire_placement("terrain:0",["original","canonical-one"]),"Explicit canonical source retirement retires only its relation")
	check(not owner.lookup_map(0).available and owner.resolve_fog_setter([5,5,0]).tile_token==1,"Area-owned TileData remains searchable after source/visual eviction")
	check(owner.snapshot().tiles.size()==initial_tiles and owner.tile_data(1,saved_life).available,"Setter search never allocates or destroys physical membership")
	var reused:=owner.register_spawn("equality-spawn",[2],"static",[5,15,0],func(_context):return true)
	check(reused.available and reused.allocated and reused.tile_token==4,"Received source ID reuse allocates only genuinely empty native fitted node")
	check(not owner.setter_target_current(equality.setter_lease),"Membership/source revision rejects a previously returned queued setter lease")
	check(owner.resolve_fog_setter([5,15,0]).tile_token==4,"Search observes current inherited membership after cold registration")
	check(not owner.retire_placement("equality-spawn",[1]) and owner.resolve_fog_setter([5,15,0]).tile_token==4,"Stale source retirement cannot erase successor search target")
	check(owner.resolve_fog_setter([5,5,0]).tile_token==1,"Reused source does not move or erase an existing physical TileData")
	var part:=owner.bind_part("equality-spawn",[2],"mesh",["part",1],null,func(_context):return true)
	check(part.available and owner.association_current(part.association_lease),"Successor preserves physical Part/endpoint lease API")
	check(owner.retire_part("equality-spawn",[2],"mesh",["part",1]) and not owner.association_current(part.association_lease) and owner.resolve_fog_setter([5,15,0]).tile_token==4,"Part eviction invalidates endpoint lease without changing setter target")
	var diagnostic:=owner.resolve_fog_setter([5,15,0]);diagnostic.tile_lifetime[0]=-1;diagnostic.native_anchor[0]=999;diagnostic.native_setter_position[0]=999
	check(owner.resolve_fog_setter([5,15,0]).native_anchor[0]==5 and owner.resolve_fog_setter([5,15,0]).tile_lifetime[0]!=-1,"Detached search output cannot mutate physical scope, anchor or query position")
	diagnostic.setter_lease.tile_lifetime[0]=-1
	check(not owner.setter_target_current(diagnostic.setter_lease) and not owner.setter_target_current({}),"Altered or missing target lease cannot certify a write")
	check(not owner.resolve_fog_setter([NAN,0,0]).available and not owner.resolve_fog_setter([5,5]).available,"Unproven native setter position remains unavailable")
	var before:=owner.snapshot();var dynamic:=owner.register_spawn("actor",[1],"dynamic",[5,5,0])
	check(dynamic.available and not dynamic.associated and owner.snapshot()==before,"Search successor never associates dynamic actors to grid fog")
	var guard_state:={"mode":"idle","calls":0,"nested":false,"nested_ok":false};var reentrant:=Resolver.new()
	var guard:=func(_scope):
		guard_state.calls+=1
		if guard_state.mode=="nested" and not guard_state.nested:
			guard_state.nested=true;guard_state.nested_ok=reentrant.resolve_fog_setter([5,5,0]).available;guard_state.nested=false
		elif guard_state.mode=="register" and guard_state.calls==2:
			guard_state.mode="idle";reentrant.register_spawn("new-source",[1],"static",[15,15,0],func(_context):return true)
		elif guard_state.mode=="close" and guard_state.calls==2:
			guard_state.mode="idle";reentrant.close()
		return true
	reentrant.configure(scope,guard,2,2,1,10);reentrant.register_canonical(0,0,1,[1])
	guard_state.mode="nested";guard_state.calls=0
	check(reentrant.resolve_fog_setter([5,5,0]).available and guard_state.nested_ok,"Nested lookup uses independent stack and detached outputs")
	guard_state.mode="register";guard_state.calls=0
	check(not reentrant.resolve_fog_setter([5,5,0]).available,"Membership mutation during post-search source guard rejects stale result")
	check(reentrant.resolve_fog_setter([15,15,0]).tile_token==2,"Next search sees exact newly registered physical membership")
	guard_state.mode="close";guard_state.calls=0
	check(not reentrant.resolve_fog_setter([5,5,0]).available,"Area retirement during post-search source guard rejects target")
	var next:=Resolver.new();var next_scope:=scope.duplicate(true);next_scope.connection="setter-two"
	next.configure(next_scope,func(_scope):return true,2,2,1,10);next.register_canonical(0,0,1,[1])
	check(next.resolve_fog_setter([5,5,0]).tile_token==1 and next.resolve_fog_setter([5,5,0]).tile_lifetime!=saved_life,"Connection reuse of opaque integer token never reuses physical lifetime")
	owner.close();owner.close()
	check(not owner.resolve_fog_setter([5,5,0]).available and not next.setter_target_current(equality.setter_lease) and next.resolve_fog_setter([5,5,0]).available,"Old area close cannot affect successor cached tree or membership")
	# A bounded CPU-only diagnostic reports both normal populated lookup and
	# sparse far-fallback cost. Neither is an FPS or production activation claim.
	var measured:=Resolver.new();measured.configure(scope,func(_scope):return true,32,32,5,10);measured.register_canonical(0,0,1,[1])
	var sparse_samples: Array=[];var sparse_visited:=0
	for repeat_index in 3:
		var began:=Time.get_ticks_usec();var target:=measured.resolve_fog_setter([315,315,0]);sparse_samples.append(Time.get_ticks_usec()-began);sparse_visited=int(target.visited_nodes)
	for index in 1024:
		if index>0:measured.register_canonical(index,0,1,[index+1])
	var populated_samples: Array=[];var populated_visited:=0
	for repeat_index in 9:
		var began:=Time.get_ticks_usec();var target:=measured.resolve_fog_setter([315,315,0]);populated_samples.append(Time.get_ticks_usec()-began);populated_visited=int(target.visited_nodes)
	sparse_samples.sort();populated_samples.sort();measured.close();reentrant.close();next.close()
	finish(report,{"native_setter_sequences":corpus.setter_cases.size(),"native_target_checks":native_setters,"scope":"Actual native setter/search/predicate target oracle, independent of radius0 placement. Scope/membership/lifetime/reentry tests. No fog state/shader writes/production/GPU/server/FPS claim.","measurement":{"sparse_samples_us":sparse_samples,"sparse_visited":sparse_visited,"populated_samples_us":populated_samples,"populated_visited":populated_visited,"scope":"CPU-only32x32 margin5 cached immutable tree; one versus1024 current physical TileData memberships. Native traversal order, no empty-subtree optimization."}})
func finish(report: String,details: Dictionary) -> void:
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"details":details},"  "))
	print("NATIVE_TILE_DATA_FOG_SETTER ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
