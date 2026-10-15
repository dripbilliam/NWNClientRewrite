import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {constructAreaEffect,initializeAreaEffect,setAreaEffectCreator,setAreaEffectShape,updateAreaEffect,inAreaEffect,closestAreaSegmentPoint,setAreaEffectAnchor,updateAreaEffectSubareas,dispatchAreaEffectEvent,addAreaEffectToArea,removeAreaEffectSubareas,setAreaEffectDuration,objectInAreaEffect,createPersistentAreaEffect,intersectAreaEffect} from '../src/area_effect.js';
import {NativeIdList} from '../src/native_id_list.js';
import {initializeSpellContext} from '../src/spell_context.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-area-effect-observations.json',import.meta.url)));
test('Persistent area-effect values, caster metadata, shape and AI timing match original instructions',async()=>{
  for(const row of oracle.rows){const c=row.case,calls=[],o={id:101,objectType:11};initializeSpellContext(o);initializeAreaEffect(o,{day:0,time:0});
    o.nativeAnchor334=c.anchor??0x7f000000;o.nativeShape310=(c.shape??0)&255;o.nativeRadius318=c.radius??0;
    o.nativeHeartbeat388={day:1,time:c.heartbeatTime??1};o.nativeDuration390=c.duration??1000;o.nativeDurationType394=c.durationType??2;
    o.nativeFrameElapsedD4=0;o.position=[0,0,0];o.nativeWidth31c=0;o.nativeLength320=0;
    if(c.mode==='constructor'){
      const e=constructAreaEffect([c.id,...c.strings],99,{create:(type,creatorId,ints,subtype)=>({type,creatorId,integers:[...ints,...Array(7).fill(0)],subtype,floats:Array(4).fill(0)})});
      assert.deepEqual(e,row.output,JSON.stringify(c));continue;
    }
    if(c.mode==='creator')setAreaEffectCreator(o,99,c.level??8,c.spell??11,c.class??3,c.meta??2,c.dc??19,c.feat??123,c.spontaneous??1,{creature:()=>c.sourceExists===false?null:{nativeCasterOverride820:c.override??0,nativeEquipmentLock97c:c.equipment??0,nativeSpellOverride9e8:11,nativeSpellOverride9ec:13,nativeSpellOverride9f0:14}});
    if(c.mode==='shape')setAreaEffectShape(o,c.shape,c.width,c.length);
    if(c.mode==='update'){
      let reads=0;await updateAreaEffect(o,{microseconds:()=>c.ticks??1000000,worldTime:()=>({day:c.day??7,time:c.time??10000}),
        difference:()=>({status:0,milliseconds:reads++===0?c.elapsed??100:c.heartbeatElapsed??6000}),runScript:(_o,index,flag)=>calls.push(['script',index,flag]),
        object:()=>c.anchorExists===false?null:{position:c.position??[1,2,3]},position:a=>a.position,area:()=>c.area===false?null:{},
        updateSubareas:(_o,point)=>calls.push(['subareas',point]),setPosition:(_o,point,flag)=>{calls.push(['position',point,flag]);o.position=point;},
        enqueue:(event,source,target)=>calls.push(['event',event,source,target]),updateEffects:(_o,now,ticks)=>calls.push(['effects',now.day,now.time,ticks])});
    }
    // The native fixture's base object starts with spell218=0. The derived
    // constructor does not write it; production initializes the base to -1.
    if(c.mode!=='creator')o.nativeSpellId218=0;
    const state={creator:o.nativeAreaEffectCreator330,level:o.nativeCasterLevel344,spell:o.nativeSpellId218,effectSpell:o.nativeAreaEffectSpellId,dc:o.nativeSpellSaveDC340,
      classId:o.nativeSpellClass22c,meta:o.nativeSpellMetamagic22d,feat:o.nativeSpellFeat23c,spontaneous:o.nativeSpellSpontaneous228,shape:o.nativeShape310,radius:o.nativeRadius318,
      width:o.nativeWidth31c,length:o.nativeLength320,anchor:o.nativeAnchor334,vertices:o.nativeVertices328,previous:o.nativePreviousTime,heartbeat:o.nativeHeartbeat388,
      elapsed:o.nativeFrameElapsedD4,duration:o.nativeDuration390,position:o.position};
    assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(state,row.state,JSON.stringify(c));
  }
});
const creation=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-area-effect-creation-observations.json',import.meta.url)));
test('Persistent-effect creation snapshots or reuses caster context and writes the canonical instance ID like the original',async()=>{
  for(const row of creation.rows){const c=row.case,calls=[],o={id:101,scripts:{}},source={id:99,objectType:c.sourceType??5,nativeSpellClass22c:3,nativeSpellMetamagic22d:2,nativeSpellFeat23c:123,nativeSpellSpontaneous228:1,nativeCreatedAreaEffects170:new NativeIdList()},
    effect={type:31,subtype:c.subtype??8,durationType:c.durationType??1,duration:3.5,creatorId:99,spellId:11,casterLevel:8,integers:c.integers?.slice()??[5,0,0,0,0,0,0,0],objectIds:[0x7f000000],strings:c.strings??['','','']};
    if(c.owned)source.nativeCreatedAreaEffects170.append(o.id);const append=source.nativeCreatedAreaEffects170.append.bind(source.nativeCreatedAreaEffects170);
    source.nativeCreatedAreaEffects170.append=id=>{calls.push(['own',id]);append(id);};
    const p={dead:()=>c.dead??0,aoe:()=>c.existing?o:null,construct:()=>{calls.push(['construct']);return o;},object:()=>c.sourceExists===false?null:source,
      saveDC:(_o,spell)=>{calls.push(['saveDC',spell]);return 19;},setCreator:(_o,...args)=>calls.push(['creator',...args]),load:(_o,id)=>calls.push(['load',id]),
      setDuration:(_o,type,seconds)=>calls.push(['duration',type,seconds]),setOrientation:(_o,v)=>calls.push(['orientation',v]),area:()=>c.area===false?null:{},
      setAnchor:(_o,id)=>calls.push(['anchor',id]),position:()=>[4,5,6],addToArea:(_o,a,v,flag)=>calls.push(['add',Boolean(a),v,flag])};
    const result=await createPersistentAreaEffect(c.attached?{id:77,objectType:c.targetType??5}:{},effect,[1,2,3],[0,1,0],p,{attached:c.attached??false,loading:c.loading??0});
    assert.equal(result??null,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(effect.integers,row.integers,JSON.stringify(c));
    assert.equal(effect.objectIds[0],row.instance,JSON.stringify(c));assert.deepEqual(Object.fromEntries(['enter','heartbeat','exit'].flatMap((key,i)=>o.scripts[key]===undefined?[]:[[i,o.scripts[key]]])),row.overrides,JSON.stringify(c));
  }
});
const overlap=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-area-effect-overlap-observations-v3.json',import.meta.url)));
test('Area-effect overlap, moving sweeps, anchor IDs and callback dispatch match original instructions',async()=>{
  const list=(values,owner,calls)=>{const l=new NativeIdList();for(const id of values)l.append(id);
    const append=l.append.bind(l),remove=l.remove.bind(l);l.append=id=>{calls.push(['append',owner,id]);append(id);};l.remove=id=>{calls.push(['remove',owner,id]);remove(id);};return l;};
  for(const row of overlap.rows){const c=row.case,calls=[],o={id:101,objectType:11,nativeShape310:c.shape??0,nativeRadius318:c.radius??2,nativeAnchor334:c.anchor??0x7f000000,
    nativeVertices328:c.vertices??[[2,2,0],[2,-2,0],[-2,-2,0],[-2,2,0]],position:(c.center??[0,0,0]).map(Math.fround),nativeEntering338:0,nativeExiting33c:0,nativeDestroyableF0:c.destroyable??1,nativeWidth31c:c.width??4,nativeLength320:c.length??6,nativeDuration390:1234,nativeDurationType394:0,nativePersistentCursor308:c.cursor??0},
    objects=(c.objects??[]).map(a=>({id:a.id,objectType:a.type??5,position:a.position.map(Math.fround),nativeSubareaMembership:list(a.membership??[],a.id,calls),nativeFollowingAOEs:list(a.following??[],a.id,calls)})).sort((a,b)=>a.position[0]-b.position[0]),
    area={nativeSubareas:list([],77,calls)},p={object:id=>objects.find(o=>o.id===id),position:o=>o.position,area:()=>c.area===false?null:area,areaIds:()=>objects.map(o=>o.id),
      firstByX:(_a,x)=>{calls.push(['first',x]);const i=objects.findIndex(o=>o.position[0]>=x);return i<0?null:i;},contains:(o,point)=>inAreaEffect(o,point,o.position),
      event:(actor,aoe,code)=>calls.push(['event',actor.id,aoe.id,code,actor.id]),runScript:(_o,index,flag)=>calls.push(['script',index,flag]),
      removeFromArea:()=>calls.push(['removeFromArea']),destroy:()=>calls.push(['destroy']),orientation:()=>c.orientation??[1,0,0],setArea:(_o,a)=>calls.push(['setArea',a?77:null]),writePosition:(o,point)=>{o.position=point;},addObject:(_a,o,flag)=>calls.push(['addObject',o.id,flag]),setFieldD8:(_o,n)=>calls.push(['fieldD8',n]),updateSubareas:()=>calls.push(['updateSubareas']),dispatchExit:actor=>calls.push(['dispatchExit',13,actor.id]),dm:o=>Number(o.id===c.dm),dead:o=>Number((c.dead??[]).includes(o.id))};
    let result=null;
    if(c.mode==='contains')result=inAreaEffect(o,c.point,o.position);
    else if(c.mode==='crossing')result=intersectAreaEffect(o,c.start,c.end,o.position,c.area!==false);
    else if(c.mode==='closest')result=closestAreaSegmentPoint(c.start,c.end,c.point);
    else if(c.mode==='anchor')setAreaEffectAnchor(o,c.newAnchor,p);
    else if(c.mode==='add')await addAreaEffectToArea(o,c.area===false?null:area,c.point??[3,4,5],1,p);
    else if(c.mode==='remove')await removeAreaEffectSubareas(o,c.synchronous??1,p);
    else if(c.mode==='duration')setAreaEffectDuration(o,c.durationType??1,c.seconds);
    else if(c.mode==='query')result=objectInAreaEffect(c.first??true,o,c.filter??1,c.zone??0,p);
    else if(c.mode==='event')await dispatchAreaEffectEvent(o,{eventId:c.event,payload:{type:c.code,objectIds:[c.actor??7]}},p);
    else await updateAreaEffectSubareas(o,c.next,p);
    assert.deepEqual(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
    assert.deepEqual(Object.fromEntries(objects.map(o=>[o.id,[...o.nativeSubareaMembership.view()]])),row.memberships,JSON.stringify(c));
    assert.deepEqual(Object.fromEntries(objects.map(o=>[o.id,[...o.nativeFollowingAOEs.view()]])),row.following,JSON.stringify(c));
    assert.deepEqual(o.position,row.position,JSON.stringify(c));assert.deepEqual(o.nativeVertices328,row.vertices,JSON.stringify(c));assert.equal(o.nativeDuration390,row.duration,JSON.stringify(c));assert.equal(o.nativeDurationType394,row.durationType,JSON.stringify(c));assert.equal(o.nativePersistentCursor308,row.cursor,JSON.stringify(c));assert.equal(o.nativeAnchor334,row.anchor,JSON.stringify(c));assert.equal(o.nativeEntering338,row.entering,JSON.stringify(c));assert.equal(o.nativeExiting33c,row.exiting,JSON.stringify(c));
  }
});
