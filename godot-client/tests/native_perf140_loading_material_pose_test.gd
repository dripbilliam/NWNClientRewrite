extends SceneTree
const Target=preload("res://systems/native_render/native_model_material.gd")
const Before=preload("res://tests/fixtures/native_perf140_loading_pose_material_before.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
const Surface=preload("res://systems/native_render/native_surface_state.gd")
var checks:=0
var failures: Array=[]
var args: Dictionary={}
var guarded:=false
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	guarded=args.get("expect-guard","false")=="true";call_deferred("run")
func material(script,standard: bool=false,output: bool=false):
	var result=script.new();var source:=StandardMaterial3D.new()
	result.configure(source,[0.5,0.6,0.7],[0.0,0.0,0.0],standard,2);result.native_surface_output=output
	return result
func state(value) -> PackedByteArray:
	return var_to_bytes([value.albedo_color,value.emission,value.emission_enabled,value.transparency,value.get_shader_parameter("native_diffuse"),value.get_shader_parameter("native_alpha"),value.get_shader_parameter("native_emission"),value.get_shader_parameter("native_emission_enabled"),value.shader.code if value.shader!=null else ""])
func publish_pair(a,b,color: Color,emission: Color,blended: bool,label: String) -> void:
	a.publish_native_pose(color,emission,blended);b.publish_native_pose(color,emission,blended)
	check(state(a)==state(b),label+": exact original backing/API-uniform/shader output")
func matrix_checks() -> Dictionary:
	var total_pubs:=0;var total_skips:=0
	for standard in [false,true]:
		for output in [false,true]:
			var a=material(Before,standard,output);var b=material(Target,standard,output)
			var colors: Array=[Color.WHITE,Color(0,0,0,0),Color(-0.0,0.0,-0.0,-0.0),Color(-1.0,0.25,2.0,0.5),Color(0.1,0.2,0.3,1.0),Color(4.0,-2.0,0.75,-0.5),Color(1,1,1,1)]
			for index in 96:
				var color: Color=colors[index%colors.size()];var emission: Color=colors[(floori(index/3.0)+2)%colors.size()];var blended:=index%2==0
				publish_pair(a,b,color,emission,blended,"Changing/negative/zero/HDR case")
				var old_pubs: int=b.pose_original_publications if guarded else 0
				publish_pair(a,b,color,emission,blended,"Repeated case")
				if guarded:check(b.pose_original_publications==old_pubs and b.pose_unchanged_skips>0,"Finite identical original output skips publication")
			# Explicit signed-zero transitions must retain original property/uniform words.
			publish_pair(a,b,Color(0,0,0,0),Color(0,0,0,0),false,"Positive zero")
			publish_pair(a,b,Color(-0.0,0,0,-0.0),Color(0,-0.0,0,-0.0),false,"Signed-zero change")
			for value in [NAN,INF,-INF]:
				var color:=Color(value,0.5,0.25,1.0);var emission:=Color(0.5,value,0.25,1.0)
				publish_pair(a,b,color,emission,true,"Nonfinite original fallback")
				var old_pubs: int=b.pose_original_publications if guarded else 0
				publish_pair(a,b,color,emission,true,"Repeated nonfinite original fallback")
				if guarded:check(b.pose_original_publications==old_pubs+1,"Nonfinite input/output never enters skip path")
			publish_pair(a,b,Color(1e30,-1e30,0.5,1),Color.BLACK,false,"Finite input with overflowing original diffuse output")
			var overflow_pubs: int=b.pose_original_publications if guarded else 0
			publish_pair(a,b,Color(1e30,-1e30,0.5,1),Color.BLACK,false,"Repeated overflowing original output")
			if guarded:check(b.pose_original_publications==overflow_pubs+1,"Nonfinite original uniform output keeps the fallback path")
			publish_pair(a,b,Color.WHITE,Color.BLACK,false,"Finite recovery")
			if guarded:total_pubs+=b.pose_original_publications;total_skips+=b.pose_unchanged_skips
	return {"original_publications":total_pubs,"unchanged_skips":total_skips}
func mutation_checks() -> void:
	var a=material(Before,true,true);var b=material(Target,true,true)
	var color:=Color(0.8,0.5,-0.25,1.0);var emission:=Color(0.1,-0.2,0.3,0.5)
	publish_pair(a,b,color,emission,false,"Initial mutable fixture")
	for mutation in [["native_diffuse",Vector3(0.11,0.22,0.33)],["native_alpha",0.125],["native_alpha",1],["native_alpha",1.0+1e-12],["native_emission",Vector3(-0.25,0.5,0.75)],["native_emission_enabled",false],["native_alpha",null],["native_emission",Color(0.1,0.2,0.3,1)],["native_diffuse",Vector3(NAN,0,0)]]:
		a.set_shader_parameter(mutation[0],mutation[1]);b.set_shader_parameter(mutation[0],mutation[1])
		var old_pubs: int=b.pose_original_publications if guarded else 0
		publish_pair(a,b,color,emission,false,"External uniform mutation restored")
		if guarded:check(b.pose_original_publications==old_pubs+1,"Actual owner uniform changes invalidate the snapshot")
	for mutation in [["albedo_color",Color(0.1,0.2,0.3,0.4)],["emission",Color(-0.1,-0.2,0.4,1)],["emission_enabled",false],["transparency",BaseMaterial3D.TRANSPARENCY_ALPHA]]:
		a.set(mutation[0],mutation[1]);b.set(mutation[0],mutation[1])
		var old_pubs: int=b.pose_original_publications if guarded else 0
		publish_pair(a,b,color,emission,false,"External backing-property mutation restored")
		if guarded:check(b.pose_original_publications==old_pubs+1,"Live backing properties invalidate the snapshot")
	a.shader=a.shader.duplicate();b.shader=b.shader.duplicate()
	var old_pubs: int=b.pose_original_publications if guarded else 0
	publish_pair(a,b,color,emission,false,"New shader identity")
	if guarded:check(b.pose_original_publications==old_pubs+1,"Replacing a shader recaptures its owner output")
	var c=a.duplicate();var d=b.duplicate();publish_pair(c,d,color,emission,true,"Duplicated resource first use")
	var bare_a:=Before.new();var bare_b:=Target.new()
	publish_pair(bare_a,bare_b,Color.WHITE,Color.BLACK,false,"Unconfigured original resource")
	publish_pair(bare_a,bare_b,Color.WHITE,Color.BLACK,false,"Repeated unconfigured resource")
	publish_pair(bare_a,bare_b,Color.WHITE,Color.BLACK,true,"Unconfigured blend/shader transition")
func outside_owner_probe() -> Dictionary:
	var a=material(Before);var b=material(Target);var color:=Color.WHITE;var emission:=Color.BLACK
	publish_pair(a,b,color,emission,false,"Out-of-owner probe initial state")
	var cached=a.get_shader_parameter("native_alpha")
	RenderingServer.material_set_param(a.get_rid(),&"native_alpha",0.125);RenderingServer.material_set_param(b.get_rid(),&"native_alpha",0.125)
	check(a.get_shader_parameter("native_alpha")==cached and b.get_shader_parameter("native_alpha")==cached,"Raw RenderingServer writes bypass the resource owner's param cache")
	var before_a: Variant=RenderingServer.material_get_param(a.get_rid(),&"native_alpha");var before_b: Variant=RenderingServer.material_get_param(b.get_rid(),&"native_alpha")
	a.publish_native_pose(color,emission,false);b.publish_native_pose(color,emission,false)
	return {"scope":"Explicit unsupported out-of-owner mutation. No parity assertion: read-only ClientAPI exposes no material/RID, no internal raw writer was found, and production guard reads owner cache only.","backend_query_available":before_a!=null or before_b!=null,"backend_before_original":before_a,"backend_before_target":before_b,"backend_after_original":RenderingServer.material_get_param(a.get_rid(),&"native_alpha"),"backend_after_target":RenderingServer.material_get_param(b.get_rid(),&"native_alpha")}
func run() -> void:
	Palette.ensure();Surface.ensure();var counts:=matrix_checks();mutation_checks();var unsupported:=outside_owner_probe()
	var proof:={"success":failures.is_empty(),"checks":checks,"failures":failures,"expect_guard":guarded,"counts":counts,"outside_owner_probe":unsupported,"scope":"Headless exact original material publication/API ownership oracle; no visual, backend dirty-work, GPU, server or FPS acceptance"}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close();print(JSON.stringify(proof));quit(0 if failures.is_empty() else 1)
