import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {receiveCreatureSpellImpact} from '../src/spell_impact.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-impact-event-observations.json',import.meta.url)));
test('queued spell impact context and item-on-hit restoration match original event instructions',async()=>{
  for(const row of oracle.rows){
    const c=row.case,calls=[],actor={id:99,nativeSpellId218:44,nativeSpellTarget214:77,nativeSpellTarget818:88,lastSpellId:-1,
      nativeCasterOverride820:c.oldOverride??0,nativeCasterOverride824:12,nativeEffectSpellId774:-1,nativeSpellFeat23c:55,nativeSpellPoint208:[1,2,3]},target={objectType:c.targetType??5};
    const snapshot=()=>({spellId:actor.nativeSpellId218,targetId:actor.nativeSpellTarget214,itemId:actor.nativeSpellTarget818,savingSpell:actor.lastSpellId,
      override:actor.nativeCasterOverride820,casterLevel:actor.nativeCasterOverride824,effectSpell:actor.nativeEffectSpellId774,feat:actor.nativeSpellFeat23c,position:actor.nativeSpellPoint208});
    const data=c.payload===0?null:{casterId:c.caster??99,spellId:1,targetId:c.target??100,itemId:c.item??0x7f000000,featId:c.feat??65535,
      position:[7,8,9],script:'impact',casterLevel:c.casterLevel??3};
    const p={object:()=>c.targetExists===false?null:target,area:o=>c.nullArea?null:o===actor||c.sameArea!==false?1:2,position:()=>[4,5,6],
      setEffectSpell:(_o,id)=>{actor.nativeEffectSpellId774=id;},projectileTime:(_o,path)=>calls.push(['projectileTime',path]),
      runScript:(_name,...args)=>calls.push(['runScript',...args,structuredClone(snapshot())])};
    await receiveCreatureSpellImpact(actor,c.event??8,c.caller??99,data,p);
    assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(snapshot(),row.fields,JSON.stringify(c));
  }
});
test('a script exception clears temporary saving/effect context and restores an interrupted item cast',async()=>{
  const actor={id:99,nativeSpellId218:44,nativeSpellTarget214:77,nativeSpellTarget818:88,lastSpellId:-1,nativeCasterOverride820:2,
    nativeCasterOverride824:12,nativeEffectSpellId774:-1,nativeSpellFeat23c:55,nativeSpellPoint208:[1,2,3]};
  const error=new Error('authored script failed');
  await assert.rejects(receiveCreatureSpellImpact(actor,19,99,{casterId:99,spellId:1,targetId:0x7f000000,itemId:88,featId:12,position:[7,8,9],casterLevel:3,script:'impact'},
    {setEffectSpell:(o,id)=>{o.nativeEffectSpellId774=id;},projectileTime:()=>{},runScript:()=>{throw error;}}),e=>e===error);
  assert.equal(actor.nativeSpellId218,44);assert.equal(actor.nativeCasterOverride820,2);assert.equal(actor.nativeCasterOverride824,12);
  assert.equal(actor.lastSpellId,-1);assert.equal(actor.nativeEffectSpellId774,-1);assert.deepEqual(actor.nativeSpellPoint208,[1,2,3]);
});
