import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {parse2da} from '../src/area.js';
import {buildSpellLikeRadial} from '../src/spell_like_radial.js';
import {radialSpellCastRequest} from '../src/spell_radial.js';

test('innate radial physical slots, duplicate levels, count wrap and continuation match original instructions',()=>{
  const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-like-radial-observations.json',import.meta.url))),rules={spells:parse2da('2DA V2.0\n\nIconResRef\n'+Array.from({length:16},(_,i)=>`${i} ability${i}`).join('\n'))};
  for(const {case:c,entries}of oracle.rows){
    const actor={id:99,objectType:5,nativeSpellLikeAbilities:c.nullPool?null:c.pool.map(([id,remaining,casterLevel])=>({id,remaining,casterLevel}))};
    const p={name:(_table,id)=>String(id),spell:id=>c.missing?.includes(id)?null:{id,targetType:c.denied?.includes(id)?0:1}};
    const menu=buildSpellLikeRadial(c.controlled===false?null:actor,actor,rules,p,{start:c.start??0,assignment:c.assignment??false});
    assert.deepEqual(menu.entries.map(e=>e.children?{slot:e.slot,next:e.start}:{slot:e.slot,spellId:e.binding.spellId,uses:e.uses,packed:Number(BigInt(e.binding.spellId>>>0)|(BigInt(e.binding.domainLevel)<<24n)),disabled:e.disabled}),entries,JSON.stringify(c));
  }
  for(const {case:c,calls}of oracle.selections){
    if(c.assignment){assert.deepEqual(calls,[{assignment:true}]);continue;}
    const packed=BigInt(c.packed),r=radialSpellCastRequest({spellId:Number(packed&65535n),domainLevel:Number((packed>>24n)&15n)}, {id:99,areaId:1},{id:99},[1.25,2.5,3.75]);
    assert.deepEqual(calls,[{spellId:r.spellId,casterLevel:r.domainLevel,targetId:r.targetId,position:r.position}]);
  }
});
