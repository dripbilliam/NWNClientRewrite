import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {requestRest,executeRest,cancelRest,receiveRestInput} from '../src/rest.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=()=>JSON.parse(fs.readFileSync(new URL('../backups/animations/native-rest-observations.json',import.meta.url)));
const fields={healInterval:'nativeRestHealInterval854',missingHP:'nativeRestMissingHP858',spellInterval:'nativeRestSpellInterval85c',spellCursor:'nativeRestSpellCursor860',startDay:'nativeRestStartDayAd8',startTime:'nativeRestStartTimeAdc',enemyDay:'nativeRestEnemyDay558',enemyTime:'nativeRestEnemyTime55c',hp:'hp',activities:'activities'};
function fixture(c,which){
 const calls=[],o={id:10,nativeField89c:c.pc??1,associateType:c.associateType??0,masterId:c.masterId??0x7f000000,excitedDuration:c.excited??0,lockedActivities:c.locks??0},node={parameterData:[c.player??1,c.started??0]};
 for(const [key,field]of Object.entries(fields))o[field]=c[key]??(key==='hp'?5:key==='activities'?16:0);
 const associates=(c.associates??[]).map((type,i)=>({id:20+i,associateType:type,masterId:10})),effects=(c.effects??[1,5,35,67]).map((type,i)=>({type,id:i+1}));
 const p={dead:()=>{calls.push(['dead']);return c.dead??0;},dying:()=>{calls.push(['dying']);return c.dying??0;},possessed:()=>{calls.push(['possessed']);return c.possessed??0;},
  area:()=>{calls.push(['area']);return c.missingArea?null:{};},noRest:()=>c.noRest??0,
  creature:id=>{calls.push(['creature',id]);return c.missingCreature?null:associates.find(a=>a.id===id)??{id:0,associateType:0,masterId:0};},
  enemyRadius:()=>{calls.push(['radius']);return c.radius??30;},nearestEnemy:(actor,radius,excluded,seen,clear)=>{calls.push(['enemy',actor.id,radius,excluded,seen>>>0,clear]);return c.enemy??0x7f000000;},
  clearActions:()=>calls.push(['clearActions']),feedback:(_o,code)=>calls.push(['feedback',code]),
  activity:(actor,mask,v)=>{calls.push(['activity',mask,v]);if((actor.lockedActivities&mask)!==mask)actor.activities=v===1?actor.activities|mask:actor.activities&~mask;},
  actionManager:(_o,n)=>calls.push(['actionManager',n]),activityManager:(_o,n)=>calls.push(['activityManager',n]),
  restEvent:(_o,n)=>calls.push(['restEvent',n]),runRestScript:(_o,n)=>calls.push(['runRestScript',n]),
  queue:(_o,id,group,params)=>calls.push(['queue',id,group,params[0].type,params[0].value,params[1].type,params[1].value]),
  client:()=>c.missingClient?null:{},time:()=>({day:c.day??1,time:c.time??10000}),effects:()=>effects,
  clearEffectsOnOthers:()=>calls.push(['clearEffectsOnOthers']),poison:(_o,e)=>calls.push(['poison',e.id]),removeLater:(_o,e)=>calls.push(['removeLater',e.id]),disease:(_o,e)=>calls.push(['disease',e.id]),
  duration:()=>{calls.push(['duration']);return c.duration??10000;},startTiming:(_o,...args)=>calls.push(['startTiming',...args]),
  stopTiming:()=>{if(which==='cancel'&&(c.missingClient||c.missingMessage))return;calls.push(['stopTiming']);},
  associates:()=>associates.map(a=>a.id),rest:(a,...args)=>calls.push(['rest',a.id,...args]),removeDomination:a=>calls.push(['removeDomination',a.id]),deleteCurrent:a=>calls.push(['deleteCurrent',a.id]),
  animation:(a,n)=>calls.push(['animation',a.id,n]),cancel:(_o,n)=>calls.push(['cancel',n]),subtract:(a,b)=>({status:0,day:0,time:(a.time-b.time)>>>0}),
  maxHP:()=>c.maxHP??20,currentHP:actor=>actor.hp,writeHP:(actor,n)=>{actor.hp=n;},highestSpellLevel:()=>{calls.push(['highest']);return c.highest??4;},
  readyLevel:(_o,n)=>calls.push(['readyLevel',n]),removeBadEffects:()=>calls.push(['removeBadEffects']),restoreItems:()=>calls.push(['restoreItems']),resetFeats:()=>calls.push(['resetFeats']),resetAbilities:()=>calls.push(['resetAbilities']),encumbrance:(_o,n)=>calls.push(['encumbrance',n])};
 return{o,node,p,calls,state:()=>Object.fromEntries(Object.entries(fields).map(([key,field])=>[key,o[field]>>>0]))};
}
for(const [key,owner]of [['request',requestRest],['execute',executeRest],['cancel',cancelRest]])test(`original full rest ${key} matches ordered owners, timers, raw started value and return state`,async()=>{
 for(const row of oracle()[key]){const c=row.case,f=fixture(c,key),result=key==='request'?await owner(f.o,c.associate??0,c.seen??0,f.p):key==='cancel'?await owner(f.o,c.reason??20,f.p):await owner(f.o,f.node,f.p);
  assert.deepEqual(f.calls,row.calls,JSON.stringify(c));assert.deepEqual(f.state(),row.state,JSON.stringify(c));assert.equal(f.node.parameterData[1],row.started,JSON.stringify(c));if(key==='execute')assert.equal(result,row.result,JSON.stringify(c));
 }
});
test('original rest input13 uses control/veto/overflow/commandability/activity admission and no underflow read',async()=>{
 for(const row of oracle().input){const c=row.case,calls=[],actor={id:10,nativeField8ac:c.field8ac,commandable:c.commandable,activities:c.activities};
  const result=await receiveRestInput(null,{clientObject:()=>{calls.push(['clientObject']);return c.missingObject?null:actor;},asCreature:()=>{calls.push(['asCreature']);return c.wrongType?null:actor;},overflow:()=>{calls.push(['overflow',c.overflow]);return c.overflow;},
   feedback:(_o,n)=>calls.push(['feedback',n]),activityState:(o,mask)=>{calls.push(['activityState',mask]);return Number((o.activities&mask)!==0);},rest:(o,...args)=>calls.push(['rest',o.id,...args])});
  assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
test('queued rest cannot cross controlled actor, area, or session changes',async()=>{
 for(const change of ['control','area','cancel']){const s=new ModuleSession(null),actor=s.register('creature','actor',{}),other=s.register('creature','other',{});s.player=actor;actor.areaId=1;s.rest.input=()=>assert.fail('Stale rest reached authority');const p=s.queuePlayerRest();if(change==='control')s.player=other;else if(change==='area')actor.areaId=2;else s.cancelPendingPlayerInputs();await s.drainPlayerInputs();assert.equal(await p,0);assert.equal(actor.activities&16,0);}
});
