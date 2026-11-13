extends "res://tests/native_bsp_collector_test.gd"
const Adapter=preload("res://tools/native_parity/visibility/bsp_collector_kernel.gd")
class Facade:
	extends RefCounted
	var adapter:=Adapter.new()
	var scope:={"connection":"oracle","area":"immutable","physical":"area-1"}
	func _init():adapter.bind_scope(scope,func(_scope):return true)
	func build(w,h,m,c) -> Dictionary:return adapter.build(w,h,m,c)
	func bind_tile(tile,position) -> Dictionary:return adapter.bind_tile(tile,position,"original-physical-"+str(tile))
	func tile_at(position) -> Dictionary:return adapter.tile_at(position)
	func export_tree() -> Dictionary:return adapter.export_tree()
	func collect(camera,planes) -> Dictionary:
		var result:=adapter.collect_bound(scope,camera,planes,{"hi":0,"lo":16666})
		if not result.available:return result
		return {"available":true,"node_indices":Array(result.node_ids),"plane_counts":Array(result.plane_counts),"tiles":Array(result.tile_tokens),"tile_nodes":Array(result.tile_nodes)}

func new_owner():return Facade.new()
func measurement_scope() -> String:return "Headless isolated separate native POD kernel + GDS gather + test-only unpacking, cached32x32 margin5 tree. No scene/GPU/server/FPS claim."
func invoke(input: Array,camera: Vector3=Vector3.ZERO,planes: PackedFloat32Array=PackedFloat32Array(),low: int=16666) -> Dictionary:
	return ClassDB.class_call_static(&"NwnBspCollector",&"collect",input[0],input[1],input[2],input[3],input[4],input[5],camera,planes,low)
