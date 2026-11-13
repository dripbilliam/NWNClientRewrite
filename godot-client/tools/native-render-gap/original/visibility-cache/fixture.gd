extends SceneTree
class Watch:
	extends Node3D
	var observer:Callable
	var reenter_target:Node3D
	var reenter_remaining:=0
	func _notification(what:int)->void:
		if observer.is_valid() and what in [NOTIFICATION_ENTER_TREE,NOTIFICATION_EXIT_TREE,NOTIFICATION_ENTER_WORLD,NOTIFICATION_EXIT_WORLD,NOTIFICATION_VISIBILITY_CHANGED]:
			observer.call(name,what)
		if what==NOTIFICATION_VISIBILITY_CHANGED and reenter_remaining>0 and is_instance_valid(reenter_target):
			reenter_remaining-=1
			reenter_target.visible=not reenter_target.visible
var output:=""
var phase:="setup"
var tracked:Array[Node3D]=[]
var observations:Array=[]
var checks:=0
var failures:Array=[]
func check(value:bool,message:="Visibility predicate failed")->void:
	if not value:
		failures.append([phase,message]);push_error(phase+": "+message)
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	call_deferred("run")
func reference(node:Node3D)->bool:
	# Stable checkpoints only. get_parent_node_3d() is a transform API which
	# returns null for top_level and follows physical parents during callbacks;
	# the original visibility walk uses its separately maintained data.parent.
	if not node.is_inside_tree():return node.visible
	var cursor:=node
	while cursor!=null:
		if not cursor.visible:return false
		cursor=cursor.get_parent() as Node3D
	return true
func observe(source:="step",what:=-1)->void:
	var rows:Array=[]
	for node in tracked:
		if not is_instance_valid(node):continue
		var actual:=node.is_visible_in_tree()
		var expected:=reference(node) if what<0 else actual
		if what<0:check(actual==expected,"Visibility differs from stable original parent walk "+phase+"/"+str(node.name))
		for repeat in 8:check(node.is_visible_in_tree()==expected)
		checks+=9
		var parent:=node.get_parent_node_3d()
		rows.append([str(node.name),node.is_inside_tree(),node.visible,actual,str(parent.name) if parent!=null else ""])
	observations.append([phase,str(source),what,rows])
func make_watch(label:String)->Watch:
	var node:=Watch.new();node.name=label;node.observer=Callable(self,"observe");tracked.append(node);return node
func _worker(node:Node3D,write:bool)->Dictionary:
	var before:=node.is_visible_in_tree()
	if write:node.visible=false
	return {"before":before,"after":node.is_visible_in_tree(),"off_main":OS.get_thread_caller_id()!=OS.get_main_thread_id()}
func run()->void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	if not ClassDB.class_exists("NwnFrameProbe"):quit(3);return
	var top:=make_watch("Top");var a:=make_watch("A");var b:=make_watch("B");var leaf:=make_watch("Leaf");var sibling:=make_watch("Sibling")
	phase="detached_constructor";observe()
	phase="enter";root.add_child(top);top.add_child(a);top.add_child(b);a.add_child(leaf);a.add_child(sibling);observe()
	phase="hide_parent_callbacks";a.hide();observe()
	phase="show_parent_callbacks";a.show();observe()
	phase="noop_same_value";a.visible=true;observe()
	phase="reentrant";leaf.reenter_target=top;leaf.reenter_remaining=1;a.hide();observe();a.show();top.show();observe()
	phase="hidden_prefix";a.hide();observe();check(top.is_visible_in_tree());check(not leaf.is_visible_in_tree());a.show()
	phase="deep_shared";var parent:Node3D=leaf
	for index in 24:
		var node:=make_watch("Deep"+str(index));parent.add_child(node);parent=node
	for iteration in 12:top.visible=(iteration&1)==0;observe("global_epoch_"+str(iteration))
	top.show()
	phase="reparent_to_hidden";b.hide();leaf.reparent(b,false);observe()
	phase="reparent_to_visible";leaf.reparent(a,true);observe()
	phase="top_level_still_inherits_visibility";leaf.top_level=true;a.hide();observe();check(not leaf.is_visible_in_tree());a.show();leaf.top_level=false
	phase="visibility_parent_rid_independent";var anchor:=MeshInstance3D.new();anchor.name="VisibilityAnchor";tracked.append(anchor);top.add_child(anchor);anchor.hide();leaf.visibility_parent=NodePath("../../VisibilityAnchor");observe();check(leaf.is_visible_in_tree());leaf.visibility_parent=NodePath("")
	phase="node_barrier";var barrier:=Node.new();barrier.name="PlainNodeBarrier";a.add_child(barrier);leaf.reparent(barrier,false);a.hide();observe();check(leaf.is_visible_in_tree());a.show();leaf.reparent(a,false);barrier.free()
	phase="pause_modes";paused=true;leaf.process_mode=Node.PROCESS_MODE_DISABLED;observe();paused=false;leaf.process_mode=Node.PROCESS_MODE_ALWAYS;observe();leaf.process_mode=Node.PROCESS_MODE_INHERIT
	phase="subthread_owner_main_caller";a.process_thread_group=Node.PROCESS_THREAD_GROUP_SUB_THREAD;observe();a.process_thread_group=Node.PROCESS_THREAD_GROUP_MAIN_THREAD;observe();a.process_thread_group=Node.PROCESS_THREAD_GROUP_INHERIT
	phase="exit_and_reattach";root.remove_child(top);observe();root.add_child(top);observe()
	phase="outside_tree_worker_read";var outside:=Node3D.new();outside.name="OutsideWorker";tracked.append(outside);observe();var worker:=Thread.new();check(worker.start(Callable(self,"_worker").bind(outside,false))==OK);var read_result:Dictionary=worker.wait_to_finish();check(read_result=={"before":true,"after":true,"off_main":true});observe()
	# This final off-main authored write intentionally tests permanent fail-closed
	# fallback; the node is detached, so existing debug API guards permit it.
	phase="outside_tree_worker_write_disables";check(worker.start(Callable(self,"_worker").bind(outside,true))==OK);var write_result:Dictionary=worker.wait_to_finish();check(write_result=={"before":true,"after":false,"off_main":true});observe()
	phase="after_disable_reparent_visibility";b.hide();leaf.reparent(b,false);observe();b.show();observe()
	var totals:Dictionary=ClassDB.class_call_static("NwnFrameProbe","feature_totals")
	var cache:Dictionary=totals.get("visibility_chain_cache",{})
	check(cache.get("available",false))
	var enabled:=OS.get_cmdline_user_args().has("--visibility-chain-cache=epochs")
	if enabled:
		check(cache.enabled and cache.hits>0 and cache.misses>0 and cache.ancestor_hits>0 and cache.fills>0 and cache.main_fallbacks>0 and cache.off_main_reads>=2 and cache.off_main_writes==1 and cache.disabled)
	else:check(not cache.enabled and cache.queries==0 and cache.hits==0 and cache.visible_invalidations==0)
	var report:Dictionary={"success":failures.is_empty(),"failures":failures,"checks":checks,"observations":observations,"worker_read":read_result,"worker_write":write_result,"cache":cache,"scope":"Actual headless Node3D subclass callbacks, authored visibility, ENTER/EXIT world and tree, reentry, deep/shared hidden chains, reparent, plain Node barrier, top-level, visibility-parent RID, pause/process group fallback, detached worker read/write. No GPU/FPS claim."}
	phase="cleanup";tracked.clear();outside.free();top.free()
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close();quit()
