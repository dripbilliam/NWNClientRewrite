extends SceneTree
const Emitter=preload("res://tests/nwn64_fog_emitter.gd")
const Probe=preload("res://tests/nwn64_fog_probe.gd")
const Fog=preload("res://systems/native_render/particle_stream_fog.gd")
const SurfaceState=preload("res://systems/native_render/native_surface_state.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
class Blocker:
	extends Node
	var failure:=""
	var calls:=0
	var retires:=0
	func ready() -> bool:calls+=1;return false
	func retire() -> void:retires+=1
var checks:=0
var failures: Array=[]
var cases: Array=[]
var optimized:=false
var camera: Camera3D
var emitter: Node3D
var source: Node3D
var owner: Node
var blocker: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL: ",label)
func one(label: String,expected_samples: int,expected_block: bool=true) -> void:
	var start:=Probe.samples;var blocks: int=blocker.calls;var before:=SurfaceState.snapshot();var state: Dictionary=emitter._state.duplicate(true)
	var elapsed: float=emitter.elapsed;var draws: int=emitter.rng.draws
	emitter._process(0.016)
	var actual:=Probe.samples-start
	check(actual==expected_samples,label+" actual Fog.sample calls")
	check(int(blocker.calls)-blocks==int(expected_block),label+" original chunk readiness boundary")
	check(emitter._state==state and emitter.elapsed==elapsed and emitter.rng.draws==draws and emitter.frames==0,label+" no simulation/RNG/clock work crosses blocked prefix")
	cases.append({"name":label,"samples":actual,"before":before,"after":SurfaceState.snapshot()})
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	optimized=args.get("optimized","")=="on"
	owner=Node.new();root.add_child(owner);source=Node3D.new();root.add_child(source)
	camera=Camera3D.new();camera.environment=Environment.new();camera.environment.fog_enabled=true;camera.environment.fog_light_color=Color(.125,.25,.75);camera.environment.fog_depth_begin=3;camera.environment.fog_depth_end=90;root.add_child(camera);camera.current=true
	emitter=Emitter.new();root.add_child(emitter);emitter.source=source;emitter._state={"chunkName":""};emitter.compiled_kernel=Kernel.enabled();emitter.native_surface_output=true;emitter.native_surface_world=weakref(owner)
	blocker=Blocker.new();emitter.add_child(blocker);emitter.chunk_models=blocker
	await process_frame
	check(Kernel.enabled() and Kernel.available(),"Accepted normal compiled particle kernel is selected")
	check(emitter.native_frame_group==null and emitter.native_stream_group==null,"Actual normal per-emitter callback, no optional shared rendering route")
	SurfaceState.bind(owner);SurfaceState.publish(owner,Vector3(.7,.2,.4),true,11,99,true)
	var authoritative_packet:=SurfaceState.packet(owner);one("authoritative area enabled",0 if optimized else 1)
	check(SurfaceState.packet(owner)==authoritative_packet and SurfaceState.authoritative(owner),"Area-owned enabled packet remains exact")
	SurfaceState.publish(owner,Vector3(.4,.3,.2),false,4,80,true);authoritative_packet=SurfaceState.packet(owner)
	one("authoritative area disabled",0 if optimized else 1)
	check(SurfaceState.packet(owner)==authoritative_packet and SurfaceState.authoritative(owner),"Disabled area fog remains authoritative")
	SurfaceState.bind(owner);one("bound owner before first area packet",1)
	check(not SurfaceState.authoritative(owner) and SurfaceState.packet(owner).size()==8,"Camera fallback still publishes complete packet")
	var fallback:=SurfaceState.packet(owner);one("camera-owned packet repeat",1)
	check(SurfaceState.packet(owner)==fallback,"Repeated camera fallback is byte-value stable")
	var successor:=Node.new();root.add_child(successor);SurfaceState.bind(successor);SurfaceState.publish(successor,Vector3(.9,.8,.7),true,8,120,true)
	var successor_packet:=SurfaceState.packet(successor);one("valid stale previous owner",1)
	SurfaceState.retire(owner);check(SurfaceState.packet(successor)==successor_packet,"Stale callback and retirement cannot overwrite successor")
	SurfaceState.bind(owner);SurfaceState.retire(owner);one("retired surface owner remains live Node",1)
	check(SurfaceState.snapshot().owner==0,"Retired binding is not republished by camera")
	var dead:=Node.new();root.add_child(dead);emitter.native_surface_world=weakref(dead);dead.free();one("freed weak owner",0)
	emitter.native_surface_world=null;one("absent weak owner",0)
	emitter.native_surface_world=weakref(owner);emitter.native_surface_output=false;one("ordinary surface mode",0);emitter.native_surface_output=true
	emitter.retired=true;one("retired emitter",0,false);emitter.retired=false
	emitter.particles_enabled=false;one("particles disabled",0,false);emitter.particles_enabled=true
	emitter.hide();one("hidden emitter",0,false);emitter.show()
	emitter._state={};one("empty particle state",0,false);emitter._state={"chunkName":""}
	emitter.failure="fixture guard";one("failed emitter guard",0,false);emitter.failure=""
	camera.clear_current();one("no active camera",0,false);camera.current=true
	SurfaceState.bind(owner);camera.environment.fog_enabled=false;one("camera fallback disabled fog",1)
	check(PackedFloat32Array(SurfaceState.packet(owner)).to_byte_array()==PackedFloat32Array([0,0,0,0,0,1,0,0]).to_byte_array(),"Disabled camera fallback keeps exact f32 packet and disabled reciprocal")
	SurfaceState.publish(owner,Vector3(.2,.3,.4),true,5,105,true);owner.queue_free();one("queued owner before destruction",0 if optimized else 1)
	await process_frame;one("owner after destruction",0)
	emitter.retire();check(emitter.retired and blocker.retires==1,"Original retirement still closes blocked chunk owner once")
	emitter.free();source.free();camera.free();successor.free()
	var report:={"issue":"NWN-64","success":failures.is_empty(),"checks":checks,"failures":failures,"optimized":optimized,"cases":cases,"sample_count":Probe.samples,"scope":"Actual complete particle_emitter.gd inherited tick/_process/retire. Only fixture setup overrides _ready; unready chunk owner stops after the real fog prefix. Private Fog.sample counter; no simulation/FPS inference, no optional shared-route selection."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("NWN64_FOG ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
