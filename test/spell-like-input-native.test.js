import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {receiveSpellLikeInput,addSpellTalentOnObject,addSpellTalentAtLocation} from '../src/spell_like_input.js';

test('spell-like decoded input and spell talent wrappers preserve original argument, veto and return behavior',async()=>{
  const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-like-input-observations.json',import.meta.url)));
  function fixture(c){
    const actor={id:99,objectType:5,nativeField8ac:c.field8ac,nativeFieldEc:c.commandable},calls=[];let byte=0,axis=0,overflow=0;
    const p={creature:id=>{calls.push(['creature',id]);return c.targetCreature?{id,objectType:5}:null;},position:()=>[4.25,5.5,6.75],area:()=>{calls.push(['area']);return c.area?{}:null;},
      addCast:(_o,r)=>{calls.push(['cast',r.spellId,r.classIndex,r.domainLevel,r.metamagic,r.spontaneous,r.position,r.targetId,r.location,r.front,r.cheat,r.path,r.instant,0,r.featId,r.casterLevel]);return c.addResult;},
      clientObject:()=>c.actor?actor:null,asCreature:o=>o,stats:()=>c.stats?{}:null,overflow:()=>Number(c.overflow===++overflow),underflow:()=>c.underflow,
      readDword:()=>c.spellId,readByte:()=>byte++===0?c.casterLevel:c.flags,readObjectId:()=>c.targetId,readFloat:()=>[1.25,2.5,3.75][axis++],
      spell:id=>{calls.push(['spell',id]);return c.missingSpell?null:{};},feedback:(_o,id)=>calls.push(['feedback',id]),actionManager:(_o,n)=>calls.push(['manager',n])};
    p.onObject=(...a)=>addSpellTalentOnObject(...a,p);p.atLocation=(...a)=>addSpellTalentAtLocation(...a,p);return{actor,p,calls};
  }
  for(const {case:c,calls}of oracle.rows){const f=fixture(c);assert.equal(await receiveSpellLikeInput(null,f.p),0);assert.deepEqual(f.calls,calls,JSON.stringify(c));}
  for(const {case:c,wrapper,calls,result}of oracle.wrappers){
    const f=fixture(c),actual=wrapper==='object'?await addSpellTalentOnObject(f.actor,c.spellId,c.targetId,254,c.casterLevel,0,f.p):await addSpellTalentAtLocation(f.actor,c.spellId,[1.25,2.5,3.75],254,c.casterLevel,0,f.p);
    assert.equal(actual,result,JSON.stringify({c,wrapper}));assert.deepEqual(f.calls,calls,JSON.stringify({c,wrapper}));
  }
});
