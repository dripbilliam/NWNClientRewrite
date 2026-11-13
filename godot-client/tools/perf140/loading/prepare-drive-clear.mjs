import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';import {digest} from './processor-graph.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2],mode=process.argv[3]??'stage';
if(!/^drive-preview-clear-[a-z0-9-]+$/.test(label??'')||!['stage','finalize'].includes(mode))throw Error('Fresh clear candidate and stage/finalize required');
const stage=path.join(project,'.cache/native-140fps/loading-agent',label),draftFile=path.join(stage,'draft.json'),manifestFile=path.join(stage,'manifest.json');
function once(s,a,b){if(s.split(a).length!==2)throw Error('Guarded clear seam differs: '+a.slice(0,100));return s.replace(a,b);}
function body(s,name){const at=s.indexOf('func '+name+'(');if(at<0)throw Error('Missing method '+name);const tail=s.slice(at),next=/\n(?:static )?func /.exec(tail);return next?tail.slice(0,next.index):tail;}
if(mode==='stage'){
 if(fs.existsSync(stage))throw Error('Existing evidence preserved');const parentFile=path.join(project,'.cache/native-140fps/loading-agent/drive-preview-envelope-v1/manifest.json'),parentBytes=fs.readFileSync(parentFile),parent=JSON.parse(parentBytes);if(digest(parentBytes)!=='d83cb44f55efbad8b1d8b840675f1f202b6047bb3592e5aeb6a92479c5352458')throw Error('Frozen envelope parent differs');
 const copy=path.join(stage,'project'),pins=new Map(),changes=[];fs.mkdirSync(copy,{recursive:true});for(const pin of parent.pins){const bytes=fs.readFileSync(path.join(parent.project,pin.relative));if(digest(bytes)!==pin.sha256)throw Error('Parent source differs '+pin.relative);const file=path.join(copy,pin.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);pins.set(pin.relative,pin.sha256);}
 function install(relative,source){if(pins.has(relative))throw Error('New clear file already exists');const bytes=fs.readFileSync(path.join(project,'tools/perf140/loading',source)),file=path.join(copy,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);pins.set(relative,digest(bytes));changes.push({relative,before:null,after:digest(bytes)});}
 function patch(relative,fn){const file=path.join(copy,relative),before=pins.get(relative),raw=fs.readFileSync(file,'utf8'),crlf=raw.includes('\r\n');let s=fn(raw.replaceAll('\r\n','\n'));if(crlf)s=s.replaceAll('\n','\r\n');fs.writeFileSync(file,s);pins.set(relative,digest(Buffer.from(s)));changes.push({relative,before,after:pins.get(relative)});}
 for(const name of ['drive_clear_kernel.hpp','drive_clear_bridge_decls.hpp','drive_clear_bridge.hpp'])install('native/'+name,name);
 install('systems/native_render/drive_clear_cache.gd','drive_clear_cache.gd');
 patch('native/particle_kernel.cpp',s=>{s=once(s,'#include "scene_geometry.hpp"','#include "drive_clear_bridge_decls.hpp"\n#include "scene_geometry.hpp"');s=once(s,'#include "scene_model.hpp"','#include "scene_model.hpp"\n#include "drive_clear_bridge.hpp"');return once(s,' if(!bind_pose_api()||!bind_scene_model_api()||!scene_index::bind())return;',' if(!bind_pose_api()||!bind_scene_model_api()||!scene_index::bind())return;\n bind_drive_clear_math();');});
 patch('native/scene_geometry.hpp',s=>{s=once(s,' bool configured=false;',' bool configured=false;drive_clear_kernel::Batch drive_batch;');s=once(s,'  configured=false;faces.clear();','  configured=false;faces.clear();drive_batch.clear();');return once(s,'break;default:throw std::runtime_error("Unknown native collision operation");','break;case 3:owner.configured=false;owner.faces.clear();out=configure_drive_batch(owner.drive_batch,input);break;case 4:out=query_drive_batch(owner.drive_batch,input,true);break;case 5:out=query_drive_batch(owner.drive_batch,input,false);break;default:throw std::runtime_error("Unknown native collision operation");');});
 let preserved;
 patch('systems/native_render/drive_collision_indexed.gd',s=>{
  const original=body(s,'_drive_clear_unprofiled');preserved={name:'_drive_clear_reference',parentSha256:digest(Buffer.from(original))};
  const reference=original.replace('func _drive_clear_unprofiled(','func _drive_clear_reference(');
  let compiled=original.replace('func _drive_clear_unprofiled(','func _drive_clear_compiled(');
  compiled=once(compiled,`\t\t\tfor tri in tile(y*int(definition.width)+x):
\t\t\t\tif tri.walk:
\t\t\t\t\tvar span:=interval(a,b,tri)
\t\t\t\t\tif span.x<=span.y: intervals.append(span)
\t\t\t\telif hits(a,b,tri,radius,low,high): return deny("tile_polygon",from,to)`,
`\t\t\tvar tile_index:=y*int(definition.width)+x
\t\t\tvar triangles: Array=tile(tile_index)
\t\t\tvar native: RefCounted=drive_native_cache.batch("tile:"+str(tile_index),triangles,true)
\t\t\tvar tested: Dictionary=drive_native_cache.query(native,a,b,radius,low,high,true)
\t\t\tif tested.get("supported",false):
\t\t\t\tif tested.blocked:return deny("tile_polygon",from,to)
\t\t\t\tintervals.append_array(tested.intervals)
\t\t\telse:
\t\t\t\tfor tri in triangles:
\t\t\t\t\tif tri.walk:
\t\t\t\t\t\tvar span:=interval(a,b,tri)
\t\t\t\t\t\tif span.x<=span.y: intervals.append(span)
\t\t\t\t\telif hits(a,b,tri,radius,low,high): return deny("tile_polygon",from,to)`);
  compiled=once(compiled,`\t\tfor tri in shape.triangles:
\t\t\tif hits(a,b,tri,radius,low,high): return deny("object_polygon",from,to)`,
`\t\tvar native: RefCounted=drive_native_cache.batch(drive_native_cache.object_key(shape),shape.triangles,false)
\t\tvar tested: Dictionary=drive_native_cache.query(native,a,b,radius,low,high,false)
\t\tif tested.get("supported",false):
\t\t\tif tested.blocked:return deny("object_polygon",from,to)
\t\telse:
\t\t\tfor tri in shape.triangles:
\t\t\t\tif hits(a,b,tri,radius,low,high): return deny("object_polygon",from,to)`);
  const gate='func _drive_clear_unprofiled(from: Vector3,to: Vector3,radius: float,height: float,obstacles: Array,creatures: Array,pending: Array) -> bool:\n\treturn _drive_clear_compiled(from,to,radius,height,obstacles,creatures,pending) if drive_native_cache.enabled else _drive_clear_reference(from,to,radius,height,obstacles,creatures,pending)\n';
  s=once(s,original,gate+reference+'\n'+compiled);
  s=once(s,'var world\n','var drive_native_cache=preload("res://systems/native_render/drive_clear_cache.gd").new()\nvar world\n');
  s=once(s,'func query(id:','func forget_precise_geometry(id: int)->void:\n\tif objects.has(id):drive_native_cache.forget_shape(objects[id])\n\tobjects.erase(id)\nfunc query(id:');
  // Release derived references before the owner releases source dictionaries;
  // these resources never enter a worker's deferred data-retirement payload.
  s=s.replaceAll('objects.erase(key);','forget_precise_geometry(key);').replaceAll('objects.erase(id)','forget_precise_geometry(id)');
  s=once(s,'\tforget_precise_geometry(id)\nfunc query(id:','\tobjects.erase(id)\nfunc query(id:');
  s=once(s,'\tobjects[id]=result\n','\tif objects.has(id):drive_native_cache.forget_shape(objects[id])\n\tobjects[id]=result\n');
  s=once(s,'\tspatial_ticket=spatial.begin(scope)\n','\tdrive_native_cache.clear()\n\tspatial_ticket=spatial.begin(scope)\n');
  for(const name of ['retire_index','reindex_sources']){const signature='func '+name+'(';const at=s.indexOf(signature),line=s.indexOf('\n',at);if(at<0||line<0)throw Error('Missing clear lifecycle hook');s=s.slice(0,line+1)+'\tdrive_native_cache.clear()\n'+s.slice(line+1);}
  s=once(s,'func detach_prepared_data() -> Dictionary:\n','func detach_prepared_data() -> Dictionary:\n\tdrive_native_cache.clear()\n');
  s=once(s,'func close() -> void:\n','func close() -> void:\n\tdrive_native_cache.clear()\n');
  s=once(s,'\tstate.spatial=spatial.snapshot();','\tstate.native_clear=drive_native_cache.snapshot()\n\tstate.spatial=spatial.snapshot();');
  if(body(s,'_drive_clear_reference').replace('func _drive_clear_reference(','func _drive_clear_unprofiled(')!==original)throw Error('Exact script reference changed');return s;
 });
 fs.writeFileSync(draftFile,JSON.stringify({version:1,label,stage,project:copy,candidate:copy,mode:'clear',parent:{file:parentFile,sha256:digest(parentBytes)},changes,preservedReference:preserved,pins:[...pins].map(([relative,sha256])=>({relative,sha256})),baseBinary:pins.get('.cache/native-kernel/nwn-particle-kernel.dll')},null,2)+'\n');console.log(JSON.stringify({draftFile,changes}));
}else{
 if(!fs.existsSync(draftFile)||fs.existsSync(manifestFile))throw Error('Fresh staged draft required');const draftBytes=fs.readFileSync(draftFile),draft=JSON.parse(draftBytes),copy=draft.project,pins=new Map(draft.pins.map(v=>[v.relative,v.sha256]));
 const buildFile=path.join(stage,'build-output/build-proof.json'),buildBytes=fs.readFileSync(buildFile),build=JSON.parse(buildBytes),binary=fs.readFileSync(path.join(stage,'build-output/nwn-particle-kernel.dll'));
 if(build.success!==true||build.project!==copy||build.binarySha256!==digest(binary)||build.binarySha256===draft.baseBinary)throw Error('Fresh private native proof required');
 for(const [relative,sha256]of Object.entries(build.sources))if(pins.get(relative)!==sha256)throw Error('Compiled source pin differs '+relative);
 const relative='.cache/native-kernel/nwn-particle-kernel.dll',old=fs.readFileSync(path.join(copy,relative));if(digest(old)!==draft.baseBinary)throw Error('Private baseline DLL changed before finalize');const backup=path.join(stage,'originals',relative);fs.mkdirSync(path.dirname(backup),{recursive:true});fs.writeFileSync(backup,old);fs.writeFileSync(path.join(copy,relative),binary);pins.set(relative,digest(binary));
 const manifest={...draft,changes:[...draft.changes,{relative,before:draft.baseBinary,after:digest(binary)}],changed:[],pins:[...pins].map(([relative,sha256])=>({relative,sha256})),build:{file:buildFile,sha256:digest(buildBytes)},draft:{file:draftFile,sha256:digest(draftBytes)},flags:['--drive-collision=indexed','--drive-clear=native'],scope:'Distinct optional typed triangle loops only. Original script prefix/heights/traversal/sort/coverage/bounds preserved; local unsupported fallback repeats neither prefix nor heights. Native payload/entry bounded geometry calculation cache, cleared before source retirement. Existing physical ray operation unchanged.',graphics:0,serverConnections:0,sharedNativeBuilds:0};
 for(const pin of manifest.pins)if(digest(fs.readFileSync(path.join(copy,pin.relative)))!==pin.sha256)throw Error('Final source drift '+pin.relative);fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({file:manifestFile,sha256:digest(fs.readFileSync(manifestFile)),binarySha256:digest(binary)}));
}
