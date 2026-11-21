import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {spellFailureEffect,missChanceEffect,applySpellFailure,removeSpellFailure} from '../src/spell_failure_effect.js';
import {ModuleSession} from '../src/module_session.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-failure-effects-observations.json',import.meta.url)));
const snapshot=e=>({id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,creatorId:e.creatorId,spellId:e.spellId,casterLevel:e.casterLevel,exposed:Number(e.exposed),showIcon:e.showIcon,integers:e.integers});
test('school/arcane failure effects match original constructors, caches, IDs versus pointers and ordered calls',async()=>{
  assert.equal(data.rows.length,1255);assert.equal(data.copyConstructorExecutions,194);
  for(const row of data.rows){const c=row.case,s=new ModuleSession(null),calls=[],actor={nativeEncumbranceDirty53c:0,nativeArcaneEffectD78:(c.cache??0)&255,nativeSpellFailuresD7b:Array.from({length:9},(_,i)=>9+i),effects:[]};let output=null,result=0;
    const mode=c.mode;
    if(['constructor','miss'].includes(mode)){
      const count=mode==='constructor'?((c.argc??3)>2?3:2):((c.argc??2)>1?2:1);for(let n=1;n<=count;n++){calls.push(['pop']);if(c.failPop===n){result=-639;break;}}
      if(result===0){const p={create:(...a)=>{calls.push(['creator',98]);return s.effects.create(...a);},invalid:()=>s.effects.invalid()},e=mode==='constructor'?spellFailureEffect([c.amount??50,c.school??0,...((c.argc??3)>2?[c.kind??0]:[])],98,p):missChanceEffect(c.amount??50,(c.argc??2)>1?c.kind??0:0,98,p);e.id='0000000000000065';output=snapshot(e);calls.push(['push']);if(c.push===0)result=-638;}
    }else{
      const e=s.effects.create(c.type??92,98,[c.amount??50,c.school??0],8);Object.assign(e,{id:'000000000000004d',durationType:c.durationType??2,spellId:11,casterLevel:7,showIcon:c.showIcon??1});
      actor.effects=(c.effects??[]).map(v=>v.samePointer?e:{id:(v.id??88).toString(16).padStart(16,'0'),type:v.type,integers:[v.amount??0,v.school??0]});
      const p={dead:()=>{calls.push(['dead']);return c.dead??0;},asCreature:()=>{calls.push(['creature']);return c.creature===false?null:actor;},effects:o=>o.effects,
        copyConstruct:(...a)=>s.effects.copyConstruct(...a),apply:(o,e,l)=>calls.push(['apply',snapshot(e),l]),updateCombat:()=>calls.push(['updateCombat'])};
      result=mode==='apply'?await applySpellFailure(actor,c.nullEffect?null:e,p,c.loading??0):await removeSpellFailure(actor,c.nullEffect?null:e,p,c.type===25);
    }
    assert.deepEqual({result,calls,output,arcane:actor.nativeArcaneEffectD78,schools:actor.nativeSpellFailuresD7b,dirty:actor.nativeEncumbranceDirty53c},{result:row.result,calls:row.calls,output:row.output,arcane:row.arcane,schools:row.schools,dirty:row.dirty},JSON.stringify(c));
  }
});
