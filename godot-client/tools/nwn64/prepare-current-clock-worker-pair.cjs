const fs=require('fs');
const path=require('path');
const crypto=require('crypto');
const root=path.resolve(__dirname,'../..');
const base=path.join(root,'.cache/nwn64/geometry-worker-installed-f');
const label=process.argv[2];
if(!/^[a-z]$/.test(label??''))throw Error('Fresh private stage letter required');
const out=path.join(root,`.cache/nwn64/geometry-worker-clock-current-${label}`);
if(fs.existsSync(out))throw Error('Private stage exists');
const source=path.join(base,'tests/geometry_worker_installed_models_test.gd');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
function one(body,from,to){if(body.split(from).length!==2)throw Error('Expected one marker: '+from.slice(0,70));return body.replace(from,to);}
fs.cpSync(base,out,{recursive:true});
let body=fs.readFileSync(source,'utf8');
body=one(body,'const Wind=preload("res://systems/native_render/scene_point_wind.gd")',`const Wind=preload("res://systems/native_render/scene_point_wind.gd")
const Rigs=preload("res://systems/model_rigs.gd")
func clock_metadata(model: Dictionary,asset: Dictionary,id: int,clip: String,anchor: Node3D) -> Dictionary:
	var nodes: Array=[];var parts: Array=[]
	for index in model.nodes.size():
		var original: Dictionary=model.nodes[index];var defaults: Dictionary=asset.defaults[index]
		nodes.append({"name":original.name,"parent":original.parent,"position":defaults.position,"quaternion":defaults.quaternion,"scale":defaults.scale});parts.append(index)
	var attachments: Array=[]
	if nodes.size()>1:attachments.append({"node":1,"external_anchor":anchor,"scale":[1.0,1.0,1.0],"flags":0,"reference_visible":true})
	return {"rigs":{"version":1,"assets":[asset],"entities":[{"id":id,"nodes":nodes,"models":[{"asset":0,"parts":parts,"defaults":asset.defaults,"clip":clip,"time":0.0,"speed":1.0,"loop":true,"follow":true}],"attachments":attachments,"clipMap":{"0":clip}}]},"meshes":[]}
func make_clock_rig(row: Dictionary,model: Dictionary,asset: Dictionary,id: int,clip: String) -> Dictionary:
	var rig_owner:=Rigs.new();row.host.add_child(rig_owner);rig_owner.set_process(false)
	var anchor:=Node3D.new();row.host.add_child(anchor)
	rig_owner.configure({"meshes_by_name":{}},{id:row.host},clock_metadata(model,asset,id,clip,anchor))
	check(rig_owner.stats.failures.is_empty() and rig_owner.entities.has(id),"Original current ModelRigs configures "+str(id))
	return {"owner":rig_owner,"id":id,"clip":clip,"anchor":anchor}
`);
body=one(body,'"worker":native_rng,"owners":[]','"worker":native_rng,"clock_rigs":[],"replaced_rigs":[],"owners":[]');
body=one(body,'["it_torch_000","plc_cndl01","plc_x0_drt","c_goldem","plc_v02","plc_i10","tnp_gmist","plc_u09"]','["it_torch_000","plc_cndl01"]');
body=one(body,'var rig: Dictionary=parser.rig_asset(model);var model_emitters:=0',`var rig: Dictionary=parser.rig_asset(model);var model_emitters:=0
		check(not rig.clips.is_empty(),"Installed original model has an animation clock "+name)`);
body=one(body,'for row: Dictionary in rows:\n\t\t\tvar source:=Node3D.new();source.name=name;row.host.add_child(source)',`for row: Dictionary in rows:
			var model_id:=1000+observations.size();var first_clip:=str(rig.clips[0].name)
			var binding: Dictionary=make_clock_rig(row,model,rig,model_id,first_clip)
			row.clock_rigs.append(binding)
			var source:=Node3D.new();source.name=name;row.host.add_child(source)`);
body=one(body,'"sourceId":source.get_instance_id()','"sourceId":binding.owner.entities[model_id].nodes[1].get_instance_id()');
body=one(body,'"wind_token":row.wind.token,"culling":true}).has("error")','"wind_token":row.wind.token,"culling":true,"clock":binding.owner.playback_state.bind(model_id,0)}).has("error")');
body=one(body,'var observations: Array=[];var unsupported: Array=[];var total_emitters:=0','var observations: Array=[];var unsupported: Array=[];var total_emitters:=0;var clock_witnesses:=0;var clock_changes:=0;var clock_restarts:=0;var previous_clocks: Dictionary={};var attachment_moves:=0;var replacements:=0;var retired:=0');
body=one(body,'row.events.clear();row.wind.tick(1.0/60.0)',`row.events.clear();row.wind.tick(1.0/60.0)
			for binding: Dictionary in row.clock_rigs:
				binding.anchor.position=Vector3(frame*0.03,0.25+frame*0.01,0.0)
				if frame in [0,12] and binding.owner.entities.has(binding.id):
					binding.owner._play(binding.owner.entities[binding.id].models[0],str(binding.clip),true,1.0,frame*0.03125,true)
				binding.owner._update(0.03125)
				binding.owner.sync_attachments(binding.id)
			if frame==20:
				for index in row.clock_rigs.size():
					var old_binding: Dictionary=row.clock_rigs[index]
					var new_binding: Dictionary=make_clock_rig(row,old_binding.model,old_binding.asset,old_binding.id,str(old_binding.clip))
					row.replaced_rigs.append(old_binding);row.clock_rigs[index]=new_binding
					for node: Node3D in row.nodes:
						if str(row.origins[row.nodes.find(node)])==str(old_binding.name):row.presentation.call("dispatch",4,{"id":node.get_instance_id(),"clock":new_binding.owner.playback_state.bind(new_binding.id,0)})
					replacements+=1
			if frame==28:
				row.presentation.call("dispatch",3,{"id":row.nodes[0].get_instance_id()});retired+=1`);
