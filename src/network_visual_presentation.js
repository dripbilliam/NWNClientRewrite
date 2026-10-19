import {LoopingVisualPresentation} from './looping_visual_presentation.js';
import {createVisualSceneRuntime} from './visual_scene_runtime.js';
import {deliverObjectVisualAsync} from './object_visual_delivery.js';
import {visualHasCessation} from './visual_selection.js';
import {nativeStringEntry} from './spell_metadata.js';
import {setModelLightShadows} from './model_light.js';
import {ModelAnimator} from './model_animation.js';
import {loadModelReferenceAssets} from './model_reference_assets.js';
import {ModelReferenceScene} from './model_reference_scene.js';

// Empty/default controller maps are identity. Retain and diagnose every other
// map rather than silently discarding scoped transforms or animated curves.
export function networkVisualIdentity(map){
 if(!map)return true;if(map.legacy)return false;
 if(map.entries.length===0)return map.keys.length===0;
 if(map.entries.length!==1||map.entries[0].key!==0||map.keys.length!==1||map.keys[0]!==0)return false;
 const leaf=map.entries[0].value;if(leaf.identity)return true;
 return leaf.channels?.length===10&&leaf.channels.every((c,i)=>c.value===([0,1,2,9].includes(i)?1:0)&&c.duration===0);
}
export const selectNetworkVisualForRemoval=(entries,visualId)=>entries.find(e=>e&&!e.removed&&(e.record.visualId&65535)===(visualId&65535)&&(!e.instance?.nativeState||!e.instance.nativeState.finishedF4&&!visualHasCessation(e.instance.nativeState)))??null;

