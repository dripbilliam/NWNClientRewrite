extends SceneTree
var checks:=0
var failures: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok:failures.append(reason)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for value in OS.get_cmdline_user_args():
		var pair:=value.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var detached:=Node3D.new()
	check(not detached.is_inside_tree() and detached.is_visible_in_tree(),"Visibility getter alone does not prove live tree membership")
	detached.free()
	var parent:=Node3D.new();var leaf:=Node3D.new();root.add_child(parent);parent.add_child(leaf)
	var retained:={"visible":leaf.is_visible_in_tree()};var observed: Array=[]
	var leaf_update:=func():retained.visible=leaf.is_visible_in_tree()
	var parent_observer:=func():observed.append({"live":leaf.is_visible_in_tree(),"retained":retained.visible,"inside":leaf.is_inside_tree()})
	leaf.visibility_changed.connect(leaf_update);parent.visibility_changed.connect(parent_observer)
	parent.hide();check(retained.visible==false,"Leaf event eventually follows parent hide")
	parent.show();check(retained.visible==true,"Leaf event eventually follows parent show")
	check(observed.size()==2,"Both synchronous parent visibility changes are observed")
	if observed.size()==2:
		check(observed[0].live==false and observed[0].retained==true and observed[0].inside,"A reentrant parent-hide listener sees stale leaf retained visibility")
		check(observed[1].live==true and observed[1].retained==false and observed[1].inside,"A reentrant parent-show listener sees stale leaf retained visibility")
	leaf.visibility_changed.disconnect(leaf_update);parent.visibility_changed.disconnect(parent_observer)
	parent.free();await process_frame;await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observed":observed,"engine":Engine.get_version_info(),"network_connections":0,"gpu_execution":false,"scope":"Pinned-engine tree/visibility notification boundary proof only. Demonstrates why leaf-signal retention alone and omission of live membership gates are not accepted; changes no rendering or simulation behavior."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
