import {OBJECT_INVALID} from './game_object_array.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {parse2da} from './area.js';
import {areaSpatialIds,firstAreaSpatialIndex} from './nearest_objects.js';
import {initializeAreaEffect,loadAreaEffect,setAreaEffectCreator,setAreaEffectDuration,setAreaEffectAnchor,addAreaEffectToArea,inAreaEffect,intersectAreaEffect,updateAreaEffectSubareas,createPersistentAreaEffect,removeAttachedAreaEffect,updateAreaEffect,dispatchAreaEffectEvent,removeAreaEffectFromArea,objectInAreaEffect} from './area_effect.js';
import {subtractWorldTimes} from './reputation.js';
const f=Math.fround,native=v=>[v[0],f(-v[2]),v[1]],render=v=>[v[0],v[2],f(-v[1])];
export class AreaEffectRuntime{
  constructor(session){this.session=session;this.tablePromise=null;}
  async table(){
    if(!this.tablePromise)this.tablePromise=this.session.resolver.getResource('vfx_persistent',RESOURCE_TYPE.TWO_DA).then(bytes=>parse2da(decodeResourceText(bytes)));
    try{return await this.tablePromise;}catch(error){this.tablePromise=null;throw error;}
  }
  providers(){const s=this.session;return{
    object:id=>s.registry.get(id)??null,creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},aoe:id=>{const o=s.registry.get(id);return o?.objectType===11?o:null;},
    area:o=>{const a=s.registry.get(o.areaId);return a?.objectType===4?a:null;},position:o=>native(o.position),orientation:o=>native(o.orientation),
    areaIds:a=>areaSpatialIds(s,a),firstByX:(a,x)=>firstAreaSpatialIndex(s,a,x),contains:(o,point)=>inAreaEffect(o,point,native(o.position)),
    dead:o=>Number(s.isDead(o)),dm:o=>Number((o.associateType&65535)===0&&Boolean(s.combat.broadcastProviders().client(o.id))&&Boolean(o.isDM)),saveDC:(o,spell)=>s.spellBook.saveDC(o,spell),
    construct:()=>{const o=s.register('areaOfEffect',`runtime:areaOfEffect:${s.registry.nextObjectId[0]}`,{areaId:OBJECT_INVALID,position:[0,0,0],authored:{}});
      initializeAreaEffect(o,s.worldTimer.time());s.aiMaster.setLevel(o,2);return o;},
    load:async(o,id)=>{loadAreaEffect(o,id,await this.table(),{
      warning:message=>s.combat.warning(o,message),addTag:(o,tag)=>{if(tag){const key=tag.slice(0,64);s.tags.set(key,[o.id,...(s.tags.get(key)??[])]);}}});},
    setArea:(o,a)=>{o.areaId=a?.id??OBJECT_INVALID;},writePosition:(o,point)=>{o.position=render(point);o.nativePosition=[...point];},
    setOrientation:(o,point)=>{o.orientation=render(point);},setFieldD8:(o,n)=>{o.nativeFieldD8=n|0;},
    setCreator:(...args)=>setAreaEffectCreator(...args,this.providers()),setDuration:setAreaEffectDuration,
    setAnchor:(...args)=>setAreaEffectAnchor(...args,this.providers()),addToArea:(...args)=>addAreaEffectToArea(...args,this.providers()),
    addObject:(a,o)=>{a.nativeSpatial.insert(o.id);if(!a.objects.includes(o.id))a.objects.push(o.id);},
    removeObject:(a,o)=>{a.nativeSpatial.remove(o.id);const index=a.objects.indexOf(o.id);if(index>=0)a.objects.splice(index,1);},
    updateSubareas:(o,point)=>this.updateSubareas(o,point),event:(actor,o,code)=>s.combat.enqueueEvent(10,actor.id,o.id,0,{type:code,objectIds:[actor.id]}),
    dispatchExit:(actor,o)=>this.dispatch(o,{eventId:10,callerId:actor.id,payload:{type:13,objectIds:[actor.id]}}),
    enqueue:(...args)=>s.combat.enqueueEvent(...args),runScript:async(o,index)=>{const name=o.scripts?.[['heartbeat','userDefined','enter','exit'][index]];
      if(name)await s.runScript(name,o.id,{scriptEventContext:11000+index});},
    microseconds:()=>BigInt(Math.trunc(performance.now()*1000)),worldTime:()=>s.worldTimer.time(),difference:(now,then)=>subtractWorldTimes(now,then,s.worldTimer.dayLength),
    setPosition:(o,point,flag)=>s.setPosition(o,render(point),flag),updateEffects:o=>s.effects.updateObject(o),
    removeFromArea:o=>removeAreaEffectFromArea(o,this.providers()),destroy:o=>this.destroy(o),
  };}
  async applyAtPoint(area,effect,point,orientation){await this.table();return createPersistentAreaEffect(area,effect,point,orientation,this.providers());}
  async applyAttached(target,effect,loading){await this.table();return createPersistentAreaEffect(target,effect,null,null,this.providers(),{attached:true,loading});}
  removeAttached(target,effect){return removeAttachedAreaEffect(target,effect,this.providers());}
  contains(o,point){return inAreaEffect(o,native(point),native(o.position));}
  intersects(o,start,end){return intersectAreaEffect(o,native(start),native(end),native(o.position),Boolean(this.session.registry.get(o.areaId)));}
  updateSubareas(o,point){return updateAreaEffectSubareas(o,point,this.providers());}
  async move(o,point){await this.updateSubareas(o,native(point));this.session.setPosition(o,point,0);}
  update(o){return updateAreaEffect(o,this.providers());}
  dispatch(o,event){return dispatchAreaEffectEvent(o,event,this.providers());}
  enumerate(first,id,filter,zone){return objectInAreaEffect(first,this.session.registry.get(id),filter,zone,this.providers());}
  async destroy(o){
    const s=this.session;if(o.effects?.length||o.nativeCreatedAreaEffects170?.count)throw new Error('Native area-effect base destructor effect/owned-AoE cleanup is unavailable');
    if(o.nativeAnchor334!==OBJECT_INVALID){const anchor=s.registry.get(o.nativeAnchor334);if(anchor){if(anchor.objectType!==5)throw new Error('Native destroyed AoE anchor is not a creature');anchor.nativeFollowingAOEs.remove(o.id);}}
    await removeAreaEffectFromArea(o,this.providers());o.nativeVertices328=null;s.aiMaster.removeObject(o);s.unregister(o.id);
  }
}
