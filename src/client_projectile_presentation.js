import {ClientObjectArray} from './client_object_array.js';
import {decodeLocalSafeProjectile} from './client_projectile_message.js';
import {clientProjectileSpell,receiveClientSpellProjectile,updateClientProjectile} from './client_projectile_runtime.js';
import {buildClientProjectilePath,configureClientProjectilePath,initializeClientProjectileNode,nextClientProjectileNode,updateClientProjectilePath} from './client_projectile_path.js';
import {stepClientProjectileMotion} from './client_projectile_motion.js';
import {setClientProjectileStage} from './client_projectile_animation.js';
import {subtractWorldTimes} from './world_timer.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {initializeRandomClientProjectile,clientProjectileRandomState} from './client_projectile_random.js';
import {initializeLinkedClientProjectile,linkRandomClientProjectile,destroyClientProjectileAuxiliary} from './client_projectile_linked.js';
import * as THREE from 'three';
import {animateExternalModel} from './model_external_animation.js';
import {ClientCastVisualPresentation} from './client_cast_visual_presentation.js';
import {clientProjectileTargetPrefix,setClientProjectileTarget} from './client_projectile_target.js';
import {attachClientProjectileImpact} from './client_projectile_impact.js';
import {ClientProjectileDummyPresentation} from './client_projectile_dummy_presentation.js';
import {clientRangedProjectileMetadata} from './client_ranged_projectile.js';
import {nativeStringEntry} from './spell_metadata.js';
import {nativeFloatEntry} from './movement_rate.js';
const f=Math.fround,render=v=>[v[0],v[2],-v[1]];

// Local delivery is queued while an area is built. Snapshot canonical identity
// before async loading, so an old message cannot attach to a replacement object.
export class ClientProjectileInbox{
 constructor({session,report}){Object.assign(this,{session,report});this.pending=[];}
 receive(event){
  if(event.type!=='safeProjectile')return false;
  const session=this.session();if(event.recipientId!==session.player?.id)return true;
  try{const header=decodeLocalSafeProjectile(event.data);this.pending.push({header,source:session.registry.get(event.data.sourceId),target:session.registry.get(event.data.targetId),areaId:session.player.areaId});}
  catch(error){this.report('visual.projectile-message-failed',error.message,{stack:error.stack});}return true;
 }
 flush({session,objects,presentation}){
  if(session!==this.session()||objects.registry!==session.registry||!presentation)return;
  for(const entry of this.pending.splice(0)){
   if(entry.areaId!==objects.areaId||[entry.source,entry.target].some(o=>o&&session.registry.get(o.id)&&session.registry.get(o.id)!==o)){this.report('visual.projectile-message-stale','Projectile belongs to an old area or replaced object',{sourceId:entry.header.sourceId,targetId:entry.header.targetId});continue;}
   void presentation.receive(entry);
  }
 }
}

