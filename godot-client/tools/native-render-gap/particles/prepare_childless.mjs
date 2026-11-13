import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),project=path.resolve(here,'../../..'),label=process.argv[2];if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh candidate label required');
const base=path.join(project,'.cache/native-render-gap/particles/boundary-skin-b'),basePins=JSON.parse(fs.readFileSync(path.join(base,'kernel-source-pins.json'))),stage=path.join(project,'.cache/native-render-gap/particles',label),kernel=path.join(stage,'kernel-project');if(fs.existsSync(stage))throw Error('Earlier proposal retained');fs.mkdirSync(kernel,{recursive:true});
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),pins=[];const once=(s,a,b)=>{if(s.split(a).length!==2)throw Error('Frozen source boundary changed: '+a.slice(0,100));return s.replace(a,b);};
for(const pin of basePins.pins){const bytes=fs.readFileSync(path.join(basePins.project,pin.relative));if(hash(bytes)!==pin.sha256)throw Error('Frozen boundary source changed');const dest=path.join(kernel,pin.relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes);pins.push({...pin,source:path.join(basePins.project,pin.relative),originalSha256:pin.sha256});}
function patch(relative,edit){const file=path.join(kernel,relative);const prior=fs.readFileSync(file,'utf8').replaceAll('\r\n','\n'),next=edit(prior);fs.writeFileSync(file,next);const pin=pins.find(p=>p.relative===relative);pin.sha256=hash(Buffer.from(next));pin.bytes=Buffer.byteLength(next);}
patch('native/particle_resident.hpp',s=>once(s,' EngineVar pose_diagnostics(){',` // Original CalculateRadius inspects current active chunk views BEFORE this
 // frame's simulation/spawns. Free/recycled children are not bound inputs.
 // 1=empty active,2=known native views/all nil child,3=missing metadata,
 // 4=unknown view kind,5=nonnull child (including stale/unknown objects).
 int childless_chunk_proof()const{
  if(!configured||!compact_records||!typed_frame||!compact_state.chunk)return 0;
  if(compact_pool.active.empty())return 1;
  for(auto* particle:compact_pool.active){const auto found=compact_extras.find(particle);if(found==compact_extras.end())return 3;if(!found->second.native_chunk)return 4;if(!found->second.child.nil())return 5;}
  return 2;
 }
 EngineVar pose_diagnostics(){`));
