// File-only frozen comparison: common measurement controls, one planning delta.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),label=process.argv[2];
if(!/^native-dense-quiescent-[a-z0-9-]+$/.test(label??''))throw Error('Supply a fresh quiescent capsule label');
const stage=path.join(project,'.cache/native-dense-area',label);
if(fs.existsSync(stage))throw Error('Existing evidence/capsule is preserved');
const parentStage=path.join(project,'.cache/native-dense-area/native-dense-pair-v3');
const parentFile=path.join(parentStage,'candidate-sources.json'),parentBytes=fs.readFileSync(parentFile),parent=JSON.parse(parentBytes);
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const sourcePath=(root,relative)=>{
 const full=path.resolve(root,relative),rel=path.relative(root,full);
 if(!rel||rel==='..'||rel.startsWith('..'+path.sep)||path.isAbsolute(rel)||relative.includes(':'))throw Error('Source path escapes capsule');
 return full;
};
const replaceOnce=(text,from,to)=>{if(text.split(from).length!==2)throw Error('Expected single candidate/control hook differs: '+from.slice(0,90));return text.replace(from,to);};
if(parent.sourceProject!==path.join(parentStage,'candidate')||parent.sourcePins.length!==2588)throw Error('Parent capsule identity differs');
const proofFile=path.join(project,'reports/native-world-quiescent-v3.json'),proofBytes=fs.readFileSync(proofFile),proof=JSON.parse(proofBytes);
if(!proof.success||proof.checks!==236||!proof.engineClean||proof.nativeBuilds!==0)throw Error('Required correctness gate is absent');
const candidateRelative='systems/native_render/live_world_quiescent_candidate.gd';
const candidateBytes=fs.readFileSync(path.join(project,candidateRelative));
const candidatePin=proof.sourcePins.find(p=>p.relative===candidateRelative);
if(!candidatePin||candidatePin.sha256!==hash(candidateBytes))throw Error('Candidate differs from passing gate');
const outcomes=[];
for(const variant of ['baseline','candidate']){
 const destination=path.join(stage,variant),pins=[],overrides=[];fs.mkdirSync(destination,{recursive:true});
 for(const pin of parent.sourcePins){
  const bytes=fs.readFileSync(sourcePath(parent.sourceProject,pin.relative));if(hash(bytes)!==pin.finalSha256)throw Error('Frozen parent source changed: '+pin.relative);
  const target=sourcePath(destination,pin.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});
  pins.push({relative:pin.relative,capturedSha256:hash(bytes),finalSha256:hash(bytes),bytes:bytes.length});
 }
 function install(relative,bytes,reason){
  if(typeof bytes==='string')bytes=Buffer.from(bytes);
  const target=sourcePath(destination,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);
  const pin=pins.find(p=>p.relative===relative);
  if(pin){pin.finalSha256=hash(bytes);pin.bytes=bytes.length;}
  else pins.push({relative,capturedSha256:hash(bytes),finalSha256:hash(bytes),bytes:bytes.length});
  overrides.push({relative,sha256:hash(bytes),source:reason});
 }
 const worldRelative='systems/native_render/live_world.gd';
 install(worldRelative,replaceOnce(fs.readFileSync(sourcePath(destination,worldRelative),'utf8'),'var drive_spatial_enabled:=true','var drive_spatial_enabled:=false'),'Common: exact current ordinary legacy collision route');
 install(candidateRelative,candidateBytes,'Identical unused-or-used candidate source in both copies');
 let live=fs.readFileSync(path.join(destination,'native_live_world.gd'),'utf8').replaceAll('\r\n','\n');
 const start=live.indexOf('func activate_window_from_click('),end=live.indexOf('func send(',start);
 if(start<0||end<=start||!live.slice(start,end).includes('root.grab_focus()'))throw Error('Explicit activation hook differs');
 live=live.slice(0,start)+'func activate_window_from_click(_event: InputEvent) -> void:\n\tpass # Copied benchmark only: never activate from input.\n'+live.slice(end);
 // Record the actual camera/frustum at measurement boundaries, not only the
 // input capture. No frame-by-frame engine measurement/readback is added.
 const marker='\treport.diagnostic_preview_policy=';
 if(!live.includes(marker))throw Error('Shutdown presentation boundary differs');
 live=live.replace(marker,'\treport.benchmark_end_view=benchmark_view()\n'+marker);
 live+='\nfunc benchmark_view() -> Dictionary:\n\tvar value:={"viewport":[root.size.x,root.size.y],"focused":root.has_focus(),"unfocusable":root.unfocusable}\n\tif is_instance_valid(camera):value.merge({"position":[camera.position.x,camera.position.y,camera.position.z],"quaternion":[camera.quaternion.x,camera.quaternion.y,camera.quaternion.z,camera.quaternion.w],"fov":camera.fov,"near":camera.near,"far":camera.far})\n\treturn value\n';
 if(variant==='candidate')live=replaceOnce(live,'const World=preload("res://systems/native_render/live_world.gd")','const World=preload("res://systems/native_render/live_world_quiescent_candidate.gd")');
 install('native_live_world.gd',live,variant==='candidate'?'Common controls plus candidate World selection':'Common controls only');
 let session=fs.readFileSync(path.join(destination,'native_session_world.gd'),'utf8').replaceAll('\r\n','\n');
 session=replaceOnce(session,'func run() -> void:\n','func run() -> void:\n\targs["render-preferences"]="res://benchmark-options.cfg"\n\targs["menu-layout"]="res://benchmark-layout.cfg"\n\targs["lobby-preferences"]="res://benchmark-lobby.cfg"\n');
 session=replaceOnce(session,'\t\t\tsamples.clear(); previous=0','\t\t\treport.benchmark_begin_view=benchmark_view()\n\t\t\tsamples.clear(); previous=0');
 install('native_session_world.gd',session,'Common: explicit isolated preference paths and measurement-start camera witness');
 install('benchmark-options.cfg','[rendering]\ngamma=1.2\nparticles_enabled=true\nparticle_collision_enabled=true\ntile_borders_enabled=true\nprofiling_enabled=true\ngore=1\ncompact_scenery=false\n[interface]\nui_scale=1.0\nui_scale_unconstrained=false\n','Common: explicitly seeded settings, no saved user-options dependency');
 for(const pin of pins)if(hash(fs.readFileSync(sourcePath(destination,pin.relative)))!==pin.finalSha256)throw Error('Final child pin differs');
 const privateUserData=path.join(stage,variant+'-user-data');fs.mkdirSync(privateUserData);
 const receipt={...parent,run:label,variant,sourceProject:destination,privateUserData,sourcePins:pins,sourceBytes:pins.reduce((n,p)=>n+p.bytes,0),overrides,indexedRequested:false,parentReceipt:{path:parentFile,sha256:hash(parentBytes)},candidateProof:{path:proofFile,sha256:hash(proofBytes),checks:236},scope:'Copied-only original/current World versus quiescent subclass. Common explicit options, nonactivating benchmark window and camera/frustum boundary witnesses. No main/runtime edits or performance acceptance.'};
 const file=path.join(stage,variant+'-sources.json');fs.writeFileSync(file,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
 outcomes.push({variant,sourceProject:destination,pins:pins.length,receipt:file,sha256:hash(fs.readFileSync(file))});
}
const a=JSON.parse(fs.readFileSync(outcomes[0].receipt)),b=JSON.parse(fs.readFileSync(outcomes[1].receipt));
const deltas=a.sourcePins.filter((p,i)=>p.finalSha256!==b.sourcePins[i].finalSha256).map(p=>p.relative);
if(JSON.stringify(deltas)!==JSON.stringify(['native_live_world.gd']))throw Error('Unexpected between-variant difference');
if(hash(fs.readFileSync(parentFile))!==hash(parentBytes))throw Error('Parent receipt changed during copy');
const summary={success:true,label,outcomes,deltas,controls:{sameCandidateHelper:true,legacyCollision:true,explicitOptions:true,nonactivating:true,cameraBoundaryWitness:true},engines:0,builds:0,serverConnections:0,performanceAccepted:false};
fs.writeFileSync(path.join(stage,'preparation.json'),JSON.stringify(summary,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(summary));
