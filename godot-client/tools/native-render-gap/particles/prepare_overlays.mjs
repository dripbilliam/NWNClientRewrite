// Freeze small private overlays against current main sources. This never writes
// main systems/native, shared DLLs, descriptors, or an existing output folder.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url));
const project=path.resolve(here,'../../..');const label=process.argv[2];
const skinV2=process.argv[3]==='--skin-v2';if(process.argv[3]&&!skinV2)throw Error('Unknown skin ABI selection');
if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh overlay label required');
const output=path.join(project,'.cache/native-render-gap/particles',label);if(fs.existsSync(output))throw Error('Previous output preserved');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const pins=[],changes=[];const read=relative=>{const bytes=fs.readFileSync(path.join(project,relative));pins.push({relative,sha256:hash(bytes),bytes:bytes.length});return bytes.toString('utf8').replaceAll('\r\n','\n');};
const once=(s,before,after)=>{if(s.split(before).length!==2)throw Error('Current source boundary changed: '+before.slice(0,100));return s.replace(before,after);};
const write=(relative,source)=>{const file=path.join(output,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,source);changes.push({relative,sha256:hash(fs.readFileSync(file)),bytes:Buffer.byteLength(source)});};
fs.mkdirSync(output,{recursive:true});
let resident=read('native/particle_resident.hpp');
resident=once(resident,'struct EnginePose {','#include "particle_scene_boundary.hpp"\nstruct EnginePose {');
resident=once(resident,' auto object=instance_from_id(id);if(!object||!cast_object(object,node_tag))throw std::runtime_error("Native particle pose owner is absent or no longer Node3D");\n alignas(8) std::array<float,12> transform{};ptrcall(node_transform,object,nullptr,transform.data());',
 ' alignas(8) std::array<float,12> transform{};if(!particle_scene_boundary::pose(id,transform)){auto object=instance_from_id(id);if(!object||!cast_object(object,node_tag))throw std::runtime_error("Native particle pose owner is absent or no longer Node3D");ptrcall(node_transform,object,nullptr,transform.data());}');
