extends "res://tests/nwn62_frame_gap_test.gd"
const Door=preload("res://systems/native_render/door_instance.gd")
const Placeable=preload("res://systems/native_render/placeable_instance.gd")
class Jobs extends Node:
	var pending: Dictionary={}
	var running: Dictionary={}
	var maximum_pending:=4
	var maximum_workers:=1
	func close()->void:pass
func original_input()->Dictionary:
	var input:=actor_input();input.value.nodes=input.value.nodes.slice(0,2)
	var defaults: Array=input.value.rig_asset.defaults.slice(0,2);var clips: Array=[]
	for name in ["closed","opened1","on","off"]:
		clips.append({"name":name,"length":1.0,"transition":0.0,"events":[],"tracks":[{"part":1,"property":"position","keys":[{"time":0.0,"value":[float(clips.size()),0.0,0.0]}],"sourceInterpolation":"linear"}]})
	input.value.rig_asset={"defaults":defaults,"clips":clips,"unsupported":[]};return input
func stream_fixture(input: Dictionary,kind: int)->Dictionary:
	var context:=setup();context.actor.free();context.erase("actor")
	context.world.pool.cooperative_templates=true;context.world.pool.publication_budget_us=1
	var row:={"id":7,"objectType":kind,"replicated":{"animation":22,"doorOpenState":0} if kind==10 else {"animation":73,"animationSpeed":1.0}}
	context.world.desired={7:{"key":"current","object":row}}
	var stream:=Objects.new();stream.admission_parent=context.world;stream.publication_keys={7:"current"};stream.pool=context.world.pool;stream.assets=Jobs.new();stream.add_child(stream.assets);context.world.add_child(stream);stream.set_process(false)
	stream.queue=[{"model":"staged","bundle":input,"placement":{"id":7,"position":Vector3.ZERO,"rotation":0.0,"object":row}}]
	context.stream=stream;context.row=row;return context
func close_stream(context: Dictionary)->void:
	context.stream.close();context.world.close();context.world.free();await process_frame;await process_frame
func normalized_actor(actor)->Dictionary:
	var result:=actor_sample(actor)
	# ActorAlpha intentionally creates private materials for each actor. Compare
	# every stored value rather than expecting those private Resource IDs equal.
	for row in result.meshes:
		var material: Material=row[3];var properties: Dictionary={}
		for property in material.get_property_list():
			if property.name=="actor_alpha_context":properties[property.name]=material.actor_alpha_context.snapshot()
			elif property.name=="actor_alpha_endpoint":properties[property.name]=[material.actor_alpha_endpoint.get_script(),material.actor_alpha_endpoint.closed]
			elif int(property.usage)&PROPERTY_USAGE_STORAGE:properties[property.name]=material.get(property.name)
		row[3]=properties
	return result
func run()->void:
	var input:=original_input()
	for kind in [10,9]:
		var context:=stream_fixture(input,kind);var stream=context.stream;var turns:=0;var changed:=false
		while stream.instances.is_empty() and turns<256:
			stream._profile_process(0);turns+=1
			if stream.instances.has(7):stream.instances[7].rigs.set_process(false);stream.instances[7].set_process(false)
			if is_instance_valid(stream._animated_instance):
				check(not stream._animated_instance.is_inside_tree() and stream.instances.is_empty(),"Animated object stays fully detached across construction frames "+str(kind))
				if not changed and turns>=3:
					context.row.replicated.animation=50 if kind==10 else 74
					if kind==10:context.row.replicated.doorOpenState=1
					changed=true
			await process_frame
		check(stream.instances.has(7) and changed and int(stream.stats.get("superseded_animated_states",0))==1,"Latest received state restarts exactly the superseded private animated object "+str(kind))
		if stream.instances.has(7):
			var actual=stream.instances[7];actual.rigs.set_process(false);actual.set_process(false)
			var expected=Door.new() if kind==10 else Placeable.new()
			check(expected.install_door(input,stream.pool,7,context.row.replicated) if kind==10 else expected.install_placeable(input,stream.pool,7,context.row.replicated),"Synchronous original animated-object adapter remains explicitly available")
			expected.rigs.set_process(false);actual.rigs._update(0);expected.rigs._update(0)
			check(normalized_actor(actual)==normalized_actor(expected),"Staged latest-state physical graph/material/rig clocks equal synchronous adapter "+str(kind))
			if kind==10:
				var a: Dictionary=actual.native_door_pick_snapshot();var b: Dictionary=expected.native_door_pick_snapshot();a.erase("owner_instance");b.erase("owner_instance")
				check(actual.received_state==1 and actual.received_animation==50 and a==b,"Door final received state and authored pick-region diagnostics preserve synchronous output")
			else:check(actual.snapshot_placeable()==expected.snapshot_placeable(),"Placeable final received state/speed and playback preserve synchronous output")
			expected.free()
		await close_stream(context)
		context=stream_fixture(input,kind);stream=context.stream;stream._profile_process(0)
		var pending=weakref(stream._animated_instance)
		context.world.desired[7].key="reused-lifetime";await process_frame;stream._profile_process(0);await process_frame
		check(stream.instances.is_empty() and stream._animated_instance==null and pending.get_ref()==null and int(stream.stats.get("stale_publications",0))==1,"Reused-ID/model generation cancels old private animated construction "+str(kind))
		await close_stream(context)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual ObjectStream staged door/placeable publication with process_frame gaps, detached blockers/helpers, authoritative state replacement, physical/material/clock/pick-state equivalence, reused-ID cancellation and sync rollback APIs. Headless correctness; no FPS measurement."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
