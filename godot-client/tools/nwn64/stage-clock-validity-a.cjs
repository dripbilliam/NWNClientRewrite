'use strict';
// Private opt-in variant of the already proven canonical ModelRigs reader.
// Never writes accepted source or binary.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const prior=path.join(root,'.cache/native-render-gap/particles/nwn64-clock-d');
const stage=path.join(root,'.cache/native-render-gap/particles/nwn64-clock-validity-a');
const source=JSON.parse(fs.readFileSync(path.join(prior,'kernel-source-pins.json'),'utf8'));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
assert(!fs.existsSync(stage));
const relative='native/particle_presentation.hpp';
assert.equal(sha(fs.readFileSync(path.join(root,relative))),'643dc50015c8f406aad9a9da3fe150a73dbd0b7853508799cdb1c70c319ac97f');
const before=`   bool actor_clock=false;if(!setup_boundary||entry.clock_route==2){++clock_validity_dispatches;actor_clock=particle_frame_group::valid_callable(entry.clock);}else if(entry.clock_route==1)++static_null_callable_uses;else ++static_noncallable_uses;
   if(actor_clock){if(sampler.coarse_phases&&sampling_context)++sampling_context->clocks;if(entry.clock_binding&&particle_clock_binding::read(*entry.clock_binding,next.clip,time))++clock_native_reads;else{if(entry.clock_binding)++clock_native_fallbacks;auto sampled=::method(entry.clock,"call");if(sampled.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Native presentation clock must return a dictionary");next.clip=::has(sampled,"clip")?engine_string(::get(sampled,"clip")):"";time=::has(sampled,"time")?::get(sampled,"time").number():0;}}
   else if(entry.clip_length>0){time=std::fmod(time,entry.clip_length);if(time<0)time+=entry.clip_length;}`;
const after=`   bool actor_clock=false,native_clock=false;
   // A recognized canonical binding validates current ObjectID, Script identity
   // and source on this exact source boundary. If it declines, retain the
   // original Callable validity/call path and its observable fallback order.
   if(entry.clock_binding&&particle_clock_binding::read(*entry.clock_binding,next.clip,time)){actor_clock=true;native_clock=true;}
   else if(!setup_boundary||entry.clock_route==2){++clock_validity_dispatches;actor_clock=particle_frame_group::valid_callable(entry.clock);}else if(entry.clock_route==1)++static_null_callable_uses;else ++static_noncallable_uses;
   if(actor_clock){if(sampler.coarse_phases&&sampling_context)++sampling_context->clocks;if(native_clock)++clock_native_reads;else{if(entry.clock_binding)++clock_native_fallbacks;auto sampled=::method(entry.clock,"call");if(sampled.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Native presentation clock must return a dictionary");next.clip=::has(sampled,"clip")?engine_string(::get(sampled,"clip")):"";time=::has(sampled,"time")?::get(sampled,"time").number():0;}}
   else if(entry.clip_length>0){time=std::fmod(time,entry.clip_length);if(time<0)time+=entry.clip_length;}`;
const pins=[];
for(const row of [...source.pins,{relative:'native/particle_geometry_worker.hpp'}]){
  const bytes=fs.readFileSync(path.join(root,row.relative));
  const output=row.relative===relative?Buffer.from((()=>{const text=bytes.toString('utf8');assert.equal(text.split(before).length,2);return text.replace(before,after);})()):bytes;
  const file=path.join(stage,'kernel-project',row.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,output,{flag:'wx'});
  pins.push({relative:row.relative,bytes:output.length,sha256:sha(output)});
}
const manifest={version:1,issue:'NWN-64',project:path.join(stage,'kernel-project'),pins,scope:'Private canonical-clock fast validity gate; source identity/owner verified per source, original Callable fallback retained. No accepted source/binary change.'};
fs.writeFileSync(path.join(stage,'kernel-source-pins.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({stage,baselineSha256:sha(fs.readFileSync(path.join(root,relative))),candidateSha256:pins.find(row=>row.relative===relative).sha256,pins:pins.length}));