// Renderer adapter for the independently checked path/animation/AI owners.
// Object arrays and animation RNG are client-side; server registry/RNG untouched.
export class ClientProjectilePresentation{
 constructor({objects,renderFor,playerId,rules,rangedRules=rules,nativePose=null,hitPartsEnabled=null,randomImpactPart=null,now,dayLength,random,loadModel,destroyModel,prepareAuxiliaryModel,modelFor,nodePose,orient,scene,report,oneShot,castAttachment,impactAttachment,impactEquipment,castFields,voiceFields,castAnimation}){
  const basis=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2),basisInverse=basis.clone().invert();
  Object.assign(this,{rules,now,dayLength,random,loadModel,destroyModel,modelFor,nodePose,orient,scene,report,oneShot,impactAttachment});
  this.objects=new ClientObjectArray({objects,render:renderFor,nativePose});this.active=new Set();this.disposed=false;this.events=[];this.stats={received:0,spawned:0,loaded:0,impacts:0,destroyed:0,failed:0};
  this.dummies=new ClientProjectileDummyPresentation({objects:this.objects,playerId,now,difference:(a,b)=>subtractWorldTimes(a,b,dayLength()),loadModel,destroyModel,scene,report});
  this.casts=new ClientCastVisualPresentation({objects:this.objects,spell:id=>clientProjectileSpell(rules(),id),castFields,voiceFields,animation:castAnimation,now,difference:(a,b)=>subtractWorldTimes(a,b,dayLength()),loadModel,destroyModel,
   sourceModel:source=>source.render?modelFor(source.render):null,nodePose,report,oneShot:(resRef,position,priority,gain)=>{oneShot({resRef,position:render(position),channel:'conjure'});report('visual.cast-audio-adapter-incomplete','Conjure audio uses browser output; native attenuation and priority remain incomplete',{resRef,priority,gain});},...castAttachment});
  const note=(code,message,data={})=>report(code,message,data),motion=(s,kind)=>{const result=stepClientProjectileMotion({...s,attachment:s.node.attachment},kind);s.velocity=result.velocity;if(result.orientation)p.setOrientation(s,result.orientation);p.setPosition(s,result.position);};
  const p=this.p={
   worldTime:()=>now(),difference:(a,b)=>subtractWorldTimes(a,b,dayLength()),object:id=>this.objects.get(id),getObject:id=>this.objects.getObject(id),clientObject:id=>this.objects.get(id),spell:id=>clientProjectileSpell(rules(),id),
   register:s=>{this.objects.addInternal(s);this.stats.spawned++;},registerAI:s=>this.active.add(s),
   model:s=>s.model??(s.render?modelFor(s.render):null),nodePose,
   castVisuals:(source,head,hand,ground)=>this.casts.release(source,head,hand,ground),
   createDummy:(targetId,position,travel)=>this.dummies.create(targetId,position,travel),
   rangedMetadata:async(base,appearance)=>{const active=await rangedRules();return this.disposed?null:clientRangedProjectileMetadata(active,base,appearance);},
   appearance:o=>o.canonical?.appearance?.appearance??o.canonical?.creatureData?.Appearance_Type??o.canonical?.authored?.Appearance_Type??o.appearance??(()=>{throw new Error('Native ranged projectile creature appearance is unavailable');})(),
   modelType:id=>nativeStringEntry(rules().appearance,id,'modeltype').value,weaponScale:id=>nativeFloatEntry(rules().appearance,id,'weaponscale'),
   hitPartsEnabled:()=>{if(!hitPartsEnabled)throw new Error('Native ranged projectile hit-part configuration is unavailable');return hitPartsEnabled();},
   randomImpactPart:model=>{if(!randomImpactPart)throw new Error('Native random model impact-part selector is unavailable');return randomImpactPart(model);},
   modelScale:(model,scale)=>model.root.scale.setScalar(scale),
   defaultMaterial:()=>{}, // Loaded model retains its DEFAULT material selection.
   trackProjectile:(target,s)=>{(target.projectiles??=new Set()).add(s.id);s.trackingTarget=target;},
   shortDirection:()=>[1,0,0],
   loadModel:async(s,name,path)=>{
    let model,adopted=false,factory;
    try{
     model=await loadModel(name);if(this.disposed||s.destroyed){destroyModel(model);return 0;}s.model=model;adopted=true;s.resourceName=name;
     if([7,10].includes(path)&&prepareAuxiliaryModel){factory=await prepareAuxiliaryModel('ref');if(this.disposed||s.destroyed){factory?.release();return 0;}s.auxiliaryFactory=factory;}
     this.stats.loaded++;this.event({kind:'loaded',id:s.id,resource:name,clips:model.model?.animations?.map(a=>a.name)??[]});return 1;
    }catch(error){this.stats.failed++;if(model&&!adopted)destroyModel(model);if(factory&&s.auxiliaryFactory!==factory)factory.release();note('visual.projectile-model-failed',error.message,{id:s.id,resource:name,stack:error.stack});return 0;}
   },
   setPosition:(s,point)=>{s.position=point.map(f);if(s.model)s.model.root.position.set(...render(s.position));},
   setOrientation:(s,vector)=>{s.orientation=vector.map(f);if(s.model)orient(s.model,s.orientation);},
   setScene:(s,on)=>{if(!s.model)return;if(on)scene.add(s.model.root);else s.model.root.removeFromParent();},
   playAnimation:(model,name,speed,flags,time)=>{
    const result=model.animator?.playNative(name,{speed,flags,time});if(!result&&name)note('visual.projectile-clip-unavailable','Native projectile animation clip cannot play',{resource:model.resourceName,clip:name});return result?1:0;
   },
   setStage:(s,stage)=>{const result=setClientProjectileStage(s,stage,p);if(result){this.event({kind:'stage',id:s.id,stage});if(stage===2)this.stats.impacts++;}return result;},getStage:s=>s.stage,
   targetPrefix:target=>{const render=target.render;if(render&&typeof render.userData.nativeLoadedModelName!=='string')throw new Error('Native projectile target loaded model-name field is unavailable');return clientProjectileTargetPrefix(target.objectType,render?.userData.nativeLoadedModelName);},
   setTarget:(s,id,node)=>setClientProjectileTarget(s,id,node,p),
   configurePath:(s,path)=>configureClientProjectilePath(s,path,p),initializeNode:(s,orientation)=>initializeClientProjectileNode(s,orientation,p),nextNode:s=>nextClientProjectileNode(s,p),updatePath:s=>updateClientProjectilePath(s,p),
   randomState:clientProjectileRandomState,initializeSpecial:(s,orientation,delta,time)=>s.node.kind===7?initializeLinkedClientProjectile(s,p):initializeRandomClientProjectile(s,orientation,delta,time,p),
   clientArray:()=>this.objects,
   createAuxiliary:(s,resource,alias)=>{
    if(s.auxiliaryFactory===undefined)throw new Error('Native linked projectile auxiliary-model adapter is unavailable');
    const model=s.auxiliaryFactory?.create(alias)??null;this.event({kind:'auxiliary',id:s.id,resource,alias,created:!!model});return model;
   },
   linkRandomModel:s=>linkRandomClientProjectile(s,p),
   reattach:(model,target,name)=>{
    if(model.references)model.references.reattach(target,name);
    else if(!Array.isArray(model.model?.nodes)||model.model.nodes.some(n=>n.type==='reference'))throw new Error('Native linked projectile reference graph is unavailable');
    this.event({kind:'referenceReattach',resource:model.resourceName,part:name});
   },
   modelPosition:model=>[model.root.position.x,-model.root.position.z,model.root.position.y].map(f),
   setModelPosition:(model,position)=>{model.root.position.set(...render(position));model.root.updateWorldMatrix(true,true);},
   modelOrientation:model=>{const q=basisInverse.clone().multiply(model.root.quaternion).multiply(basis);return[q.w,q.x,q.y,q.z].map(f);},
   setModelOrientation:(model,q)=>{model.root.quaternion.copy(basis).multiply(new THREE.Quaternion(q[1],q[2],q[3],q[0])).multiply(basisInverse);model.root.updateWorldMatrix(true,true);},
   modelScene:model=>model.root.parent,
   setModelScene:(model,parent)=>{if(parent)parent.add(model.root);else model.root.removeFromParent();},
   buildPath:(s,path)=>buildClientProjectilePath(s,path,p),random:()=>random.next(),allocateNode:()=>{},destroyNode:()=>{},basicMotion:s=>motion(s,'basic'),spiralMotion:s=>motion(s,'spiral'),
   animateExternal:(model,delta)=>{
    model.externalAnimationHeader??={counter:0};animateExternalModel(model,delta,{header:m=>m.externalAnimationHeader,animate:(m,time)=>m.animator?.update(time)});
    note('visual.projectile-external-animation-adapter-incomplete','External animation counter/run owners are connected; native outer scene/cache gates remain incomplete',{resource:model.resourceName,delta});
   },
   ready:s=>{s.ready=true;this.event({kind:'ready',id:s.id,position:[...s.position],endpoint:[...s.endpoint],path:s.path});},
   destroy:s=>{if(s.destroyed)return;s.destroyed=true;s.ready=false;this.active.delete(s);this.objects.remove(s);s.trackingTarget?.projectiles.delete(s.id);
    // These endpoint models never acquire an AttachToObject parent; their
    // scene membership is separate. Native detach(NULL,NULL,0) is already
    // unbound here, followed by the actual scene removal and deletion.
    destroyClientProjectileAuxiliary(s,{attachAuxiliary:(_model,parent,part,flags)=>{if(parent!==null||part!==null||flags!==0)throw new Error('Projectile auxiliary parent attachment is unavailable');},setModelScene:p.setModelScene,destroyAuxiliary:model=>s.auxiliaryFactory.destroy(model)});
    if(s.model){impactAttachment?.forget(s.model);destroyModel(s.model);s.model=null;}s.auxiliaryFactory?.release();s.auxiliaryFactory=null;
    this.stats.destroyed++;this.event({kind:'destroy',id:s.id});},
   camera:()=>null,faceCamera:()=>{throw new Error('Native projectile camera-facing orientation is not connected');},
   modelHandle:target=>target.model??target.render,
   field28:target=>{if(!this.impactFieldsReported){this.impactFieldsReported=true;note('visual.projectile-impact-client-fields-incomplete','Impact uses the native client flag28 constructor value; complete client flag update replication remains unavailable');}if(!Number.isInteger(target.nativeField28))throw new Error('Native projectile impact client flag28 is unavailable');return target.nativeField28|0;},
   creature:target=>target.objectType===5?target:null,
   equipped:(target,slot)=>{if(!impactEquipment)throw new Error('Native projectile shield equipment projection is unavailable');return impactEquipment.equipped(target,slot);},
   item:id=>impactEquipment.item(id),weaponType:item=>impactEquipment.weaponType(item),itemModel:(item,part,flags)=>impactEquipment.model(item,part,flags),
   attach:(model,anchor,part,flags)=>{if(!impactAttachment)throw new Error('Native projectile impact scene attachment adapter is unavailable');const result=impactAttachment.attach(model,anchor,part,flags);this.event({kind:'impactAttach',resource:model.resourceName,part,attached:!!result});if(!result)note('visual.projectile-impact-anchor-unavailable','Projectile impact target part is unavailable',{resource:model.resourceName,part});return result;},
   setNodePose:(model,part,position,quaternion)=>{if(!impactAttachment)throw new Error('Native projectile impact pose adapter is unavailable');return impactAttachment.setNodePose(model,part,position,quaternion);},
   rangedImpact:(target,s)=>{note('visual.projectile-ranged-impact-effect-unimplemented','Native ranged impact blood/weapon effects are not connected',{targetId:target.id,effect:s.rangedEffect,critical:s.impactCritical,damage:s.impactDamage});s.rangedEffect=0;},
   attachImpact:s=>attachClientProjectileImpact(s,p),
   createSound:resRef=>({resRef}),soundPriority:(sound,value)=>sound.priority=value,sound3d:(sound,value)=>sound.is3d=value,soundLooping:(sound,value)=>sound.looping=value,updateSound:(sound,position,range)=>{sound.position=position;sound.range=range;},
   playSound:sound=>note('visual.projectile-loop-audio-unimplemented','Native moving projectile loop audio is not connected',{resRef:sound.resRef,priority:sound.priority,position:sound.position}),stopSound:sound=>sound.stopped=true,destroySound:sound=>sound.destroyed=true,
   oneShot:(resRef,position,priority,gain)=>{oneShot({resRef,position:render(position),objectId:OBJECT_INVALID,channel:'projectile'});note('visual.projectile-audio-adapter-incomplete','Projectile one-shot uses browser audio; native attenuation/priority remain incomplete',{resRef,priority,gain});}
  };
 }
 event(event){this.events.push(event);if(this.events.length>64)this.events.shift();}
 async receive(entry){
  if(this.disposed)return;this.stats.received++;
  try{
   this.objects.sync();
   if([[entry.header.sourceId,entry.source],[entry.header.targetId,entry.target]].some(([id,expected])=>expected&&this.objects.get(id)?.canonical&&this.objects.get(id).canonical!==expected)){this.report('visual.projectile-target-stale','Projectile source or target was replaced before delivery',{sourceId:entry.header.sourceId,targetId:entry.header.targetId});return;}
   const sourceAtReceive=this.objects.get(entry.header.sourceId)?.canonical,targetAtReceive=this.objects.get(entry.header.targetId)?.canonical;
   await receiveClientSpellProjectile(entry.header,{...this.p,loadModel:async(s,name,path)=>{
    const result=await this.p.loadModel(s,name,path);if(!result||this.disposed||s.destroyed)return 0;
    this.objects.sync();
    if([[entry.header.sourceId,sourceAtReceive],[entry.header.targetId,targetAtReceive]].some(([id,expected])=>expected&&this.objects.get(id)?.canonical&&this.objects.get(id).canonical!==expected)){
     this.report('visual.projectile-target-stale','Projectile source or target changed during asset loading',{id:s.id,sourceId:entry.header.sourceId,targetId:entry.header.targetId});return 0;
    }
    return 1;
   }});
  }
  catch(error){this.stats.failed++;this.report('visual.projectile-receiver-failed',error.message,{header:entry.header,stack:error.stack});}
 }
 update(delta){
  if(this.disposed)return;
  try{this.objects.sync();}catch(error){this.report('visual.projectile-object-sync-failed',error.message,{stack:error.stack});return;}
  this.casts.update(delta);
  const now=this.now();
  this.dummies.update();
  for(const s of [...this.active])if(s.ready&&!s.destroyed){
   try{updateClientProjectile(s,now,this.p);if(!s.destroyed)s.model?.animator?.update(delta);}
   catch(error){this.stats.failed++;this.report('visual.projectile-update-failed',error.message,{id:s.id,path:s.path,stack:error.stack});this.p.destroy(s);}
  }
  try{this.impactAttachment?.updateAttachments();}catch(error){this.report('visual.projectile-impact-scene-update-failed',error.message,{stack:error.stack});for(const s of [...this.active])this.p.destroy(s);}
 }
 snapshot(){return{...this.stats,active:[...this.active].map(s=>({id:s.id,ready:!!s.ready,stage:s.stage,path:s.path,remaining:s.remaining,resource:s.resourceName,position:s.position,targetId:s.targetId,impactNode:s.impactNode})),events:this.events,casts:this.casts.snapshot(),dummies:this.dummies.snapshot()};}
 dispose(){this.disposed=true;this.casts.dispose();for(const s of [...this.active])this.p.destroy(s);this.dummies.dispose();}
}
