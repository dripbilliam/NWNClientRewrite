extends "res://tests/native_transition_door_hover_test.gd"
const AsciiNative=preload("res://systems/native_data/ascii_native_animation.gd")
const ActorModel=preload("res://systems/native_data/actor_model.gd")

func find_native(node: Dictionary,id: int) -> Dictionary:
	if int(node.id34)==id:return node
	for child in node.get("children68",[]):
		var found:=find_native(child,id)
		if not found.is_empty():return found
	return {}

func exercise_ascii(bundle: Dictionary,pool) -> void:
	check(bundle.get("sha256")=="22f9cbf71956e9d82feea48314d883abd51b0d9bd50e6865206fdf0cafc7a875","installed original ASCII resource hash")
	var model: Dictionary=bundle.value;var original:=model.duplicate(true)
	var native: Dictionary=model.rig_asset.get("nativeAnimation",{})
	check(native.get("source")=="original-ascii-linear-native-v1" and native.parts.size()==model.nodes.size(),"bounded ASCII native metadata activated")
	if native.is_empty() or native.parts.is_empty():return
	var sam:=-1
	for at in model.nodes.size():
		if str(model.nodes[at].name).to_lower()=="sam":sam=at;break
	check(sam>=0,"authored doorway physical Part retained")
	if sam<0:return
	var source: Dictionary=model.nodes[sam]
	check(source.alpha==0.0 and source.mesh.render and source.mesh.native_bounds_available,"ASCII authored alpha0/render1/original derived bounds")
	var static_alpha: Array=native.parts[sam].node.controllers78.filter(func(row):return int(row.displacement0)==168)
	check(static_alpha.size()==1 and float(native.parts[sam].node.values88[int(static_alpha[0].valueIndex8)])==0.0,"static constructor control preserves authored alpha0")
	for name in ["opened1","opened2","closed","opening1","closing1","die","dead"]:
		var rest:=find_native(native.clips[name].root,sam)
		check(not rest.is_empty() and int(rest.controllerCount80)==0,"original empty sam controllers retained in "+name)
	var trans:=find_native(native.clips.trans.root,sam)
	check(trans.controllerCount80==1 and trans.controllers78[0].displacement0==168 and trans.controllers78[0].rows4==2,"original two-key linear alpha descriptor retained")
	check(trans.values88[0]==0.0 and trans.values88[1]==Color(0.0333333,0,0,0).r and trans.values88[2]==0.25 and trans.values88[3]==0.25,"original ASCII times/values quantized once to native f32 pool")
	var state:={"doorOpenState":1,"animation":50,"hasTransition":true,"useable":false};var received_before:=state.duplicate(true)
	var door:=Door.new();root.add_child(door)
	check(door.install_door(bundle,pool,55701,state),"actual ASCII door installs original mesh/effect hierarchy")
	if door.rigs==null:door.free();return
	door.set_process(false);door.rigs.set_process(false);door.rigs._update(0.15)
	var entry: Dictionary=door.rigs.entities[55701];var part: Node3D=door.rigs.node_at(55701,int(entry.model_parts[0][sam]))
	var poses: Array=entry.nodes.map(func(node):return node.transform);var stable:=part.global_transform
	check(alpha(part)==0.0,"ordinary initial ASCII material remains alpha0")
	check(doorway_pick(door,part,source.mesh.native_bounds).get("hit",false),"original ASCII alpha0 doorway remains pickable")
	var hover:=Hover.new();var context:={"controlled_present":true,"has_transition":true}
	var selected: Dictionary=hover.update(door,context)
	check(selected.available and selected.special_transition and selected.suppress_hover,"actual ASCII Trans now enters existing native owner")
	var owner: Dictionary=entry.models[0]
	if not owner.has("native_owner"):
		hover.close();door.retire();return
	check(owner.native_owner.pose.native_context!=null,"actual compiled NativePose storage is used")
	check(not run_named(door,"opened1").is_empty() and not run_named(door,"trans").is_empty(),"native auxiliary run retains ordinary main run")
	var maximum:=0.0
	for at in poses.size():maximum=maxf(maximum,pose_delta(entry.nodes[at].transform,poses[at]))
	check(maximum<0.00001,"ASCII owner promotion preserves every current physical pose within explicit1e-5 conversion tolerance")
	door.rigs._update(0.5)
	check(alpha(part)==0.25,"actual ASCII alphakey reaches compiled storage/private material")
	check(near_pose(part.global_transform,stable),"native Trans leaves original doorway TRS unchanged")
	check(doorway_pick(door,part,source.mesh.native_bounds).get("hit",false),"same authored doorway bounds pick after native Trans")
	var previous:=run_named(door,"trans");var clock: float=previous.time14;var serial: int=owner.play_serial
	check(hover.update(door,context).available and is_same(previous,run_named(door,"trans")) and previous.time14==clock and owner.play_serial==serial,"repeat hover retains same native run/clock")
	door.observe_door({"doorOpenState":2,"animation":51});door.rigs._update(0.1)
	check(not run_named(door,"opening2").is_empty() and is_same(previous,run_named(door,"trans")),"received ASCII main transition retains auxiliary run")
	door._process(door.rigs.clip_length(55701,301)+0.01);door.rigs._update(0.0)
	check(not run_named(door,"opened2").is_empty(),"ordinary received rest settles through existing native run owner")
	check(hover.clear().available,"ASCII Trans cleanup removes only auxiliary run and restores CURRENT rest")
	door.rigs._update(0.5)
	check(run_named(door,"trans").is_empty() and not run_named(door,"opened2").is_empty(),"flags128 cleanup/current rest reflected in actual native run list")
	# This ASCII resource has NO main-clip alpha key. The original controller
	# owner performs no write, so retain current alpha instead of adding zero.
	check(alpha(part)==0.25,"absent ASCII main alpha controller retains current Part value; no fabricated reset")
	check(state==received_before and door.received_state==2 and model==original,"metadata, received state and original asset remain immutable")
	check(doorway_pick(door,part,source.mesh.native_bounds).get("hit",false),"cleanup never destroys original ASCII doorway pick bounds")
	door.observe_door({"doorOpenState":0,"animation":22});door.rigs._update(0.1)
	check(not run_named(door,"closing2").is_empty(),"ordinary closing remains functional after ASCII promotion")
	door._process(door.rigs.clip_length(55701,303)+0.01);door.rigs._update(0.0)
	check(not run_named(door,"closed").is_empty() and not hover.update(door,context).special_transition,"closed received state remains authoritative")
	check(door.snapshot_transition_hover().unavailable.is_empty() and owner.native_owner.pose.diagnostics.is_empty(),"supported ASCII native pose has no controller diagnostics")
	models.append({"resource":"t_door11","sha256":bundle.sha256,"compiled_native_pose":true,"empty_rest_alpha_retains_current":true,"promotion_max_pose_delta":maximum,"received_unchanged":state==received_before})
	hover.close();door.retire();await process_frame;await process_frame
	# Reuse actual authored geometry with an explicitly unsupported metadata
	# descriptor. Original AnimationPlayer and targeting must remain operational.
	var missing:=bundle.duplicate();missing.value=model.duplicate();missing.value.rig_asset=model.rig_asset.duplicate();missing.value.rig_asset.nativeAnimation=native.duplicate();missing.value.rig_asset.nativeAnimation.clips=native.clips.duplicate();missing.value.rig_asset.nativeAnimation.clips.trans={"unavailable":"fixture unsupported ASCII controller"}
	var fallback:=Door.new();root.add_child(fallback);check(fallback.install_door(missing,pool,55702,{"doorOpenState":1,"animation":50}),"unavailable-controller ASCII case installs unchanged original geometry")
	fallback.set_process(false);fallback.rigs.set_process(false)
	var fallback_hover:=Hover.new();var result: Dictionary=fallback_hover.update(fallback,context);var fallback_model: Dictionary=fallback.rigs.entities[55702].models[0]
	check(not result.available and result.special_transition and not fallback_model.has("native_owner") and fallback_model.player.is_playing(),"unsupported ASCII metadata preserves ordinary playback with explicit reason")
	var fallback_part: Node3D=fallback.rigs.node_at(55702,int(fallback.rigs.entities[55702].model_parts[0][sam]))
	check(doorway_pick(fallback,fallback_part,source.mesh.native_bounds).get("hit",false),"unsupported metadata keeps original ASCII doorway pick behavior")
	fallback.observe_door({"doorOpenState":0,"animation":22});check(fallback_model.clip=="closing1","unsupported native path keeps ordinary received closing")
	fallback_hover.close();fallback.retire();await process_frame;await process_frame

