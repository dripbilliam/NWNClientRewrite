extends SceneTree
# Parse the exact whole-suite closure and exercise the ACTUAL copied owner.
const Collision=preload("res://systems/native_render/drive_collision_indexed.gd")
const Spatial=preload("res://systems/native_render/drive_spatial_index.gd")
const Suite0=preload("res://tests/native_drive_spatial_index_test.gd")
const Suite1=preload("res://tests/native_drive_spatial_adapter_test.gd")
const Suite2=preload("res://tests/native_perf140_loading_drive_envelope_test.gd")
const Suite3=preload("res://tests/native_drive_preview_lazy_fixture_test.gd")
const Suite4=preload("res://tests/native_drive_preview_transaction_test.gd")
const Suite5=preload("res://tests/native_perf140_loading_drive_route_test.gd")
const Suite6=preload("res://tests/native_perf140_loading_drive_clear_test.gd")
const Suite7=preload("res://tests/native_perf140_loading_drive_clear_physical_test.gd")
var full_report:=""
var full_checks: Array=[]
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):full_report=arg.trim_prefix("--report=")
	call_deferred("run")
func full_check(ok: bool,label: String)->void:full_checks.append({"ok":ok,"label":label})
func run()->void:
	if full_report.is_empty() or FileAccess.file_exists(full_report):quit(2);return
	var owner:=Collision.new();owner.set_process(false)
	full_check(owner.get_script()==Collision,"Actual full-overlay owner class")
	for index in 463:
		var key: String="canonical-%04d"%index
		var id:=1000+index;var witness: Array=[id+100,1]
		var center:=Vector3.ZERO if index==0 else Vector3(1000+index*4,1000,0)
		var spatial:=Spatial.new();var ticket: Dictionary=spatial.begin([771,3,91])
		var added: Dictionary=spatial.upsert_shape(ticket,id,witness,1,"pwk",center-Vector3.ONE,center+Vector3.ONE,false,index)
		full_check(added.get("accepted",false),"Actual spatial shape "+str(index))
		owner.static_groups[key]={"bounds":{"min_x":float(center.x)-1.0,"min_y":float(center.y)-1.0,"max_x":float(center.x)+1.0,"max_y":float(center.y)+1.0},"index":spatial,"ticket":ticket}
		owner.models[key]={"states":[{}]};owner.model_bounds[key]=[{"min":Vector3(-1,-1,-1),"max":Vector3(1,1,1),"radius":1.0}]
		owner.source_rows[id]={"witness":witness,"spec":{"door":false,"state":0},"pose":{"position":center,"rotation":0.0},"bounds_signature":[]}
	var result: Dictionary=owner.static_candidates(Vector3.ZERO,Vector3.ONE,0.5,77)
	var stats: Dictionary=owner.prefix_statistics();var enabled: bool=OS.get_cmdline_user_args().has("--static-prefix-cursor=on")
	full_check(result.get("ready",false) and result.get("rows",[]).size()==1,"Full actual owner canonical result")
	if enabled:
		full_check(int(stats.get("native_cursor_calls",0))>0,"Full owner actual cursor calls")
		full_check(int(stats.get("native_scanned",0))==463 and int(stats.get("native_admit",0))==1 and int(stats.get("native_fallback",-1))==0,"Full owner canonical463 native route")
		full_check(int(stats.get("fast_terminal_scans",0))>0 and int(stats.get("rollback_count",-1))==0,"Full owner safe fast terminal")
	else:full_check(int(stats.get("native_cursor_calls",0))==0,"Explicit off original reference performs no cursor calls")
	owner.free()
	await process_frame;await process_frame
	var report:={"success":full_checks.all(func(row):return row.ok),"checks":full_checks,"scope":"Private full-owner parser/canonical activation functional gate; no world performance or activation acceptance.","cursor_enabled":enabled,"actual_use":stats,"result_bytes":var_to_bytes(result).hex_encode()}
	var file:=FileAccess.open(full_report,FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close();quit(0 if report.success else 1)
