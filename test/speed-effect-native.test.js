import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applySpeedEffect,removeSpeedEffect,applyAttackCountEffect,removeAttackCountEffect} from '../src/speed_effect.js';
import {setNativeMovementFactor} from '../src/movement_rate.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-speed-effect-observations.json',import.meta.url)));

test('Speed modifiers, attack-count flag and factor setter match original instructions',async()=>{
  for(const row of oracle.rows){const c=row.case,calls=[],actor={id:99,objectType:c.objectType??5,nativeField76c:0,nativeMovementFactor8e8:0,
    authored:{ClassList:(c.classes??[]).map(([Class,ClassLevel])=>({Class,ClassLevel}))}},
    effect={id:'000000000000004d',type:c.type??28,creatorId:98,durationType:c.durationType??2,bypassImmunity:c.bypass??0,integers:Array(8).fill(0)};
    effect.integers[0]=c.amount??50;
    const effects=(c.effects??[]).map((e,i)=>e.samePointer?effect:{type:e.type,id:BigInt(e.id??10+i).toString(16).padStart(16,'0'),integers:[e.amount??0]});
    const p={dead:()=>c.dead??0,creature:()=>c.sourceExists===false?null:{id:98},immunity:(_o,id)=>{calls.push(['immunity',id]);return c.immune??0;},
      plot:()=>c.plot??0,effects:()=>effects,setFactor:(_o,value)=>calls.push(['factor',value]),copy:e=>structuredClone(e),apply:(_o,e,loading)=>calls.push(['icon',e.integers[0],loading])};
    let result;
    if(c.mode==='setter'){
      setNativeMovementFactor(actor,c.value,{ruleset:{orderedRows:Object.entries(c.rulesOverrides??{}).map(([Label,Value])=>({Label,Value:String(Value)}))}});result=null;
    }else if(c.mode==='apply')result=await(c.type===59?applyAttackCountEffect:applySpeedEffect)(actor,effect,p,c.loading??0);
    else result=(c.type===59?removeAttackCountEffect:removeSpeedEffect)(actor,effect,p);
    assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
    assert.equal(effect.integers[0],row.amount,JSON.stringify(c));assert.equal(actor.nativeField76c,row.field76c,JSON.stringify(c));
    assert.equal(actor.nativeMovementFactor8e8,row.factor,JSON.stringify(c));
  }
});