// Separate render facades carry client visual lists. Canonical network proxies,
// game effects/property IDs and replicated gameplay state are never modified.
export class NetworkVisualPresentation{
 constructor(scene){
  this.scene=scene;this.views=new Map();this.dummyViews=new Map();this.visualAssets=new Map();this.closed=false;this.delivery=Promise.resolve();this.stats={added:0,removed:0,instant:0};
  const objects={get:id=>this.view(id)},report=(...args)=>scene.report(...args);
  this.loops=new LoopingVisualPresentation({areaId:scene.area.id,objects:()=>this.views.values(),object:id=>this.view(id),render:id=>this.render(id),tables:async()=>({visuals:scene.tables.visualeffects,programs:scene.tables.progfx,appearance:scene.tables.appearance}),selectedObjectId1406ac1c0:()=>scene.world.localObjectId,report,
   createNative:(actor,_render,record,tables)=>{
    if(!networkVisualIdentity(record.networkTransform))throw new Error('Native network visual controller-map presentation is not connected');
    return createVisualSceneRuntime({actor,record,tables,objects,renderFor:id=>this.render(id),player:()=>this.view(scene.world.localObjectId),sceneRoot:scene.root,report,
     loadAsset:name=>this.asset(name),releaseAsset:()=>{}, // Scene cache owns shared assets including referenced children.
     createModel:(asset,name)=>this.createModel(asset,name),destroyModel:model=>this.destroyModel(model),updateReferences:(model,delta)=>model.references?.update(delta),shadowing:(model,enabled)=>setModelLightShadows(model.root,enabled,scene.configureShadow)});
   }});
 }
 asset(name){
  const key=String(name).toLowerCase();if(!this.visualAssets.has(key))this.visualAssets.set(key,loadModelReferenceAssets(key,{load:async name=>{if(this.closed||this.scene.closed)throw new Error('Network visual scene is closed');return this.scene.asset(name);},release:()=>{}}));return this.visualAssets.get(key);
 }
 createModel(asset,name){
  const scene=this.scene;if(this.closed||scene.closed)throw new Error('Network visual scene is closed');
  const model=scene.instantiate(asset,name);model.model=asset.model;model.resourceName=name;model.animator??=new ModelAnimator(asset.model,model.root);scene.instances.add(model);
  try{if(asset.model.nodes.some(n=>n.type==='reference'))model.references=new ModelReferenceScene({owner:model,asset,sceneRoot:scene.root,createModel:(asset,name)=>this.createModel(asset,name),destroyModel:model=>this.destroyModel(model)});return model;}
  catch(error){this.destroyModel(model);throw error;}
 }
 destroyModel(model){model.references?.dispose();this.scene.destroyModels([model]);}
 enqueue(work){this.delivery=this.delivery.then(work).catch(error=>this.scene.report('network.visual-delivery-failed',error.message,{stack:error.stack}));return this.delivery;}
 view(id){
  const dummy=this.dummyViews.get(id);if(dummy)return this.closed||this.scene.closed||dummy.dummy.destroyed?null:dummy;
  const s=this.scene,o=s.world.registry.get(id);if(this.closed||s.closed||!o||o.replicationRemoved||o.areaId!==s.area.id)return null;
  let v=this.views.get(id);if(v?.canonical!==o){v={id:o.id,objectType:o.objectType,canonical:o,logical:[],nativeLoopingVisuals160:{records:[]},get areaId(){return o.areaId;},get creatureData(){return{Appearance_Type:o.appearance?.appearance};},get position(){return s.objects.get(id)?.wrapper.position.toArray()??v.lastRender?.position.toArray()??[0,0,0];}};this.views.set(id,v);}return v;
 }
 render(id){const v=this.view(id);if(!v)return null;if(v.dummy)return v.dummy.model?.root??null;const current=this.scene.objects.get(id)?.wrapper;if(current)v.lastRender=current;return current??(this.scene.failures.has(id)?null:v.lastRender)??null;}
 async createDummy(role,position,lifetime,visualId){
  // Projectiles and visuals share ONE client internal allocator and AI expiry
  // owner. No entry or ID is inserted into the server's canonical registry.
  const owner=this.scene.projectiles?.dummies;
  if(!owner){this.scene.report('network.visual-dummy-unhandled','Native client dummy owner is unavailable',{role,position,lifetime,visualId});return null;}
  const dummy=await owner.createVisual(role,position,lifetime);if(!dummy)return null;
  if(this.closed||this.scene.closed||this.scene.world.areaId!==this.scene.area.id){owner.destroy(dummy);return null;}
  const scene=this.scene,view={id:dummy.id,objectType:5,dummy,logical:[],nativeLoopingVisuals160:{records:[]},areaId:scene.area.id,creatureData:{Appearance_Type:dummy.appearance},get position(){return dummy.model.root.position.toArray();}};
  this.views.set(dummy.id,view);this.dummyViews.set(dummy.id,view);return view;
 }
 record(change){return{visualId:change.visualId,sourceId:change.target??0x7f000000,bodyPart:0,transform:{scale:1,translate:[0,0,0],rotate:[0,0,0]},networkTransform:structuredClone(change.visualTransform),delivery:{instant:0,sourcePart:change.field8??0,targetPart:0,point:[0,0,0]}};}
 async add(actor,record,transient=false){
  if(!actor||!this.render(actor.id)){this.scene.report('network.visual-target-unavailable','Native visual target render binding is unavailable',{objectId:actor?.id,visualId:record.visualId});return 0;}let entry;
  if(transient){const old=new Set(this.loops.entries.keys());this.loops.addTransient(actor,record);entry=[...this.loops.entries.values()].find(e=>!old.has(e.record));}
  else{actor.nativeLoopingVisuals160.records.push(record);this.loops.update(0);entry=this.loops.entries.get(record);}
  if(!entry)return 0;actor.logical.push(entry);this.stats[transient?'instant':'added']++;await entry.ready;return 1;
 }
 remove(actor,visualId){
  if(!actor)return 0;
  // Complete762ad0 scans from the HEAD and skips already finished/cessation
  // entries. This differs from the server's last-match looping-array removal.
  const entry=selectNetworkVisualForRemoval(actor.logical,visualId);
  if(!entry)return 0;const records=actor.nativeLoopingVisuals160.records,index=records.indexOf(entry.record);if(index>=0)records.splice(index,1);
  this.loops.retire(entry);this.loops.entries.delete(entry.record);this.loops.selectInstances(actor);this.stats.removed++;return 1;
 }
 receive(events){
  const inputs=events.filter(e=>e.action==='visual-effects').map(e=>({event:structuredClone(e),canonical:this.scene.world.registry.get(e.id),areaId:this.scene.world.areaId}));
  return this.enqueue(async()=>{for(const input of inputs){if(this.closed)return;const {event,canonical,areaId}=input;if(this.scene.world.registry.get(event.id)!==canonical||areaId!==this.scene.world.areaId)continue;const actor=this.view(event.id);for(const change of event.changes){if(change.action==='A')await this.add(actor,this.record(change));else if(change.action==='D')this.remove(actor,change.visualId);else this.scene.report('network.visual-action-unhandled','Native looping visual action is unavailable',{objectId:event.id,action:change.action});}}});
 }
 receiveInstant(message){
  const target=this.scene.world.registry.get(message.targetId),areaId=this.scene.world.areaId;
  return this.enqueue(async()=>{if(this.closed||this.scene.world.areaId!==areaId||target&&this.scene.world.registry.get(target.id)!==target)return;const pending=[];let dummyFailure=false;
   const result=await deliverObjectVisualAsync({...message,transform:{scale:1,translate:[0,0,0],rotate:[0,0,0]}},{visualType:id=>nativeStringEntry(this.scene.tables.visualeffects,id,'Type_FD'),object:id=>this.view(id),renderObject:o=>o,
    createDummy:async(role,position,lifetime)=>{const actor=await this.createDummy(role,position,lifetime,message.visualId);if(!actor)dummyFailure=true;return actor;},add:(actor,record)=>{record.networkTransform=structuredClone(message.visualTransform);pending.push(this.add(actor,record,true));return 1;}});if(result!==1&&!dummyFailure)this.scene.report('network.visual-target-unavailable','Native visual target could not be resolved',{visualId:message.visualId,objectId:message.targetId});await Promise.all(pending);
  });
 }
 update(delta){
  if(this.closed)return;
  for(const v of this.views.values()){const render=this.render(v.id);let changed=false;for(const entry of [...this.loops.entries.values(),...this.loops.retiring])if(entry.actor===v&&render&&entry.render!==render){entry.render=render;changed=true;}if(changed)this.loops.rebindModel(v);}
  this.loops.update(delta);
  for(const [id,v]of this.views){v.logical=v.logical.filter(e=>this.loops.entries.get(e.record)===e||this.loops.retiring.has(e));if(this.view(id)!==v){this.views.delete(id);this.dummyViews.delete(id);}}
 }
 dispose(){this.closed=true;this.loops.dispose();for(const v of this.dummyViews.values())this.scene.projectiles?.dummies.destroy(v.dummy);this.views.clear();this.dummyViews.clear();this.visualAssets.clear();}
 snapshot(){return{...this.stats,active:this.loops.snapshot(),dummies:[...this.dummyViews.values()].map(v=>({id:v.id,position:v.dummy.position,duration:v.dummy.duration}))};}
}
