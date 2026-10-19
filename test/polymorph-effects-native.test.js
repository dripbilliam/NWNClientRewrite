import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applyPolymorph,removePolymorph,constructPolymorph} from '../src/polymorph_effect.js';
import {applyRacialType,removeRacialType,loadRacialFeatList,isFirstLevelRacialFeat} from '../src/racial_effect.js';
import {EffectRuntime} from '../src/effect_runtime.js';
import {ModuleSession} from '../src/module_session.js';
import {addWorldTimes,secondsToWorldDelta,subtractWorldTimes} from '../src/world_timer.js';
import {hasNativeFeat} from '../src/feat_uses.js';
import {parse2da} from '../src/area.js';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-polymorph-effect-observations.json',import.meta.url)));
function snapshot(e){return Object.fromEntries(Object.keys(fixture.rows[0].before).map(k=>[k,k==='exposed'?Number(e[k]):structuredClone(e[k])]));}
test('polymorph and racial effect upper owners agree with original guards, copy metadata, replacement, timing and callbacks',async()=>{
 assert.equal(fixture.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.rows.length,1815);
 for(const row of fixture.rows){const c=row.case;if(['loader','query','racialRemove'].includes(c.mode))continue;
  const actor={id:99,objectType:c.creature===false?6:5,effects:structuredClone(row.initial),associateType:c.associate??0,nativeField97c:c.locked??0,nativeField9f8:c.overrideFlag??0,nativeField89c:c.pc??0,nativeDestroyableF0:c.destroyable??1},effect=structuredClone(row.before),calls=[],runtime=new ModuleSession(null).effects;runtime.nextId=101n;
  const p={asCreature:o=>o.objectType===5?o:null,dead:()=>{calls.push(['dead']);return c.dead??0;},dying:()=>{calls.push(['dying']);return c.dying??0;},possessed:()=>{calls.push(['possessed']);return c.possessed??0;},effects:o=>o.effects,
   copyConstruct:(e,icons)=>EffectRuntime.prototype.copyConstruct(e,icons),setCreator:(e,id)=>{e.creatorId=id;},create:(...args)=>runtime.create(...args),
   apply:(_o,e,loading)=>{calls.push(['apply',snapshot(e),loading>>>0]);},
   remove:(o,id)=>{calls.push(['remove',id,o.effects.map(snapshot)]);o.effects=o.effects.filter(e=>e.id!==id);},
   transform:(_o,form,e,loading)=>{calls.push(['transform',form>>>0,snapshot(e),loading>>>0]);if(Object.hasOwn(c,'transformOverride'))e.integers[2]=c.transformOverride;return c.transformResult??1;},
   untransform:(_o,e)=>{calls.push(['untransform',snapshot(e)]);return c.transformResult??1;},
   client:id=>{calls.push(['client',id]);return c.client?{}:null;},notify:(_client,id,apply,value)=>calls.push(['notify',id,apply,value]),
   time:()=>{calls.push(['time']);return{day:c.day??2,time:c.time??100};},delta:value=>secondsToWorldDelta(value,(c.dayLength??7200000)/1000),
   addTime:(now,delta)=>{calls.push(['addTime',now.day,now.time,delta.day,delta.time]);return addWorldTimes(now,delta,c.dayLength??7200000);},setExpiry:()=>{},raceFeats:()=>Uint16Array.from(c.feats??[])};
  const result=c.mode==='apply'?await applyPolymorph(actor,effect,p,c.loading??0):c.mode==='remove'?await removePolymorph(actor,effect,p):await applyRacialType(actor,effect,p,c.loading??0);
  assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(snapshot(effect),row.effect,JSON.stringify(c));assert.deepEqual(actor.effects.map(snapshot),row.effects,JSON.stringify(c));assert.equal(actor.nativeField9f8,row.overrideFlag,JSON.stringify(c));
 }
});
test('physical race feat loader and WORD membership match the original native allocation/query owners',()=>{
 for(const row of fixture.rows){const c=row.case;if(c.mode==='loader'){
   const rows=Array.from({length:c.count},(_,i)=>({FeatIndex:c.entries[i]===null||c.entries[i]===undefined?'****':String(c.entries[i])})),table={orderedRows:rows,columns:['FeatIndex'],defaultValue:''};
   const list=loadRacialFeatList(table);assert.deepEqual([...list],row.feats,JSON.stringify(c));assert.deepEqual(Array.from({length:list.length},(_,i)=>['int',i,'FeatIndex',c.entries[i]!==null&&c.entries[i]!==undefined]),row.calls,JSON.stringify(c));
  }else if(c.mode==='query')assert.equal(isFirstLevelRacialFeat(c.nullList?null:Uint16Array.from(c.feats),c.feat),row.result,JSON.stringify(c));
  else if(c.mode==='racialRemove')assert.equal(removeRacialType(),row.result);
 }
});
test('race feat loading uses physical rows, first matching column, defaults and successful WORD narrowing',()=>{
 const table=parse2da('2DA V2.0\nDEFAULT: 65889\n\nFeatIndex featindex\n99 -1 1\n99 **** 228\n7 228 354');assert.deepEqual([...loadRacialFeatList(table)],[65535,0,228]);assert.equal(isFirstLevelRacialFeat(loadRacialFeatList(table),65889),0);
 assert.deepEqual([...loadRacialFeatList(null)],[]);
});
test('EffectPolymorph constructor matches old argument grouping and native class/feat ability selection',()=>{
 assert.equal(fixture.constructors.length,1932);
 for(const row of fixture.constructors){const c=row.case,calls=[],s=new ModuleSession(null);s.effects.nextId=101n;
  if(c.failPop!==undefined){assert.equal(row.result,0xfffffd81);assert.equal(row.output,null);continue;}
  const actor={nativeSpellClass22c:c.classIndex??0,nativeSpellFeat23c:c.feat??65535},args=c.args??[],p={create:(...args)=>s.effects.create(...args),setCreator:(e,id)=>{e.creatorId=id;},
   creature:id=>{calls.push(['creature',id]);return c.creature===false?null:actor;},hasStats:()=>true,
   classType:(_o,index)=>{calls.push(['classType',index]);return(c.classes??[10,5])[index]??255;},
   featSource:(_o,id)=>{calls.push(['featSource',id]);return c.featSource??255;},classInfo:id=>{calls.push(['classInfo',id]);return{castingAbility:c.classInfo?.[id]?.casting??3,primaryAbility:c.classInfo?.[id]?.primary??0};}};
  if(!args.length||args.length>2&&args.length<5){assert.equal(row.result,0xfffffd81);assert.throws(()=>constructPolymorph(args,99,p),/-639/);assert.equal(s.effects.nextId,102n);continue;}
  const actual=constructPolymorph(args,99,p);assert.deepEqual(snapshot(actual),row.output,JSON.stringify(c));assert.deepEqual(calls,row.calls.filter(v=>!['pop','push'].includes(v[0])),JSON.stringify(c));assert.equal(row.result,c.push===0?0xfffffd82:0,JSON.stringify(c));
 }
});
test('live EffectPolymorph command preserves raw form/lock/caster inputs and does not fabricate a transform',()=>{
 const s=new ModuleSession(null),e=s.commands.EffectPolymorph([-1,-1,-1,2,17],{self:99});assert.equal(e.type,62);assert.equal(e.subtype,8);assert.equal(e.creatorId,99);assert.deepEqual(e.integers,[-1,0,-1,1,-1,1,2,17]);
 assert.throws(()=>s.commands.EffectPolymorph([44,0,85],{self:99}),/-639/);
 const legacy=s.commands.EffectPolymorph([44],{self:99});assert.deepEqual(legacy.integers,[44,0,0,0,0,1,255,0]);
});
test('actual polymorph callbacks share live icon/bonus-feat removal and defer reversal across a world-day boundary',async()=>{
 const s=new ModuleSession(null),o=s.register('creature','polymorph-fixture',{creatureData:{ClassList:[],FeatList:[]}}),effect=s.effects.create(62,0x7f000000,[44,0,0,1,-1,1,2,17],8),events=[];effect.durationType=2;
 s.worldTimer.setTime(2,s.worldTimer.dayLength-200);
 const p={asCreature:o=>o.objectType===5?o:null,dead:()=>0,dying:()=>0,possessed:()=>0,effects:o=>o.effects,remove:(o,id)=>s.effects.remove(o.id,id),copyConstruct:(...a)=>s.effects.copyConstruct(...a),
  apply:(o,e,loading)=>s.effects.applyNative(e,o.id,undefined,loading),transform:actor=>{assert.equal(actor,o);events.push('transform');},untransform:actor=>{assert.equal(actor,o);events.push('untransform');},client:()=>null,
  time:()=>s.worldTimer.time(),delta:n=>secondsToWorldDelta(n,s.worldTimer.secondsPerDay),addTime:(a,b)=>addWorldTimes(a,b,s.worldTimer.dayLength),
  setExpiry:(e,expiry)=>{const delta=subtractWorldTimes(expiry,s.worldTimer.time(),s.worldTimer.dayLength);assert.equal(delta.status,0);assert.equal(e.expiryDay,expiry.day);assert.equal(e.expiryTime,expiry.time);}};
 assert.equal(await applyPolymorph(o,effect,p),0);s.effects.retain(o,effect);assert.deepEqual(o.effects.map(e=>e.type),[62,67,83]);assert.equal(hasNativeFeat(o,289),1);assert.equal(o.nativeEffectIcons778.records.length,1);
 const original=s.effects.onRemove.bind(s.effects);s.effects.onRemove=(actor,e,context)=>e.type===62?removePolymorph(actor,e,p):original(actor,e,context);
 await s.effects.remove(o.id,effect.id);assert.deepEqual(o.effects,[effect]);assert.equal(hasNativeFeat(o,289),0);assert.equal(o.nativeEffectIcons778.records.length,0);assert.deepEqual(events,['transform']);assert.equal(effect.expiryDay,3);assert.equal(effect.expiryTime,300);
 s.scheduler.time=500;s.worldTimer.snapshot();await s.effects.updateObject(o);assert.deepEqual(o.effects,[effect]);assert.deepEqual(events,['transform']);
 s.scheduler.time=501;s.worldTimer.snapshot();await s.effects.updateObject(o);assert.deepEqual(o.effects,[]);assert.deepEqual(events,['transform','untransform']);assert.equal(s.registry.get(o.id),o);
});
