import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {versusEffect} from '../src/versus_effect.js';
import {ModuleSession} from '../src/module_session.js';
import {attackEffectBonus,savingThrowEffectBonus,skillEffectBonus} from '../src/combat_modifiers.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-versus-effect-observations.json',import.meta.url)));

test('versus wrappers match original type dispatch, unsigned alignment gate and active BYTE race count',()=>{
  for(const row of oracle.rows.filter(r=>!r.case.failure)){
    const c=row.case,effect=c.effect?{type:c.type,id:'123456789abcdef0',creatorId:91,spellId:44,integers:Array.from({length:8},(_,i)=>100+i),linkLeft:{type:48,integers:Array(8).fill(7)}}:null,before=structuredClone(effect);
    const result=versusEffect(effect,c.ordinal,c.first,c.second,c.raceCount);
    assert.equal(row.result,0);assert.deepEqual(result?.integers??before?.integers??Array.from({length:8},(_,i)=>100+i),row.integers,JSON.stringify(c));
    assert.deepEqual(effect,before,'VM input survives');
    if(result){assert.notEqual(result,effect);assert.equal(result.id,effect.id);assert.equal(result.creatorId,effect.creatorId);assert.equal(result.spellId,effect.spellId);assert.deepEqual(result.linkLeft,effect.linkLeft);}
  }
});

test('native VM failure evidence includes pop/push failure and the original cleanup boundary',()=>{
  const failures=oracle.rows.filter(r=>r.case.failure);
  for(const row of failures){
    assert.equal(row.result,(-638)>>>0);
    assert.equal(row.calls.some(c=>c[0]==='destroy'),false,'native returns immediately on stack failure');
    assert.equal(row.calls.some(c=>c[0]==='free'),false);
    if(row.case.failure==='effect')assert.deepEqual(row.calls,[['pop-effect']]);
    if(row.case.failure==='int1')assert.deepEqual(row.calls,[['pop-effect'],['pop-int',1]]);
    if(row.case.failure==='int2')assert.deepEqual(row.calls,[['pop-effect'],['pop-int',1],['pop-int',2]]);
  }
  for(const row of oracle.rows.filter(r=>!r.case.failure).slice(-4))assert.equal(row.calls.some(c=>c[0]==='destroy'),row.case.effect);
});

test('canonical script bindings feed the existing conditional attack, save and skill consumers',()=>{
  const s=new ModuleSession(null);s.characterRules={racialtypes:{orderedRows:Array(29)},skills:{orderedRows:Array(28)}};
  const frame={self:91},attack=s.commands.EffectAttackIncrease([3,0],frame),save=s.commands.EffectSavingThrowIncrease([0,2,0],frame),skill=s.skillEffect(55,4,5,91);
  const aligned=e=>s.commands.VersusAlignmentEffect([e,0,5]);
  const evil={race:6,lawChaos:1,goodEvil:5},good={...evil,goodEvil:4};
  assert.equal(attackEffectBonus([aligned(attack)],[],1,{target:evil}).total,3);assert.equal(attackEffectBonus([aligned(attack)],[],1,{target:good}).total,0);
  assert.equal(savingThrowEffectBonus({FeatList:[],ClassList:[]},[aligned(save)],[],1,{target:evil}).total,2);assert.equal(savingThrowEffectBonus({FeatList:[],ClassList:[]},[aligned(save)],[],1,{target:good}).total,0);
  const racial=s.commands.VersusRacialTypeEffect([skill,6]);assert.equal(skillEffectBonus([racial],[],4,{target:evil}).total,5);assert.equal(skillEffectBonus([racial],[],4,{target:{...evil,race:7}}).total,0);
  assert.deepEqual(s.commands.VersusRacialTypeEffect([attack,30]),attack);assert.equal(s.commands.VersusRacialTypeEffect([attack,29]).integers[2],29,'original includes count itself');
  s.characterRules.racialtypes.orderedRows=Array(257);assert.equal(s.commands.VersusRacialTypeEffect([attack,1]).integers[2],1);assert.deepEqual(s.commands.VersusRacialTypeEffect([attack,2]),attack,'count narrows to BYTE');
});
