'use strict';
// Isolated source transform. Does not modify any active engine tree.
// The root engine builder can import transform(header, source), preserving its
// independent metric insertions. Default engine behavior remains unchanged.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const MARKER='NWN_SKELETON_PAIR_GUARD_EXACT_V1';
function once(text,old,next){const count=text.split(old).length-1;if(count!==1)throw Error('Expected unique guard source anchor ('+count+'): '+old.slice(0,100));return text.replace(old,next);}
function transform(header,source){
 if(header.includes(MARKER)||source.includes(MARKER))throw Error('Pair guard already present');
 header=once(header,'\t\tbool update_dependencies;','\t\tbool update_dependencies;\n\t\t// '+MARKER+': pending queue reasons; any ordinary queue promotes this to false.\n\t\tbool update_skeleton_pair_only = true;');
 header=once(header,'\t\t\t\tcase Dependency::DEPENDENCY_CHANGED_SKELETON_BONES:\n','');
 header=once(header,'\t\t\t\tcase Dependency::DEPENDENCY_CHANGED_SKELETON_DATA:',
 '\t\t\t\tcase Dependency::DEPENDENCY_CHANGED_SKELETON_BONES: {\n\t\t\t\t\tsingleton->_instance_queue_update(instance, true, false, true);\n\t\t\t\t} break;\n\t\t\t\tcase Dependency::DEPENDENCY_CHANGED_SKELETON_DATA:');
 header=once(header,'void _instance_queue_update(Instance *p_instance, bool p_update_aabb, bool p_update_dependencies = false) const;',
 'void _instance_queue_update(Instance *p_instance, bool p_update_aabb, bool p_update_dependencies = false, bool p_skeleton_pair_only = false) const;');
 header=once(header,'void _update_instance(Instance *p_instance) const;','void _update_instance(Instance *p_instance, bool p_skeleton_pair_only) const;');
 source=once(source,'void RendererSceneCull::_instance_queue_update(Instance *p_instance, bool p_update_aabb, bool p_update_dependencies) const {',
 'void RendererSceneCull::_instance_queue_update(Instance *p_instance, bool p_update_aabb, bool p_update_dependencies, bool p_skeleton_pair_only) const {\n\t// Promote before list coalescing, including false/false capture and layer queues.\n\tif (!p_skeleton_pair_only || p_update_dependencies) {\n\t\tp_instance->update_skeleton_pair_only = false;\n\t}');
 source=once(source,'void RendererSceneCull::_update_dirty_instance(Instance *p_instance) const {',
 'void RendererSceneCull::_update_dirty_instance(Instance *p_instance) const {\n\tconst bool skeleton_pair_only = p_instance->update_skeleton_pair_only && p_instance->update_aabb && !p_instance->update_dependencies;\n\t// Consume this queue epoch before any callbacks can enqueue the next one.\n\tp_instance->update_skeleton_pair_only = true;');
 source=once(source,'\t_update_instance(p_instance);','\t_update_instance(p_instance, skeleton_pair_only);');
 source=once(source,'void RendererSceneCull::_update_instance(Instance *p_instance) const {',
 'void RendererSceneCull::_update_instance(Instance *p_instance, bool p_skeleton_pair_only) const {\n\t// '+MARKER+'; explicit opt-in only, read once on the rendering thread.\n\tstatic const bool skeleton_pair_guard_exact = OS::get_singleton()->get_cmdline_user_args().find("--skeleton-pair-guard=exact") != nullptr;\n\tconst bool skeleton_pair_had_index = p_instance->indexer_id.is_valid();');
 const guard='\t// Earlier deformation shadow dirtiness, lightmap capture, geometry transform,\n\t// motion vectors, versioning, quantized BVH shrink and visibility data remain\n\t// unchanged. Pair membership depends only on exact bounds and other volumes;\n\t// every non-bone queue cancels this fast path, and moved volumes repair both sides.\n\tif (skeleton_pair_guard_exact && p_skeleton_pair_only && p_instance->update_skeleton_pair_only &&\n\t\tp_instance->base_type == RSE::INSTANCE_MESH && p_instance->skeleton.is_valid() &&\n\t\tskeleton_pair_had_index && p_instance->indexer_id.is_valid() && p_instance->array_index >= 0 &&\n\t\tp_instance->aabb.is_finite() && instance_xform->is_finite() &&\n\t\tp_instance->transformed_aabb.is_finite() && p_instance->prev_transformed_aabb.is_finite() &&\n\t\tp_instance->transformed_aabb == p_instance->prev_transformed_aabb) {\n\t\tp_instance->prev_transformed_aabb = p_instance->transformed_aabb;\n\t\treturn;\n\t}\n\n';
 source=once(source,'\t//move instance and repair\n\tpair_pass++;',guard+'\t//move instance and repair\n\tpair_pass++;');
 return{header,source};
}
module.exports={transform,MARKER};
if(require.main===module){
 const baseline=path.resolve(__dirname,'../../../../.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/source'),output=path.resolve(__dirname,'../../../../.cache/native-render-gap/original/bounds-repair/source-a');if(fs.existsSync(output))throw Error('Keep prior staged guard source');
 const headerFile=path.join(baseline,'servers/rendering/renderer_scene_cull.h'),sourceFile=path.join(baseline,'servers/rendering/renderer_scene_cull.cpp'),header=fs.readFileSync(headerFile,'utf8'),source=fs.readFileSync(sourceFile,'utf8'),sha=s=>crypto.createHash('sha256').update(s).digest('hex');
 if(sha(header)!=='341e4f3da150bb91927479d55ef06baee2b212db96b3f548d92ef11ba3000f5e'||sha(source)!=='62658efa156d6b080a4d24eab9812f9f596a41b5998f077ae0fcb82976df933e')throw Error('Pinned baseline changed');
 const result=transform(header,source);fs.mkdirSync(output,{recursive:true});for(const [name,value]of[['renderer_scene_cull.h',result.header],['renderer_scene_cull.cpp',result.source]])fs.writeFileSync(path.join(output,name),value,{flag:'wx'});
 const receipt={version:1,baseline,output,defaultEnabled:false,arg:'--skeleton-pair-guard=exact',sourcePins:{header:sha(header),source:sha(source)},resultPins:{header:sha(result.header),source:sha(result.source)},scope:'Isolated source only; no engine compilation, runtime source replacement or GPU test performed.'};fs.writeFileSync(path.join(output,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(receipt,null,2));
}