func parser_cases() -> void:
	var parser:=ActorModel.new()
	var prefix:="newmodel sample\nsetsupermodel sample NULL\nbeginmodelgeom sample\nnode dummy sample\n parent NULL\nendnode\nnode trimesh helper\n parent sample\n alpha 0\nendnode\nendmodelgeom sample\n"
	var suffix:="newanim trans sample\n length 1\n transtime 0\n animroot sample\n node dummy sample\n parent NULL\n endnode\n node trimesh helper\n parent sample\n alphakey\n 0 .25\n 1 .5\n endlist\n endnode\ndoneanim trans sample\ndonemodel sample\n"
	var supported:=parser.parse((prefix+suffix).to_ascii_buffer());check(parser.failure.is_empty() and supported.native_ascii_preparation.available,"small actual decoder supports linear scalar metadata")
	var before:=supported.duplicate(true);var rig:=parser.rig_asset(supported);check(rig.nativeAnimation.source=="original-ascii-linear-native-v1" and before==supported,"rig metadata query does not mutate decoder state")
	for pair in [["alphakey","alphabezierkey"],["alphakey","unknownkey"]]:
		var invalid:=ActorModel.new();var data:=invalid.parse((prefix+suffix.replace(pair[0],pair[1])).to_ascii_buffer())
		check(invalid.failure.is_empty() and not data.native_ascii_preparation.available and not invalid.rig_asset(data).nativeAnimation.clips.trans.has("root"),"unsupported key retains ordinary geometry/explicit native unavailability "+pair[1])
	var inherited:=ActorModel.new();var inherited_data:=inherited.parse((prefix.replace("sample NULL","sample parent")+suffix).to_ascii_buffer());check(inherited.failure.is_empty() and not inherited_data.native_ascii_preparation.available,"inherited ASCII never guessed")
	var extra:=ActorModel.new();var extra_text:=suffix.replace(" node trimesh helper"," node dummy ignored\n parent sample\n endnode\n node dummy ignored_child\n parent ignored\n endnode\n node trimesh helper");var extra_data:=extra.parse((prefix+extra_text).to_ascii_buffer())
	check(extra.failure.is_empty() and extra_data.native_ascii_preparation.available and extra_data.native_ascii_preparation.value.clips.trans.root.childCount70==1,"unmatched native -1 animation branch omitted without inventing physical nodes")
	var mismatch:=ActorModel.new();var mismatch_data:=mismatch.parse((prefix+suffix.replace(" parent sample\n alphakey"," parent missing\n alphakey")).to_ascii_buffer());check(mismatch.failure.is_empty() and not mismatch_data.native_ascii_preparation.available,"mapped node with unproven parent cannot become a guessed direct child")
	for fragment in [" 1 .5"," 0 .25"]:
		var out_of_range:=ActorModel.new();var data:=out_of_range.parse((prefix+suffix.replace(fragment,fragment.replace(".5","1e100").replace(".25","1e100"))).to_ascii_buffer())
		check(out_of_range.failure.is_empty() and not data.native_ascii_preparation.available,"finite double overflow cannot enter native f32 controller storage "+fragment)
	var reordered:=ActorModel.new();var reordered_data:=reordered.parse((prefix+suffix.replace(" 1 .5"," -.1 .5")).to_ascii_buffer());check(not reordered.failure.is_empty() or not reordered_data.get("native_ascii_preparation",{}).get("available",false),"negative/unordered native source times rejected")
	var duplicated:=ActorModel.new();var duplicate_data:=duplicated.parse((prefix+suffix.replace(" endnode\ndoneanim"," endnode\n node trimesh helper\n parent sample\n endnode\ndoneanim")).to_ascii_buffer());check(duplicated.failure.is_empty() and not duplicate_data.native_ascii_preparation.available,"duplicate mapped animation Part is explicit unavailable")

