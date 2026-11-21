import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),project=path.resolve(here,'../../..'),label=process.argv[2];
if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh private label required');
const base=path.join(project,'.cache/native-render-gap/particles/hot-parameters-c'),manifest=JSON.parse(fs.readFileSync(path.join(base,'kernel-source-pins.json'))),stage=path.join(project,'.cache/native-render-gap/particles',label),kernel=path.join(stage,'kernel-project');
if(fs.existsSync(stage))throw Error('Retain prior independent candidate');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),pins=[],once=(text,from,to)=>{if(text.split(from).length!==2)throw Error('Expected frozen empty-clip boundary: '+from.slice(0,100));return text.replace(from,to);};
fs.mkdirSync(kernel,{recursive:true});
for(const pin of manifest.pins){const source=path.join(manifest.project,pin.relative),bytes=fs.readFileSync(source);if(hash(bytes)!==pin.sha256)throw Error('Sealed HotC source drift');const output=path.join(kernel,pin.relative);fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,bytes);pins.push({...pin,source,originalSha256:pin.sha256});}
function write(relative,text){const bytes=Buffer.from(text);fs.writeFileSync(path.join(kernel,relative),bytes);const pin=pins.find(row=>row.relative===relative);if(pin){pin.sha256=hash(bytes);pin.bytes=bytes.length;}else pins.push({relative,source:path.join(here,path.basename(relative)),sha256:hash(bytes),bytes:bytes.length,originalSha256:null});}
write('native/empty_clips.hpp',fs.readFileSync(path.join(here,'empty_clips.hpp')));
let relative='native/particle_resident.hpp',text=fs.readFileSync(path.join(kernel,relative),'utf8');
text=once(text,'#include "hot_parameters.hpp"','#include "hot_parameters.hpp"\n#include "empty_clips.hpp"');
text=once(text,' std::unique_ptr<hot_parameters::Bindings> hot_bindings;',` bool skip_empty_clip_lookups=false,has_any_clip_channels=true,empty_clip_map_sealed=false;uint64_t clip_configure_depth=0;
 uint64_t clip_sample_calls=0,clip_lookup_calls=0,empty_clip_lookup_skips=0,preconfigure_sample_calls=0;
 EngineVar empty_clip_info()const{
  auto out=EngineVar::dictionary();size_t channel_count=0;for(const auto& clip:clips)channel_count+=clip.second.size();
  ::set(out,"configured",EngineVar::boolean(configured));::set(out,"enabled",EngineVar::boolean(skip_empty_clip_lookups));::set(out,"has_any_channels",EngineVar::boolean(has_any_clip_channels));
  ::set(out,"map_sealed",EngineVar::boolean(empty_clip_map_sealed));::set(out,"configure_depth",EngineVar::integer(static_cast<int64_t>(clip_configure_depth)));
  ::set(out,"copied_clip_count",EngineVar::integer(static_cast<int64_t>(clips.size())));::set(out,"copied_channel_count",EngineVar::integer(static_cast<int64_t>(channel_count)));
  ::set(out,"sample_calls",EngineVar::integer(static_cast<int64_t>(clip_sample_calls)));::set(out,"lookup_calls",EngineVar::integer(static_cast<int64_t>(clip_lookup_calls)));::set(out,"lookup_skips",EngineVar::integer(static_cast<int64_t>(empty_clip_lookup_skips)));::set(out,"preconfigure_sample_calls",EngineVar::integer(static_cast<int64_t>(preconfigure_sample_calls)));
  return out;
 }
 std::unique_ptr<hot_parameters::Bindings> hot_bindings;`);
text=once(text,'  if(configured)throw std::runtime_error("Native particle owner already configured");',`  if(configured)throw std::runtime_error("Native particle owner already configured");
  if(clip_configure_depth==UINT64_MAX)throw std::runtime_error("Native particle configure depth overflow");
  struct ConfigureScope {Owner& owner;explicit ConfigureScope(Owner& value):owner(value){++owner.clip_configure_depth;owner.empty_clip_map_sealed=false;}~ConfigureScope(){--owner.clip_configure_depth;}} configure_scope(*this);`);
text=once(text,'  configured=true;',`  // A failed configure may have retained partial vectors. Compute over the
  // complete current private map, and enable only after final success.
  has_any_clip_channels=false;for(const auto& clip:clips)if(!clip.second.empty()){has_any_clip_channels=true;break;}
  skip_empty_clip_lookups=::has(config,"skipEmptyClipLookups")?::get(config,"skipEmptyClipLookups").boolean():empty_clips::requested;
  empty_clip_map_sealed=clip_configure_depth==1;
  configured=true;`);
text=once(text,' void sample(const std::string& clip,float time){\n  auto found=clips.find(clip);',` void sample(const std::string& clip,float time){
  ++clip_sample_calls;if(!configured)++preconfigure_sample_calls;
  if(configured&&empty_clip_map_sealed&&clip_configure_depth==0&&skip_empty_clip_lookups&&!has_any_clip_channels){++empty_clip_lookup_skips;return;}
  ++clip_lookup_calls;
  auto found=clips.find(clip);`);
text=once(text,'case 9:out=owner.hot_parameter_info();break;','case 9:out=owner.hot_parameter_info();break;case 10:out=owner.empty_clip_info();break;');write(relative,text);
relative='native/particle_presentation.hpp';text=fs.readFileSync(path.join(kernel,relative),'utf8');
text=once(text,'case 19:out=resident::hot_parameters::component_oracle();break;','case 19:out=resident::hot_parameters::component_oracle();break;case 22:{auto rows=::array_empty();for(const auto& pair:owner.entries)if(pair.second->owner){auto row=pair.second->owner->empty_clip_info();::set(row,"id",EngineVar::integer(pair.first));::method(rows,"append",{row});}::set(out,"owners",rows);break;}');write(relative,text);
relative='native/particle_kernel.cpp';text=fs.readFileSync(path.join(kernel,relative),'utf8');text=once(text,'resident::hot_parameters::bind();','resident::hot_parameters::bind();resident::empty_clips::bind();');write(relative,text);
const group=fs.readFileSync(path.join(base,'systems/native_render/particle_stream_group.gd'));fs.mkdirSync(path.join(stage,'systems/native_render'),{recursive:true});fs.writeFileSync(path.join(stage,'systems/native_render/particle_stream_group.gd'),group);
fs.writeFileSync(path.join(stage,'kernel-source-pins.json'),JSON.stringify({version:1,project:kernel,pins,compilerInvoked:false,scope:'Independent default-legacy configure-success-only all-clips-empty lookup skip; no channel/value/clock/pose/simulation work skipped'},null,2)+'\n');
fs.writeFileSync(path.join(stage,'proposal.json'),JSON.stringify({label,kernel,sourcePins:pins,groupSha256:hash(group),flag:'--particle-empty-clips=skip',default:'legacy',nativeOwnerInspectDispatch:10,presentationInspectDispatch:22,residentTextIncluded:false,sourceWritesOutsideStage:0,sharedBinaryWrites:0,engineStarts:0},null,2)+'\n');
console.log(JSON.stringify({stage,files:pins.length,default:'legacy',independentFromResidentText:true}));
