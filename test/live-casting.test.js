import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {receiveSpellInput} from '../src/spell_input.js';
import {castSpellAndImpact} from '../src/spell_cast_impact.js';
import {ModuleSession} from '../src/module_session.js';
import {parse2da} from '../src/area.js';
import {checkSpellComponents} from '../src/spell_components.js';
import {broadcastOrdinarySpellCast} from '../src/spell_cast_broadcast.js';
import {createObjectAction} from '../src/object_actions.js';
import {createCombatRound} from '../src/combat_round.js';
const invalid=0x7f000000;
test('ordinary impact dispatch matches untouched original event ownership, delay and once guard',async()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-cast-impact-dispatch-observations.json',import.meta.url)));
 for(const row of oracle.rows){
  const c=row.case,calls=[],o={id:99,objectType:5,areaId:88,nativeSpellImpact224:c.done??0,nativeSpellFeat23c:65535,nativeSpellProjectileTime220:c.delay??150},spell={id:1,impactScript:'impact',hasProjectile:0};
  o.nativeCounterspellers310=[...(c.counters??[]),...Array(10).fill(invalid)].slice(0,10);o.nativeCounterCount338=c.count??c.counters?.length??0;
  await castSpellAndImpact(o,1,[1.25,-2,3],c.target??100,0,invalid,c.countered??0,0,0,c.instant??0,{spell:id=>c.missing?null:id===1?spell:{id:9},
   creature:id=>id===101&&!c.counterMissing?{id:101,nativeCounterSpell7fc:9}:null,spellName:id=>id===1?101:202,
   counterBroadcast:(_o,_spell,data)=>calls.push(['counterBroadcast',{objects:Object.fromEntries(data.objects.map((v,i)=>[String(i),v])),integers:Object.fromEntries(data.integers.map((v,i)=>[String(i),v]))}]),
   area:()=>({id:88}),broadcast:()=>calls.push(['broadcast']),enqueue:(id,caller,target,delay,data)=>{const {script,...payload}=data;assert.equal(script,'impact');calls.push(['event',id,delay,caller,target,payload]);}});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(o.nativeSpellImpact224,row.impact);
 }
});
test('player cast input validates active master metamagic and uses before ActionManager and shared queue',async()=>{
 const actor={id:99,objectType:5},spell={master:2,targetType:43,metamagic:255},master={metamagic:16},calls=[],request={spellId:1,classIndex:2,metamagic:16,targetType:43,targetId:99,position:[1,2,3]},p={spell:id=>id===1?spell:master,uses:()=>1,
  actionManager:(o,n)=>calls.push(['manager',o.id,n]),addCast:(o,r)=>{calls.push(['cast',o.id,r]);r.position[0]=77;return 1;},feedback:(_o,n)=>calls.push(['feedback',n])};
 assert.equal(await receiveSpellInput(actor,request,p),1);assert.deepEqual(calls[0],['manager',99,1]);assert.equal(calls[1][2].classIndex,2);assert.equal(request.position[0],1);
 calls.length=0;assert.equal(await receiveSpellInput(actor,{...request,metamagic:32},p),0);assert.deepEqual(calls,[['feedback',22]]);
 calls.length=0;assert.equal(await receiveSpellInput(actor,request,{...p,uses:()=>0}),0);assert.deepEqual(calls,[['feedback',22]]);
 calls.length=0;assert.equal(await receiveSpellInput(actor,{...request,targetType:1},p),0);assert.deepEqual(calls,[['feedback',22]]);
 calls.length=0;assert.equal(await receiveSpellInput(actor,{...request,spontaneous:1},{...p,classAllowsConversion:()=>false}),0);assert.deepEqual(calls,[['feedback',22]]);
});
test('serialized spell clicks retain actor, area and copied position and reject stale ownership',async()=>{
 const s=new ModuleSession(null,{runStartupScripts:false});s.characterRules={spells:parse2da('2DA V2.0\n\nTargetType\n0 43')};
 const area=s.register('area','area',{resRef:'test'}),o=s.register('player','player',{areaId:area.id,authored:{},stats:{}});s.player=o;
 let received;s.spells.input=async r=>{received=r;return 1;};const position=[1,2,3],promise=s.queuePlayerCastSpell({spellId:0,classIndex:0,position});position[0]=50;await s.drainPlayerInputs();assert.equal(await promise,1);assert.deepEqual(received.position,[1,2,3]);assert.equal(received.targetType,43);
 received=null;const stale=s.queuePlayerCastSpell({spellId:0,classIndex:0});o.areaId=invalid;await s.drainPlayerInputs();assert.equal(await stale,0);assert.equal(received,null);
 const changed=s.queuePlayerCastSpell({spellId:0,classIndex:0});s.player=null;await s.drainPlayerInputs();assert.equal(await changed,0);assert.equal(received,null);
});
test('real VS component strings use exact lowercase native s/v searches',()=>{
 const o={nativeField8d4:0},p={spell:()=>({metamagic:63}),hasFeat:()=>0},spell={master:0,userType:0,components:'vs'};
 assert.equal(checkSpellComponents(o,spell,0,0,0,{},p).feedback,210);
 o.nativeField8d4=4;assert.equal(checkSpellComponents(o,spell,0,0,0,{},p).feedback,211);
 assert.equal(checkSpellComponents(o,{...spell,components:'VS'},0,0,0,{},p).accepted,true,'Uppercase is not a native component');
});
test('ordinary spellcraft broadcasts draw for each visible nearby NPC/client in spatial order',async()=>{
 const rules={spells:parse2da('2DA V2.0\n\nSchool AltMessage\n0 A 0'),classes:parse2da('2DA V2.0\n\nPickSchool\n0 0')},caster={id:99,areaId:88,position:[0,0,0]},viewers=new Map([[99,{...caster,authored:{ClassList:[]}}],[100,{id:100,position:[1,0,0],authored:{ClassList:[]}}],[101,{id:101,position:[100,0,0],authored:{ClassList:[]}}]]),calls=[];
 await broadcastOrdinarySpellCast(caster,{id:0,userType:1,innate:1},rules,{area:()=>({id:88}),ids:()=>[99,100,101],range:60,creature:id=>viewers.get(id),visibility:()=>3,
  skill:async(o)=>{calls.push(['skill',o.id]);return 0;},roll:()=>{calls.push(['roll']);return 1;},client:id=>id===99?{id}:null,send:(_client,type,data)=>calls.push(['send',type,data.integers[1]])});
 assert.deepEqual(calls,[['skill',99],['roll'],['send',8,1],['skill',100],['roll']]);assert.deepEqual(caster.nativeSpellIdentified808,[99]);
});
test('ordinary cast cancellation follows release flag and preserves consumed uses',async()=>{
 const s=new ModuleSession(null,{runStartupScripts:false}),o=s.register('creature','caster',{authored:{},stats:{}}),node=createObjectAction(15,7);
 o.combatRound=createCombatRound();
 s.combat.processPending=async()=>{};o.nativeField81c=1;o.spellActionTargetId=22;o.nativeTarget740=22;o.objectActionState.startDay=4;o.objectActionState.startTime=5;
 assert.equal(await s.spells.clear(o,node,1),1);assert.equal(o.nativeField81c,0);assert.equal(o.spellActionTargetId,invalid);assert.equal(o.objectActionState.startTime,0);
 node.nativeField9c=0;o.nativeField81c=1;assert.equal(await s.spells.clear(o,node,1),0);assert.equal(o.nativeField81c,1);
});
