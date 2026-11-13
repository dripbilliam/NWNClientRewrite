'use strict';
// Standalone correctness capsule. Its only extension registration is LOCAL to
// this new private project; there is no autoload, editor import or live client.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const arg=n=>process.argv.find(x=>x.startsWith('--'+n+'='))?.slice(n.length+3);
const planPath=path.resolve(root,arg('plan')??''),plan=JSON.parse(fs.readFileSync(planPath)),build=path.dirname(planPath),label=arg('label');
if(!label||!/^[a-z0-9-]+$/.test(label)||plan.schema!=='nwn65-private-rig-batch-plan-v1')throw Error('Fresh --label and pinned --plan required');
const output=path.join(root,'.cache/nwn65/native-rig-batch-view-'+label);if(fs.existsSync(output))throw Error('Private view already exists');
for(const row of plan.frozenInputs)if(sha(fs.readFileSync(path.join(build,row.frozen)))!==row.sha256)throw Error('Frozen source differs: '+row.file);
const copy=(file,data)=>{fs.mkdirSync(path.dirname(path.join(output,file)),{recursive:true});fs.writeFileSync(path.join(output,file),data,{flag:'wx'});};
const sourcePins=[];
for(const row of plan.frozenInputs.filter(x=>x.file.startsWith('systems/'))){copy(row.file,fs.readFileSync(path.join(build,row.frozen)));sourcePins.push({file:row.file,sha256:row.sha256,bytes:row.bytes});}
if(sourcePins.find(row=>row.file===plan.pins.rig.file).sha256!==plan.pins.rig.sha256)throw Error('Frozen active rig differs');
for(const [source,target] of [['tests/nwn65_active_event_test.gd','tests/nwn65_active_event_test.gd'],['tests/nwn65_native_batch_test.gd','tests/nwn65_native_batch_test.gd'],['tests/nwn65_native_batch_player.gd','tests/nwn65_native_batch_player.gd'],['driver/candidate_rigs.gd','tests/nwn65_native_batch_candidate.gd']]){
  const row=plan.frozenInputs.find(x=>source===x.file||source===x.frozen);if(!row)throw Error('Missing frozen test/driver '+source);copy(target,fs.readFileSync(path.join(build,row.frozen)));
}
for(const name of ['a_ba','c_goblina','fx_light_clr']){const file='.cache/nwn65/original-census-a/'+name+'-original-events.json',row=plan.frozenInputs.find(x=>x.file===file);if(!row)throw Error('Missing original event fixture');copy(file,fs.readFileSync(path.join(build,row.frozen)));sourcePins.push({file,sha256:row.sha256,bytes:row.bytes});}
const buildReceiptPath=path.join(build,'build-receipt.json'),compiled=fs.existsSync(buildReceiptPath);
if(compiled){const receipt=JSON.parse(fs.readFileSync(buildReceiptPath));if(!receipt.success||receipt.binary.sha256!==sha(fs.readFileSync(path.join(root,receipt.binary.file))))throw Error('Unsuccessful/mixed private build');copy('native/nwn-rig-animation-batch.dll',fs.readFileSync(path.join(root,receipt.binary.file)));copy('native/nwn-rig-animation-batch.gdextension','[configuration]\nentry_symbol = "nwn_rig_animation_batch_init"\ncompatibility_minimum = "4.7"\nreloadable = false\n\n[libraries]\nwindows.debug.x86_64 = "res://native/nwn-rig-animation-batch.dll"\nwindows.release.x86_64 = "res://native/nwn-rig-animation-batch.dll"\n');copy('.godot/extension_list.cfg','res://native/nwn-rig-animation-batch.gdextension\n');}
copy('project.godot','config_version=5\n[application]\nconfig/name="NWN65 Private Rig Batch"\nconfig/features=PackedStringArray("4.7")\n[nwn]\nrig_animation_batch=true\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
copy('.godot/global_script_class_cache.cfg','list=[]\n');
const receipt={schema:'nwn65-private-rig-batch-view-v1',plan:{file:path.relative(root,planPath).replaceAll('\\','/'),sha256:sha(fs.readFileSync(planPath))},compiled,sourcePins,scope:'Fresh standalone correctness capsule; no autoload/client assets, no global extension registrations, no live/FPS claim'};copy('view-receipt.json',JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify({view:path.relative(root,output).replaceAll('\\','/'),compiled,runtimeFiles:sourcePins.length}));
