import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';import {createRequire} from 'node:module';
const here=path.dirname(fileURLToPath(import.meta.url)),project=path.resolve(here,'../../..'),label=process.argv[2];if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh proposal label required');
const base=path.join(project,'.cache/native-render-gap/particles/childless-chunk-a'),input=JSON.parse(fs.readFileSync(path.join(base,'kernel-source-pins.json'))),stage=path.join(project,'.cache/native-render-gap/particles',label),kernel=path.join(stage,'kernel-project');if(fs.existsSync(stage))throw Error('Earlier evidence retained');fs.mkdirSync(kernel,{recursive:true});
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),pins=[];const once=(s,a,b)=>{if(s.split(a).length!==2)throw Error('Frozen boundary differs: '+a.slice(0,100));return s.replace(a,b);};
for(const pin of input.pins){const file=path.join(input.project,pin.relative),bytes=fs.readFileSync(file);if(hash(bytes)!==pin.sha256)throw Error('Frozen childless input differs');const dest=path.join(kernel,pin.relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes);pins.push({...pin,source:file,originalSha256:pin.sha256});}
const helper='native/particle_frame_sampler.hpp',helperBytes=fs.readFileSync(path.join(here,'particle_frame_sampler.hpp'));fs.writeFileSync(path.join(kernel,helper),helperBytes);pins.push({relative:helper,source:path.join(here,'particle_frame_sampler.hpp'),originalSha256:null,sha256:hash(helperBytes),bytes:helperBytes.length});
const relative='native/particle_presentation.hpp',file=path.join(kernel,relative);let s=fs.readFileSync(file,'utf8').replaceAll('\r\n','\n');
s=once(s,'using Clock=std::chrono::steady_clock;','using Clock=std::chrono::steady_clock;\n#include "particle_frame_sampler.hpp"');
s=once(s,'EngineVar retained,providers,clock,fallback,readiness;','EngineVar retained,providers,clock,fallback,readiness;uint8_t clock_route=0;');
s=once(s,'bool animation_enabled(const EngineVar& common){','bool animation_enabled(const EngineVar& common,const EngineVar* bound_key=nullptr){');s=once(s,'get_keyed(common.data,::key("animating").data,value.data,&present);','get_keyed(common.data,bound_key ? bound_key->data : ::key("animating").data,value.data,&present);');
s=once(s,' GDExtensionObjectPtr identity=nullptr;',' FrameSampler sampler;FrameSampler::Invocation* sampling_context=nullptr;bool setup_boundary=false;uint64_t animating_key_binds=0,clock_validity_dispatches=0,static_noncallable_uses=0,static_null_callable_uses=0;\n GDExtensionObjectPtr identity=nullptr;');
s=once(s,'if(::has(config,"clock"))entry->clock=::get(config,"clock");','if(::has(config,"clock")){entry->clock=::get(config,"clock");entry->clock_route=setup_clock_route::classify(entry->clock);}');
s=once(s,'if(::has(config,"clock"))entry.clock=::get(config,"clock");','if(::has(config,"clock")){entry.clock=::get(config,"clock");entry.clock_route=setup_clock_route::classify(entry.clock);}');
s=once(s,'const bool profile=::has(common,"profile")&&::get(common,"profile").boolean();','const bool profile=::has(common,"profile")&&::get(common,"profile").boolean();if(sampling_context){sampling_context->profile_seen=true;sampling_context->profile=profile;}');
s=once(s,'  refresh_order();','  const EngineVar* animating_key=nullptr;\n  refresh_order();');
s=once(s,'next.animate=animation_enabled(common)||(entry.source_key&&entry.source_animating);','if(setup_boundary&&!animating_key){animating_key=&::key("animating");++animating_key_binds;}next.animate=animation_enabled(common,animating_key)||(entry.source_key&&entry.source_animating);');
s=once(s,'   if(particle_frame_group::valid_callable(entry.clock)){auto sampled=',`   bool actor_clock=false;if(!setup_boundary||entry.clock_route==2){++clock_validity_dispatches;actor_clock=particle_frame_group::valid_callable(entry.clock);}else if(entry.clock_route==1)++static_null_callable_uses;else ++static_noncallable_uses;
   if(actor_clock){auto sampled=`);