patch('native/particle_presentation.hpp',s=>{
 s=once(s,'bool culling=true,draw_enabled=true,detonate=false,profile=false,original_admission=false,animate=true;','bool culling=true,draw_enabled=true,detonate=false,profile=false,original_admission=false,animate=true,childless_chunk_admission=false;');
 s=once(s,'bool prepared=false,culled=false,checked=false,animation_invoked=false,updated=false;float radius=0;','bool prepared=false,culled=false,checked=false,animation_invoked=false,updated=false;float radius=0;int chunk_proof=0;');
 s=once(s,'prepared=false;culled=false;checked=false;animation_invoked=false;updated=false;radius=0;','prepared=false;culled=false;checked=false;animation_invoked=false;updated=false;radius=0;chunk_proof=0;');
 s=once(s,'const bool known_wind=!wind||wind->points.empty();checked=known_wind&&!emitter.chunk&&camera&&controls.culling&&controls.source_flags>=0;',
 `const bool known_wind=!wind||wind->points.empty();
  if(controls.childless_chunk_admission&&emitter.chunk&&known_wind&&camera&&controls.culling&&controls.source_flags>=0)chunk_proof=owner->childless_chunk_proof();
  const bool childless=chunk_proof==1||chunk_proof==2;
  checked=known_wind&&(!emitter.chunk||childless)&&camera&&controls.culling&&controls.source_flags>=0;`);
 s=once(s,'if(::has(config,"source_flags"))c.source_flags=::get(config,"source_flags").integer();','if(::has(config,"childless_chunk_admission"))c.childless_chunk_admission=::get(config,"childless_chunk_admission").boolean();\n  if(::has(config,"source_flags"))c.source_flags=::get(config,"source_flags").integer();');
 s=once(s,' EngineVar entry_info(int64_t id)const{',` EngineVar chunk_census()const{
  auto out=EngineVar::dictionary(),rows=::array_empty();int64_t counts[6]{};
  for(const auto id:order){const auto& entry=*entries.at(id);if(!entry.owner||!entry.owner->compact_state.chunk)continue;const auto proof=entry.owner->childless_chunk_proof();++counts[proof];auto row=EngineVar::dictionary();
   ::set(row,"id",EngineVar::integer(id));::set(row,"resource",EngineVar::text(resident::get(entry.owner->state,particle_field::chunkName).string.c_str()));::set(row,"proof",EngineVar::integer(proof));::set(row,"active",EngineVar::integer(static_cast<int64_t>(entry.owner->compact_pool.active.size())));::set(row,"free",EngineVar::integer(static_cast<int64_t>(entry.owner->compact_pool.free.size())));::set(row,"source_flags",EngineVar::integer(entry.controls.source_flags));::set(row,"requested",EngineVar::boolean(entry.controls.childless_chunk_admission));::set(row,"last_checked",EngineVar::boolean(entry.step.checked));::set(row,"last_culled",EngineVar::boolean(entry.step.culled));::set(row,"last_proof",EngineVar::integer(entry.step.chunk_proof));::method(rows,"append",{row});}
  ::set(out,"entries",rows);const char* names[]={"unsupported","empty_active","all_active_children_nil","missing_metadata","unknown_view","nonnull_child"};for(size_t index=0;index<6;++index)::set(out,names[index],EngineVar::integer(counts[index]));return out;
 }
 EngineVar entry_info(int64_t id)const{`);
 s=once(s,'::set(out,"pending_patch",EngineVar::boolean(!e.controls.patch.nil()));return out;','::set(out,"pending_patch",EngineVar::boolean(!e.controls.patch.nil()));::set(out,"childless_chunk_admission",EngineVar::boolean(e.controls.childless_chunk_admission));::set(out,"chunk_proof",EngineVar::integer(e.step.chunk_proof));return out;');
 s=once(s,'case 13:out=particle_scene_boundary::inspect();break;','case 13:out=particle_scene_boundary::inspect();break;case 14:out=owner.chunk_census();break;');return s;
});
let group=fs.readFileSync(path.join(project,'systems/native_render/particle_stream_group.gd'),'utf8').replaceAll('\r\n','\n');const groupOriginal=hash(fs.readFileSync(path.join(project,'systems/native_render/particle_stream_group.gd')));
group=once(group,'\tif fast:\n\t\tconfig.merge(', '\tif fast:\n\t\tconfig.childless_chunk_admission=OS.get_cmdline_user_args().has("--particle-chunk-admission=childless")\n\t\tconfig.merge(');
fs.mkdirSync(path.join(stage,'systems/native_render'),{recursive:true});fs.writeFileSync(path.join(stage,'systems/native_render/particle_stream_group.gd'),group);
fs.writeFileSync(path.join(stage,'kernel-source-pins.json'),JSON.stringify({version:1,project:kernel,pins,compilerInvoked:false,scope:'Private default-off fresh active-childless chunk admission; no runtime/performance acceptance'},null,2)+'\n');
fs.writeFileSync(path.join(stage,'proposal.json'),JSON.stringify({version:1,label,kernel:kernel,sourcePins:pins,script:{relative:'systems/native_render/particle_stream_group.gd',originalSha256:groupOriginal,sha256:hash(Buffer.from(group))},base:{file:path.join(base,'kernel-source-pins.json'),sha256:hash(fs.readFileSync(path.join(base,'kernel-source-pins.json')))},sharedSourceWrites:0,sharedBinaryWrites:0,engineStarts:0,scope:'Source-only proposal. Current active typed-view/nil-child proof after controllers/commands/poses, before unchanged conservative admission. Freepool ignored; all unknown/nonnull children fall back.'},null,2)+'\n');
console.log(JSON.stringify({stage,kernel,files:pins.length,default:'off'}));
