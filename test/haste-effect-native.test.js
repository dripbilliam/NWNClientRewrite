import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applyHasteOrSlow,removeHasteOrSlow,applyHasteController,removeHasteController} from '../src/haste_effect.js';
import {ModuleSession} from '../src/module_session.js';
import {parse2da} from '../src/area.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-haste-effect-observations-v2.json',import.meta.url)));
const project=e=>({id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,spellId:e.spellId,creatorId:e.creatorId,casterLevel:e.casterLevel,showIcon:e.showIcon,exposed:Number(e.exposed),integers:e.integers});
test('Haste/Slow balance and hidden controller fields, ordering and active rule overrides match original instructions',async()=>{
  for(const row of oracle.rows){const c=row.case,calls=[],actor={id:99,objectType:c.objectType??5,nativeHaste760:c.hasted??0,nativeSlow764:c.slowed??0},
    effect={id:'000000000000004d',type:c.type,subtype:8,durationType:c.durationType??2,spellId:11,creatorId:98,casterLevel:7,showIcon:c.showIcon??1,exposed:true,integers:Array(8).fill(0),bypassImmunity:c.bypass??0};let ids=100;
    const p={effects:()=> (c.effects??[]).map((type,i)=>({type,id:BigInt(10+i).toString(16).padStart(16,'0')})),dead:()=>c.dead??0,creature:()=>c.sourceExists===false?null:{id:98},
      immunity:(_o,id)=>{calls.push(['immunity',id]);return c.immune??0;},feedback:(o,code,data)=>calls.push(['feedback',o.id,code,data]),remove:(_o,e)=>calls.push(['remove',e.id]),
      create:(type,creatorId,integers,subtype)=>({type,creatorId,integers:Array(8).fill(0),subtype,durationType:0,spellId:-1,casterLevel:-1,showIcon:1,exposed:true,id:BigInt(++ids).toString(16).padStart(16,'0')}),
      copyConstruct:(e,icons)=>({...structuredClone(e),integers:Array(e.integers.length).fill(0),exposed:false,showIcon:icons?e.showIcon:0}),
      apply:(_o,e,loading)=>calls.push(['apply',project(e),loading,actor.nativeHaste760,actor.nativeSlow764])};
    const rules={ruleset:{orderedRows:Object.entries(c.rulesOverrides??{}).map(([Label,Value])=>({Label,Value:String(Value)}))}};
    let result;
    if(c.mode==='apply')result=await applyHasteOrSlow(actor,effect,p,c.loading??0);
    else if(c.mode==='remove')result=await removeHasteOrSlow(actor,effect,p);
    else if(c.mode==='controller')result=await applyHasteController(actor,effect,rules,p,c.loading??0);
    else result=removeHasteController(actor,effect);
    assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
    assert.equal(actor.nativeHaste760,row.hasted,JSON.stringify(c));assert.equal(actor.nativeSlow764,row.slowed,JSON.stringify(c));
  }
});

test('live Haste and Slow cancel controllers, restore remaining balance and expire without orphan bonuses',async()=>{
  const table=(columns,rows)=>parse2da(`2DA V2.0\n\n${columns}\n${rows}`),s=new ModuleSession(null);
  s.characterRules={racialtypes:table('StrAdjust','0 0'),classes:table('AttackBonusTable SavingThrowTable','0 bab saves'),
    classTables:new Map([['bab',table('BAB','0 1')],['saves',table('FortSave RefSave WillSave','0 0 0 0')]]),
    gains:new Map(),ruleset:table('Label Value','0 **** ****'),exptable:table('XP','0 0'),epicattacks:table('BAB','0 0'),epicsaves:table('FortSave RefSave WillSave','0 0 0 0')};
  const actor=s.register('creature','target',{authored:{ClassList:[{Class:0,ClassLevel:1}],LvlStatList:[{LvlStatClass:0,LvlStatHitDie:10}],HitPoints:10,CurrentHitPoints:10,Race:0,FeatList:[],Str:10,Dex:10,Con:10,Int:10,Wis:10,Cha:10},
    stats:{currentHP:10,feats:[],combat:{saves:{}}},acCache:{up:Array(7).fill(0),down:Array(7).fill(0)}}),frame={self:actor.id};
  // Capture the separate full-stat refresh owner. This test checks live
  // controller ownership/caches, rather than asserting its unported tail.
  const refreshes=[];s.refreshCombat=o=>refreshes.push(o.id);
  const haste=s.commands.EffectHaste([],frame),second=s.commands.EffectHaste([],frame),slow=s.commands.EffectSlow([],frame);
  await s.effects.apply(1,haste,actor.id,1);await s.effects.apply(2,second,actor.id);
  assert.equal(actor.hasted,1);assert.equal(actor.slowed,0);assert.equal(actor.nativeMovementFactor8e8,1.5);assert.equal(actor.acCache.up[0],4);
  assert.equal(actor.effects.filter(e=>e.type===41).length,1);assert.ok(actor.effects.filter(e=>e.type===41||e.type===28).every(e=>e.durationType===4&&!e.exposed));
  await s.effects.apply(2,slow,actor.id);assert.equal(actor.hasted,1,'two Haste sources outweigh one Slow');
  s.scheduler.time=1001;s.worldTimer.snapshot();await s.effects.updateObject(actor);
  assert.equal(actor.hasted,0);assert.equal(actor.slowed,0);assert.equal(actor.nativeMovementFactor8e8,1);assert.equal(actor.acCache.up[0],0);
  await s.effects.remove(actor.id,second.id);
  assert.equal(actor.slowed,1);assert.equal(actor.nativeMovementFactor8e8,.5);assert.equal(actor.nativeField76c,1);assert.equal(actor.acCache.down[0],2);
  assert.ok(actor.effects.some(e=>e.type===42&&e.spellId===-1));
  await s.effects.remove(actor.id,slow.id);
  assert.equal(actor.effects.length,0);assert.equal(actor.hasted,0);assert.equal(actor.slowed,0);assert.equal(actor.nativeField76c,0);
  assert.equal(actor.nativeMovementFactor8e8,1);assert.equal(actor.acCache.down[0],0);assert.equal(actor.nativeEffectIcons778.records.length,0);
  assert.ok(refreshes.length>0);
});
