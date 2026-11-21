import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applyPoison,applyPoisonPayload,applyDisease,applyDiseasePayload,updateAffliction} from '../src/affliction_effect.js';
import {EffectRuntime} from '../src/effect_runtime.js';
import {equalEffectValues} from '../src/effect_identity.js';
import {addWorldTimes,compareWorldTimes} from '../src/world_timer.js';
import {displayFloatyToSelf} from '../src/effect_feedback.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-affliction-observations.json',import.meta.url)));
const make=(id,type,creatorId,integers=[],subtype=0)=>({id:BigInt(id).toString(16).padStart(16,'0'),type,creatorId,integers:Array.from({length:8},(_,i)=>integers[i]??0),floats:Array(4).fill(0),strings:Array(6).fill(''),vectors:[[0,0,0],[0,0,0]],objectIds:Array(4).fill(0x7f000000),subtype,durationType:0,duration:0,spellId:-1,casterLevel:-1,bypassImmunity:0,exposed:true,showIcon:1,propertyId:'0000000000000000',customTag:''});
const project=e=>({id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,duration:e.duration,creatorId:e.creatorId,spellId:e.spellId,casterLevel:e.casterLevel,showIcon:e.showIcon,exposed:Number(e.exposed),bypassImmunity:e.bypassImmunity,propertyId:e.propertyId,customTag:e.customTag,integers:e.integers,strings:e.strings});

test('poison/disease application and payload dispatch match complete original owners with actual native copy/identity logic',async()=>{
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,710);
 for(const row of oracle.rows){
  const c=row.case,calls=[],actor={id:99,objectType:c.objectType??5},source={id:98},e=make(77,c.type??(c.mode.startsWith('poison')?35:5),98,c.integers??[],c.subtype??8);let ids=100,rolls=0;
  Object.assign(e,{durationType:c.durationType??0,duration:3.25,spellId:11,casterLevel:7,bypassImmunity:c.bypass??0,propertyId:'000000000000007b',showIcon:c.showIcon??1,exposed:c.exposed===0?false:c.exposed??true});e.strings[0]=c.inputScript??'';
  let effects=c.mode.endsWith('Payload')?[e]:(c.effects??[]).map(type=>({type}));
  const p={asCreature:o=>o.objectType===5?o:null,dead:()=>c.dead??0,plot:()=>c.plot??0,creature:()=>c.sourceExists===false?null:source,effects:()=>effects,
   immunity:(_o,category)=>{calls.push(['immunity',category]);return c.immunity??0;},feedback:(o,code,data)=>calls.push(['feedback',o.id,code,data]),
   tableInt:(kind,id,column)=>{const raw=c.table?.[column],found=raw!==null&&raw!==undefined,value=found?Number(raw):0;calls.push(['int',kind,id>>>0,column,Number(found),value]);return{found,value};},
   tableString:(kind,id,column)=>{const raw=c.table?.[column],found=raw!==null&&raw!==undefined,value=found?String(raw):'';calls.push(['str',kind,id>>>0,column,Number(found),value]);return{found,value};},
   roll:(count,sides)=>{calls.push(['roll',count,sides]);return(c.roll??7)+rolls++;},save:(_o,...args)=>{calls.push(['save',...args]);return c.save??0;},
   create:(type,creator,values,subtype)=>make(++ids,type,creator,values,subtype),copyConstruct:(effect,icons)=>EffectRuntime.prototype.copyConstruct(effect,icons),copyAssign:structuredClone,equal:equalEffectValues,
   apply:(_o,child,loading)=>calls.push(['apply',structuredClone(project(child)),loading]),enqueue:(_o,id,child)=>calls.push(['event',id,structuredClone(project(child))]),
   floatySelf:(_o,id)=>calls.push(['self',id]),floaty:(o,id)=>calls.push(['floaty',id,o.id]),
   time:()=>{calls.push(['time']);return{day:c.day??2,time:c.time??100};},minutesPerHour:()=>c.minutes??5,
   addTime:(now,delta)=>{calls.push(['addTime',now.day,now.time,delta.day,delta.time]);const value=addWorldTimes(now,delta,1000000);assert.equal(value.status,0);return value;},
   script:(name,o)=>{calls.push(['script',name,o.id]);if(c.scriptMutation==='remove')effects=[];if(c.scriptMutation==='mutate')e.integers[0]=99;if(c.scriptMutation==='replace')effects=[structuredClone(e)];}
  };
  const result=await({poison:()=>applyPoison(actor,e,p,c.loading??0),disease:()=>applyDisease(actor,e,p,c.loading??0),poisonPayload:()=>applyPoisonPayload(actor,e,p),diseasePayload:()=>applyDiseasePayload(actor,e,{day:c.day??2,time:c.time??100},p)})[c.mode]();
  assert.deepEqual({result,calls,effect:project(e),liveEffects:c.mode.endsWith('Payload')?effects.map(project):[]},{result:row.result,calls:row.calls,effect:row.effect,liveEffects:row.liveEffects},JSON.stringify(c));
 }
});