write('native/particle_resident.hpp',resident);
let group=read('native/particle_frame_group.hpp');group=once(group,'bool eligible(int64_t id){','bool eligible(int64_t id){\n bool result=false;if(particle_scene_boundary::eligible(id,result))return result;');write('native/particle_frame_group.hpp',group);
let kernel=read('native/particle_kernel.cpp');kernel=once(kernel,' if(!bind_pose_api()||!bind_scene_model_api()||!scene_index::bind())return;',' if(!bind_pose_api()||!bind_scene_model_api()||!scene_index::bind())return;\n particle_scene_boundary::bind();');write('native/particle_kernel.cpp',kernel);
write('native/particle_scene_boundary.hpp',fs.readFileSync(path.join(here,'particle_scene_boundary.hpp'),'utf8'));
let presentation=read('native/particle_presentation.hpp');presentation=once(presentation,'case 12:out=emitter_lighting::inspect(input);break;','case 12:out=emitter_lighting::inspect(input);break;case 13:out=particle_scene_boundary::inspect();break;');write('native/particle_presentation.hpp',presentation);
let rigs=read('systems/model_rigs.gd');rigs=once(rigs,'var registry\n','var registry\n'+fs.readFileSync(path.join(here,skinV2?'rig_helpers_v2.gd.inc':'rig_helpers.gd.inc'),'utf8')+'\n');
rigs=once(rigs,'\t\tentities[id] = entry','\t\tnative_skin_publishers.erase(id)\n\t\tentities[id] = entry');
rigs=once(rigs,'\tfor model in entities[id].models:\n\t\tif model.has("native_owner"): model.native_owner.close()','\tnative_skin_publishers.erase(id)\n\tfor model in entities[id].models:\n\t\tif model.has("native_owner"): model.native_owner.close()');
rigs=once(rigs,'\t\tentities[id] = source.entities[id]','\t\tnative_skin_publishers.erase(id)\n\t\tentities[id] = source.entities[id]');
rigs=once(rigs,'func _exit_tree() -> void:\n','func _exit_tree() -> void:\n\tnative_skin_publishers.clear()\n');
if(skinV2){
 rigs=once(rigs,'\t\tvar rigid: Array[Transform3D] = []\n\t\tfor index in entry.nodes.size():\n\t\t\tvar node: Node3D = entry.nodes[index]\n\t\t\tvar local := Transform3D(Basis(node.quaternion), node.position)\n\t\t\tvar parent := int(entry.parents[index])\n\t\t\trigid.append(local if parent == -1 else rigid[parent] * local)\n\t\tfor skin in entry.skins:',
 '\t\tvar native_skin_result: Variant=_publish_skin_native(int(id),entry)\n\t\tif native_skin_result is int and int(native_skin_result)!=1:\n\t\t\tFrameProfile.finish("actor_skin",phase_began)\n\t\t\tif int(native_skin_result)>1:return\n\t\t\tcontinue\n\t\tvar rigid: Array[Transform3D] = []\n\t\tvar skin_rows: Array=entry.skins\n\t\tvar skin_start: int=0\n\t\tif native_skin_result is Dictionary:\n\t\t\trigid.assign(native_skin_result.rigid);skin_rows=native_skin_result.skins;skin_start=int(native_skin_result.start)\n\t\telse:\n\t\t\tfor index in entry.nodes.size():\n\t\t\t\tvar node: Node3D = entry.nodes[index]\n\t\t\t\tvar local := Transform3D(Basis(node.quaternion), node.position)\n\t\t\t\tvar parent := int(entry.parents[index])\n\t\t\t\trigid.append(local if parent == -1 else rigid[parent] * local)\n\t\tvar skin_cursor: int=0\n\t\tfor skin in skin_rows:\n\t\t\tif skin_cursor<skin_start:\n\t\t\t\tskin_cursor+=1;continue\n\t\t\tskin_cursor+=1');
}else rigs=once(rigs,'\t\tvar rigid: Array[Transform3D] = []','\t\tvar native_skin_status: int=_publish_skin_native(int(id),entry)\n\t\tif native_skin_status!=1:\n\t\t\tFrameProfile.finish("actor_skin",phase_began)\n\t\t\tif native_skin_status>1:return\n\t\t\tcontinue\n\t\tvar rigid: Array[Transform3D] = []');write('systems/model_rigs.gd',rigs);
for(const file of ['scene_boundary.h','scene_boundary.cpp','rig_skin_publisher.h','rig_skin_publisher.cpp'])write('engine-module/'+file,fs.readFileSync(path.join(here,skinV2&&file.startsWith('rig_skin_')?'engine-module-v2':'engine-module',file),'utf8'));
for(const file of ['scene_boundary_test.gd','rig_skin_publisher_test.gd','rig_skin_continuation_test.gd']){const source=path.join(here,file);if(fs.existsSync(source)){let text=fs.readFileSync(source,'utf8');if(skinV2&&file==='rig_skin_publisher_test.gd')text=once(text,'"abi_version"))==1,"Versioned actual publisher"','"abi_version"))==2,"Versioned actual publisher"');write('tests/native_render_gap_'+file,text);}}
write('tools/native-render-gap/particles/source_census.gd',fs.readFileSync(path.join(here,'source_census.gd'),'utf8'));
fs.writeFileSync(path.join(output,'overlay-receipt.json'),JSON.stringify({version:1,label,createdUtc:new Date().toISOString(),sourcePins:pins,outputs:changes,sharedSourceWrites:0,sharedBinaryWrites:0,engineStarts:0,scope:'Private source proposal and tests, not a build or acceptance receipt'},null,2)+'\n');
console.log(JSON.stringify({output,sourcePins:pins.length,files:changes.length,sharedSourceWrites:0}));
