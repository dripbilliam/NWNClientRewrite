import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {spellResistance,resistSpell,spellAbsorption,spellImmunity} from '../src/spell_resistance.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-resistance-observations.json',import.meta.url)));
const rulesFor=overrides=>({ruleset:{orderedRows:Object.entries(overrides??{}).map(([Label,Value])=>({Label,Value:String(Value)}))}});
test('resistance wrapper, signed caches and absorption/immunity match untouched native owners',async()=>{
  for(const row of oracle.rows){
    const c=row.case,calls=[],caster={id:99,objectType:c.casterType??5,nativeCasterLevel344:c.aoeLevel??5,nativeSpellId218:1,nativeSpellClass22c:0,nativeSpellFeat23c:c.feat??65535,nativeCasterOverride820:c.override??0,nativeCasterOverride824:c.overrideLevel??7},
      target={id:100,objectType:c.targetType??5,effects:structuredClone(c.effects??[]).map((e,i)=>({...e,id:i+1}))},aoe={id:101,objectType:11,nativeCasterLevel344:c.aoeLevel??5,nativeSpellClass22c:0},
      spell={id:1,innate:c.innate??1,userType:c.userType??1,school:c.school??1,master:1},rules=rulesFor(c.rulesOverrides);
    const p={object:id=>id===99?c.casterExists===false?null:caster:id===100?c.targetExists===false?null:target:id===101&&c.selfAoE?aoe:null,
      spell:id=>c.spellExists===false||id===2&&c.aoeSpellMissing?null:{...spell,id},effectSpell:()=>2,
      casterLevel:o=>{calls.push(['level',o.id]);return c.casterLevel??3;},hasFeat:(_o,id)=>(c.feats??[]).includes(id)?c.featResult??1:0,
      absorption:()=>{calls.push(['absorption']);return c.absorption??-1;},immunity:()=>{calls.push(['immunity']);return c.immunity??-1;},
      resistance:()=>{calls.push(['resistance']);return c.resistance??10;},dice:(...args)=>{calls.push(['dice',...args]);return c.roll??10;},
      client:id=>c.clients===false?null:{id},send:(client,type,data)=>calls.push(['send',client.id,type,data]),
      classes:()=> (c.classes??[]).map(([Class,ClassLevel])=>({Class,ClassLevel})),classType:()=>c.classType??10,level:()=>c.level??1,effects:o=>o.effects,
      remove:(o,e)=>{calls.push(['remove',e.id]);o.effects=[];},feedback:(o,code,data)=>calls.push(['feedback',o.id,code,data])};
    let result;
    if(c.mode==='resist')result=await resistSpell(99,100,c.selfAoE?101:99,rules,p);
    else if(c.mode==='stats')result=spellResistance({nativeSpellResistanceIncreaseD84:c.increase??0,nativeSpellResistanceDecreaseD85:c.decrease??0},rules,p);
    else result=await(c.mode==='absorption'?spellAbsorption:spellImmunity)(target,caster,c.selfAoE?aoe:null,p);
    assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
    assert.deepEqual(target.effects.map(({type,integers})=>({type,integers})),row.effects,JSON.stringify(c));
  }
});
