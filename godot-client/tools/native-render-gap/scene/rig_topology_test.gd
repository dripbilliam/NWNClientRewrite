extends SceneTree
const Census=preload("res://rig_topology_census.gd")
var checks:=0
var failures: Array=[]
var output:=""
func _initialize()->void:call_deferred("run")
func check(okay: bool,label: String)->void:
	checks+=1
	if not okay:failures.append(label)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	var owner:=Node3D.new();root.add_child(owner)
	var nodes: Array=[]
	for index in 64:
		var node:=Node3D.new();(owner if index==0 else nodes[index-1]).add_child(node);nodes.append(node)
	var work:=Census.model_work({"nodes":nodes,"manual_poses":{}},range(64),{})
	check(work.setters_per_publication==192,"64Part chain has192 original setters")
	check(work.propagation_visits_per_publication==6240,"Unconditional subtree traversal has6240visits")
	check(work.maximum_subtree_depth==64,"Exact deepest chain")
	check(work.local_notifications==0 and work.scripted_parts==0 and work.nonplain_parts==0,"Constructed standard Parts have plain callback-free node gates")
	var mesh:=MeshInstance3D.new();nodes.back().add_child(mesh)
	work=Census.model_work({"nodes":nodes,"manual_poses":{}},range(64),{})
	check(work.mesh_visits_per_publication==192 and work.mesh_node_ids==[mesh.get_instance_id()],"One render mesh is revisited by every ancestor setter")
	nodes[32].top_level=true
	work=Census.model_work({"nodes":nodes,"manual_poses":{}},range(64),{})
	check(work.propagation_visits_per_publication==3264,"Top-level child cuts parent propagation while retaining own subtree publication")
	check(work.mesh_visits_per_publication==96,"Top-level child cuts unrelated ancestor mesh visits")
	var manual:={32:{}}
	work=Census.model_work({"nodes":nodes,"manual_poses":manual},range(64),{})
	check(work.manual_skips==1 and work.setters_per_publication==189,"Native manual skip preserved")
	nodes[0].set_notify_local_transform(true)
	work=Census.model_work({"nodes":nodes,"manual_poses":{}},[0],{})
	check(work.local_notifications==1,"Cold local-notification exclusion visible")
	owner.free()
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false}));file.close();quit(0 if failures.is_empty() else 1)