s=once(s,' EngineVar chunk_census()const{',` void configure_sampler(const EngineVar& input){
  if(closed||running)throw std::runtime_error("Frame sampler/setup changes require an open frame boundary");
  if(input.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Sparse frame sampler requires a dictionary");
  const bool next_setup=::has(input,"setup_boundary")?::get(input,"setup_boundary").boolean():setup_boundary;
  const bool reset=::has(input,"reset")&&::get(input,"reset").boolean();sampler.configure(input);setup_boundary=next_setup;if(reset)animating_key_binds=clock_validity_dispatches=static_noncallable_uses=static_null_callable_uses=0;
 }
 EngineVar sampler_info()const{
  auto out=sampler.inspect();::set(out,"setup_boundary",EngineVar::boolean(setup_boundary));::set(out,"animating_key_binds",EngineVar::integer(static_cast<int64_t>(animating_key_binds)));::set(out,"clock_validity_dispatches",EngineVar::integer(static_cast<int64_t>(clock_validity_dispatches)));::set(out,"static_noncallable_uses",EngineVar::integer(static_cast<int64_t>(static_noncallable_uses)));::set(out,"static_null_callable_uses",EngineVar::integer(static_cast<int64_t>(static_null_callable_uses)));int64_t routes[3]{};for(const auto& pair:entries)if(pair.second->owner)++routes[pair.second->clock_route];::set(out,"compiled_noncallable_entries",EngineVar::integer(routes[0]));::set(out,"compiled_null_callable_entries",EngineVar::integer(routes[1]));::set(out,"live_callable_entries",EngineVar::integer(routes[2]));return out;
 }
 EngineVar timed_frame(const EngineVar& input){
  if(!sampler.enabled||!sampler.select(entries.size()))return frame(input);
  FrameSampler::Invocation invocation;auto* previous=sampling_context;sampling_context=&invocation;
  struct Restore{FrameSampler::Invocation*& slot;FrameSampler::Invocation* previous;~Restore(){slot=previous;}}restore{sampling_context,previous};
  FrameSampler::Sample sample;sample.call=sampler.calls;sample.setup=setup_boundary;sample.boundary=particle_scene_boundary::enabled;const auto began=Clock::now();
  const auto finish=[&](bool success){sample.wall_ms=std::chrono::duration<double,std::milli>(Clock::now()-began).count();sample.success=success;sample.generation=generation;sample.registered=static_cast<int64_t>(entries.size());sample.prepared=prepared;sample.culled=culled;sample.active=active;sampler.record(invocation,sample);};
  try{auto out=frame(input);finish(true);return out;}catch(...){finish(false);throw;}
 }
 EngineVar chunk_census()const{`);
s=once(s,'case 1:out=owner.frame(input);break;','case 1:out=owner.timed_frame(input);break;');s=once(s,'case 14:out=owner.chunk_census();break;','case 14:out=owner.chunk_census();break;case 15:owner.configure_sampler(input);out=owner.sampler_info();break;case 16:out=owner.sampler_info();break;');
s=once(s,' Name name("NwnParticlePresentation"),base("RefCounted"),',' setup_clock_route::bind();\n Name name("NwnParticlePresentation"),base("RefCounted"),');
const require=createRequire(import.meta.url),surveyFile=path.join(project,'tools/native-render-gap/original/admission-chain/prepare-survey.cjs'),survey= require(surveyFile);s=survey.transform(s);
fs.writeFileSync(file,s);const pin=pins.find(p=>p.relative===relative);pin.sha256=hash(Buffer.from(s));pin.bytes=Buffer.byteLength(s);
let group=fs.readFileSync(path.join(base,'systems/native_render/particle_stream_group.gd'),'utf8');group=once(group,'effect=Effect.new(); effect.configure(renderer);',`var sparse_enabled: bool=OS.get_cmdline_user_args().has("--particle-sparse-timing")
\tvar setup_enabled: bool=OS.get_cmdline_user_args().has("--particle-setup-boundary=bound")
\tif sparse_enabled or setup_enabled:
\t\tvar sampled: Dictionary=native.call("dispatch",15,{"enabled":sparse_enabled,"stride":120,"min_members":1800,"setup_boundary":setup_enabled,"reset":true})
\t\tif sampled.has("error"):failure=str(sampled.error);close();return false
\teffect=Effect.new(); effect.configure(renderer);`);fs.mkdirSync(path.join(stage,'systems/native_render'),{recursive:true});fs.writeFileSync(path.join(stage,'systems/native_render/particle_stream_group.gd'),group);
fs.mkdirSync(path.join(stage,'inputs'),{recursive:true});for(const name of ['prepare-survey.cjs','survey.hpp.inc'])fs.copyFileSync(path.join(path.dirname(surveyFile),name),path.join(stage,'inputs',name));
fs.writeFileSync(path.join(stage,'kernel-source-pins.json'),JSON.stringify({version:1,project:kernel,pins,compilerInvoked:false,scope:'Private default-off setup boundary, profile-OFF sparse whole-frame wall sampler, and cold admission survey17'},null,2)+'\n');
fs.writeFileSync(path.join(stage,'proposal.json'),JSON.stringify({label,kernel,sourcePins:pins,groupSha256:hash(Buffer.from(group)),surveyTransformerSha256:hash(fs.readFileSync(surveyFile)),sharedSourceWrites:0,sharedBinaryWrites:0,engineStarts:0,scope:'No value/pose snapshots. Fresh per-entry common.animating reads; only structurally null/noncustom/noncallable clock routes compiled. All nonempty/custom target validity remains live.'},null,2)+'\n');console.log(JSON.stringify({stage,files:pins.length,default:'off'}));
