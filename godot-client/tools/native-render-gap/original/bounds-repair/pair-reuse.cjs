'use strict';
// Exact-query pair-record reuse prototype. All changes stay in staged source.
// Same BVH queries, intersection tests, callback sequence and final list order.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const MARKER='NWN_PAIR_RECORD_REUSE_EXACT_V1';
const once=(text,old,next)=>{const n=text.split(old).length-1;if(n!==1)throw Error('Pair reuse source anchor count'+n+': '+old.slice(0,100));return text.replace(old,next);};
function transform(header,source){
 if(header.includes(MARKER)||source.includes(MARKER))throw Error('Pair reuse already present');
 header=once(header,'\t\tuint64_t pair_check;','\t\tuint64_t pair_check;\n\t\t// '+MARKER+': scratch exists only during one serialized pair pass.\n\t\tuint64_t pair_reuse_pass = 0;\n\t\tInstancePair *pair_reuse_candidate = nullptr;');
 header=once(header,'\t\tuint64_t pair_pass;\n','\t\tuint64_t pair_pass;\n\t\tbool reuse_records = false;\n\t\tuint64_t query_visits = 0, matched_count = 0, record_reused_count = 0, record_allocated_count = 0, record_freed_count = 0;\n\t\tuint64_t relation_added_count = 0, relation_removed_count = 0, relation_kept_count = 0, reuse_fallback_count = 0;\n');
 header=once(header,'\t\t\tInstance *p_instance = (Instance *)p_data;\n\n\t\t\tif (instance != p_instance',
 '\t\t\tInstance *p_instance = (Instance *)p_data;\n\t\t\tquery_visits++;\n\n\t\t\tif (instance != p_instance');
 header=once(header,'\t\t\t\tp_instance->pair_check = pair_pass;\n\t\t\t\tInstancePair *pair = pair_allocator->alloc();\n\t\t\t\tpair->a = instance;\n\t\t\t\tpair->b = p_instance;\n\t\t\t\tpairs_found.add(&pair->list_a);',
 `\t\t\t\tmatched_count++;
\t\t\t\tInstancePair *pair = nullptr;
\t\t\t\tif (reuse_records && p_instance->pair_reuse_pass == pair_pass) {
\t\t\t\t\t// An old relation exists, including an unexpected repeated BVH hit.
\t\t\t\t\t// Retain the baseline zero marker so only genuinely new relations call _instance_pair.
\t\t\t\t\tp_instance->pair_check = 0;
\t\t\t\t\tpair = p_instance->pair_reuse_candidate;
\t\t\t\t\tif (pair) {
\t\t\t\t\t\tp_instance->pair_reuse_candidate = nullptr;
\t\t\t\t\t\tpair->list_a.remove_from_list();
\t\t\t\t\t\tpair->list_b.remove_from_list();
\t\t\t\t\t\trecord_reused_count++;
\t\t\t\t\t\trelation_kept_count++;
\t\t\t\t\t}
\t\t\t\t} else {
\t\t\t\t\tp_instance->pair_check = pair_pass;
\t\t\t\t}
\t\t\t\tif (!pair) {
\t\t\t\t\tpair = pair_allocator->alloc();
\t\t\t\t\trecord_allocated_count++;
\t\t\t\t}
\t\t\t\t// A kept record can have the opposite orientation from its prior owner.
\t\t\t\tpair->a = instance;
\t\t\t\tpair->b = p_instance;
\t\t\t\tpairs_found.add(&pair->list_a);`);
 header=once(header,'\t\tvoid pair() {\n\t\t\tif (bvh) {',
 `\t\tvoid pair() {
\t\t\t// Current callbacks only enqueue work; they do not recursively drain pairs.
\t\t\t// Dirty scratch or duplicate old relations conservatively retain the baseline path.
\t\t\tif (reuse_records && pair_pass == 0) {
\t\t\t\treuse_records = false;
\t\t\t\treuse_fallback_count++;
\t\t\t}
\t\t\tif (reuse_records) {
\t\t\t\t// Validate before seeding so a foreign/stale same-pass marker is never cleared.
\t\t\t\tfor (const SelfList<InstancePair> *E = instance->pairs.first(); E; E = E->next()) {
\t\t\t\t\tInstancePair *old_pair = E->self();
\t\t\t\t\tInstance *other = instance == old_pair->a ? old_pair->b : old_pair->a;
\t\t\t\t\tif (other->pair_reuse_pass != 0 || other->pair_reuse_candidate != nullptr) {
\t\t\t\t\t\treuse_records = false;
\t\t\t\t\t\treuse_fallback_count++;
\t\t\t\t\t\tbreak;
\t\t\t\t\t}
\t\t\t\t}
\t\t\t}
\t\t\tif (reuse_records) {
\t\t\t\tfor (const SelfList<InstancePair> *E = instance->pairs.first(); E; E = E->next()) {
\t\t\t\t\tInstancePair *old_pair = E->self();
\t\t\t\t\tInstance *other = instance == old_pair->a ? old_pair->b : old_pair->a;
\t\t\t\t\tif (other->pair_reuse_pass != 0 || other->pair_reuse_candidate != nullptr) {
\t\t\t\t\t\treuse_records = false;
\t\t\t\t\t\treuse_fallback_count++;
\t\t\t\t\t\tbreak;
\t\t\t\t\t}
\t\t\t\t\tother->pair_reuse_pass = pair_pass;
\t\t\t\t\tother->pair_reuse_candidate = old_pair;
\t\t\t\t}
\t\t\t\tif (!reuse_records) {
\t\t\t\t\t// Clear only scratch seeded by this operation, never another active pass.
\t\t\t\t\tfor (const SelfList<InstancePair> *E = instance->pairs.first(); E; E = E->next()) {
\t\t\t\t\t\tInstancePair *old_pair = E->self();
\t\t\t\t\t\tInstance *other = instance == old_pair->a ? old_pair->b : old_pair->a;
\t\t\t\t\t\tif (other->pair_reuse_pass == pair_pass && other->pair_reuse_candidate == old_pair) {
\t\t\t\t\t\t\tother->pair_reuse_pass = 0;
\t\t\t\t\t\t\tother->pair_reuse_candidate = nullptr;
\t\t\t\t\t\t}
\t\t\t\t\t}
\t\t\t\t}
\t\t\t}
\t\t\tif (bvh) {`);
 header=once(header,'\t\t\t\tInstance *other_instance = instance == pair->a ? pair->b : pair->a;\n\t\t\t\tif (other_instance->pair_check != pair_pass) {',
 `\t\t\t\tInstance *other_instance = instance == pair->a ? pair->b : pair->a;
\t\t\t\tif (reuse_records && other_instance->pair_reuse_pass == pair_pass && other_instance->pair_reuse_candidate == pair) {
\t\t\t\t\tother_instance->pair_reuse_pass = 0;
\t\t\t\t\tother_instance->pair_reuse_candidate = nullptr;
\t\t\t\t}
\t\t\t\tif (other_instance->pair_check != pair_pass) {`);
 header=once(header,'\t\t\t\t\t//unpaired\n\t\t\t\t\t_instance_unpair(instance, other_instance);',
 '\t\t\t\t\t//unpaired\n\t\t\t\t\trelation_removed_count++;\n\t\t\t\t\t_instance_unpair(instance, other_instance);');
 header=once(header,'\t\t\t\t\t//kept\n\t\t\t\t\tother_instance->pair_check = 0;',
 '\t\t\t\t\t//kept\n\t\t\t\t\trelation_kept_count++;\n\t\t\t\t\tother_instance->pair_check = 0;');
 header=once(header,'\n\t\t\t\tpair_allocator->free(pair);\n\t\t\t}\n\t\t\twhile (pairs_found.first()) {',
 '\n\t\t\t\trecord_freed_count++;\n\t\t\t\tpair_allocator->free(pair);\n\t\t\t}\n\t\t\twhile (pairs_found.first()) {');
 header=once(header,'\t\t\t\tpairs_found.remove(pairs_found.first());\n\n\t\t\t\tif (pair->b->pair_check == pair_pass) {',
 `\t\t\t\tpairs_found.remove(pairs_found.first());
\t\t\t\tif (reuse_records && pair->b->pair_reuse_pass == pair_pass) {
\t\t\t\t\tDEV_ASSERT(pair->b->pair_reuse_candidate == nullptr);
\t\t\t\t\tpair->b->pair_reuse_pass = 0;
\t\t\t\t}

\t\t\t\tif (pair->b->pair_check == pair_pass) {`);
 header=once(header,'\t\t\t\t\t//paired\n\t\t\t\t\t_instance_pair(instance, pair->b);',
 '\t\t\t\t\t//paired\n\t\t\t\t\trelation_added_count++;\n\t\t\t\t\t_instance_pair(instance, pair->b);');
 source=once(source,'\tPairInstances pair;\n',
 `\t// ${MARKER}: opt-in exact-query record reuse; baseline remains available.
\tstatic const bool pair_record_reuse_exact = OS::get_singleton()->get_cmdline_user_args().find("--pair-record-reuse=exact") != nullptr;
\t// Preserve the legacy stamp behavior after an unsigned wrap instead of aliasing scratch epochs.
\tstatic bool pair_record_reuse_pass_wrapped = false;
\tif (pair_pass == 0) {
\t\tpair_record_reuse_pass_wrapped = true;
\t}
\tPairInstances pair;
\tpair.reuse_records = pair_record_reuse_exact && !pair_record_reuse_pass_wrapped;
`);
 return{header,source};
}
module.exports={transform,MARKER};
if(require.main===module){const label=process.argv[2]??'a';if(!/^[a-z0-9-]+$/.test(label))throw Error('Fresh source label required');const project=path.resolve(__dirname,'../../../..'),baseline=path.join(project,'.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/source'),output=path.join(project,'.cache/native-render-gap/original/bounds-repair/reuse-source-'+label);if(fs.existsSync(output))throw Error('Keep staged pair reuse');const header=fs.readFileSync(path.join(baseline,'servers/rendering/renderer_scene_cull.h'),'utf8'),source=fs.readFileSync(path.join(baseline,'servers/rendering/renderer_scene_cull.cpp'),'utf8'),result=transform(header,source),sha=x=>crypto.createHash('sha256').update(x).digest('hex');fs.mkdirSync(output,{recursive:true});for(const [name,data]of[['renderer_scene_cull.h',result.header],['renderer_scene_cull.cpp',result.source]])fs.writeFileSync(path.join(output,name),data,{flag:'wx'});const receipt={version:1,baseline,output,arg:'--pair-record-reuse=exact',defaultEnabled:false,headerBefore:sha(header),sourceBefore:sha(source),headerAfter:sha(result.header),sourceAfter:sha(result.source),scope:'Prototype source only. No engine compile/runtime change; differential callback/list oracle and real engine fixture required.'};fs.writeFileSync(path.join(output,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(receipt,null,2));}
