extends SceneTree
const Census=preload("res://tools/native-render-gap/scene/rig_topology_census_v2.gd")
const Chunks=preload("res://systems/native_render/chunk_models.gd")
var checks:=0
var failures: Array=[]
var output:=""
func _initialize()->void:call_deferred("run")
func check(okay: bool,label: String)->void:
	checks+=1
	if not okay:failures.append(label);print("FAIL ",label)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	var owner:=Node3D.new();root.add_child(owner)
	var part:=Node3D.new();part.name="Part";owner.add_child(part)
	var rigid_mesh:=MeshInstance3D.new();part.add_child(rigid_mesh)
	var skeleton:=Skeleton3D.new();skeleton.name="Skeleton";skeleton.add_bone("bone");owner.add_child(skeleton)
	var skin_mesh:=MeshInstance3D.new();owner.add_child(skin_mesh);skin_mesh.skeleton=skin_mesh.get_path_to(skeleton)
	var player:=AnimationPlayer.new();owner.add_child(player);player.root_node=NodePath("..");player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var animation:=Animation.new();animation.length=2
	for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:
		var track:=animation.add_track(type);animation.track_set_path(track,NodePath("Part"));animation.track_insert_key(track,0,Quaternion.IDENTITY if type==Animation.TYPE_ROTATION_3D else Vector3.ONE)
	var bezier:=animation.add_track(Animation.TYPE_BEZIER);animation.track_set_path(bezier,NodePath("Part:position:x"));animation.bezier_track_insert_key(bezier,0,2)
	var bone:=animation.add_track(Animation.TYPE_POSITION_3D);animation.track_set_path(bone,NodePath("Skeleton:bone"));animation.track_insert_key(bone,0,Vector3.ONE)
	var library:=AnimationLibrary.new();library.add_animation("clip",animation);player.add_animation_library("",library);player.play("clip")
	var chunks=Chunks.new();chunks.resource="null";owner.add_child(chunks);chunks.models.append(part)
	var before:=[part.position,part.quaternion,part.scale,player.current_animation_position]
	var result:=Census.capture(owner)
	check(result.ordinary_players.size()==1,"All active ordinary players found")
	var row: Dictionary=result.ordinary_players[0]
	check(row.effective_ordinary_publisher and row.callback_mode==AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,"Manual advancement ownership remains ordinary")
	check(row.tracks.size()==5,"Loaded3D and bezier tracks inspected without resolving or sampling")
	check(row.node_transform_targets==[part.get_instance_id()],"Three transform channels coalesce to one target identity")
	check(row.bone_targets==[skeleton.get_instance_id()],"Bone track distinguished from Node3D subtree transform")
	check(row.tracks[0].mesh_node_ids==[rigid_mesh.get_instance_id()],"Rigid descendant render mesh identity joined")
	check(row.tracks[4].mesh_node_ids==[skin_mesh.get_instance_id()] and row.tracks[4].subtree_visits==0,"Bone track joins bound skin mesh without claiming Node3D traversal")
	check(result.chunk_owner_count==1 and result.chunks.size()==1 and result.chunk_resources["null"].models==1,"Chunk owner/resource/live model counted")
	check(result.chunks[0].mesh_node_ids==[rigid_mesh.get_instance_id()],"Chunk motion joins same render mesh target")
	check(before==[part.position,part.quaternion,part.scale,player.current_animation_position],"Census neither advances animation nor changes transform state")
	chunks.models.clear();owner.free()
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false}));file.close();quit(0 if failures.is_empty() else 1)