func run() -> void:
	var output:="";var install:="";var cache:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		elif arg.begins_with("--install="):install=arg.substr(10)
		elif arg.begins_with("--cache="):cache=arg.substr(8)
	if output.is_empty() or install.is_empty() or cache.is_empty() or FileAccess.file_exists(output):quit(2);return
	parser_cases()
	var catalog:=Catalog.new();check(catalog.mount_install(install),"original installed catalog mounts")
	if catalog.layers.is_empty():quit(3);return
	catalog.decoder_store=Store.new();var service:=Assets.new();root.add_child(service);service.maximum_workers=1;service.cache_directory=cache;service.configure(catalog);service.completed.connect(func(id,result):received[id]=result)
	var pool:=Pool.new();pool.picking=true;pool.unshaded=true
	var bundle: Dictionary=await request(service,"t_door11")
	if str(bundle.get("error","missing")).is_empty():await exercise_ascii(bundle,pool)
	service.close();service.free();await process_frame;await process_frame;pool.clear()
	var report:={"checks":checks,"failures":failures,"models":models,"scope":"Original installed ASCII t_door11, actual worker/native Runs/compiled NativePose/materials/authored doorway bounds and explicit fallback. No server/GPU/FPS or live visual claim. Existing fx_ref-scope and point-to-point warnings are separately admitted only by exact message/count."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
