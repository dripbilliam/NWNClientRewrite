const fs=require('fs'),path=require('path'),crypto=require('crypto');
const project=path.resolve(__dirname,'../../..'),stage=path.join(project,'.cache/native-render-gap/engine'),file=path.join(stage,'manifest.json'),m=JSON.parse(fs.readFileSync(file)),source=m.source;
const sha=x=>crypto.createHash('sha256').update(x).digest('hex'),plans=new Map();
function once(s,a,b){if(s.split(a).length!==2)throw Error('Nonunique anchor '+a.slice(0,120));return s.replace(a,b);}
function read(relative){return plans.get(relative)?.after??fs.readFileSync(path.join(source,relative),'utf8');}
function edit(relative,fn){const before=read(relative),after=fn(before);if(before===after)throw Error('No change '+relative);if(!plans.has(relative))plans.set(relative,{before,after});else plans.get(relative).after=after;}
for(const p of m.patches)if(sha(fs.readFileSync(path.join(source,p.relative)))!==p.afterSha256)throw Error('Private source drift');
for(const p of m.modules)if(sha(fs.readFileSync(path.join(source,p.relative)))!==p.sha256)throw Error('Private module drift');
for(const script of ['pair-reuse.cjs','light-pair-filter.cjs']){
 const r=require('../original/bounds-repair/'+script).transform(read('servers/rendering/renderer_scene_cull.h'),read('servers/rendering/renderer_scene_cull.cpp'));
 edit('servers/rendering/renderer_scene_cull.h',()=>r.header);edit('servers/rendering/renderer_scene_cull.cpp',()=>r.source);
}
const keys=['PAIR_QUERY_VISITS','PAIR_MATCHES','PAIR_RECORDS_REUSED','PAIR_RECORDS_ALLOCATED','PAIR_RECORDS_FREED','PAIR_RELATIONS_ADDED','PAIR_RELATIONS_REMOVED','PAIR_RELATIONS_KEPT','PAIR_REUSE_FALLBACKS','LIGHT_PAIR_CANDIDATES','LIGHT_PAIR_EXCLUDED','LIGHT_PAIR_KEPT','LIGHT_PAIR_FALLBACKS'];
const features=['F_BONE_SKIPPED','F_PAIR_SKIPPED','F_PAIR_REUSED','F_PAIR_ALLOCATED','F_PAIR_FREED','F_PAIR_REUSE_PASSES','F_PAIR_REUSE_FALLBACKS','F_LIGHT_EXCLUDED','F_LIGHT_KEPT','F_LIGHT_CANDIDATES','F_LIGHT_FILTER_PASSES'];
edit('modules/nwn_frame_probe/frame_probe.h',s=>{
 s=once(s,' COUNT\n',' '+keys.join(', ')+',\n COUNT\n');
 s=once(s,'bool active();','enum Feature { '+features.join(', ')+', F_COUNT };\nvoid feature_add(Feature key,uint64_t value=1);\nbool active();');
 return once(s,' static Dictionary dirty_instance_sample();',' static Dictionary dirty_instance_sample();\n static Dictionary feature_totals();');
});
edit('modules/nwn_frame_probe/frame_probe.cpp',s=>{
 s=once(s,'"world_bounds_changed"','"world_bounds_changed",\n '+keys.map(k=>'"'+k.toLowerCase()+'"').join(', '));
 s=once(s,'thread_local uint64_t sample_total=0;','thread_local uint64_t sample_total=0;\nstd::atomic<uint64_t> feature_generation{0},feature_frame{0};\nstd::atomic<uint64_t> feature_published[NwnFrameMetrics::F_COUNT]{};\nthread_local uint64_t feature_values[NwnFrameMetrics::F_COUNT]{};\nthread_local bool feature_touched=false;\nconst char *feature_names[]={'+features.map(k=>'"'+k.slice(2).toLowerCase()+'"').join(',')+'};');
 s=once(s,'bool active() { return recording; }','void feature_add(Feature key,uint64_t value) { if(value){ feature_values[key]+=value;feature_touched=true; } }\nbool active() { return recording; }');
 s=once(s,'void finish() {\n if (!recording) return;','void finish() {\n if(feature_touched) {\n  feature_generation.fetch_add(1);\n  for(int i=0;i<F_COUNT;++i)feature_published[i].store(feature_values[i]);\n  feature_frame.fetch_add(1);feature_generation.fetch_add(1);\n }\n if (!recording) return;');
 s=once(s,'void NwnFrameProbe::_bind_methods() {',
 'Dictionary NwnFrameProbe::feature_totals() {\n Dictionary out;out["available"]=false;\n for(int attempt=0;attempt<5;++attempt) {\n  const uint64_t before=feature_generation.load();if(before&1)continue;\n  uint64_t copy[NwnFrameMetrics::F_COUNT];for(int i=0;i<NwnFrameMetrics::F_COUNT;++i)copy[i]=feature_published[i].load();\n  const uint64_t frame=feature_frame.load();if(before!=feature_generation.load()||frame==0)continue;\n  out["available"]=true;out["frames"]=int64_t(frame);\n  for(int i=0;i<NwnFrameMetrics::F_COUNT;++i)out[feature_names[i]]=int64_t(copy[i]);\n  break;\n }\n out["scope"]="Actual feature work, cumulative through a completed render frame; plain render-thread counters plus bounded atomic publication, profiling-independent; no time/FPS claim.";return out;\n}\nvoid NwnFrameProbe::_bind_methods() {');
 return once(s,' ClassDB::bind_static_method("NwnFrameProbe", D_METHOD("dirty_instance_sample"), &NwnFrameProbe::dirty_instance_sample);',' ClassDB::bind_static_method("NwnFrameProbe", D_METHOD("dirty_instance_sample"), &NwnFrameProbe::dirty_instance_sample);\n ClassDB::bind_static_method("NwnFrameProbe", D_METHOD("feature_totals"), &NwnFrameProbe::feature_totals);');
});
edit('servers/rendering/renderer_scene_cull.cpp',s=>{
 s=once(s,'\t\tNwnFrameMetrics::add(NwnFrameMetrics::PAIR_SKIPPED);','\t\tNwnFrameMetrics::add(NwnFrameMetrics::PAIR_SKIPPED);\n\t\tNwnFrameMetrics::feature_add(NwnFrameMetrics::F_PAIR_SKIPPED);');
 const original='\t{ NwnFrameMetrics::Scope probe(NwnFrameMetrics::PAIR_REPAIR_US); pair.pair(); }';
 let next=original+'\n';
 for(const [key,field]of [['PAIR_QUERY_VISITS','query_visits'],['PAIR_MATCHES','matched_count'],['PAIR_RECORDS_REUSED','record_reused_count'],['PAIR_RECORDS_ALLOCATED','record_allocated_count'],['PAIR_RECORDS_FREED','record_freed_count'],['PAIR_RELATIONS_ADDED','relation_added_count'],['PAIR_RELATIONS_REMOVED','relation_removed_count'],['PAIR_RELATIONS_KEPT','relation_kept_count'],['PAIR_REUSE_FALLBACKS','reuse_fallback_count'],['LIGHT_PAIR_CANDIDATES','light_filter_candidates'],['LIGHT_PAIR_EXCLUDED','light_filter_excluded'],['LIGHT_PAIR_KEPT','light_filter_kept'],['LIGHT_PAIR_FALLBACKS','light_filter_fallbacks']])next+='\tNwnFrameMetrics::add(NwnFrameMetrics::'+key+',pair.'+field+');\n';
 next+='\tif(pair_record_reuse_exact) {\n';
 for(const [key,field]of [['F_PAIR_REUSED','record_reused_count'],['F_PAIR_ALLOCATED','record_allocated_count'],['F_PAIR_FREED','record_freed_count'],['F_PAIR_REUSE_FALLBACKS','reuse_fallback_count']])next+='\t NwnFrameMetrics::feature_add(NwnFrameMetrics::'+key+',pair.'+field+');\n';
 next+='\t if(pair.reuse_records) NwnFrameMetrics::feature_add(NwnFrameMetrics::F_PAIR_REUSE_PASSES);\n\t}\n\tif(pair.filter_light_pairs) {\n';
 for(const [key,field]of [['F_LIGHT_EXCLUDED','light_filter_excluded'],['F_LIGHT_KEPT','light_filter_kept'],['F_LIGHT_CANDIDATES','light_filter_candidates']])next+='\t NwnFrameMetrics::feature_add(NwnFrameMetrics::'+key+',pair.'+field+');\n';
 next+='\t NwnFrameMetrics::feature_add(NwnFrameMetrics::F_LIGHT_FILTER_PASSES);\n\t}';
 return once(s,original,next);
});
edit('servers/rendering/renderer_rd/storage_rd/mesh_storage.cpp',s=>once(s,'NwnFrameMetrics::add(NwnFrameMetrics::BONE_GUARD_SKIPPED); return;','NwnFrameMetrics::add(NwnFrameMetrics::BONE_GUARD_SKIPPED); NwnFrameMetrics::feature_add(NwnFrameMetrics::F_BONE_SKIPPED); return;'));
const lightStage=path.join(project,'.cache/native-render-gap/scene/light-live-a'),lightProof=path.join(lightStage,'manifest.json'),light=JSON.parse(fs.readFileSync(lightProof));
for(const p of light.outputs)if(sha(fs.readFileSync(p.file))!==p.sha256)throw Error('Sealed live-light proposal drift');
const lightModule=path.join(lightStage,'engine_module/nwn_light_input_registry');
for(const f of fs.readdirSync(lightModule)){
 if(!/\.(cpp|h|py)$/.test(f)&&f!=='SCsub')continue;
 const relative='modules/nwn_light_input_registry/'+f;
 const before=fs.readFileSync(path.join(source,relative),'utf8'),after=fs.readFileSync(path.join(lightModule,f),'utf8');
 if(before!==after)plans.set(relative,{before,after});
}
const dir=path.join(stage,'upgrade-v4');if(fs.existsSync(dir))throw Error('Existing upgrade retained');
fs.mkdirSync(dir,{recursive:true});fs.copyFileSync(file,path.join(dir,'previous-manifest.json'));
for(const [relative,p]of plans){const saved=path.join(dir,'before',relative);fs.mkdirSync(path.dirname(saved),{recursive:true});fs.writeFileSync(saved,p.before);fs.writeFileSync(path.join(source,relative),p.after);if(!relative.startsWith('modules/'))m.patches.find(x=>x.relative===relative).afterSha256=sha(p.after);}
m.modules=[];for(const name of ['nwn_frame_probe','nwn_particle_snapshot','nwn_motion_numeric','nwn_light_input_registry'])for(const f of fs.readdirSync(path.join(source,'modules',name))){const p=path.join(source,'modules',name,f);if(fs.statSync(p).isFile())m.modules.push({relative:path.relative(source,p),sha256:sha(fs.readFileSync(p))});}
m.revision=4;m.createdAt=new Date().toISOString();m.lightReaderProposal={file:lightProof,sha256:sha(fs.readFileSync(lightProof))};m.upgradeV4='Independent default-off exact pair record reuse, Clustered light-consumer filter requiring layer-repair correctness control, live canonical GDScript light-field reads; cold profiling-independent actual feature counters.';
fs.writeFileSync(file,JSON.stringify(m,null,2)+'\n');fs.writeFileSync(path.join(dir,'receipt.json'),JSON.stringify({success:true,changes:[...plans].map(([relative,p])=>({relative,before:sha(p.before),after:sha(p.after)})),manifestSha256:sha(fs.readFileSync(file))},null,2)+'\n');console.log(JSON.stringify({success:true,changes:plans.size,source}));
