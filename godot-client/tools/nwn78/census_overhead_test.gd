extends SceneTree
const Census=preload("res://tools/nwn78/persistent_state_census.gd")
class MotionState extends RefCounted:
	var objects: Dictionary={}
class QueryState extends RefCounted:
	var entries: Dictionary={}
class WorldState extends Node3D:
	var generation:=1
	var area_id:=91
	var controlled_id:=1
	var desired: Dictionary={}
	var installed: Dictionary={}
	var instances: Dictionary={}
	var batches: Array=[]
	var motion:=MotionState.new()
	var drive_collision: Node=null
	var terrain: Node=null
	var static_collision_index:=QueryState.new()
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var world:=WorldState.new();root.add_child(world)
	var shared: Array[ArrayMesh]=[]
	for index in 20:shared.append(ArrayMesh.new())
	var branches: Array[Node3D]=[]
	for index in 100:
		var branch:=Node3D.new();world.add_child(branch);branches.append(branch)
	for index in 10000:
		var node: Node3D=MeshInstance3D.new() if index%4==0 else Node3D.new()
		if node is MeshInstance3D:node.mesh=shared[index%20]
		if index%5==0:node.name="part_"+str(index)
		elif index%13==0:node.name="native_emitter"
		branches[index%100].add_child(node)
	var samples: Array=[];var observed: Dictionary={}
	for index in 3:
		observed=Census.capture(world,"synthetic")
		samples.append(observed.census_ms)
	var passed: bool=observed.subtree_nodes==10101 and observed.mesh_instances==2500 and observed.unique_mesh_resources==5 and not observed.truncated
	var output:={"passed":passed,"samples_ms":samples,"node_count":observed.subtree_nodes,"mesh_instances":observed.mesh_instances,"unique_mesh_resources":observed.unique_mesh_resources,"linear_60000_node_extrapolation_ms":float(samples[1])*60000.0/float(observed.subtree_nodes),"scope":"Bounded synthetic 10,101-Node headless census overhead only; actual world cost may differ. No FPS or client benchmark."}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file:=FileAccess.open(arg.substr(9),FileAccess.WRITE);file.store_string(JSON.stringify(output,"\t"));file.close()
	print(JSON.stringify(output));world.free();quit(0 if passed else 1)
