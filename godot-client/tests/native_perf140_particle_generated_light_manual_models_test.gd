extends "res://tests/native_perf140_particle_generated_light_manual_test.gd"
# Actual installed fx_placeable01 through the production native preparation,
# ActorInstance/ModelRigs, generated-light owner and palette path. No GPU pixels.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
class TestWorld:
	extends Node3D
	signal instance_ready(id: int,source: Dictionary,instance)
	signal instance_removed(id: int)
	var area_id:=123
	var instances: Dictionary={}
class Body:
	extends Node3D
	var parts: Array=[]
func ready_inputs(owner: Node,expected: int) -> bool:
	return owner.errors.is_empty() and owner.requests.is_empty() and owner.tables.has_all(["placeables","lightcolor"]) and not owner.bundle.is_empty() and (expected<0 or owner.instances.size()==expected and not owner.dirty)
func settle(owner: Node,expected: int) -> void:
	var deadline:=Time.get_ticks_msec()+30000
	while not ready_inputs(owner,expected) and owner.errors.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(ready_inputs(owner,expected),"Production generated-light preparation settles cleanly: "+JSON.stringify(owner.errors))
func run() -> void:
	var args: Dictionary={}
	for value in OS.get_cmdline_user_args():
		var pair:=value.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed original assets mount read-only")
	var scene:=Node3D.new();root.add_child(scene);var worlds: Array=[];var observations: Array=[]
	for retained in [false,true]:
		set_mode(retained)
		var world:=TestWorld.new();scene.add_child(world)
		var pool:=Pool.new();pool.native_lighting=true
		var owner:=Placeables.new();world.add_child(owner);owner.configure(world,catalog,pool,"",[])
		await settle(owner,-1)
		if not ready_inputs(owner,-1):break
		var appearance:=-1
		for index in owner.tables.placeables.orderedRows.size():
			if not Placeables.definition(owner.tables.placeables,owner.tables.lightcolor,index).is_empty():appearance=index;break
		check(appearance>=0,"Installed authoritative table supplies a real enabled generated-light appearance")
		if appearance<0:break
		owner.receive_area([{"id":17,"appearance":appearance,"position":[1.0,2.0,0.0]},{"id":18,"appearance":appearance,"position":[4.0,5.0,0.0]}])
		await settle(owner,2);owner.set_process(false)
		if not ready_inputs(owner,2):break
		var body:=Body.new();world.add_child(body);var anchor:=Node3D.new();anchor.set_meta("native_part_parent",-1);body.add_child(anchor);body.parts.append(anchor);world.instances[17]=body
		var object:={"id":17,"areaId":world.area_id,"objectType":9,"replicated":{"appearance":appearance,"position":[1.0,2.0,0.0],"lightOn":true}}
		owner.receive([object]);owner._process(0.0)
		check(owner.instances[17].anchor_node==anchor,"Actual canonical owner reuses and attaches one dynamic light")
		var items: Array=[]
		for id in [17,18]:
			var model: Node3D=owner.instances[id];model.set_process(false);model.rigs.set_process(false)
			var part: Node3D=model.node_for(0,"root");var light: Node3D=model.node_for(0,"auroralight01").get_child(0)
			items.append({"publisher":owner,"model":model,"rig":model.rigs,"part":part,"entry":model.rigs.entities[0],"light":light,"anchor":anchor,"retained":retained,"id":id})
			var manual: Dictionary=model.rigs.entities[0].manual_poses.values()[0]
			var q: Quaternion=manual.quaternion;var s: Vector3=manual.scale
			observations.append({"retained":retained,"id":id,"dynamic":id==17,"model_names":model.model_names.duplicate(),"publisher_id_matches":owner.instances.get(int(model.get_meta("native_generated_placeable_id")))==model,"quaternion_bits":Array(bytes([q.x,q.y,q.z,q.w])),"scale_bits":Array(bytes([s.x,s.y,s.z])),"state":model.rigs.generated_manual_snapshot()})
		worlds.append({"world":world,"pool":pool,"owner":owner,"items":items,"body":body,"anchor":anchor,"appearance":appearance,"model_sha256":owner.bundle.sha256})
	check(worlds.size()==2,"Paired ordinary and selected installed models actually exist")
	if worlds.size()==2:
		for frame in 24:
			for row: Dictionary in worlds:
				set_mode(row.items[0].retained)
				row.body.position=Vector3(frame*0.02,sin(frame*0.1)*0.03,cos(frame*0.13)*0.05);row.body.rotation=Vector3(0.03,frame*0.02,-0.01);row.body.scale=Vector3(1.2,0.8,1.1)
				if frame in [6,12]:
					var plan: Dictionary=row.owner.configurations[18].duplicate(true);plan.offset=[0.1,0.2,0.7] if frame==6 else [0.0,0.0,3.0]
					check(row.owner.apply(18,plan),"Actual authoritative plan update keeps generated ownership")
				for item: Dictionary in row.items:item.rig._update(0.016);item.model._process(0.016)
			for index in 2:
				var a:=sample(worlds[0].items[index]);var b:=sample(worlds[1].items[index]);a.erase("pose_frames");b.erase("pose_frames")
				check(a==b,"Exact installed static/dynamic local/global/palette/particle inputs "+str(frame)+"/"+str(index))
			if not failures.is_empty():break
	var coverage:={"candidates":0,"active":0,"armed":0,"omitted":0,"reasons":{},"records":[]}
	if worlds.size()==2:
		for item: Dictionary in worlds[1].items:
			var rows: Array=item.rig.generated_manual_snapshot().entries
			for record: Dictionary in rows:
				coverage.candidates+=1;coverage.active+=int(record.active);coverage.armed+=int(record.armed);coverage.omitted+=int(record.omitted_publications)
				coverage.reasons[record.reason]=int(coverage.reasons.get(record.reason,0))+1;coverage.records.append(record)
		check(coverage.candidates==2,"Coverage reports both REAL canonical owners, never assumes room count34")
		if coverage.active>0:check(coverage.omitted>0,"Any admitted installed owner actually uses retained publication")
		else:check(coverage.omitted==0,"Unsupported real tuples retain complete original updates")
	for row: Dictionary in worlds:row.owner.close();row.pool.clear()
	worlds.clear();scene.free();await process_frame;await process_frame;set_mode(false)
	check(Palette.active.is_empty(),"Actual installed model retirement releases every palette slot")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"coverage":coverage,"server_connections":0,"gpu_execution":false,"scope":"Actual installed fx_placeable01 and native base tables through production preparation/canonical ownership with exact ordinary-vs-retained local/global/light/palette/particle inputs; measured restrictive enrollment coverage, no GPU/FPS acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
