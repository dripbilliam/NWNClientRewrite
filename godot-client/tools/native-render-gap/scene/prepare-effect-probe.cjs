const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../../..');
const label=process.argv[2]??'effect-activity-probe-a';
if(!/^[a-z0-9-]+$/.test(label))throw Error('Invalid fresh stage label');
const directory=path.join(project,'.cache/native-render-gap/scene',label);
if(fs.existsSync(directory))throw Error('Existing probe is frozen');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const rows=[];
function put(relative,bytes,originalSha256=null){const file=path.join(directory,'overlay',relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});rows.push({relative,file,sha256:sha(bytes),originalSha256});}
function source(relative){return fs.readFileSync(path.join(project,relative),'utf8').replace(/\r\n/g,'\n');}
function once(s,a,b){if(s.split(a).length!==2)throw Error('Probe seam changed: '+a);return s.replace(a,b);}
const effectPath='systems/native_render/effect_world.gd';
const effectSource=source(effectPath);let effect=effectSource;
effect=once(effect,'\tcasts.advance()\n','\tvar child_began:=Timing.begin()\n\tTiming.count("count_effect_entries",entries.size());Timing.count("count_effect_records",records.size());Timing.count("count_effect_models",models.size());Timing.count("count_effect_pending",queue.size())\n\tcasts.advance()\n\tTiming.finish("effect_child_casts",child_began);child_began=Timing.begin()\n');
for(const [call,name]of[['blood.advance()','blood'],['parries.advance()','parries'],['special_attacks.advance(delta)','special'],['equipped_attacks.advance()','equipped'],['creature_voices.advance()','voice']])effect=once(effect,'\t'+call+'\n','\t'+call+'\n\tTiming.finish("effect_child_'+name+'",child_began);child_began=Timing.begin()\n');
effect=once(effect,'\tsuper._process(delta)\n','\tTiming.finish("effect_sources_and_definitions",child_began);child_began=Timing.begin()\n\tsuper._process(delta)\n\tTiming.finish("effect_physical_list",child_began)\n');
put(effectPath,effect,sha(Buffer.from(effectSource)));