func additional_checks() -> Dictionary:
	var scope:={"connection":"one","area":"area","physical":"area-physical-one"};var adapter:=Adapter.new()
	check(Adapter.kernel_available(),"Separate native kernel is required and loaded")
	check(not adapter.bind_scope(scope,Callable()).available,"Missing source scope guard rejected")
	check(adapter.bind_scope(scope,func(_scope):return true).available,"Explicit source-owned scope accepted")
	check(not adapter.bind_scope(scope,func(_scope):return true).available,"Open owner cannot be rebound to a different source")
	check(adapter.build(2,2,1,10).available,"Adapter cold immutable tree pack succeeds")
	check(not adapter.bind_tile(7,[5,5,0],"").available,"Physical tile lifetime cannot be omitted")
	check(adapter.bind_tile(7,[5,5,0],"physical-a").available and adapter.bind_tile(7,[15,15,0],"physical-a").available,"One physical TileData can occupy multiple native nodes")
	var collected:=adapter.collect_bound(scope,[0,0,0],[],{"hi":0,"lo":16666})
	check(Array(collected.tile_tokens).count(7)==2,"Duplicate TileData occurrences preserved without dedup")
	check(adapter.bind_tile(7,[5,15,0],"physical-b").available,"Same tile ID can be replaced with new physical lifetime")
	collected=adapter.collect_bound(scope,[0,0,0],[],{"hi":0,"lo":16666})
	check(Array(collected.tile_tokens).count(7)==1,"Physical ID reuse retires both previous memberships")
	check(not adapter.retire_tile(7,"physical-a"),"Stale physical retirement rejected")
	check(adapter.bind_tile(8,[5,15,0],"physical-c").available and adapter.retire_tile(7,"physical-b"),"Node successor can replace and retire predecessor independently")
	collected=adapter.collect_bound(scope,[0,0,0],[],{"hi":0,"lo":16666})
	check(Array(collected.tile_tokens)==[8],"Retiring displaced owner never clears successor membership")
	collected.node_ids[0]=-99;collected.tile_tokens[0]=-99
	var repeated:=adapter.collect_bound(scope,[0,0,0],[],{"hi":0,"lo":16666})
	check(repeated.node_ids[0]>=0 and Array(repeated.tile_tokens)==[8],"Returned callback arrays do not alias cached inputs or later results")
	var packed:=adapter.packed_input();var valid:=invoke(packed)
	check(valid.available,"Packed detached diagnostic vector runs independently")
	packed[4].fill(-1)
	check(Array(adapter.collect_bound(scope,[0,0,0],[],{"hi":0,"lo":16666}).tile_tokens)==[8],"Detached packed diagnostics cannot erase live membership")
	packed=adapter.packed_input();packed[1][int(packed[5])*3+1]=packed[5]
	check(not invoke(packed).available,"Malformed cycle rejected within bounded native kernel")
	packed=adapter.packed_input();packed[1][1]=999999
	check(not invoke(packed).available,"Out-of-range topology rejected before native traversal")
	packed=adapter.packed_input();packed[0][0]=NAN
	check(not invoke(packed).available,"Nonfinite split rejected")
	packed=adapter.packed_input();packed[2].append(1.)
	check(not invoke(packed).available,"Malformed vertex packing rejected")
	packed=adapter.packed_input();packed[3][1]=999999
	check(not invoke(packed).available,"Out-of-range vertex range rejected")
	packed=adapter.packed_input();packed[4][0]=-2
	check(not invoke(packed).available,"Invalid tile sentinel rejected")
	packed=adapter.packed_input()
	check(not invoke(packed,Vector3(INF,0,0)).available,"Native camera finite validation is independent of adapter")
	check(not invoke(packed,Vector3.ZERO,PackedFloat32Array([0,0,0,INF])).available,"Native frustum finite validation is independent of adapter")
	check(not invoke(packed,Vector3.ZERO,PackedFloat32Array(),-1).available,"Native snapshot low word must be explicit unsigned32")
	var dag: Array=[PackedFloat32Array([1,0,0,0,0,0,0,0]),PackedInt32Array([0,1,1,2,-1,-1]),PackedFloat32Array(),PackedInt32Array([0,0,0,0]),PackedInt64Array([-1,3]),0]
	var duplicate:=invoke(dag)
	check(duplicate.available and Array(duplicate.node_ids)==[0,1,1] and Array(duplicate.tile_tokens)==[3,3],"Shared-child callback occurrences preserve order and multiplicity")
	var bounded: Array=[PackedFloat32Array(),PackedInt32Array(),PackedFloat32Array(),PackedInt32Array(),PackedInt64Array(),0]
	for index in 131:
		bounded[0].append_array(PackedFloat32Array([1,0,0,0]));bounded[1].append_array(PackedInt32Array([0,index+1 if index<130 else -1,-1]));bounded[3].append_array(PackedInt32Array([0,0]));bounded[4].append(-1)
	check(not invoke(bounded).available,"Over-deep input rejected before unbounded native stack use")
	bounded=[PackedFloat32Array(),PackedInt32Array(),PackedFloat32Array(),PackedInt32Array(),PackedInt64Array(),0]
	for index in 22:
		var child:=index+1 if index<21 else -1
		bounded[0].append_array(PackedFloat32Array([1,0,0,0]));bounded[1].append_array(PackedInt32Array([0,child,child]));bounded[3].append_array(PackedInt32Array([0,0]));bounded[4].append(-1)
	check(not invoke(bounded).available,"Exponential duplicate DAG hits explicit callback bound without deduplication")
	var corpus_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--oracle="):corpus_path=arg.substr(9)
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(corpus_path))
	for delta in corpus.deltas:check(invoke(adapter.packed_input(),Vector3.ZERO,PackedFloat32Array(),int(delta.lo)).delta_t_word==int(delta.delta_t_word),"Native kernel matches original signed-low32 CVTDQ2PS/DIVSS word")
	check(not adapter.collect_bound({"connection":"old"},[0,0,0],[],{"hi":0,"lo":0}).available,"Previous connection/area scope rejected")
	check(not adapter.collect_bound(scope,[0,0,0],[],{"lo":0}).available,"Missing snapshot high word remains unavailable")
	var before:=adapter.export_tree()
	check(not adapter.build(65536,65536,5,10).available and adapter.export_tree()==before,"Kernel adapter invalid rebuild preserves immutable tree and memberships")
	adapter.close()
	check(not adapter.collect_bound(scope,[0,0,0],[],{"hi":0,"lo":0}).available,"Retired owner cannot publish callbacks")
	var reconnect:=Adapter.new();var next_scope:=scope.duplicate(true);next_scope.connection="two"
	check(reconnect.bind_scope(next_scope,func(_scope):return true).available and reconnect.build(2,2,1,10).available,"New connection creates independent tree owner")
	reconnect.bind_tile(8,[5,15,0],"physical-new");adapter.close()
	check(Array(reconnect.collect_bound(next_scope,[0,0,0],[],{"hi":0,"lo":0}).tile_tokens)==[8],"Old connection close cannot retire same-ID successor")
	var state:={"mode":"idle","calls":0,"nested":false,"nested_ok":false};var reentrant:=Adapter.new()
	reentrant.bind_scope(scope,func(_scope):
		state.calls+=1
		if state.mode=="close" and state.calls==2:reentrant.close()
		elif state.mode=="nested" and not state.nested:
			state.nested=true;state.nested_ok=reentrant.collect_bound(scope,[0,0,0],[],{"hi":0,"lo":1}).available;state.nested=false
		elif state.mode=="replace" and state.calls==2:
			state.mode="idle";reentrant.bind_tile(4,[5,5,0],"replacement")
		return true)
	reentrant.build(1,1,1,10);reentrant.bind_tile(3,[5,5,0],"initial")
	state.mode="nested";state.calls=0
	check(reentrant.collect_bound(scope,[0,0,0],[],{"hi":0,"lo":1}).available and state.nested_ok,"Synchronous nested collection retains detached independent POD outputs")
	state.mode="replace";state.calls=0
	check(not reentrant.collect_bound(scope,[0,0,0],[],{"hi":0,"lo":1}).available,"Physical replacement during publication guard rejects stale result")
	state.mode="close";state.calls=0
	check(not reentrant.collect_bound(scope,[0,0,0],[],{"hi":0,"lo":1}).available,"Scope retirement during publication guard rejects result")
	# Full adapter measurement includes camera6planes construction and every
	# scope/finite check, packing, native validation/traversal and publication.
	var measured:=Facade.new();measured.build(32,32,5,10)
	for y in 32:
		for x in 32:measured.bind_tile(y*32+x,[x*10.+5,y*10.+5,0])
	var camera: Dictionary=corpus.cases[0].cameras[0].camera.duplicate(true);camera.position=[160.,160.,150.];camera.half_tangent_word=int(corpus.cases[0].cameras[0].half_tangent_word);camera.half_tangent_angle_word=Collector.word(camera.angle)
	var samples: Array=[];var phase_samples: Array=[]
	for repeat_index in 31:
		var started:=Time.get_ticks_usec();var output:=measured.adapter.collect_camera(measured.scope,camera,{"hi":0,"lo":16666});var elapsed:=Time.get_ticks_usec()-started
		check(output.available,"Measured full camera adapter collection succeeds")
		samples.append(elapsed);phase_samples.append(measured.adapter.cost())
	samples.sort();reconnect.close();reentrant.close();measured.adapter.close()
	return {"full_camera_gather_and_kernel_samples_us":samples,"median_us":samples[15],"phases":phase_samples,"scope":"Bounded headless32x32 margin5 immutable tree, cached native SSE tangent word. Includes source camera6plane math + checks + gather + separate POD kernel validation/traversal + detached outputs. CPU cost only, no GPU/server or FPS claim."}
