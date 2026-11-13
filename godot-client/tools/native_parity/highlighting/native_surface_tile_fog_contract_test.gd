extends SceneTree
const Native=preload("res://systems/native_render/native_model_material.gd")
const Transfer=preload("res://systems/native_render/native_surface_transfer.gd")
const AlphaOwner=preload("res://tools/native_parity/ui/actor-alpha-owner.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func material() -> ShaderMaterial:
	var base:=StandardMaterial3D.new()
	var value:=Native.new();value.configure(base,[1,1,1],[0,0,0],true,2)
	value.native_surface_output=true;value.native_world_fog=true
	return value
func uniform_enabled(value: ShaderMaterial) -> bool:
	return value.shader.code.contains("instance uniform float nwn_tile_fog_factor=1.0;")
func alpha_copy(enabled: bool) -> void:
	var original=material();original.native_tile_fog_enabled=enabled
	var original_shader: Shader=original.shader
	var mesh:=MeshInstance3D.new();mesh.mesh=QuadMesh.new();mesh.material_override=original
	var owner:=AlphaOwner.new()
	check(owner.enroll(mesh,0),"Actual enhanced alpha enrollment "+str(enabled))
	var target=mesh.material_override
	check(target!=original and target is Native,"Actor owns a private enhanced material "+str(enabled))
	check(target.native_tile_fog_enabled==enabled,"Storage copy preserves explicit fog opt-in "+str(enabled))
	check(target.native_surface_output and target.native_world_fog,"Storage copy preserves other surface flags "+str(enabled))
	check(target.shader==original_shader and uniform_enabled(target)==enabled,"Copied shader shares matching cache variant "+str(enabled))
	check(owner.set_alpha(0.4),"Actual actor alpha update "+str(enabled))
	check(target.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and uniform_enabled(target)==enabled,"Transparency shader retains fog enrollment policy "+str(enabled))
	check(original.shader==original_shader and original.native_tile_fog_enabled==enabled,"Actor material changes preserve shared source "+str(enabled))
	check(owner.set_alpha(1.0),"Actual actor alpha returns opaque "+str(enabled))
	check(target.shader==original_shader,"Opaque actor returns to matching cached shader "+str(enabled))
	target.native_tile_fog_enabled=not enabled
	check(uniform_enabled(target)!=enabled and original.native_tile_fog_enabled==enabled,"Actor fog opt-in switches independently "+str(enabled))
	owner.close();mesh.free()
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	check(Transfer.code()==Transfer.code(false),"Default transfer explicitly disables instance fog")
	check(Transfer.code().contains("const float nwn_tile_fog_factor=1.0;"),"Default transfer keeps physical fog factor1")
	check(not Transfer.code().contains("instance uniform"),"Default transfer reserves no instance-uniform slots")
	check(Transfer.code(true).contains("instance uniform float nwn_tile_fog_factor=1.0;"),"Explicit transfer opts into existing instance uniform")
	check(not Transfer.code(true).contains("const float nwn_tile_fog_factor"),"Opt-in has one factor declaration")
	check(Transfer.vertex_code().contains("INSTANCE_CUSTOM.y>0.5?INSTANCE_CUSTOM.x:nwn_tile_fog_factor"),"MultiMesh custom fog selection remains intact")
	var first=material();var second=material();var default_shader: Shader=first.shader
	check(not first.native_tile_fog_enabled,"Material fog opt-in defaults false")
	check(not uniform_enabled(first) and first.shader.code.contains("const float nwn_tile_fog_factor=1.0;"),"Actual default native surface shader has no instance fog")
	check(first.shader==second.shader,"Default surface shader cache sharing")
	var stored:=false
	for property in first.get_property_list():
		if str(property.name)=="native_tile_fog_enabled":stored=(int(property.usage)&PROPERTY_USAGE_STORAGE)!=0 and int(property.type)==TYPE_BOOL
	check(stored,"Fog enrollment opt-in is an exported storage bool")
	first.native_tile_fog_enabled=true;var explicit_shader: Shader=first.shader
	check(uniform_enabled(first) and explicit_shader!=default_shader,"Explicit opt-in selects a separate instance shader")
	check(second.shader==default_shader and not second.native_tile_fog_enabled,"Opt-in cannot mutate an existing default shader")
	second.native_tile_fog_enabled=true
	check(second.shader==explicit_shader,"Explicit enabled shader cache sharing")
	first.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	check(uniform_enabled(first) and first.shader!=explicit_shader,"Blended variant preserves explicit enrollment")
	first.native_tile_fog_enabled=false
	check(not uniform_enabled(first),"Disabling removes instance uniform from blended shader")
	first.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
	check(first.shader==default_shader,"Default shader cache identity survives round trip")
	first.native_surface_output=false;first.native_tile_fog_enabled=true
	check(not uniform_enabled(first),"Fog opt-in alone cannot activate native surface output")
	first.native_surface_output=true
	check(first.shader==explicit_shader,"Returning surface output preserves explicit opt-in")
	first.native_tile_fog_enabled=false
	check(first.shader==default_shader,"Explicit off restores default surface shader")
	alpha_copy(false);alpha_copy(true)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual NativeModelMaterial shader cache/API and actual enhanced-alpha storage copy; no GPU draw/readback, no server, no physical fog activation"}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("NATIVE_SURFACE_TILE_FOG_CONTRACT "+JSON.stringify(result));quit(0 if failures.is_empty() else 1)
