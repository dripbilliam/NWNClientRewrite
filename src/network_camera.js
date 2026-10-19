import {GameCamera} from './game_camera.js';
import {nativeFloatEntry} from './movement_rate.js';
import {cameraSceneQuery} from './camera_scene_query.js';
// Scene-only native camera state. Canonical proxies/ownership are never changed.
export class NetworkPlayerCamera{
 constructor({report=()=>{}}={}){this.report=report;this.controller=new GameCamera();this.reset();}
 reset(position=null){this.anchor=position?[...position]:null;this.controlledId=null;this.targetId=null;this.sourceHeight=null;this.attachmentId=null;this.waitingForTarget=false;this.pendingEntryAttach=false;this.controller.reset({position:position?[position[0],-position[2],position[1]]:null});}
 //6ab410 ->6d65f0 installs the PC render object and attaches with clear-view1.
 // A new area is not a new camera session. Keep module-level commands/pose;
 // wait for the asynchronous PC render binding before replacing Follow.
 enterArea(position){this.anchor=[...position];this.targetId=null;this.sourceHeight=null;this.attachmentId=null;this.waitingForTarget=true;this.pendingEntryAttach=true;this.controller.findClearView=false;}
 recenter(position){if(this.attachmentId!==null&&this.anchor)position=this.anchor;this.anchor=[...position];this.controller.focus=[position[0],-position[2],position[1]].map((v,i)=>Math.fround(v+this.controller.offset[i]));}
 height(object,presentation){const row=object?.appearance?.appearance,table=presentation?.tables?.appearance;return table&&Number.isInteger(row)?nativeFloatEntry(table,row,'HEIGHT').value:1;}
 attach(message,world,presentation){
  const id=message.objectId,object=world?.registry?.get(id),binding=presentation?.objects.get(id);
  if(!Number.isInteger(id)||id<0||id>0xffffffff||!object||object.replicationRemoved||object.areaId!==world.areaId||![5,9].includes(object.objectType)||!binding){this.report('network.camera-attachment-unavailable','Camera attachment target has no current supported render object',{objectId:id});return false;}
  const p=binding.wrapper.position.toArray(),height=this.height(object,presentation);this.controller.attach({position:[p[0],-p[2],p[1]],height,creature:object.objectType===5,findClearView:message.findClearView});this.attachmentId=id===world.localObjectId?null:id;this.targetId=id;this.sourceHeight=height;this.anchor=p;this.waitingForTarget=false;
  this.pendingEntryAttach=false;return true;
 }
 receive(message,world,presentation){this.controller.modeAppearanceHeight=this.height(world?.registry?.get(world?.localObjectId),presentation);if(message.kind==='camera-attach'){this.attach(message,world,presentation);return true;}if(message.kind==='camera-flags'&&(message.flags&~115))this.report('network.camera-flags-partial','Camera flag storage is applied; translation/effect and other behavior bits are not yet connected',{flags:message.flags,unsupportedBits:(message.flags&~115)>>>0});return this.controller.applyCommand(message);}
 update(world,presentation,camera,controls,seconds=1/60,{keyholeActive=true}={}){
  if(this.attachmentId!==null){const object=world?.registry?.get(this.attachmentId);if(!object||object.replicationRemoved||object.areaId!==world.areaId){this.attachmentId=null;this.controller.findClearView=false;const binding=presentation?.objects.get(world?.localObjectId);if(binding)this.attach({objectId:world.localObjectId,findClearView:false},world,presentation);}}
  const id=this.attachmentId??world?.localObjectId,binding=presentation?.objects.get(id);this.waitingForTarget=!binding;if(!binding)return false;
  if(this.pendingEntryAttach&&!this.attach({objectId:world.localObjectId,findClearView:true},world,presentation))return false;
  const object=world.registry?.get(id),p=binding.wrapper.position.toArray(),actor=world.registry?.get(world.localObjectId),actorBinding=presentation.objects.get(world.localObjectId),motion=presentation.motion?.objects.get(world.localObjectId),orientation=motion?.orientation??actor?.replicated?.orientation;
  this.controller.modeAppearanceHeight=this.height(actor,presentation);
  const height=this.height(object,presentation);if(id!==this.targetId||height!==this.sourceHeight){this.controller.setHeight(height,{preserveOverride:this.targetId===null||this.targetId===id});this.sourceHeight=height;}
  // Native mode steering consults the controlled creature even when Follow is
  // attached to another object; attachment changes the position target only.
  const facing=orientation?.length?Math.atan2(-orientation[0],orientation[1])*180/Math.PI:(actorBinding?.wrapper.rotation?.y??0)*180/Math.PI;
  const targetOrientation=presentation.motion?.objects.get(id)?.orientation??object?.replicated?.orientation??object?.staticState?.orientation??object?.lightState?.orientation,vector=Array.isArray(targetOrientation)?targetOrientation:targetOrientation?.vector;
  const clearViewFacing=vector?.length?Math.fround(Math.fround(Math.atan2(-vector[0],vector[1]))*Math.fround(57.295776)):(binding.wrapper.rotation?.y??0)*180/Math.PI;
  const needsQuery=this.controller.findClearView||!keyholeActive||(this.controller.flags&1),query=needsQuery&&presentation.root?(presentation.cameraQuery??=cameraSceneQuery(presentation.root,presentation.cameraTriangles)):null;query?.update();
  const clearViewQuery=this.controller.findClearView?query:null;
  if(this.controller.findClearView&&!clearViewQuery)this.report('network.camera-clear-view-unavailable','Camera clear-view scene geometry is unavailable',{objectId:id});
  const actorPosition=actorBinding?.wrapper.position.toArray(),collision=actorPosition&&query?{query:query.nearest,position:[actorPosition[0],-actorPosition[2],actorPosition[1]],cameraPosition:[camera.position.x,-camera.position.z,camera.position.y],keyholeActive,eligible:actorBinding.models?.length>0}:null;
  this.controller.update({position:[p[0],-p[2],p[1]],facing,clearViewFacing,clearViewQuery,collision,animation:motion?.active?motion.animation:actor?.replicated?.animation??0},seconds,camera,controls);
  this.anchor=p;this.controlledId=world.localObjectId;this.targetId=id;return true;
 }
}
