extends SceneTree
const Collector=preload("res://tools/native_parity/visibility/bsp_collector.gd")
var checks:=0
var failures: Array=[]
func new_owner():return Collector.new()
func additional_checks() -> Dictionary:return {}
func measurement_scope() -> String:return "Headless isolated GDS POD collector32x32, margin5, one supplied camera; same constructed cached tree. No scene/GPU/server/FPS claim."
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<40:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func words(value: Array) -> Array:return value.map(func(v):return Collector.word(float(v)))
func ints(value: Array) -> Array:return value.map(func(v):return int(v))
func visit(nodes: Array,index: int,order: Array) -> void:
	if index<0:return
	order.append(index);visit(nodes,int(nodes[index].negative),order);visit(nodes,int(nodes[index].positive),order)
func canonical(tree: Dictionary) -> Dictionary:
	var order: Array=[];visit(tree.nodes,int(tree.root),order);var map: Dictionary={}
	for index in order.size():map[order[index]]=index
	var result: Array=[]
	for id in order:
		var n: Dictionary=tree.nodes[id]
		result.append({"plane":words(n.plane),"leaf":int(n.leaf),"negative":map.get(n.negative,-1),"positive":map.get(n.positive,-1),"low":words(n.low),"high":words(n.high),"vertices":n.vertices.map(func(v):return words(v))})
	return {"nodes":result,"map":map}
func run() -> void:
	var output:="";var input:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		elif arg.begins_with("--oracle="):input=arg.substr(9)
	if output.is_empty() or input.is_empty() or FileAccess.file_exists(output):quit(2);return
	var corpus: Variant=JSON.parse_string(FileAccess.get_file_as_string(input))
	if not corpus is Dictionary or corpus.get("binary_sha256")!="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a":quit(3);return
	var cases:=0;var nodes:=0;var traversals:=0;var cameras:=0
	for original in corpus.cases:
		var owner=new_owner();var value: Dictionary=original.input
		check(owner.build(value.width,value.height,value.margin,value.cell).available,"Native InitBSP source inputs build")
		check(owner.build(value.width,value.height,value.margin,value.cell).cached,"Immutable native area tree is reused without construction on repeated lookup")
		var built:=canonical(owner.export_tree());var same_count: bool=built.nodes.size()==original.tree.size()
		check(same_count,"Original executed native node count")
		if not same_count:continue
		for index in original.tree.size():
			var actual: Dictionary=built.nodes[index];var expected: Dictionary=original.tree[index]
			for key in ["plane","low","high"]:check(actual[key]==ints(expected[key]),"Original native exact f32 node "+str(index)+" "+key)
			for key in ["leaf","negative","positive"]:check(actual[key]==int(expected[key]),"Original native topology "+str(index)+" "+key)
			var vertices: Array=expected.vertices.map(func(v):return ints(v))
			check(actual.vertices==vertices,"Original native split vertex order "+str(index))
		for binding in original.bindings:
			var bound: Dictionary=owner.bind_tile(int(binding.tile),binding.position)
			check(bound.available and built.map[bound.node]==int(binding.node),"Original SceneBSPAddTileData radius0 node mapping")
		for alias in original.get("aliases",[]):owner.bind_tile(int(alias.tile),alias.position)
		for fit in original.get("fits",[]):check(built.map[owner.tile_at(fit.position).node]==int(fit.node),"Original radius0 exact split/outer-boundary equality")
		for camera in original.cameras:
			var request: Dictionary=camera.camera.duplicate(true)
			if request.angle>0:request.half_tangent_word=int(camera.half_tangent_word);request.half_tangent_angle_word=Collector.word(request.angle)
			var planes:=Collector.camera_planes(request)
			check(planes.available,"Native source camera has explicit required projection/transform lowers")
			if planes.available:
				for index in 6:check(words(planes.planes[index])==ints(camera.plane_words[index]),"Original executed camera plane f32 words "+str(index))
			cameras+=1
		for traversal in original.collections:
			var collected: Dictionary=owner.collect(traversal.camera,traversal.planes)
			check(collected.available,"Exact native volume input accepted")
			if not collected.available:continue
			check(collected.node_indices.map(func(id):return built.map[id])==ints(traversal.nodes),"Original callback occurrence order including zero-plane far-first fallback")
			check(collected.plane_counts==ints(traversal.plane_counts),"Original reduced plane-count delivery at every callback")
			check(collected.tiles==ints(traversal.tiles),"Original exact TileData occurrence list without mesh cull or deduplication")
			traversals+=1
		var before: Dictionary=owner.export_tree();var detached: Dictionary=owner.export_tree();detached.nodes[0].plane[0]=99
		check(owner.export_tree()==before,"Diagnostics cannot mutate native tree/tile bindings")
		check(not owner.build(65536,65536,5,10).available and owner.export_tree()==before,"Bounded tree capacity leaves existing native cache unchanged")
		check(not owner.collect([NAN,0,0],[]).available and not owner.collect([0,0,0],[[0,0,0,INF]]).available,"Unproven nonfinite camera/plane inputs remain unavailable")
		cases+=1;nodes+=original.tree.size()
	for original in corpus.deltas:
		var delta:=Collector.renderer_delta_t({"hi":original.hi,"lo":original.lo})
		check(delta.available and Collector.word(delta.delta_t)==int(original.delta_t_word),"Original renderer signed-low32 CVTDQ2PS/DIVSS snapshot conversion")
	check(not Collector.renderer_delta_t({"lo":1}).available,"Missing primary snapshot word is never a guessed clock")
	check(not Collector.camera_planes({"position":[0,0,0],"quaternion_wxyz":[1,0,0,0],"angle":45,"aspect":1,"near":.1,"far":100}).available,"Missing native tangent lower never silently uses host/Godot tan")
	var measurement=new_owner();measurement.build(32,32,5,10)
	for y in 32:
		for x in 32:measurement.bind_tile(y*32+x,[float(x*10+5),float(y*10+5),0.])
	var camera: Dictionary=corpus.cases[0].cameras[0].camera.duplicate(true);camera.position=[160.,160.,150.];camera.half_tangent_word=int(corpus.cases[0].cameras[0].half_tangent_word);camera.half_tangent_angle_word=Collector.word(camera.angle)
	var planes:=Collector.camera_planes(camera);var samples: Array=[];var count:=0
	if planes.available:
		for repeat_index in 9:
			var started:=Time.get_ticks_usec();var collection: Dictionary=measurement.collect(camera.position,planes.planes);samples.append(Time.get_ticks_usec()-started);count=collection.node_indices.size()
		samples.sort()
	var supplemental:=additional_checks()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"original_cases":cases,"original_nodes":nodes,"original_traversals":traversals,"original_cameras":cameras,"supplemental":supplemental,"measurement":{"scope":measurement_scope(),"samples_us":samples,"median_us":samples[4] if samples.size()==9 else null,"collected_nodes":count},"scope":"Differential exact original Unicorn-executed InitBSP/grid/node layout/TileData fitting/volume and ordered traversal/camera6planes/rendererDeltaT instructions. Allocator/API-only oracle captures. Native tangent words supplied from original SSE math branch; AVX/FMA lower and production render scheduling remain explicit."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("NATIVE_BSP_COLLECTOR ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
