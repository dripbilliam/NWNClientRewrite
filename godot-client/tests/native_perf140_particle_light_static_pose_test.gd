extends SceneTree
# SOURCE ONLY: no parse/run until Root/user explicitly clears a test lane.
# Real Node3D/EffectModel setters and descendants, but no loaded assets/palette/
# native library/server. This cannot establish actual lit-renderer parity alone.
const Ordinary=preload("res://systems/native_render/placeable_lights.gd")
const Candidate=preload("res://tools/perf140/particles/placeable_light_static_pose_candidate.gd")
const EffectModel=preload("res://systems/native_render/effect_model.gd")
class TestWorld extends Node3D:
	var generation:=7
	var area_id:=99
	var closed:=false
	var retiring:=false
	var instances: Dictionary={}
class TestBody extends Node3D:
	var parts: Array=[]
class ReentrantCandidate:
	extends "res://tools/perf140/particles/placeable_light_static_pose_candidate.gd"
	var trigger:=true
	func _ordinary_static_pose(id: int,model: Node3D,point: Vector3) -> void:
		super._ordinary_static_pose(id,model,point)
		if trigger:trigger=false;instance_removed(id)
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func plan(dynamic: bool=false) -> Dictionary:
	return {"appearance":0,"colour_row":0,"color":[1,0.5,0.25],"offset":[0,0,3],"position":[1,2,3],"dynamic":dynamic}
func model_for(owner,id: int,source: Dictionary) -> Node3D:
	var model:=EffectModel.new();model.installed=true;owner.add_child(model)
	owner.instances[id]=model;owner.configurations[id]=source.duplicate(true)
	var endpoint:=Node3D.new();endpoint.name="Endpoint";endpoint.position=Vector3(0.25,1,-0.5);model.add_child(endpoint)
	return model
func outputs(model: Node3D) -> PackedByteArray:
	var endpoint: Node3D=model.get_node("Endpoint")
	# The light/particle/collision consumers read these same current transforms;
	# this state witness is not an actual palette upload/render image assertion.
	return var_to_bytes([model.transform,model.scale,model.rotation_order,model.global_transform,endpoint.global_transform,endpoint.global_position,endpoint.global_transform*Vector3(1,2,3)])
func pair_apply(ordinary,candidate,id: int,source: Dictionary) -> void:
	ordinary.apply(id,source);candidate.apply(id,source)
	check(outputs(ordinary.instances[id])==outputs(candidate.instances[id]),"Original/candidate final local/global/descendant transform bytes match")
