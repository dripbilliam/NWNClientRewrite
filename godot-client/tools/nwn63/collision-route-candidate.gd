extends SceneTree
# Actual World route factory and preview integration. Polygon/broadphase
# oracles stay in native_drive_spatial_adapter_test / spatial_index_test.
const World=preload("res://tools/nwn63/collision-world-candidate.gd")
const Legacy=preload("res://systems/native_render/drive_collision.gd")
const Indexed=preload("res://.cache/nwn63/collision-group-index-a/candidate.gd")
const Surface=preload("res://systems/native_render/terrain_surface.gd")
const Profile=preload("res://systems/native_render/frame_profile.gd")
class QuietWorld:
	extends World
	func _enter_tree() -> void:pass
	func ready_for_control() -> bool:return not closed and not retiring
var constructor_selection: Dictionary={}
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func make_world(mode: String) -> QuietWorld:
	var world:=QuietWorld.new()
	world.drive_collision_configuration=World.configured_drive_collision(PackedStringArray(["--drive-collision="+mode]))
	world.drive_spatial_enabled=mode=="indexed"
	world.generation=3;world.area_id=91
	root.add_child(world);world.set_process(false)
	return world
func finish(world: QuietWorld) -> void:
	world.close();world.free()
func parsing() -> void:
	var default:=World.configured_drive_collision(PackedStringArray())
	check(default.valid and default.requested=="indexed" and not default.explicit and default.reason=="registry-default","Absent flag consumes the authoritative indexed default")
	check(World.configured_drive_collision(PackedStringArray(["--other=indexed","--drive-collision-extra=indexed"])).requested=="indexed","Only the exact named flag selects a route")
	for invalid_registry in [null,{}, {"version":2,"features":[]},{"version":1,"features":[]},{"version":1,"features":[{"name":"drive-collision","default":"bad","choices":["legacy","indexed"]}]},{"version":1,"features":[{"name":"drive-collision","default":null,"choices":["legacy","indexed"]}]},{"version":1,"features":[{"name":"drive-collision","default":"indexed"}]},{"version":1,"features":[{"name":"drive-collision","default":"indexed","choices":["legacy"]}]},{"version":1,"features":[{"name":"drive-collision","default":"legacy","choices":["legacy","indexed"]},{"name":"drive-collision","default":"indexed","choices":["legacy","indexed"]}]}]:
		var rejected:=World._registry_drive_collision_default(invalid_registry)
		check(not rejected.valid and not rejected.explicit and rejected.requested.is_empty() and rejected.reason=="invalid-registry-default","Missing/invalid/duplicate registry defaults reject without fallback")
		var world:=make_world("legacy");world.drive_collision_configuration=rejected
		check(world._new_drive_collision()==null and world.drive_collision_selection_snapshot().effective=="unavailable","Invalid registry default cannot construct a fallback owner")
		finish(world)
	for mode in ["legacy","indexed"]:
		var registry_default:=World._registry_drive_collision_default({"version":1,"features":[{"name":"drive-collision","default":mode,"choices":["legacy","indexed"]}]})
		check(registry_default.valid and registry_default.requested==mode and not registry_default.explicit,"Pure default reader uses the registry value rather than a second policy: "+mode)
		var selection:=World.configured_drive_collision(PackedStringArray(["--drive-collision="+mode]))
		check(selection.valid and selection.explicit and selection.requested==mode and selection.reason=="explicit-selection","Valid exact route: "+mode)
	for arguments in [["--drive-collision"],["--drive-collision="],["--drive-collision=INDEXED"],["--drive-collision=garbage"],["--drive-collision=indexed","--drive-collision=legacy"],["--drive-collision=indexed","--drive-collision=indexed"]]:
		var selection:=World.configured_drive_collision(PackedStringArray(arguments))
		check(not selection.valid and selection.explicit,"Invalid/missing/duplicate route rejects: "+str(arguments))
		var world:=make_world("legacy");world.drive_collision_configuration=selection
		var before:=world.get_child_count()
		world.open(null,{"id":91},3,"unused-headless-cache")
		check(world.drive_collision==null and world.terrain==null and world.catalog==null and world.model_environment==null and world.get_child_count()==before,"Rejected open prepares no collision/world owner")
		check(world.stats.errors.size()==1 and str(world.stats.errors[0]).contains(str(selection.reason)),"Rejected open exposes its exact reason")
		check(world._new_drive_collision()==null and world.drive_collision_selection_snapshot().effective=="unavailable","Invalid direct factory cannot silently fall back")
		finish(world)
