// Private copies only. Native registry keeps all existing light polling policy.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import{fileURLToPath}from'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),label=process.argv[2],mode=process.argv[3]??'prepare';
if(!/^native-dense-light-input-[a-z0-9-]+$/.test(label??''))throw Error('Fresh light input capsule label required');
const stage=path.join(project,'.cache/native-dense-area',label),hash=b=>crypto.createHash('sha256').update(b).digest('hex'),read=f=>fs.readFileSync(f),text=f=>read(f).toString().replaceAll('\r\n','\n');
const once=(s,a,b)=>{if(s.split(a).length!==2)throw Error('Expected one light input hook: '+a.slice(0,80));return s.replace(a,b);};
if(mode==='finalize'){
 const file=path.join(stage,'candidate-sources.json'),r=JSON.parse(read(file)),proofFile=path.join(r.sourceProject,'.cache/native-kernel/pose-build.json'),proof=JSON.parse(read(proofFile));
 if(!proof.success||proof.changedGuards.length||r.isolatedBuildFinalized)throw Error('Private build proof failed');
 for(const p of r.sourcePins){const b=read(path.join(r.sourceProject,p.relative)),sha=hash(b);if(!['.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json'].includes(p.relative)&&p.finalSha256!==sha)throw Error('Unexpected compilation mutation');p.finalSha256=sha;p.bytes=b.length;}
 r.isolatedBuildFinalized=true;r.isolatedBuild={file:proofFile,sha256:hash(read(proofFile)),binarySha256:proof.binarySha256};fs.writeFileSync(file,JSON.stringify(r,null,2)+'\n');console.log(JSON.stringify({success:true,label,finalized:true}));process.exit(0);
}
if(mode!=='prepare'||fs.existsSync(stage))throw Error('Existing capsule preserved');
const parentFile=path.join(project,'.cache/native-dense-area/native-dense-pose-v2/candidate-sources.json'),parent=JSON.parse(read(parentFile));
const baselineBytes=read(path.join(project,'systems/native_render/focus_lighting.gd')),baselineText=baselineBytes.toString().replaceAll('\r\n','\n');
const tailStart=baselineText.indexOf('\tTiming.finish("light_history_registry",began);'),tailEnd=baselineText.indexOf('func register(',tailStart);
if(tailStart<0||tailEnd<=tailStart)throw Error('Light solve/publication boundary differs');
let candidate=`extends "res://systems/native_render/focus_lighting.gd"
# Unimported candidate. Property/lifecycle/visibility/position polling is native;
# native history and the source-pinned solver/publication tail remain identical.
var input_registry: RefCounted
func _init() -> void: input_registry=ClassDB.instantiate("NwnLightInputRegistry")
func register(light: Node3D) -> void:
 if closed:return
 super.register(light)
 var id:=light.get_instance_id();var entry:Dictionary=members[id]
 var source=entry.source.get_ref() if entry.source!=null else null
 var result:Dictionary=input_registry.call("dispatch",0,{"id":id,"source":source.get_instance_id() if is_instance_valid(source) else 0})
 if result.has("error"):history_error=str(result.error);push_error(history_error)
func unregister(light: Node3D) -> void:
 if input_registry!=null:input_registry.call("dispatch",2,{"id":light.get_instance_id()})
 super.unregister(light)
func enable_history(maximum:int=DEFAULT_MAXIMUM) -> void:
 if closed or history!=null:return
 input_registry.call("dispatch",4,{})
 super.enable_history(maximum)
func close() -> void:
 super.close()
 if input_registry!=null:input_registry.call("dispatch",8,{});input_registry=null
func history_frame(delta:float) -> void:
 if history==null or closed:return
 var began:=Time.get_ticks_usec()
 var camera:Camera3D=history_camera.get_ref() if history_camera!=null else null
 var planes:Array=camera.get_frustum() if is_instance_valid(camera) else []
 var view_changed:bool=planes!=history_planes;history_planes=planes
 var update:Dictionary=input_registry.call("dispatch",1,{"planes":planes,"view_changed":view_changed})
 if update.has("error"):history_error=str(update.error);push_error(history_error);disable_history();return
 var rows:Array=update.rows;var removed:Array=update.removed
 for id in update.retired:members.erase(id)
 for id in removed:history_rows.erase(id)
 for row in rows:history_rows[int(row.id)]=row
 history_view_tests+=int(update.view_tests);history_input_rows+=rows.size();history_input_reused+=int(update.reused)
`;
candidate=candidate.split('\n').map(line=>line.startsWith(' ')?'\t'+line.slice(1):line).join('\n')+baselineText.slice(tailStart,tailEnd);
const outcomes=[];
for(const variant of ['baseline','candidate']){
 const destination=path.join(stage,variant),pins=[],overrides=[];fs.mkdirSync(destination,{recursive:true});
 for(const pin of parent.sourcePins){const main=path.join(project,pin.relative),from=fs.existsSync(main)?main:path.join(parent.sourceProject,pin.relative),bytes=read(from),to=path.join(destination,pin.relative);fs.mkdirSync(path.dirname(to),{recursive:true});fs.writeFileSync(to,bytes,{flag:'wx'});pins.push({relative:pin.relative,capturedSha256:hash(bytes),finalSha256:hash(bytes),bytes:bytes.length});}
 function install(relative,bytes,reason){if(typeof bytes==='string')bytes=Buffer.from(bytes);const target=path.join(destination,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);let pin=pins.find(p=>p.relative===relative);if(!pin){pin={relative,capturedSha256:hash(bytes)};pins.push(pin);}pin.finalSha256=hash(bytes);pin.bytes=bytes.length;overrides.push({relative,sha256:pin.finalSha256,reason});}
 // Keep the prior explicit options/camera/focus controls. The current ordinary
 // entry/Session has no benchmark controls, so retain their frozen versions.
 for(const name of ['native_live_world.gd','native_session_world.gd','benchmark-options.cfg'])install(name,read(path.join(parent.sourceProject,name)),'Common frozen measurement controls and current quiescent World');
 install('tests/fixtures/focus_lighting_before_native_input.gd',baselineBytes,'Exact current baseline for paired native tests');
 install('systems/native_render/focus_lighting_native_input_candidate.gd',candidate,'Same candidate source in both copies; imported only by candidate');
 install('tests/native_light_input_registry_test.gd',read(path.join(project,'tests/native_light_input_registry_test.gd')),'Dedicated exact source/native history/lamp comparisons');
 if(variant==='candidate'){
  install('native/experimental/light_input_registry.hpp',read(path.join(project,'tests/fixtures/native_light_input_registry.hpp')),'Private-only compiled light input poller');
  let cpp=text(path.join(destination,'native/particle_kernel.cpp'));
  cpp=once(cpp,'#include "light_history.hpp"','#include "light_history.hpp"\n#include "experimental/light_input_registry.hpp"');
  cpp=once(cpp,' light_history::register_owner(property);',' light_history::register_owner(property);\n light_input_registry::register_owner(property);');
  cpp=once(cpp,'light_history::unregister_owner();','light_input_registry::unregister_owner();light_history::unregister_owner();');
  install('native/particle_kernel.cpp',cpp,'Candidate native class registration only');
  let world=text(path.join(destination,'systems/native_render/live_world.gd'));
  world=once(world,'preload("res://systems/native_render/focus_lighting.gd").new()','preload("res://systems/native_render/focus_lighting_native_input_candidate.gd").new()');
  install('systems/native_render/live_world.gd',world,'Candidate light input owner selection');
 }
 const privateUserData=path.join(stage,variant+'-user-data');fs.mkdirSync(privateUserData);
 const receipt={...parent,run:label,variant,sourceProject:destination,privateUserData,sourcePins:pins,overrides,sourceBytes:pins.reduce((n,p)=>n+p.bytes,0),isolatedBuildFinalized:variant==='baseline',parentReceipt:{file:parentFile,sha256:hash(read(parentFile))},baselineFocusSha256:hash(Buffer.from(baselineText)),solverPublicationTailSha256:hash(Buffer.from(baselineText.slice(tailStart,tailEnd))),scope:'Private compiled light input polling versus original GDScript. Same input/visibility/collection/fade/publication policy; no ordinary changes.'};
 const file=path.join(stage,variant+'-sources.json');fs.writeFileSync(file,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});outcomes.push({variant,file,pins:pins.length});
}
fs.writeFileSync(path.join(stage,'preparation.json'),JSON.stringify({success:true,label,outcomes,engines:0,builds:0,publicConnections:0},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,label,outcomes}));
