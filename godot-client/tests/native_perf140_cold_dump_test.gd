extends SceneTree
const Dump=preload("res://systems/native_render/perf140_cold_particle_dump.gd")
class Emitter extends RefCounted:
	var source: Node3D
class Group extends RefCounted:
	var members: Dictionary={}
	func cold_particle_census() -> Dictionary:
		var rows: Array=[]
		for id in members:rows.append({"id":id})
		return {"emitters":rows}
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:
	var world:=Node3D.new()
	check(Dump.capture(world).has("error"),"missing owner returns an explicit error without missing-meta logging")
	var parent:=Node3D.new()
	var source:=Node3D.new()
	parent.add_child(source)
	parent.set_meta("native_tile_index",0)
	var emitter:=Emitter.new();emitter.source=source
	var group:=Group.new();group.members[7]={"emitter":weakref(emitter)}
	world.set_meta("native_particle_stream_group",group)
	var result:=Dump.capture(world)
	check(result.emitters.size()==1,"one detached row")
	var row: Dictionary=result.emitters[0]
	check(row.direct_tile_index==null,"missing direct index stays null")
	check(row.source_parent_tile_index==0,"tile zero is available")
	check(row.source_parent_model==null,"missing optional model stays null")
	check(row.source_script==null and row.source_parent_script==null,"missing scripts stay null")
	check(group.members[7].size()==1,"cold export leaves membership unchanged")
	row.source_parent_tile_index=999
	check(parent.get_meta("native_tile_index")==0,"detached export cannot mutate source metadata")
	parent.remove_child(source);source.free()
	emitter.source=null
	check(Dump.capture(world).emitters[0].source_parent_tile_index==null,"missing source is explicit")
	world.remove_meta("native_particle_stream_group");world.free();parent.free()
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			file.store_string(JSON.stringify(report))
	print(JSON.stringify(report));quit(0 if report.success else 1)
