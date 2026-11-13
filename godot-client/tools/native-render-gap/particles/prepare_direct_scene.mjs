import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),project=path.resolve(here,'../../..'),label=process.argv[2];
if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh proposal label required');
const base=path.join(project,'.cache/native-render-gap/particles/setup-boundary-a'),manifest=JSON.parse(fs.readFileSync(path.join(base,'kernel-source-pins.json'))),stage=path.join(project,'.cache/native-render-gap/particles',label),kernel=path.join(stage,'kernel-project');
if(fs.existsSync(stage))throw Error('Earlier source evidence retained');
fs.mkdirSync(kernel,{recursive:true});
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),pins=[];
const once=(s,a,b)=>{if(s.split(a).length!==2)throw Error('Frozen source boundary differs: '+a.slice(0,120));return s.replace(a,b);};
for(const pin of manifest.pins){const source=path.join(manifest.project,pin.relative),bytes=fs.readFileSync(source);if(hash(bytes)!==pin.sha256)throw Error('Frozen sampler input changed');const dest=path.join(kernel,pin.relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes);pins.push({...pin,source,originalSha256:pin.sha256});}
function write(relative,bytes,source){const dest=path.join(kernel,relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes);const pin=pins.find(pin=>pin.relative===relative);if(pin){pin.sha256=hash(bytes);pin.bytes=bytes.length;}else pins.push({relative,source,originalSha256:null,sha256:hash(bytes),bytes:bytes.length});}
const abiSource=path.join(here,'particle_scene_direct_abi.hpp'),abi=fs.readFileSync(abiSource);write('native/particle_scene_direct_abi.hpp',abi,abiSource);
const helperSource=path.join(here,'particle_scene_direct.hpp.inc'),helper=fs.readFileSync(helperSource);write('native/particle_scene_direct.hpp.inc',helper,helperSource);
let relative='native/particle_scene_boundary.hpp',s=fs.readFileSync(path.join(kernel,relative),'utf8').replaceAll('\r\n','\n');
s=once(s,'namespace particle_scene_boundary {','#include "particle_scene_direct_abi.hpp"\nnamespace particle_scene_boundary {');
s=once(s,'bool bind(){','#include "particle_scene_direct.hpp.inc"\nbool bind(){');
s=once(s,'if(::method(args,"has",{EngineVar::text("--particle-scene-boundary=legacy")}).boolean())enabled=false;','direct_requested=::method(args,"has",{EngineVar::text("--particle-scene-direct=pod")}).boolean();if(::method(args,"has",{EngineVar::text("--particle-scene-direct=legacy")}).boolean())direct_requested=false;if(::method(args,"has",{EngineVar::text("--particle-scene-boundary=legacy")}).boolean())enabled=false;');
s=once(s,' return available=eligibility_binding&&transform_binding&&status_binding;',' available=eligibility_binding&&transform_binding&&status_binding;if(available)bind_direct(classdb);return available;');
s=once(s,'if(!enabled||!available)return false;++pose_calls;const auto signed_id=',`if(!enabled||!available)return false;++pose_calls;
 if(direct_active()){
  ++direct_pose_calls;const auto status=direct_transform_binding(id,result.data(),12);
  if(status==nwn_particle_scene_direct_v1::OK){++direct_pose_reads;++pose_reads;return true;}
  if(status==nwn_particle_scene_direct_v1::ABSENT||status==nwn_particle_scene_direct_v1::WRONG_TYPE){++direct_pose_failures;++pose_failures;throw std::runtime_error("Native particle pose owner is absent or no longer Node3D");}
  if(status==nwn_particle_scene_direct_v1::BAD_DESTINATION)throw std::runtime_error("Native direct scene pose destination violates ABI1");
  ++direct_fallbacks;++pose_fallbacks;return false;
 }
 const auto signed_id=`);
s=once(s,'EngineVar inspect(){auto out=EngineVar::dictionary();','EngineVar inspect(){auto out=EngineVar::dictionary();direct_info(out);');write(relative,Buffer.from(s),path.join(base,'kernel-project',relative));
relative='native/particle_frame_group.hpp';s=fs.readFileSync(path.join(kernel,relative),'utf8').replaceAll('\r\n','\n');s=once(s,'bool eligible(int64_t id){','bool eligible(int64_t id,bool allow_boundary=true){');s=once(s,'if(particle_scene_boundary::eligible(id,result))return result;','if(allow_boundary&&particle_scene_boundary::eligible(id,result))return result;');write(relative,Buffer.from(s),path.join(base,'kernel-project',relative));
relative='native/particle_presentation.hpp';s=fs.readFileSync(path.join(kernel,relative),'utf8').replaceAll('\r\n','\n');
s=once(s,'   if(!entry.enabled||!particle_frame_group::eligible(id)){',`   bool direct_eligible=false,direct_source_exists=false,bypass_boundary=false;
   const bool fused=!profile&&entry.enabled&&entry.owner&&particle_scene_boundary::eligible_source(id,entry.owner->source_id,direct_eligible,direct_source_exists,bypass_boundary);
   if(!entry.enabled||!(fused?direct_eligible:particle_frame_group::eligible(id,!bypass_boundary))){`);
s=once(s,'   const bool source_exists=instance_from_id(entry.owner->source_id)!=nullptr;','   const bool source_exists=fused?direct_source_exists:instance_from_id(entry.owner->source_id)!=nullptr;');write(relative,Buffer.from(s),path.join(base,'kernel-project',relative));
relative='native/particle_kernel.cpp';s=fs.readFileSync(path.join(kernel,relative),'utf8').replaceAll('\r\n','\n');s=once(s,' library=lib;',' library=lib;particle_scene_boundary::direct_address=address;');write(relative,Buffer.from(s),path.join(base,'kernel-project',relative));
const engine=path.join(stage,'engine-module');fs.mkdirSync(engine,{recursive:true});const enginePins=[];
for(const name of ['scene_boundary.h','scene_boundary.cpp']){const source=path.join(here,'engine-module-scene-direct-v1',name),bytes=fs.readFileSync(source);fs.writeFileSync(path.join(engine,name),bytes);enginePins.push({relative:name,source,sha256:hash(bytes),bytes:bytes.length});}
fs.writeFileSync(path.join(engine,'particle_scene_direct_abi.hpp'),abi);enginePins.push({relative:'particle_scene_direct_abi.hpp',source:abiSource,sha256:hash(abi),bytes:abi.length});
fs.mkdirSync(path.join(stage,'systems/native_render'),{recursive:true});const group=fs.readFileSync(path.join(base,'systems/native_render/particle_stream_group.gd'));fs.writeFileSync(path.join(stage,'systems/native_render/particle_stream_group.gd'),group);
fs.writeFileSync(path.join(stage,'kernel-source-pins.json'),JSON.stringify({version:1,project:kernel,pins,compilerInvoked:false,scope:'Default-off direct POD scene C ABI; same four ObjectDB lookups, current getters and callback boundaries'},null,2)+'\n');
fs.writeFileSync(path.join(stage,'proposal.json'),JSON.stringify({label,kernel,sourcePins:pins,engine,enginePins,groupSha256:hash(group),flags:['--particle-scene-boundary=native','--particle-scene-direct=pod'],fallback:'Absent capability, ABI mismatch, explicit legacy and unsupported engine/thread routes preserve established live ObjectDB/ptrcall path',sourceWritesOutsideStage:0,sharedBinaryWrites:0,engineStarts:0},null,2)+'\n');
console.log(JSON.stringify({stage,files:pins.length,enginePins,default:'off'}));
