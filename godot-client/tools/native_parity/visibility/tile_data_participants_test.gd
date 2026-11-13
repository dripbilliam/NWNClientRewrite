extends SceneTree
const Resolver=preload("res://tools/native_parity/visibility/tile_data_participants.gd")
const Math=preload("res://tools/native_parity/visibility/bsp_collector.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<40:failures.append(label);print("FAIL ",label)
func ints(values: Array) -> Array:return values.map(func(v):return int(v))
func words(values: Array) -> Array:return values.map(func(v):return Math.word(v))
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
	var scope:={"connection":"native-one","area":"native-area","physical":"native-area-life"}
	var owner:=Resolver.new()
	if missing:
		check(not owner.configure(scope,func(_scope):return true,2,2,1,10).available,"Missing native kernel is explicitly unavailable")
		check(not owner.register_canonical(0,0,1,[1]).available,"Missing kernel cannot silently register a GDS traversal owner")
		check(not owner.collect_bound([0,0,0],[],{"hi":0,"lo":1}).available,"Missing kernel cannot collect")
		owner.close();finish(report,{"missing_kernel":true});return
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle))
	if corpus.get("binary_sha256")!="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a":quit(3);return
	var shape: Dictionary=corpus.area
	check(owner.configure(scope,func(_scope):return true,shape.width,shape.height,shape.margin,shape.cell).available,"Resolver binds existing proved kernel/tree to source area scope")
	check(not owner.configure(scope,func(_scope):return true,2,2,1,10).available,"Physical area resolver cannot be rebound")
	var reference:=Math.new();reference.build(shape.width,shape.height,shape.margin,shape.cell)
	var tree:=reference.export_tree();var order: Array=[];visit(tree.nodes,tree.root,order);var map: Dictionary={}
	for index in order.size():map[order[index]]=index
	for sample in corpus.setposition_cases:
		var input: Array=sample.input;var actual:=Resolver.tile_position(input[0],input[1],input[2],input[3])
		check(actual.available and words(actual.native_position)==ints(sample.position_words),"Original executed CNWTile::SetPosition f32 XYZ words")
	var state:={"sources":{},"parts":{},"source_mode":"idle","part_mode":"idle"};var registered: Dictionary={};var tile_lifetimes: Dictionary={}
	var source_guard:=func(context):
		if state.source_mode=="false":return false
		if state.source_mode=="string":return "true"
		return state.sources.get(context.key)==context.lifetime
	var part_guard:=func(context):
		if state.part_mode=="false":return false
		return state.parts.get(context.key+"/"+context.part_key)==context.part_lifetime
	for sample in corpus.registrations:
		var key: String=sample.key;var life: Array=["source",key,1];state.sources[key]=life.duplicate(true)
		var result: Dictionary
		if sample.kind=="canonical":result=owner.register_canonical(int(key.trim_prefix("terrain:")),sample.input[2],sample.input[3],life,source_guard)
		else:result=owner.register_spawn(key,life,sample.kind,sample.input,source_guard)
		check(result.available,"Original SpawnTile input registers physical association")
		if not result.available:continue
		registered[key]=result
		check(result.tile_token==int(sample.expected.token),"Original SpawnTile first-allocation physical pointer equivalence/order")
		check(result.allocated==sample.expected.allocated,"Original SpawnTile GetTileData reuse versus constructor allocation branch")
		check(map[result.node]==int(sample.expected.node),"Original radius0 fitted-node TileData ownership")
		check(words(result.native_position)==ints(sample.expected.position_words),"Source native XYZ is preserved separately from visual pose")
		check(words(result.native_anchor)==ints(sample.expected.tile_anchor_words),"Shared TileData keeps original first-allocation anchor")
		if tile_lifetimes.has(result.tile_token):check(result.tile_lifetime==tile_lifetimes[result.tile_token],"Shared physical pointer retains one TileData lifetime")
		else:tile_lifetimes[result.tile_token]=result.tile_lifetime.duplicate()
		check(int(sample.expected.constructor_fogged)==0 and int(sample.expected.constructor_factor_word)==Math.word(1.),"Original TileData constructor certifies reducer initialization source")
	for index in 4:
		check(owner.lookup_map(index).tile_token==registered["terrain:"+str(index)].tile_token,"Canonical map-index→physical token relation is independent and exact")
	check(owner.snapshot().tiles.size()==7,"Original12 registrations share exactly7 physical TileData")
	check(registered["outside-one"].tile_token==registered["outside-two"].tile_token and registered["outside-one"].canonical_indices.is_empty(),"Outside leaf sharing is preserved without clamping to canonical map indices")
	check(registered["above-one"].tile_token==registered["above-two"].tile_token and registered["above-one"].tile_token!=registered["terrain:0"].tile_token,"Native height boundary selects separate physical TileData")
	var leases: Dictionary={};var ancestor_cases:=0
	for sample in corpus.parts:
		var key: String=sample.placement;var life: Array=["source",key,1];var part_key: String=sample.label;var part_life: Array=["physical-part",key,part_key,1]
		state.parts[key+"/"+part_key]=part_life.duplicate(true)
		var mesh_node:=int(order[int(sample.mesh_node)])
		var result:=owner.bind_part(key,life,part_key,part_life,mesh_node,part_guard)
		check(result.available and result.tile_token==int(sample.part_tile_token),"Actual original ProcessStaticParts+a0 store assigns originating physical TileData")
		check(result.mesh_node==mesh_node and map[result.node]==int(sample.tile_node),"Original BSPFitBox mesh node is independent of owning TileData node")
		check(owner.association_current(result.association_lease),"Exact physical Part association lease is current")
		leases[key+"/"+part_key]=result.association_lease.duplicate(true)
		if sample.mesh_node!=sample.tile_node:ancestor_cases+=1
	check(ancestor_cases>0,"Original supplied-bounds corpus includes ancestor mesh nodes independent of TileData")
	check(owner.lookup_spawn("static-one",["source","static-one",1]).tile_token==owner.lookup_map(0).tile_token,"Received static SpawnTile shares original canonical TileData")
	var before:=owner.snapshot()
	check(owner.register_spawn("actor",["actor",1],"dynamic",[5,5,0]).associated==false and owner.snapshot()==before,"Dynamic actor remains explicitly unassociated/default1 without fake grid association")
	check(not owner.register_spawn("unknown",[1],"static",[5,5,0]).available and owner.snapshot()==before,"Unknown static source guard cannot manufacture association")
	check(not owner.register_canonical(4,0,1,[1]).available and not owner.register_canonical(0,0.5,1,[1]).available,"Invalid canonical index/height remain unavailable")
	check(not Resolver.tile_position(0,0,2147483647,1e38).available and not Resolver.tile_position(0,0,0,NAN).available,"Nonfinite SetPosition inputs/results rejected without guessed placement")
	var old_life: Array=["source","static-one",1];var token: int=registered["static-one"].tile_token;var tile_life: Array=registered["static-one"].tile_lifetime.duplicate()
	check(not owner.retire_placement("static-one",["source","static-one",0]),"Stale source retirement cannot erase current Part associations")
	check(owner.retire_part("static-one",old_life,"small",["physical-part","static-one","small",1]),"Visual Part retirement detaches only its own association lease")
	check(not owner.association_current(leases["static-one/small"]) and owner.association_current(leases["static-one/large"]),"Sibling physical Part remains valid after endpoint eviction")
	check(owner.tile_data(token,tile_life).available,"Visual retirement never destroys shared TileData")
	var new_life: Array=["source","static-one",2];state.sources["static-one"]=new_life.duplicate()
	var reused:=owner.register_spawn("static-one",new_life,"static",[15,15,0],source_guard)
	check(reused.available and not reused.allocated and reused.tile_token==registered["terrain:3"].tile_token,"Reused source ID selects existing new-position TileData through native lookup")
	check(not owner.association_current(leases["static-one/large"]) and not owner.retire_placement("static-one",old_life),"Old physical source/Part leases cannot retire reused-ID successor")
	check(owner.tile_data(token,tile_life).available and owner.lookup_map(0).tile_token==token,"Source ID reuse preserves old shared physical TileData/canonical mapping")
	check(not owner.register_spawn("static-one",new_life,"static",[5,5,0],source_guard).available,"Same physical SpawnTile input cannot be silently repositioned")
	var canonical_life: Array=["source","terrain:0",1]
	check(owner.retire_placement("terrain:0",canonical_life) and not owner.lookup_map(0).available,"Canonical source retirement removes only its map relation")
	check(owner.tile_data(token,tile_life).available and owner.association_current(leases["static-one-repeat/large"]),"Sharing static Part retains TileData when canonical placement retires")
	state.sources["terrain:0"]=["source","terrain:0",2]
	var canonical_again:=owner.register_canonical(0,0,1,state.sources["terrain:0"],source_guard)
	check(canonical_again.available and not canonical_again.allocated and canonical_again.tile_token==token,"New canonical placement reuses retained physical TileData; constructor init not repeated")
	var selected:=owner.lookup_spawn("terrain:1",["source","terrain:1",1]);selected.tile_lifetime[0]=-1;selected.native_anchor[0]=999;selected.placement_lease.lifetime[0]="mutated"
	check(owner.lookup_map(1).tile_lifetime==tile_lifetimes[registered["terrain:1"].tile_token] and owner.lookup_map(1).native_anchor[0]!=999,"Lookup diagnostics cannot mutate native ownership or endpoint lifetime")
	state.source_mode="false"
	check(not owner.lookup_spawn("static-one",new_life).available and not owner.association_current(leases["terrain:1/small"]),"Live source guard rejects retired source before an endpoint use")
	state.source_mode="string"
	check(not owner.lookup_map(1).available,"Truthy non-Boolean source guard does not certify ownership")
	state.source_mode="idle";state.part_mode="false"
	check(not owner.association_current(leases["terrain:1/small"]),"Actual endpoint lifetime guard can invalidate Part lease without mutating source TileData")
	state.part_mode="idle"
	var replacement_life: Array=["physical-part","terrain:1","small",2];state.parts["terrain:1/small"]=replacement_life.duplicate()
	var replacement:=owner.bind_part("terrain:1",["source","terrain:1",1],"small",replacement_life,null,part_guard)
	check(replacement.available and not owner.association_current(leases["terrain:1/small"]) and owner.association_current(replacement.association_lease),"Physical Part reuse invalidates old endpoint lease and preserves successor")
	check(not owner.retire_part("terrain:1",["source","terrain:1",1],"small",["physical-part","terrain:1","small",1]),"Stale endpoint removal cannot erase replacement Part")
	var collected:=owner.collect_bound([0,0,0],[],{"hi":0,"lo":16666})
	check(collected.available and Array(collected.tile_tokens).size()==7,"Existing kernel collects physical tokens, including outside and noncanonical TileData")
	check(not owner.collect_bound([0,0,0],[],{"lo":16666}).available and owner.association_current(replacement.association_lease),"Missing clock leaves old physical associations unchanged")
	var reentrant_state:={"mode":"idle","entered":false};var reentrant:=Resolver.new()
	check(reentrant.configure(scope,func(_scope):return true,2,2,1,10).available,"Separate reentry fixture binds proved kernel")
	var reentrant_source:=func(_context):
		if reentrant_state.mode=="retire":
			reentrant_state.mode="idle";reentrant.retire_placement("reentry",[1])
		return true
	reentrant.register_spawn("reentry",[1],"static",[5,5,0],reentrant_source)
	var reentrant_part:=reentrant.bind_part("reentry",[1],"mesh",[1],null,func(_context):return true)
	reentrant_state.mode="retire"
	check(not reentrant.association_current(reentrant_part.association_lease),"Source retirement reentry during endpoint validation rejects stale Part lease")
	check(reentrant.snapshot().tiles.size()==1 and reentrant.snapshot().placements==0,"Reentrant source retirement leaves independent TileData ownership intact")
	var close_state:={"close":false};var closing:=Resolver.new()
	var closing_guard:=func(_scope):
		if close_state.close:close_state.close=false;closing.close()
		return true
	closing.configure(scope,closing_guard,2,2,1,10)
	closing.register_canonical(0,0,1,[1]);close_state.close=true
	check(not closing.lookup_map(0).available,"Area retirement reentry rejects all stale lookup output")
	var reconnect:=Resolver.new();var next_scope:=scope.duplicate(true);next_scope.connection="native-two"
	reconnect.configure(next_scope,func(_scope):return true,2,2,1,10)
	var next:=reconnect.register_canonical(0,0,1,[1])
	check(next.tile_token==1 and next.tile_lifetime!=tile_life and not reconnect.association_current(replacement.association_lease),"Reconnection may reuse opaque integers but never physical TileData/Part lifetimes")
	owner.close();owner.close()
	check(not owner.tile_data(token,tile_life).available and not owner.association_current(replacement.association_lease),"Area close invalidates all physical token/Part leases")
	check(reconnect.lookup_map(0).available,"Old area close cannot retire successor area")
	reentrant.close();closing.close();reconnect.close()
	finish(report,{"native_registrations":corpus.registrations.size(),"native_physical_tiledata":tile_lifetimes.size(),"native_parts":corpus.parts.size(),"native_setposition":corpus.setposition_cases.size(),"ancestor_cases":ancestor_cases,"scope":"Original SpawnTile allocation/reuse slice + ctor/GetTileData/AddTileData + SetPosition words + ProcessStaticParts+a0 store and supplied native bounds BSPFitBox. Source/Part lifetime and reentry fences; no shader writes, production hookup, GPU, server or FPS claim."})
func finish(report: String,details: Dictionary) -> void:
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"details":details},"  "))
	print("NATIVE_TILE_DATA_PARTICIPANTS ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