body=one(body,'row.clock_rigs.append(binding)','binding.model=model;binding.asset=rig;binding.name=name;row.clock_rigs.append(binding)');
body=one(body,'check(rows[0].rng.state==rows[1].rng.state and rows[0].rng.draws==rows[1].rng.draws and rows[0].events==rows[1].events,"Exact original-model shared RNG and external-service order "+str(frame))',`check(rows[0].rng.state==rows[1].rng.state and rows[0].rng.draws==rows[1].rng.draws and rows[0].events==rows[1].events,"Exact original-model shared RNG and external-service order "+str(frame))
		for clock_index in rows[0].clock_rigs.size():
			var left: Dictionary=rows[0].clock_rigs[clock_index];var right: Dictionary=rows[1].clock_rigs[clock_index]
			var left_clock: Dictionary=left.owner.playback_state(left.id,0);var right_clock: Dictionary=right.owner.playback_state(right.id,0)
			check(left_clock==right_clock,"Exact current original ModelRigs clock "+str(frame)+"/"+str(clock_index));clock_witnesses+=1
			check(not left_clock.is_empty(),"Current original model clock remains available "+str(frame)+"/"+str(clock_index))
			if previous_clocks.has(clock_index) and previous_clocks[clock_index]!=left_clock:clock_changes+=1
			if frame==12 and previous_clocks.has(clock_index) and int(previous_clocks[clock_index].get("serial",0))!=int(left_clock.get("serial",0)):clock_restarts+=1
			previous_clocks[clock_index]=left_clock.duplicate()
			var left_held: Node3D=rows[0].replaced_rigs[clock_index].owner.entities[left.id].nodes[1] if frame>=20 else left.owner.entities[left.id].nodes[1]
			var right_held: Node3D=rows[1].replaced_rigs[clock_index].owner.entities[right.id].nodes[1] if frame>=20 else right.owner.entities[right.id].nodes[1]
			check(left_held.global_transform==right_held.global_transform,"Exact attached source pose "+str(frame)+"/"+str(clock_index))
			if frame>0 and left_held.global_position.x>0:attachment_moves+=1`);
body=one(body,'var worker_stats: Dictionary=rows[1].presentation.call("dispatch",7,{})',`check(clock_witnesses>=36 and clock_changes>0 and clock_restarts==2 and attachment_moves>0 and replacements==4 and retired==2,"Clock, restart, attachment, replacement and retirement boundaries exercised")
	var worker_stats: Dictionary=rows[1].presentation.call("dispatch",7,{})`);
body=one(body,'"unsupported":unsupported,"network_connections":0','"unsupported":unsupported,"clock_witnesses":clock_witnesses,"clock_changes":clock_changes,"clock_restarts":clock_restarts,"attachment_moves":attachment_moves,"clock_replacements":replacements,"retired_emitters":retired,"network_connections":0');
body=one(body,'"scope":"Private OFF/ON geometry-worker pair over eight installed original MDLs and their authored emitter fields/TRS/controller pools; exact ordered native packet/state/RNG/service callbacks and worker execution. Controlled chunk callbacks and clip authority; no texture/child-Gob/GPU/FPS claim."','"scope":"Private OFF/ON original-model pair with current ModelRigs.playback_state clock, native attachment source, play/restart, authority replacement and emitter retirement; exact ordered packet/state/RNG/clock/attachment witnesses. Controlled attachment metadata, no texture/GPU/FPS claim."');
const target=path.join(out,'tests/geometry_worker_current_clock_test.gd');fs.writeFileSync(target,body);
const receipt={source:path.relative(root,source).replaceAll('\\','/'),sourceSha256:hash(fs.readFileSync(source)),derivedSha256:hash(Buffer.from(body)),modelRigsSha256:hash(fs.readFileSync(path.join(out,'systems/model_rigs.gd'))),binarySha256:hash(fs.readFileSync(path.join(out,'.cache/native-kernel/nwn-particle-kernel.dll'))),privateProject:out,sourceWritesOutsideStage:0};
fs.writeFileSync(path.join(out,'current-clock-receipt.json'),JSON.stringify(receipt,null,2)+'\n');console.log(JSON.stringify(receipt));
