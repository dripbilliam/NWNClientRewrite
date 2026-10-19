import {createAreaVisualState,loadAreaVisualEffect,startAreaVisualEffect,updateAreaVisualEffect} from './area_visual_effect.js';
import {nativeStringEntry} from './spell_metadata.js';
import {nativeFloatEntry} from './movement_rate.js';
import {intEntry} from './combat_stats.js';
import {subtractWorldTimes} from './world_timer.js';
import {networkVisualIdentity} from './network_visual_presentation.js';
import {setModelLightPriority} from './model_light.js';
const clips={1:'impact',2:'duration',3:'cessation'};

// CNWCVisualEffect uses client type11/internal IDs. It is independent of the
// canonical server registry and of object effects' temporary-creature lifetime.
export class NetworkAreaVisualPresentation{
 constructor(scene){this.scene=scene;this.active=new Set();this.closed=false;this.received=0;this.failed=0;}
 note(e,code,message,data={}){e.reported??=new Set();const key=code+JSON.stringify(data);if(!e.reported.has(key)){e.reported.add(key);this.scene.report(code,message,{visualId:e.visual180,...data});}}
 providers(){const s=this.scene,owner=this;return{
  now:()=>s.combat.timer.time(),difference:(a,b)=>subtractWorldTimes(a,b,s.combat.timer.dayLength),
  quality:()=>1,int:(id,key)=>intEntry(s.tables.visualeffects,id,key),float:(id,key)=>nativeFloatEntry(s.tables.visualeffects,id,key),string:(id,key)=>nativeStringEntry(s.tables.visualeffects,id,key),
  loadModel:async(e,name)=>{const asset=await s.visuals.asset(name);if(owner.closed||s.closed||e.destroyed)return 0;e.model=s.visuals.createModel(asset,name);e.model.root.userData.areaVisualId=e.visual180;setModelLightPriority(e.model.root,11);return 1;},
  animationMode:e=>owner.note(e,'network.area-visual-orientation-unhandled','Native special area visual orientation is not connected'),
  defaultAnimation:e=>owner.note(e,'network.area-visual-default-animation-unhandled','Native special area visual default playback is not connected'),
  shake:(type,delay,duration)=>s.report('network.area-visual-shake-unhandled','Native area visual camera shake is not connected',{type,delay,duration}),
  speed40:()=>{s.report('network.area-visual-speed-unverified','Native special visual speed configuration is unavailable');return 1;},
  animationLength:(e,phase)=>Math.fround((e.model.model.animations.find(a=>a.name===clips[phase])?.length??0)*1000),
  play:(e,phase,speed,flags,time)=>e.model.animator.playNative(clips[phase]??String(phase),{speed,flags,time}),
  oneShot:(name,position,height,priority)=>{if(name)s.report('network.area-visual-audio-unhandled','Native area visual audio output is not connected',{resource:name,position,height,priority});},
  createSound:resRef=>({resRef}),sound3d:(o,v)=>o.is3d=v,soundPriority:(o,v)=>o.priority=v,soundLooping:(o,v)=>o.looping=v,
  playSound:o=>{if(o.resRef)s.report('network.area-visual-audio-unhandled','Native area visual duration sound output is not connected',{resource:o.resRef});},stopSound:()=>{},destroySound:()=>{},updateSound:()=>{},
  setScene:(e,scene)=>{if(!scene)e.model?.root.removeFromParent();},destroy:e=>owner.destroy(e)
 };}
 async receive(message){
  if(this.closed)return;this.received++;const s=this.scene,e=createAreaVisualState(s.combat.timer.time()),p=this.providers();e.visual180=message.visualId;
  try{
   if(!networkVisualIdentity(message.visualTransform))throw new Error('Native area visual controller-map presentation is not connected');
   s.projectiles.objects.addInternal(e);this.active.add(e);
   if(!await loadAreaVisualEffect(e,message.visualId,p)){this.destroy(e);return;}
   if(this.closed||s.closed||e.destroyed){this.destroy(e);return;}
   e.instant190=1;e.destroy194=1;e.position=message.position.map(Math.fround);
   if(e.model){e.model.root.position.set(e.position[0],e.position[2],-e.position[1]);s.root.add(e.model.root);if(e.orient198)this.note(e,'network.area-visual-ground-orientation-unhandled','Native area visual ground-normal orientation is not connected');}
   startAreaVisualEffect(e,1,p);
   if(e.model&&!e.remaining17c)this.note(e,'network.area-visual-zero-animation-length','Native area visual has no positive impact countdown; it is retained by the native AI rule',{model:e.model.resourceName});
   this.note(e,'network.area-visual-scene-adapter-incomplete','Native area-effect selection, playback and AI are connected; asynchronous resource/cache, scene visibility and client clock scheduling remain unverified');
  }catch(error){this.failed++;this.destroy(e);s.report('network.area-visual-failed',error.message,{visualId:message.visualId,stack:error.stack});}
 }
 update(delta){if(this.closed)return;const p=this.providers();for(const e of [...this.active])try{updateAreaVisualEffect(e,p);if(!e.destroyed&&e.model){e.model.animator.update(delta);e.model.references?.update(delta);}}catch(error){this.failed++;this.destroy(e);this.scene.report('network.area-visual-update-failed',error.message,{visualId:e.visual180});}}
 destroy(e){if(e.destroyed)return;e.destroyed=true;this.active.delete(e);this.scene.projectiles?.objects.remove(e);if(e.sound170){const p=this.providers();p.stopSound(e.sound170);p.destroySound(e.sound170);e.sound170=null;}if(e.model){this.scene.visuals.destroyModel(e.model);e.model=null;}}
 dispose(){this.closed=true;for(const e of [...this.active])this.destroy(e);}
 snapshot(){return{received:this.received,failed:this.failed,active:[...this.active].map(e=>({id:e.id,visualId:e.visual180,ready:Boolean(e.model),model:e.model?.resourceName,phase:e.phase184,remaining:e.remaining17c,retiring:e.retiring188,retireRemaining:e.retire178,position:e.position}))};}
}