func run() -> void:
	var world:=TestWorld.new();root.add_child(world)
	var ordinary:=Ordinary.new();var candidate:=Candidate.new()
	root.add_child(ordinary);root.add_child(candidate);ordinary.set_process(false);candidate.set_process(false)
	ordinary.world=world;candidate.world=world
	var source:=plan();var left:=model_for(ordinary,1,source);var right:=model_for(candidate,1,source)
	pair_apply(ordinary,candidate,1,source)
	check(candidate.static_pose_stats.original_publications==1 and candidate.static_pose_stats.skipped_publications==0,"First publication always original")
	pair_apply(ordinary,candidate,1,source)
	check(candidate.static_pose_stats.original_publications==2,"Second stable publication stays original")
	pair_apply(ordinary,candidate,1,source)
	check(candidate.static_pose_stats.skipped_publications==1,"Only two-stable original boundary can reuse")
	# Parent changes still propagate inherited global dirtiness on their own.
	for owner in [ordinary,candidate]:owner.position=Vector3(4,5,6);owner.rotation=Vector3(0.1,0.3,0.2);owner.scale=Vector3(2,3,4)
	pair_apply(ordinary,candidate,1,source)
	check(candidate.static_pose_stats.skipped_publications==2,"Parent change keeps live descendants without redundant local writes")
	var originals: int=candidate.static_pose_stats.original_publications
	left.visible=false;right.visible=false;pair_apply(ordinary,candidate,1,source)
	check(candidate.static_pose_stats.original_publications==originals+1,"Visibility witness change returns to original")
	left.visible=true;right.visible=true;pair_apply(ordinary,candidate,1,source)
	left.position+=Vector3(7,8,9);right.position+=Vector3(7,8,9);pair_apply(ordinary,candidate,1,source)
	# General scale states are deliberately outside first-version enrollment.
	left.scale=Vector3(2,3,4);right.scale=Vector3(2,3,4)
	var excluded: int=candidate.static_pose_stats.ineligible_original
	pair_apply(ordinary,candidate,1,source);pair_apply(ordinary,candidate,1,source)
	check(candidate.static_pose_stats.ineligible_original==excluded+2,"Nonuniform scale remains original")
	left.scale=Vector3.ONE;right.scale=Vector3.ONE
	# Reparenting away from the canonical manager refuses enrollment.
	var left_parent:=Node3D.new();var right_parent:=Node3D.new();root.add_child(left_parent);root.add_child(right_parent)
	left.reparent(left_parent,false);right.reparent(right_parent,false)
	pair_apply(ordinary,candidate,1,source)
	check(not candidate._static_records.has(1),"Unowned parent cannot retain a publication record")
	left.reparent(ordinary,false);right.reparent(candidate,false)
	pair_apply(ordinary,candidate,1,source)
	# Force real removal wake then reentry, without changing raw plan data.
	candidate.instance_removed(1);ordinary.instance_removed(1)
	check(not candidate._static_records.has(1),"World body retirement revokes before detach")
	pair_apply(ordinary,candidate,1,source);pair_apply(ordinary,candidate,1,source)
	# Dynamic branch retains every original attach_to call and scale recapture.
	var body:=TestBody.new();world.add_child(body);var anchor:=Node3D.new();anchor.set_meta("native_part_parent",-1);body.add_child(anchor);body.parts=[anchor];world.instances[1]=body
	var dynamic:=plan(true)
	for owner in [ordinary,candidate]:owner.configurations[1]=dynamic.duplicate(true)
	pair_apply(ordinary,candidate,1,dynamic);anchor.position=Vector3(8,9,10);pair_apply(ordinary,candidate,1,dynamic)
	check(candidate.static_pose_stats.dynamic_original==2 and not candidate._static_records.has(1),"Dynamic attachments always use original live path")
	for owner in [ordinary,candidate]:owner.configurations[1]=source.duplicate(true)
	pair_apply(ordinary,candidate,1,source);pair_apply(ordinary,candidate,1,source)
	check(not candidate._static_records.has(1),"Previously dynamic generated lifetime remains excluded")
	# Generated model replacement cannot inherit a prior lifetime's record.
	for owner in [ordinary,candidate]:owner.erase(1);model_for(owner,1,source)
	pair_apply(ordinary,candidate,1,source)
	check(candidate._static_records.has(1) and candidate._static_records[1].stable==1,"Replacement receives a fresh first publication")
	# Reentrant removal after setters invalidates an in-flight first grant.
	var reentrant:=ReentrantCandidate.new();root.add_child(reentrant);reentrant.set_process(false);reentrant.world=world;model_for(reentrant,4,source)
	reentrant.apply(4,source)
	check(reentrant.static_pose_stats.reentrant_boundaries==1 and not reentrant._static_records.has(4),"Reentrant wake cannot grant stale record")
	var cold: Dictionary=candidate.snapshot();var kept: int=candidate.static_pose_stats.original_publications
	check(cold.static_outer_pose.enabled and cold.static_outer_pose.mode=="generated-static-outer-pose-v1","Existing cold snapshot proves candidate mode")
	cold.static_outer_pose.stats.original_publications=-1
	check(candidate.static_pose_stats.original_publications==kept,"Cold counters are detached")
	for owner in [ordinary,candidate,reentrant]:owner.close();owner.free()
	left_parent.free();right_parent.free();world.free()
	print("NATIVE_PERF140_PARTICLE_LIGHT_STATIC_POSE ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