// Diagnostic wrappers preserve every original return and synchronous callback.
// Their timers overlap the parent list span and must never be added to it.
function wrap(relative,signature,renamed,returnValue,metric){const original=source(relative);let body=original;const head=signature+'\n';const suffix=signature.slice(signature.indexOf('('));const args=suffix.slice(1,suffix.indexOf(')')).split(',').filter(Boolean).map(x=>x.trim().split(':')[0].trim().split('=')[0].trim()).join(',');const name=signature.slice(5,signature.indexOf('('));const timer=relative.includes('visual_world')?'SelectionTiming':'preload("res://systems/native_render/frame_profile.gd")';const wrapper=head+'\tvar probe_began: int='+timer+'.begin()\n'+(returnValue?'\tvar probe_result: Variant='+renamed+'('+args+')\n':'\t'+renamed+'('+args+')\n')+'\t'+timer+'.finish("'+metric+'",probe_began)\n'+(returnValue?'\treturn probe_result\n':'')+'\nfunc '+renamed+suffix+'\n';body=once(body,head,wrapper);return {relative,original,body};}
const worldPath='systems/visual_world.gd';let world=source(worldPath);const worldOriginal=world;
for(const [signature,renamed,returns,metric]of[
 ['func _bound(entry: Dictionary) -> bool:','_probe_original_bound',true,'effect_bound_checks'],
 ['func _begin(entry: Dictionary) -> void:','_probe_original_begin',false,'effect_begin'],
 ['func _status(entry: Dictionary, stage: String) -> void:','_probe_original_status',false,'effect_status']
]){const head=signature+'\n';const suffix=signature.slice(signature.indexOf('('));const args=suffix.slice(1,suffix.indexOf(')')).split(',').map(x=>x.trim().split(':')[0]).join(',');world=once(world,head,head+'\tvar probe_began:=SelectionTiming.begin()\n'+(returns?'\tvar probe_result: bool='+renamed+'('+args+')\n':'\t'+renamed+'('+args+')\n')+'\tSelectionTiming.finish("'+metric+'",probe_began)\n'+(returns?'\treturn probe_result\n':'')+'\nfunc '+renamed+suffix+'\n');}
put(worldPath,world,sha(Buffer.from(worldOriginal)));
for(const spec of[
 ['systems/visual_clock.gd','func advance(delta: float) -> bool:','_probe_original_advance',true,'effect_clock_advance'],
 ['systems/visual_runtime.gd','func refresh_bindings() -> void:','_probe_original_refresh',false,'effect_binding_refresh'],
 ['systems/visual_runtime.gd','func _view(id: int) -> Variant:','_probe_original_view',true,'effect_view_projection']
]){let [relative,signature,renamed,returns,metric]=spec;const prior=rows.find(x=>x.relative===relative);const prepared=wrap(relative,signature,renamed,returns,metric);if(prior){const previous=fs.readFileSync(prior.file,'utf8');const head=signature+'\n';const replacement=prepared.body.slice(prepared.body.indexOf(head),prepared.body.indexOf('\nfunc '+renamed)+1)+prepared.body.slice(prepared.body.indexOf('func '+renamed),prepared.body.indexOf('func '+renamed)+('func '+renamed+signature.slice(signature.indexOf('('))+'\n').length);const updated=once(previous,head,replacement);fs.writeFileSync(prior.file,updated);prior.sha256=sha(updated);}else put(relative,prepared.body,sha(Buffer.from(prepared.original)));}
const livePath='systems/native_render/live_world.gd';const liveOriginal=source(livePath);let live=liveOriginal;
if(process.argv.includes('--pose-detail')){
 live=once(live,'func apply_pose(id: int) -> void:\n\tif not instances.has(id) or not desired.has(id): return\n','func apply_pose(id: int) -> void:\n\tif not instances.has(id) or not desired.has(id): return\n\tvar pose_detail_began:=FrameProfile.begin()\n');
 live=once(live,'\tif pose.is_empty(): return\n\tstats.pose_evaluations+=1\n','\tFrameProfile.finish("world_pose_derive",pose_detail_began);pose_detail_began=FrameProfile.begin()\n\tif pose.is_empty(): return\n\tstats.pose_evaluations+=1\n');
 live=once(live,'\tvar node_id:=instance.get_instance_id()\n','\tFrameProfile.finish("world_pose_root",pose_detail_began);pose_detail_began=FrameProfile.begin()\n\tvar node_id:=instance.get_instance_id()\n');
 live=once(live,'\telse: static_collision_index.erase(node_id)\n\tif creature:\n','\telse: static_collision_index.erase(node_id)\n\tFrameProfile.finish("world_pose_collision",pose_detail_began);pose_detail_began=FrameProfile.begin()\n\tif creature:\n');
 live=once(live,'\t\tif is_instance_valid(combat):\n\t\t\tcombat.base_frame','\t\tFrameProfile.finish("world_pose_gait_and_clip",pose_detail_began);pose_detail_began=FrameProfile.begin()\n\t\tif is_instance_valid(combat):\n\t\t\tcombat.base_frame');
 live=once(live,'\t\tif is_instance_valid(effects) and effects.casts!=null: effects.casts.observe(object,code)\n','\t\tFrameProfile.finish("world_pose_combat_base",pose_detail_began);pose_detail_began=FrameProfile.begin()\n\t\tif is_instance_valid(effects) and effects.casts!=null: effects.casts.observe(object,code)\n\t\tFrameProfile.finish("world_pose_cast_observe",pose_detail_began);pose_detail_began=FrameProfile.begin()\n');
 live=once(live,'\t\tif is_instance_valid(effects) and effects.special_attacks!=null: effects.special_attacks.observe(object)\n','\t\tif is_instance_valid(effects) and effects.special_attacks!=null: effects.special_attacks.observe(object)\n\t\tFrameProfile.finish("world_pose_special_observe",pose_detail_began);pose_detail_began=FrameProfile.begin()\n');
 live=once(live,'\t\tif is_instance_valid(effects) and effects.equipped_attacks!=null: effects.equipped_attacks.observe(object)\n','\t\tif is_instance_valid(effects) and effects.equipped_attacks!=null: effects.equipped_attacks.observe(object)\n\t\tFrameProfile.finish("world_pose_equipped_observe",pose_detail_began)\n');
}
live=once(live,'\tapply_poses()\n\tcombat.update(delta,desired)\n','\tFrameProfile.count("count_live_motion_owners",motion.objects.size())\n\tvar pose_child_began:=FrameProfile.begin()\n\tapply_poses()\n\tFrameProfile.finish("world_apply_poses",pose_child_began);pose_child_began=FrameProfile.begin()\n\tcombat.update(delta,desired)\n\tFrameProfile.finish("world_combat_update",pose_child_began);pose_child_began=FrameProfile.begin()\n');
live=once(live,'\tFrameProfile.finish("world_poses",phase_began)\n','\tFrameProfile.finish("world_pose_finish_frame",pose_child_began)\n\tFrameProfile.finish("world_poses",phase_began)\n');
put(livePath,live,sha(Buffer.from(liveOriginal)));
put('tools/native-render-gap/scene/effect_activity_census.gd',fs.readFileSync(path.join(__dirname,'effect_activity_census.gd')));
const manifest={version:1,createdAtUtc:new Date().toISOString(),directory,rows,installed:false,launches:0,parseTested:false,poseDetail:process.argv.includes('--pose-detail'),scope:'Source-only diagnostic overlays. Child spans overlap parent callbacks. Wrapper timers and profile bookkeeping affect CPU; never use this stage for clean FPS acceptance.',coldHook:'preload("res://tools/native-render-gap/scene/effect_activity_census.gd").capture(world)',sourceGuard:'OriginalSha256 hashes normalized LF text. Preparation stops if replacement seams are absent or ambiguous; root must freeze inputs and pin manifest before any launch.'};
fs.mkdirSync(directory,{recursive:true});fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(manifest,null,2),{flag:'wx'});console.log(JSON.stringify({directory,files:rows.length,launches:0}));
