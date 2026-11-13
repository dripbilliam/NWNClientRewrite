extends "res://tests/native_drive_preview_lazy_fixture_test.gd"
# Same-process bounded CPU experiment against the exact frozen v4 owner. No
# graphical client, server, replay, frame pacing or FPS measurement.
const FrozenOwner=preload("res://tools/native-drive-numeric/frozen_drive_collision_indexed.gd")
var native_requested:=false
var rows: Array=[]
var numeric_provenance: Dictionary={}
func make_world(indexed: bool=true)->Dictionary:
	var setup:=super.make_world(indexed)
	if not indexed:return setup
	var configure_us:=0
	if native_requested:
		var began:=Time.get_ticks_usec();setup.collision.numeric_batch.configure();configure_us=Time.get_ticks_usec()-began
		check(setup.collision.numeric_batch.enabled,"Private actual numeric candidate enabled")
		numeric_provenance=setup.collision.numeric_batch.provenance.duplicate(true)
	else:
		setup.collision.free();var collision:=FrozenOwner.new();setup.world.add_child(collision)
		collision.world=setup.world;collision.tables=tables();setup.world.drive_collision=collision;collision.ensure_spatial_scope();collision.set_process(false);setup.collision=collision
	setup.configure_us=configure_us;return setup
func dense_floor(world)->void:
	var vertices: Array=[];var faces: Array=[];var materials: Array=[];var normals: Array=[];var constants: Array=[]
	for y in 25:
		for x in 25:vertices.append([10.0*x/24,10.0*y/24,0.0])
	for y in 24:
		for x in 24:
			var a:=y*25+x;var b:=a+1;var c:=a+25;var d:=c+1
			faces.append([a,b,d]);faces.append([a,d,c]);materials.append(0);materials.append(0);normals.append([0,0,1]);normals.append([0,0,1]);constants.append(0);constants.append(0)
	world.surface.meshes.floor={"vertices":vertices,"faces":faces,"materials":materials,"normals":normals,"constants":constants}
func prepared(name: String,native: bool)->Dictionary:
	native_requested=native;var setup:=fixture()
	if name.begins_with("dense"):dense_floor(setup.world)
	if name=="inflated-free":
		for index in 32:setup.world.receive_delta([object(100+index,Vector2(0.25+(index%16)*0.2,5.5 if index<16 else 8.5))],[],1)
	return setup
func once(collision,from: Vector3,target: Vector3)->Dictionary:
	var queries: int=collision.stats.queries;var began:=Time.get_ticks_usec()
	var clear: Callable=collision.query_preview(1,from,target,from)
	var value:=Plan.path(from,target,from,clear);var total:=Time.get_ticks_usec()-began
	return {"total_us":total,"clear_calls":int(collision.stats.queries)-queries,"result":value}
func run_case(name: String,from: Vector3,target: Vector3)->void:
	var before:=prepared(name,false);var after:=prepared(name,true)
	var a:=once(before.collision,from,target);var b:=once(after.collision,from,target)
	check(var_to_bytes(a.result)==var_to_bytes(b.result) and a.clear_calls==b.clear_calls,name+" cold exact result/probes")
	var warm: Array=[]
	for index in 8:
		var first: Dictionary;var second: Dictionary
		if index%2==0:first=once(before.collision,from,target);second=once(after.collision,from,target)
		else:second=once(after.collision,from,target);first=once(before.collision,from,target)
		check(var_to_bytes(first.result)==var_to_bytes(second.result) and first.clear_calls==second.clear_calls,name+" warm exact result/probes "+str(index))
		warm.append({"frozen_v4":first,"native":second})
	var numeric: Dictionary=after.collision.numeric_batch.snapshot()
	if not name.begins_with("dense"):
		check(numeric.counts.bindings==0 and numeric.counts.queries==0 and numeric.counts.fallbacks==0,name+" ineligible geometry does not dispatch or allocate native fallback results")
	rows.append({"name":name,"cold":{"frozen_v4":a,"native":b,"native_configuration_us":after.configure_us,"native_total_with_configuration_us":int(b.total_us)+int(after.configure_us)},"warm":warm,"numeric":numeric})
	before.world.free();after.world.free()
func run()->void:
	Profile.enabled=false;Profile.phases.clear();Profile.postdraw_phases.clear()
	run_case("free",Vector3(1,7,0),Vector3(2,7,0))
	run_case("sparse-blocked38",Vector3(3.8,1.5,0),Vector3(4.8,1.5,0))
	run_case("dense-free",Vector3(1,7,0),Vector3(2,7,0))
	run_case("dense-blocked38",Vector3(3.8,1.5,0),Vector3(4.8,1.5,0))
	run_case("inflated-free",Vector3(1,7,0),Vector3(2,7,0))
	check(Profile.phases.is_empty() and Profile.postdraw_phases.is_empty(),"Detailed profiling stays disabled")
	var report_path:="";var expected_digest:="";var expected_module:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.substr(9)
		if arg.begins_with("--expect-module="):expected_module=arg.substr(16)
		if arg.begins_with("--expect-module-sha256="):expected_digest=arg.substr(23)
	check(expected_digest.length()==64 and numeric_provenance.get("sha256")==expected_digest and str(numeric_provenance.get("module_path","")).replace("\\","/").to_lower()==expected_module.replace("\\","/").to_lower(),"Microcomparison loads the pinned native DLL")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"rows":rows,"native_present":true,"detailed_profiling":false,"headless":true,"provenance":numeric_provenance,"scope":"Five bounded CPU fixtures, frozen v4 versus private native candidate; total query plus path, first use and eight alternating warm pairs. Numeric capability setup is separately recorded and included in the cold aggregate. Excludes fixture/world construction and scene/GPU publication. No FPS, full-area or live-stall result."}
	if not report_path.is_empty() and not FileAccess.file_exists(report_path):
		var file:=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print(JSON.stringify({"success":result.success,"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
