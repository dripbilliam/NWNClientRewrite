extends SceneTree
# Real material/pool requests, bounded owner reset and final shader identity.
# Run later in native headless acceptance; no catalog, scene draw or FPS claim.
const Warmup=preload("res://systems/native_render/material_prewarm.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const NativeMaterial=preload("res://systems/native_render/native_model_material.gd")
const Before=preload("res://tests/fixtures/native_perf140_loading_model_material_before.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func finish_wave(warm) -> void:
	var steps:=0
	while not warm.recipes.is_empty() and steps<30:
		var before: int=warm.materials.size();warm.step();steps+=1
		check(warm.materials.size()<=before+1,"A warmup callback requests at most one material")
		check(warm.materials.size()<=23 and warm.pool.textures.size()<=2,"Each policy wave retains at most23 materials and two authored textures")
	check(warm.recipes.is_empty() and warm.snapshot().done and warm.stats.failures.is_empty(),"Bounded policy wave completes without family mismatch")
func verify_native(warm,policy: Dictionary) -> void:
	var production:=Pool.new()
	production.native_lighting=policy.native_lighting;production.native_standard=policy.native_standard;production.native_surface_output=policy.native_surface_output;production.texture_filter=policy.texture_filter
	var native_count:=0
	for material in warm.materials:
		if not material is NativeMaterial:continue
		native_count+=1
		var cutout: bool=material.scissor;var blended: bool=material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA
		var part:={"alpha":0.75 if blended else 1.0,"selfillum":[0.0,0.0,0.0],"mesh":{"diffuse":[1.0,1.0,1.0],"transparency_hint":blended}}
		var actual=production.material(part,warm.raster(not blended and not cutout))
		check(actual is NativeMaterial and material.shader==actual.shader,"Warmup retains the exact production native shader resource")
		check(material.shader_variant_key()==actual.shader_variant_key() and warm.native_family_keys.has(actual.shader_variant_key()),"Warmup family key equals actual final-policy shader key")
	check(native_count==3 and warm.native_family_keys.size()==3,"Exactly opaque/blended/scissor native families are requested once")
	production.clear()
func legacy_key_checks() -> void:
	# Independent before implementation is an oracle for generated shader source;
	# every filter/quality combination remains available after key factoring.
	var source:=StandardMaterial3D.new()
	for filter_value in [0,1,2,3,4,5]:
		for quality in [1,2]:
			for transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED,BaseMaterial3D.TRANSPARENCY_ALPHA,BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR]:
				source.texture_filter=filter_value;source.transparency=transparency
				var before:=Before.new();before.configure(source,[1.0,1.0,1.0],[0.0,0.0,0.0],true,quality);before.native_surface_output=true;before.native_tile_fog_enabled=true
				var current:=NativeMaterial.new();current.configure(source,[1.0,1.0,1.0],[0.0,0.0,0.0],true,quality,true);current.native_tile_fog_enabled=true
				check(current.shader.code==before.shader.code,"Exact before shader source survives filtering/quality/tile-fog key factoring")
				var old_key: String=str(transparency==BaseMaterial3D.TRANSPARENCY_ALPHA)+str(transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)+["filter_nearest","filter_linear","filter_nearest_mipmap","filter_linear_mipmap","filter_nearest_mipmap_anisotropic","filter_linear_mipmap_anisotropic"][filter_value]+str(true)+str(quality)+str(true)+str(true)
				check(current.shader_variant_key()==old_key,"Family key preserves exact legacy bytes")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var warm:=Warmup.new();root.add_child(warm);warm.start();warm.set_process(false)
	finish_wave(warm)
	check(warm.materials.size()==20 and warm.native_family_keys.is_empty(),"Legacy standard-only warmup remains exactly20 materials")
	var source_pool:=Pool.new();source_pool.native_lighting=true;source_pool.native_surface_output=true;source_pool.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var policy:=Warmup.policy_from_pool(source_pool);var weak_pool:=weakref(source_pool);source_pool=null
	check(weak_pool.get_ref()==null,"Scalar policy snapshot does not retain the live production pool")
	var old_material:=weakref(warm.materials[0])
	check(warm.configure_policy(policy),"Final enhanced policy is accepted while enabled")
	policy.native_standard=true
	check(warm.policy.native_standard==false and warm.policy.is_read_only(),"Caller mutation cannot alter pending immutable policy")
	check(old_material.get_ref()==null and warm.materials.is_empty() and warm.recipes.size()==23,"Policy reset releases old private owners and schedules one bounded new wave")
	check(warm.recipes[0].native and warm.recipes[1].native and warm.recipes[2].native,"Verified native families precede the20 preserved legacy requests")
	var duplicate_family: Dictionary=warm.recipes[0].duplicate(true)
	warm.set_process(false);finish_wave(warm);verify_native(warm,warm.policy)
	warm.recipes.append(duplicate_family);warm.step()
	check(warm.materials.size()==23 and warm.stats.prepared==23 and warm.stats.done,"Repeated actual native family key requests neither another material nor an unfinished wave")
	var previous_first: int=warm.materials[0].get_instance_id();var previous_resets: int=warm.stats.policy_resets
	check(warm.configure_policy(warm.policy.duplicate()) and warm.materials[0].get_instance_id()==previous_first and warm.stats.policy_resets==previous_resets,"Identical final policy preserves owners and performs no redundant requests")
	var invalid:=warm.policy.duplicate();invalid.texture_filter=100
	check(not warm.configure_policy(invalid) and warm.materials[0].get_instance_id()==previous_first,"Unsupported policy rejection preserves the active bounded wave")
	var verified:=warm.policy.duplicate();verified.native_standard=true;verified.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	check(warm.configure_policy(verified),"Catalog-verified standard profile can explicitly replace the earlier native family")
	warm.set_process(false);warm.step();var partial:=weakref(warm.materials[0])
	var reset_again:=verified.duplicate();reset_again.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	check(warm.configure_policy(reset_again) and partial.get_ref()==null and warm.recipes.size()==23,"Cancellation of a partial policy wave releases private resources before restart")
	warm.set_process(false);finish_wave(warm);verify_native(warm,reset_again)
	check(warm.pool.meshes.is_empty() and warm.pool.templates.is_empty(),"Final-policy warmup creates no gameplay graph or geometry")
	var before_close:=warm.snapshot();warm.close();warm.close()
	check(warm.materials.is_empty() and warm.recipes.is_empty() and warm.pool.materials.is_empty() and warm.pool.textures.is_empty() and warm.snapshot().closed,"Idempotent close cancels every private owner")
	check(warm.snapshot().prepared==23 and warm.snapshot().native_families_prepared==3 and warm.snapshot().native_family_keys.size()==3,"Completed policy diagnostics survive owner cleanup")
	check(not warm.configure_policy(reset_again),"Closed owner cannot restart or accept a new policy")
	warm.free();legacy_key_checks()
	var output:=FileAccess.open(report,FileAccess.WRITE);output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"warmup":before_close,"scope":"Real Pool native shader requests with exact legacy shader-source/key oracle, scalar immutable policy, family deduplication, bounded callbacks and cancellation/reset. No scene draw/GPU completion/FPS claim."},"\t")+"\n");output.close();quit(0 if failures.is_empty() else 1)
