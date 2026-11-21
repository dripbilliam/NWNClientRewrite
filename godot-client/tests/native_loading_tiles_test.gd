extends SceneTree
const Setup=preload("res://systems/native_data/session_catalog.gd")
const Model=preload("res://systems/native_data/binary_model.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Instance=preload("res://systems/native_render/model_instance.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
class Inspector:
	extends Model
	var headers: Array=[]
	func read_mesh(at: int) -> Dictionary:
		headers.append({"at":at,"vertices":reader.u16(at+448),"faces":reader.u32(at+12),"textures":reader.u16(at+450),"draws":reader.u32(at+420)})
		return super.read_mesh(at)
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var mounted:=Setup.prepare(JSON.parse_string(FileAccess.get_file_as_string(args.source)))
	check(str(mounted.error).is_empty(),"Cached server resource catalog mounts locally")
	var service:=Assets.new(); root.add_child(service); service.configure(mounted.catalog)
	var pool:=Pool.new(); var received: Array=[]; var observations: Array=[]
	service.completed.connect(func(_id,result):received.append(result))
	for name in ["ttu01_v13_01","ttu01_o17_01"]:
		var bytes: PackedByteArray=mounted.catalog.get_resource(name,2002); var parser:=Inspector.new(); var value:=parser.parse(bytes)
		check(parser.failure.is_empty() and not value.is_empty(),"Previously rejected tile parses: "+name)
		check(value.get("nodes",[]).size()==(16 if name=="ttu01_v13_01" else 17),"All original physical nodes are retained: "+name)
		var empty: Array=parser.headers.filter(func(row):return row.vertices==0 and row.faces==0 and row.textures==0 and row.draws==0)
		check(not empty.is_empty(),"Fixture contains an actual empty serialized mesh")
		if empty.is_empty(): continue
		for mode in [0,3,72,98,208,255]:
			var changed:=bytes.duplicate(); changed.encode_u8(int(empty[0].at)+436,mode); var decoder:=Model.new(); var decoded:=decoder.parse(changed)
			check(decoder.failure.is_empty() and decoded.get("nodes",[]).size()==value.nodes.size(),"Unused mode on empty mesh retains node: "+str(mode))
		var nonempty: Array=parser.headers.filter(func(row):return row.vertices>0 and row.faces>0)
		check(not nonempty.is_empty(),"Fixture also contains drawn geometry")
		if not nonempty.is_empty():
			var at:=int(nonempty[0].at); var changed:=bytes.duplicate(); changed.encode_u8(at+436,208); var decoder:=Model.new(); decoder.parse(changed)
			check(not decoder.failure.is_empty(),"Nonempty unsupported primitive mode is still rejected")
			changed=bytes.duplicate(); var face:=12+int(changed.decode_u32(at+8)); changed.encode_u16(face+26,int(nonempty[0].vertices)); decoder=Model.new(); decoder.parse(changed)
			check(decoder.failure.contains("index exceeds"),"Out-of-range geometry indices are still rejected")
		var truncated:=Model.new(); truncated.parse(bytes.slice(0,bytes.size()-1)); check(not truncated.failure.is_empty(),"Truncated model payload is rejected")
		service.request(name,2002,"static-model"); var deadline:=Time.get_ticks_msec()+30000
		while received.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
		check(not received.is_empty(),"Worker preparation completes")
		if received.is_empty(): continue
		var result: Dictionary=received.pop_front()
		check(str(result.error).is_empty() and int(result.thread)!=OS.get_main_thread_id(),"Actual model and texture preparation succeeds off the main thread")
		if not str(result.error).is_empty(): continue
		var model:=Instance.new(); root.add_child(model)
		check(model.install(result,pool) and not model.meshes.is_empty(),"Native tile geometry publishes successfully")
		observations.append({"name":name,"nodes":value.nodes.size(),"meshes":model.meshes.size(),"sha256":result.sha256})
		model.retire(); await process_frame
	service.close(); pool.clear(); service.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"models":observations,"network":false,"scope":"Original cached tiles plus in-memory malformed variants; native worker and geometry publication"},"  ")+"\n"); quit(0 if failures.is_empty() else 1)
