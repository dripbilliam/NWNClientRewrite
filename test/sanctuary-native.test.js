import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {sanctuaryEffect,applySanctuary,removeSanctuary} from '../src/sanctuary_effect.js';
import {pacifyCreature} from '../src/combat_pacify.js';
import {removeCombatInvisibility} from '../src/combat_broadcast.js';
import {setCreatureCombatState} from '../src/combat_lifecycle.js';
import {createCombatRound} from '../src/combat_round.js';
import {ModuleSession} from '../src/module_session.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-sanctuary-observations.json',import.meta.url))),hex=v=>v.toString(16).padStart(16,'0');
const snapshot=e=>({id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,creatorId:e.creatorId,spellId:e.spellId,casterLevel:e.casterLevel,showIcon:e.showIcon,exposed:Number(e.exposed),integers:e.integers});

test('sanctuary constructor matches native raw DC/save flag, optional arity, invalid and VM failure cases',()=>{
 for(const row of oracle.rows.filter(r=>r.case.mode==='construct')){
  const c=row.case,failed=c.failPop===1||c.argc>1&&c.failPop===2;
  if(failed){assert.equal(row.result,0xfffffd81);assert.equal(row.output,null);continue;}
  const s=new ModuleSession(null),effect=sanctuaryEffect(c.dc,c.argc>1?c.versus:1,99,{create:(...a)=>s.effects.create(...a),invalid:()=>s.effects.invalid()});
  assert.deepEqual({...snapshot(effect),id:hex(100)},row.output,JSON.stringify(c));assert.equal(row.result,c.push===0?0xfffffd82:0);
 }
});

test('sanctuary apply/remove match original observer flags, BYTE initial DC, source-ID stacking, dead/loading and icon copy',async()=>{
 const s=new ModuleSession(null);
 for(const row of oracle.rows.filter(r=>['apply','remove'].includes(r.case.mode))){
  const c=row.case,calls=[],actor={id:99,objectType:c.objectType??5},objects=new Map([[99,actor],[100,{id:100}],[101,{id:101}]]),nodes=new Map([99,100,101].map(id=>[id,{flags:c.nodes?.[id]??0}]));
  const effect={...s.effects.create(63),id:hex(77),creatorId:98,spellId:11,casterLevel:7,subtype:8,durationType:c.durationType??2,exposed:true,showIcon:c.showIcon??1};effect.integers=[8,28,0,0,c.dc??17,c.versus??1,0,0];
  actor.effects=(c.effects??[]).map(e=>({type:e.type,id:hex(e.id??77)}));
  const p={dead:()=>{calls.push(['dead']);return c.dead??0;},asCreature:o=>o.objectType===5?o:null,area:()=>{calls.push(['area']);return c.area===false?null:{};},areaIds:()=>c.areaIds??[100,101,99,999],
   creature:id=>{calls.push(['creature',id]);return id===101&&c.missing?null:objects.get(id);},visibility:(o,id)=>{calls.push(['node',o.id,id]);return c.nodes?.[o.id]===undefined||c.nodes[o.id]===null?null:nodes.get(o.id);},
   save:(o,...args)=>{calls.push(['save',o.id,...args]);return c.save??0;},pacify:(o,id)=>calls.push(['pacify',o.id,id]),addInvisible:id=>calls.push(['addInvisible',id]),
   copyConstruct:(e,n)=>s.effects.copyConstruct(e,n),apply:(_o,e,n)=>calls.push(['apply',snapshot(e),n]),index:()=>{const n=actor.effects.findIndex(e=>e.type>=47);return n<0?actor.effects.length:n;},effects:()=>actor.effects,
   removeInvisible:id=>calls.push(['removeInvisible',id]),removeVisibility:(o,id)=>calls.push(['removeNode',o.id,id])};
  const result=await(c.mode==='apply'?applySanctuary(actor,effect,p,c.loading??0):removeSanctuary(actor,effect,p));
  const label=JSON.stringify(c);assert.equal(result,row.result,label);assert.deepEqual(calls,row.calls,label);assert.deepEqual(Object.fromEntries([...nodes].map(([id,n])=>[id,n.flags])),row.nodes,label);
 }
});