func routes() -> void:
	var automatic:=QuietWorld.new()
	var selected:=World.configured_drive_collision(OS.get_cmdline_user_args())
	check(automatic.drive_collision_configuration==selected and automatic.drive_spatial_enabled==(selected.requested=="indexed" and selected.valid),"Actual constructor consumes process arguments before open")
	automatic.drive_collision=automatic._new_drive_collision();automatic.add_child(automatic.drive_collision)
	var actual:=automatic.drive_collision_selection_snapshot();constructor_selection=actual.duplicate(true)
	check(automatic.drive_collision.get_script()==(Indexed if selected.requested=="indexed" else Legacy) and actual.effective==selected.requested and actual.explicit==selected.explicit,"Actual omitted/explicit process selection constructs the reported collision owner")
	if not selected.explicit:check(actual.requested=="indexed" and actual.effective=="indexed" and actual.owner_script=="res://.cache/nwn63/collision-group-index-a/candidate.gd","Actual no-argument World factory owns indexed collision")
	finish(automatic)
	for mode in ["legacy","indexed"]:
		var world:=make_world(mode)
		world.drive_collision=world._new_drive_collision();world.add_child(world.drive_collision)
		var expected=Indexed if mode=="indexed" else Legacy
		check(world.drive_collision.get_script()==expected,"Actual open factory constructs "+mode+" script")
		var snapshot:=world.drive_collision_selection_snapshot()
		check(snapshot.requested==mode and snapshot.effective==mode and snapshot.owner_script==expected.resource_path and snapshot.scope.generation==3 and snapshot.scope.area_id==91,"Report has requested/effective route, actual script and immutable owner scope")
		var absent_shadow:=Node.new();world.set_meta("native_point_shadow_budget",weakref(absent_shadow));absent_shadow.free()
		var world_snapshot:=world.snapshot(false)
		check(world_snapshot.drive_collision_configuration.effective==mode and world_snapshot.drive_collision_route==mode,"Actual World snapshot exposes the selected owner: "+mode)
		snapshot.scope.generation=99;snapshot.reason="mutated by consumer"
		check(world.drive_collision_selection_snapshot().scope.generation==3 and world.drive_collision_selection_snapshot().reason=="explicit-selection","Route report is a detached view")
		world.drive_spatial_enabled=not world.drive_spatial_enabled
		check(world.drive_collision.get_script()==expected and world.drive_collision_selection_snapshot().effective==mode,"Changing preference never hot-switches a live owner")
		finish(world)
	var override:=make_world("legacy");override.drive_spatial_enabled=true
	override.drive_collision=override._new_drive_collision();override.add_child(override.drive_collision)
	var report:=override.drive_collision_selection_snapshot()
	check(report.requested=="legacy" and report.effective=="indexed" and report.reason=="programmatic-pre-open-override","Explicit programmatic test seam is distinguishable from requested configuration")
	finish(override)
func prepare_preview(mode: String) -> QuietWorld:
	var world:=make_world(mode);world.controlled_id=1
	var floor:=Surface.new();world.add_child(floor);world.surface=floor;floor.done=true;floor.set_process(false)
	floor.table={"orderedRows":[{"Walk":"1"}]}
	floor.definition={"width":1,"height":1,"tiles":[{"model":"floor","orientation":0,"position":Vector3(5,0,-5)}]}
	floor.meshes={"floor":{"vertices":[[0,0,0],[10,0,0],[10,10,0],[0,10,0]],"faces":[[0,1,2],[0,2,3]],"materials":[0,0],"normals":[[0,0,1],[0,0,1]],"constants":[0,0]}}
	var received:={"position":[1,1,0],"orientation":[1,0,0],"animation":0,"walkRate":2000,"runRate":4000}
	world.desired[1]={"object":{"id":1,"areaId":91,"objectType":5,"nativeLifetime":101,"clientKnownLifetime":1,"appearance":{"appearance":0},"replicated":received}}
	world.motion.ensure(1,received)
	world.drive_collision=world._new_drive_collision();world.add_child(world.drive_collision);world.drive_collision.world=world;world.drive_collision.set_process(false)
	world.drive_collision.tables={"appearance":{"orderedRows":[{"PERSPACE":"0.3","HEIGHT":"1.8"}]},"placeables":{},"genericdoors":{},"doortypes":{}}
	if mode=="indexed":world.drive_collision.sync_full()
	return world
func prediction_and_scopes() -> void:
	var outputs: Array=[]
	for mode in ["legacy","indexed"]:
		var world:=prepare_preview(mode)
		var received: Dictionary=world.desired[1].object.replicated
		var before:=var_to_bytes(received)
		Profile.enabled=true;Profile.phases={};Profile.phase_frame=-1;Profile.collected_frame=-1
		var result:=world.preview_drive(1,3,-1);outputs.append(result)
		check(result.has("target") and result.target.x>1,"Actual "+mode+" preview accepts WOK-backed motion")
		check(Profile.phases.has("keyboard_preview_query") and Profile.phases.has("keyboard_preview_path") and Profile.phases.has("keyboard_preview"),"Detailed "+mode+" preview records query/path/total spans")
		check(var_to_bytes(received)==before,"Prediction preserves received server state: "+mode)
		Profile.enabled=false;Profile.phases={}
		world.preview_drive(1,3,-1)
		check(Profile.phases.is_empty(),"No timing records while profiling is disabled: "+mode)
		if mode=="indexed":
			var old: Callable=world.drive_collision.query(1)
			world.generation+=1;world.drive_collision.sync_full()
			check(not old.call(Vector3(1,1,0),Vector3(2,1,0)),"Old closure cannot resolve after area-generation transition")
			var current: Callable=world.drive_collision.query(1)
			check(current.call(Vector3(1,1,0),Vector3(2,1,0)),"New generation retains current floor collisions")
			world.begin_retirement()
			check(not current.call(Vector3(1,1,0),Vector3(2,1,0)),"Actual World retirement invalidates held collision query")
			var reconnected:=prepare_preview("indexed")
			check(reconnected.drive_collision.query(1).call(Vector3(1,1,0),Vector3(2,1,0)) and not current.call(Vector3(1,1,0),Vector3(2,1,0)),"New World reconnect cannot resurrect old same-ID query")
			finish(reconnected)
		finish(world)
	check(outputs.size()==2 and outputs[0]==outputs[1],"Legacy and indexed actual World previews return identical target/factor")
func run() -> void:
	parsing();routes();prediction_and_scopes()
	Profile.enabled=false;Profile.phases={}
	await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"constructor_selection":constructor_selection,"headless":true,"network":false,"scope":"Production World strict route parser, real owner factory, fail-closed open, detached actual-owner report, unchanged preview result/server state, profile gating, generation retirement and reconnect. Detailed geometry/lifetime oracles run separately; no live/GPU/FPS validation."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(result,"  ")+"\n")
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
