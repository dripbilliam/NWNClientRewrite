'use strict';
// Private Clustered light-pair consumer filter. No active source mutation.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const MARKER='NWN_LIGHT_PAIR_CONSUMERS_V1';
const once=(text,old,next)=>{const n=text.split(old).length-1;if(n!==1)throw Error('Light pair filter source anchor count '+n+': '+old.slice(0,110));return text.replace(old,next);};
function transform(header,source){
 if(header.includes(MARKER)||source.includes(MARKER))throw Error('Light pair filter already present');
 header=once(header,'\t\tbool uses_projector = false;','\t\t// '+MARKER+': refreshed by each light update before its pair query.\n\t\tbool uses_shadow = false;\n\t\tbool uses_projector = false;');
 header=once(header,'\t\tuint64_t pair_pass;\n','\t\tuint64_t pair_pass;\n\t\tbool filter_light_pairs = false;\n\t\tuint64_t light_filter_candidates = 0, light_filter_excluded = 0, light_filter_kept = 0, light_filter_fallbacks = 0;\n');
 const gate='\t\t\tif (instance != p_instance && instance->transformed_aabb.intersects(p_instance->transformed_aabb) && (pair_mask & (1 << p_instance->base_type))) {\n';
 header=once(header,gate,gate+`\t\t\t\tif (filter_light_pairs) {
\t\t\t\t\tInstance *light_instance = nullptr;
\t\t\t\t\tif (instance->base_type == RSE::INSTANCE_LIGHT && ((1 << p_instance->base_type) & RSE::INSTANCE_GEOMETRY_MASK)) {
\t\t\t\t\t\tlight_instance = instance;
\t\t\t\t\t} else if (p_instance->base_type == RSE::INSTANCE_LIGHT && ((1 << instance->base_type) & RSE::INSTANCE_GEOMETRY_MASK)) {
\t\t\t\t\t\tlight_instance = p_instance;
\t\t\t\t\t}
\t\t\t\t\tif (light_instance) {
\t\t\t\t\t\tlight_filter_candidates++;
\t\t\t\t\t\tconst InstanceLightData *light = static_cast<const InstanceLightData *>(light_instance->base_data);
\t\t\t\t\t\tif (!light) {
\t\t\t\t\t\t\t// Unknown state conservatively keeps the legacy relationship.
\t\t\t\t\t\t\tlight_filter_fallbacks++;
\t\t\t\t\t\t} else if (!light->uses_shadow && !light->uses_projector && !light->uses_softshadow) {
\t\t\t\t\t\t\tlight_filter_excluded++;
\t\t\t\t\t\t\treturn false;
\t\t\t\t\t\t} else {
\t\t\t\t\t\t\tlight_filter_kept++;
\t\t\t\t\t\t}
\t\t\t\t\t}
\t\t\t\t}
`);
 const update='\tif (p_instance->base_type == RSE::INSTANCE_LIGHT) {\n\t\tInstanceLightData *light = static_cast<InstanceLightData *>(p_instance->base_data);\n\n\t\tRSG::light_storage->light_instance_set_transform';
 source=once(source,update,'\tif (p_instance->base_type == RSE::INSTANCE_LIGHT) {\n\t\tInstanceLightData *light = static_cast<InstanceLightData *>(p_instance->base_data);\n\t\tlight->uses_shadow = RSG::light_storage->light_has_shadow(p_instance->base);\n\n\t\tRSG::light_storage->light_instance_set_transform');
 source=once(source,'\t// Particles always need to be unpaired. Geometry may need to be unpaired, but only if lights or decals use pairing.\n',`\t// ${MARKER}: Clustered shadow/projector membership also depends on geometry layers.
\t// Opt-in correctness control repairs this dependency before evaluating the consumer filter.
\tstatic const bool light_pair_layer_repair_exact = OS::get_singleton()->get_cmdline_user_args().find("--light-pair-layer-repair=exact") != nullptr;
\tconst bool clustered_layer_pair_repair = light_pair_layer_repair_exact && geometry_instance_pair_mask == (1u << RSE::INSTANCE_VOXEL_GI);
\t// Particles always need to be unpaired. Geometry may need to be unpaired for light or decal membership.
`);
 source=once(source,'(((geometry_instance_pair_mask & (1 << RSE::INSTANCE_LIGHT)) || (geometry_instance_pair_mask & (1 << RSE::INSTANCE_DECAL))) && ((1 << instance->base_type) & RSE::INSTANCE_GEOMETRY_MASK))','(((geometry_instance_pair_mask & (1 << RSE::INSTANCE_LIGHT)) || (geometry_instance_pair_mask & (1 << RSE::INSTANCE_DECAL)) || clustered_layer_pair_repair) && ((1 << instance->base_type) & RSE::INSTANCE_GEOMETRY_MASK))');
 source=once(source,'\tPairInstances pair;\n',`\t// ${MARKER}: Clustered has no per-geometry traditional light consumer.
\tstatic const bool light_pair_filter_consumers = OS::get_singleton()->get_cmdline_user_args().find("--light-pair-filter=consumers") != nullptr;
\tstatic const bool light_pair_layer_repair_exact = OS::get_singleton()->get_cmdline_user_args().find("--light-pair-layer-repair=exact") != nullptr;
\tPairInstances pair;
\t// Exact renderer mask deliberately leaves Mobile, Compatibility and unknown renderers unchanged.
\t// Require the layer repair correctness control; otherwise preserve the baseline path.
\tpair.filter_light_pairs = light_pair_filter_consumers && light_pair_layer_repair_exact && geometry_instance_pair_mask == (1u << RSE::INSTANCE_VOXEL_GI);
`);
 return{header,source};
}
module.exports={transform,MARKER};
if(require.main===module){const label=process.argv[2]??'a';if(!/^[a-z0-9-]+$/.test(label))throw Error('Fresh stage label required');const project=path.resolve(__dirname,'../../../..'),base=path.join(project,'.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/source'),out=path.join(project,'.cache/native-render-gap/original/bounds-repair/light-filter-source-'+label);if(fs.existsSync(out))throw Error('Keep prior source stage');const header=fs.readFileSync(path.join(base,'servers/rendering/renderer_scene_cull.h'),'utf8'),source=fs.readFileSync(path.join(base,'servers/rendering/renderer_scene_cull.cpp'),'utf8'),result=transform(header,source),sha=x=>crypto.createHash('sha256').update(x).digest('hex');fs.mkdirSync(out,{recursive:true});for(const[name,data]of[['renderer_scene_cull.h',result.header],['renderer_scene_cull.cpp',result.source]])fs.writeFileSync(path.join(out,name),data,{flag:'wx'});const receipt={version:2,output:out,baseline:base,marker:MARKER,argument:'--light-pair-filter=consumers',requiredControlArgument:'--light-pair-layer-repair=exact',defaultEnabled:false,scope:'Private source prototype only; same-engine GPU functional and performance acceptance required. Layer repair alone is the correctness control; filter without layer repair fails closed.',headerBefore:sha(header),sourceBefore:sha(source),headerAfter:sha(result.header),sourceAfter:sha(result.source)};fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(receipt));}