test('world deadlines match original add/compare leaves, including invalid untouched outputs and DWORD wrapping',()=>{
 assert.equal(oracle.times.length,450);
 for(const c of oracle.times){const result=addWorldTimes(c.a,c.b,c.length);assert.equal(result.status,c.status,JSON.stringify(c));if(c.status===0)assert.deepEqual(result,{status:0,day:c.day,time:c.time});else{assert.deepEqual(result,{status:-2});assert.equal(c.day,0xfeedface);assert.equal(c.time,0xdeadbeef);}assert.equal(compareWorldTimes(c.a,c.b,c.length),c.comparison,JSON.stringify(c));}
});

test('full-value effect identity and original copy constructor preserve source immunity override while clearing child payload storage',()=>{
 assert.equal(oracle.identities.length,21);assert.equal(oracle.copies.length,9);
 for(const c of oracle.identities)assert.equal(Number(equalEffectValues(c.left,c.right)),c.result,c.change);
 for(const c of oracle.copies){const value=EffectRuntime.prototype.copyConstruct(c.source,c.icons);assert.deepEqual({...project(value),floats:value.floats,objectIds:value.objectIds,vectors:value.vectors},c.result,JSON.stringify(c));}
});

test('poison and disease script constructors match original raw row selection, subtype and payload defaults',()=>{
 assert.equal(oracle.constructors.length,8);
 for(const c of oracle.constructors){const s=new ModuleSession(null);s.effects.nextId=101n;const effect=s.commands[c.kind==='poison'?'EffectPoison':'EffectDisease']([c.value],{self:99});assert.equal(c.result,0);assert.deepEqual(project(effect),c.effect,JSON.stringify(c));}
});

test('self affliction feedback follows original direct-client then master fallback routing and message fields',async()=>{
 assert.equal(oracle.selfFeedback.length,12);
 for(const c of oracle.selfFeedback){const calls=[];await displayFloatyToSelf({id:99,masterId:98},c.strref,{client:id=>{calls.push(['client',id]);return id===99&&c.direct?{playerId:77}:id===98&&c.master?{playerId:88}:null;},send:(client,type,data)=>calls.push(['send',client.playerId,type,data])});assert.deepEqual(calls,c.calls,JSON.stringify(c));}
});

test('effect-list affliction poll block matches original exact deadlines, attempted flag and creature gates',async()=>{
 assert.equal(oracle.polls.length,256);
 for(const c of oracle.polls){const calls=[],e=structuredClone(c.initial);await updateAffliction({id:99,objectType:c.objectType},e,c.now,{
  asCreature:o=>o.objectType===5?o:null,compareTime:(a,b)=>{calls.push(['compare',a.day,a.time,b.day,b.time]);return compareWorldTimes(a,b,1000000);},
  poisonPayload:(_o,_e,now)=>calls.push(['poisonPayload',now.day,now.time]),diseasePayload:(_o,_e,now)=>calls.push(['diseasePayload',now.day,now.time]),enqueue:(_o,id,child)=>calls.push(['event',id,child])
 });assert.deepEqual(calls,c.calls,JSON.stringify(c));}
});