test('targeted pacification matches original five target gates, round clearing and forced hostile/action cleanup',async()=>{
 const fields={0x728:'attackActionTargetId',0x724:'nativeAttackTarget724',0x73c:'spellActionTargetId',0x740:'nativeTarget740',0x190:'lastHostileActorId'};
 for(const row of oracle.rows.filter(r=>r.case.mode==='pacify')){
  const c=row.case,calls=[],actor={id:99},target={id:100,nativeField700:2,nativeField704:8000,nativeField744:17,initiativePending:0,combatRound:c.round?createCombatRound():null};
  for(const [field,name]of Object.entries(fields))target[name]=c.targets.includes(Number(field))?99:OBJECT_INVALID;
  await pacifyCreature(actor,c.id,{creature:id=>{calls.push(['creature',id]);return id===100?target:null;},combatState:(o,state)=>{setCreatureCombatState(o,state);if(o.combatRound)calls.push(['roundActions'],['roundAttacks']);},lastHostile:(o,id,force)=>{calls.push(['lastHostile',o.id,id,force]);o.lastHostileActorId=id;},clearHostile:(o,t)=>calls.push(['clearHostile',o.id,t.id])});
  const actual={'0x700':target.nativeField700,'0x704':target.nativeField704,'0x744':target.nativeField744,'0x6fc':target.initiativePending,'0x724':target.nativeAttackTarget724,'0x190':target.lastHostileActorId};
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(actual,row.target,JSON.stringify(c));
 }
});

test('combat invisibility removal matches original linked-ID erasure and re-queried native effect index',async()=>{
 for(const row of oracle.rows.filter(r=>r.case.mode==='combatRemove')){
  const c=row.case,calls=[],actor={effects:c.effects.map(e=>({id:hex(e.id??77),type:e.type,kind:e.kind??1}))};let index=c.index;
  await removeCombatInvisibility(actor,{effects:o=>o.effects,index:()=>index,integer:e=>e.kind,remove:(o,e)=>{calls.push(['removeId',e.id]);o.effects=o.effects.filter(other=>other.id!==e.id);const n=o.effects.findIndex(e=>e.type>=47);index=n<0?o.effects.length:n;}});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(actor.effects,row.effects,JSON.stringify(c));
 }
 assert.equal(oracle.rows.length,1545);assert.equal(oracle.copies,743);
});

test('live combat removal erases invisibility and linked icon, preserving other sources and canonical IDs',async()=>{
 const s=new ModuleSession(null);s.module=s.register('module','module',{nativeInvisibleCreatureIds330:[]});
 const actor=s.register('creature','subject',{}),cursor=s.registry.nextObjectId[0],effect=s.commands.EffectInvisibility([1],{self:actor.id});
 await s.effects.apply(2,effect,actor.id);assert.equal(actor.effects.filter(e=>e.id===effect.id).length,2);assert.deepEqual(s.module.nativeInvisibleCreatureIds330,[actor.id]);
 const improved=s.commands.EffectInvisibility([2],{self:actor.id});await s.effects.apply(2,improved,actor.id);
 await s.combat.removeInvisibility(actor);assert.ok(actor.effects.every(e=>e.id!==effect.id));assert.ok(actor.effects.some(e=>e.id===improved.id));assert.deepEqual(s.module.nativeInvisibleCreatureIds330,[actor.id]);
 await s.effects.remove(actor.id,improved.id);assert.deepEqual(actor.effects,[]);assert.deepEqual(s.module.nativeInvisibleCreatureIds330,[]);assert.equal(s.registry.nextObjectId[0],cursor);
});

test('stacked live sanctuaries retain observer nodes and shared icon until the final source leaves',async()=>{
 const s=new ModuleSession(null);s.module=s.register('module','module',{nativeInvisibleCreatureIds330:[]});const area=s.register('area','area',{}),actor=s.register('creature','subject',{areaId:area.id}),observer=s.register('creature','observer',{areaId:area.id});area.objects=[actor.id,observer.id];observer.perception.set(actor.id,1);observer.attackActionTargetId=actor.id;
 const a=s.commands.EffectSanctuary([17,0],{self:actor.id}),b=s.commands.EffectSanctuary([17,0],{self:actor.id}),cursor=s.registry.nextObjectId[0];await s.effects.apply(2,a,actor.id);await s.effects.apply(2,b,actor.id);
 assert.equal(observer.perception.get(actor.id)&12,4);assert.equal(observer.nativeField700,0);assert.deepEqual(s.module.nativeInvisibleCreatureIds330,[actor.id]);assert.equal(actor.nativeEffectIcons778.records.filter(i=>i.iconId===107).length,1);
 await s.effects.remove(actor.id,a.id);assert.equal(observer.perception.get(actor.id)&12,4);assert.deepEqual(s.module.nativeInvisibleCreatureIds330,[actor.id]);assert.ok(actor.nativeEffectIcons778.records.some(i=>i.iconId===107));
 await s.effects.remove(actor.id,b.id);assert.equal(observer.perception.get(actor.id),undefined);assert.deepEqual(s.module.nativeInvisibleCreatureIds330,[]);assert.deepEqual(actor.nativeEffectIcons778.records,[]);assert.equal(s.registry.nextObjectId[0],cursor);
});
