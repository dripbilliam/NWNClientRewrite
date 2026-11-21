// Seven-fix source branch onto the frozen measured renderer, using exact
// per-file before-feature owners. No shared source writes, build or launch.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const root=path.dirname(project),label=process.argv[2];
if(!/^parity-launch-[a-z0-9-]+$/.test(label??''))throw Error('Explicit launch audit label required');
const folder=path.join(project,'.cache/native-presentation-parity/loading-agent',label);
const audit=JSON.parse(fs.readFileSync(path.join(folder,'audit.json'))),parent=JSON.parse(fs.readFileSync(audit.parent.file));
const output=path.join(folder,'composition');if(fs.existsSync(output))throw Error('Existing composition preserved');
const sha=raw=>crypto.createHash('sha256').update(raw).digest('hex');
if(sha(fs.readFileSync(audit.parent.file))!==audit.parent.sha256)throw Error('Frozen parent descriptor changed');
const before=new Map();
function add(relative,file,pin){const raw=fs.readFileSync(file);if(sha(raw)!==pin.toLowerCase())throw Error('Before-feature source differs: '+relative);if(before.has(relative))throw Error('Duplicate base '+relative);before.set(relative,{file,sha256:sha(raw)});}
function rootRows(name,allowed){const dir=path.join(project,'.cache/native-presentation-parity/root',name);for(const row of JSON.parse(fs.readFileSync(path.join(dir,'before.json')))){const relative=row.source.replaceAll('\\','/').replace(/^godot-client\//,'');if(allowed.includes(relative))add(relative,path.join(dir,row.backup??relative.split('/').at(-1)+'.before'),row.sha256);}}
rootRows('lifetime-inspector-v1',['systems/native_render/live_world.gd','systems/native_entity_inspector.gd']);
rootRows('support-door-promotion-v1',['native_live_world.gd','systems/native_render/door_instance.gd']);
rootRows('alpha-integration-v1',['systems/visual_runtime.gd','systems/visual_phases.gd','systems/native_render/effect_world.gd','systems/native_render/creature_stream.gd']);
rootRows('part-metadata-cache-v1',['systems/native_data/asset_service.gd','systems/native_data/prework_store.gd']);
rootRows('highlight-integration-v1',['systems/entity_registry.gd','systems/world_input.gd']);
// Later disjoint parity owners whose exact before bytes equal the frozen
// parent. Keep earliest existing ancestors for files already in the23 cohort.
for(const [relative,directory,file,pin] of [
 ['systems/native_data/actor_model.gd','ascii-native-animation-before-v1','actor_model.gd','2b13eb66630132440f72436fc4dd67052e2aa064c295fa2ca932977bc708a06a'],
 ['systems/native_data/client_clock_services.gd','reveal-clock-before-v1','client_clock_services.gd','a50f22e6420b964c8c0f8b4e025b023dc364aaf10cf4fe5a2080a39b2bf8eeba'],
])add(relative,path.join(project,'.cache/native-presentation-parity/render-agent',directory,file),pin);
add('systems/native_client_clock_runtime.gd',path.join(project,'.cache/native-presentation-parity/root/visibility-runtime-before-v1/systems__native_client_clock_runtime.gd'),'28193c2c9e251685a27eddd796447acc8f5114791563ead9fbfd223312d1cf7f');
const dialogue=JSON.parse(fs.readFileSync(path.join(project,'tools/native_parity/loading/backups/dialogue-extents-before-v1/before.json'))).pins.find(row=>row.relative==='systems/native_data/conversation_layout.gd');
add(dialogue.relative,path.join(root,dialogue.copy),dialogue.sha256);
for(const [relative,pin] of [
 ['systems/native_render/native_surface_state.gd','93aef4f09f6281c057b959f76892564588fc295ad5e7135536ffb80553c31e80'],
 ['systems/native_render/native_surface_transfer.gd','2e3f975da71049a3922c7ba437424897d982d7e355c9fe1080b8aeddcbb356d2'],
 ['systems/native_render/terrain_batches.gd','b4cb09c9572f0be1985c5811fc2b755fbf9fff61ecc70d9279d87af6701dc262'],
])add(relative,path.join(project,'.cache/native-presentation-parity/root/tile-fog-shader-before-v1','godot-client__'+relative.replaceAll('/','__')),pin);
const fov=path.join(project,'.cache/native-presentation-parity/root/fov-entry-v1');add('native_session_world.gd',path.join(fov,'native_session_world.before.gd'),JSON.parse(fs.readFileSync(path.join(fov,'backup.json'))).before_sha256);
for(const [relative,name,pin] of [
 ['systems/native_render/object_stream.gd','support-door-promotion-v1','b00b530f1e8f28bc91a3030a01d0282a080dee8a70acd4c9caff46cb939e95fb'],
 ['systems/visual_world.gd','alpha-integration-v1','a01803402da30efeae2496e2143ce38193b59260507f4791ea818cfdc4a81bad'],
 ['systems/native_render/model_template.gd','alpha-integration-v1','6722f49f7d8baa1979ae030d40068995cac0d4bbe2976579ad4cbf1457a085e3']
])add(relative,path.join(project,'.cache/native-presentation-parity/root',name,'godot-client__'+relative.replaceAll('/','__')),pin);
for(const group of ['native-door-parser-before-v1','native-parity-ui-before-v1']){
 const dir=path.join(project,'.cache/native-140fps/particles-agent',group);
 for(const row of JSON.parse(fs.readFileSync(path.join(dir,'backup.json'))))add(row.file.replace(/^godot-client\//,''),path.join(root,row.backup),row.sha256);
}
const alpha=path.join(project,'.cache/native-140fps/particles-agent/actor-alpha-before-v1');
const alphaPins=JSON.parse(fs.readFileSync(path.join(alpha,'pins.json')));add('systems/model_native_pose.gd',path.join(alpha,'model_native_pose.gd'),alphaPins.find(row=>row.Path.endsWith('model_native_pose.gd')).Hash);
const provenance=path.join(project,'tools/native_parity/visibility/before-provenance-v1');
for(const row of JSON.parse(fs.readFileSync(path.join(provenance,'before.json'))))add(row.path.replace(/^godot-client\//,''),path.join(provenance,row.path.split('/').at(-1)),row.sha256);
add('systems/network_motion.gd',path.join(project,'tools/native_parity/loading/backups/support-motion-before-v1/network_motion.gd'),'086c3e6693f7b858519820c5539496090de51656de990ef0ee972e866877092d');
fs.mkdirSync(output,{recursive:true});const results=[],conflicts=[];
for(const [relative,base] of before){
 const currentFile=path.join(project,relative),frozenFile=path.join(parent.project,relative),frozenPin=parent.pins.find(row=>row.relative===relative);
 const current=fs.readFileSync(currentFile),frozen=fs.readFileSync(frozenFile);
 if(sha(frozen)!==frozenPin.sha256)throw Error('Frozen renderer changed: '+relative);
 const audited=audit.rows.find(row=>row.relative===relative);if(audited?.currentSha256!==sha(current))throw Error('Current source changed since audit: '+relative);
 let merged,mode,conflict=false;
 if(sha(current)===base.sha256){merged=frozen;mode='feature-unchanged';}
 else if(sha(frozen)===base.sha256){merged=current;mode='current-feature-only';}
 else{
  const merge=spawnSync('git',['-c','core.autocrlf=false','merge-file','--stdout','--diff3','-L','SEVEN_FIX_CURRENT','-L','EXACT_BEFORE_FEATURE','-L','FROZEN_CCE71',currentFile,base.file,frozenFile],{encoding:null,windowsHide:true,maxBuffer:4*1024*1024});
  if(merge.error||merge.status===null||merge.status<0||merge.status>127)throw Error('Source merge failed: '+relative+' '+String(merge.error??merge.stderr));
  merged=merge.stdout;mode='exact-three-way';conflict=merge.status!==0;
 }
 const file=path.join(output,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,merged);
 const result={relative,mode,conflict,before:base,current:{file:currentFile,sha256:sha(current)},frozen:{file:frozenFile,sha256:sha(frozen)},output:{file,sha256:sha(merged)}};results.push(result);if(conflict)conflicts.push(relative);
}
const report={version:1,label,parent:audit.parent,beforeOwners:results,conflicts,launchable:false,scope:'Exact per-file before-feature 3-way source composition only; conflicts remain explicit; no shared writes, copy of native outputs, launch/auth/server/build'};
fs.writeFileSync(path.join(folder,'composition.json'),JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({folder,featureFiles:results.length,conflicts,report:path.join(folder,'composition.json')}));
