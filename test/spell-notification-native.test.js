import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {spellCastAtEvent,receiveSpellCastAt} from '../src/spell_notification.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-notification-observations.json',import.meta.url)));
test('spell target history, script guards and harmful combat/reputation ordering match native event2',async()=>{
  for(const row of oracle.rows){
    const c=row.case,calls=[],actor={id:99},source={id:100,objectType:c.sourceType??5},creator={id:101,objectType:5};
    const p={object:()=>c.exists===false?null:source,creature:id=>id===0x7f000000?null:source.objectType===5?source:source.objectType===11&&c.creatorExists!==false?creator:null,
      areaEffectCreator:()=>101,setLastHostile:(o,id,force)=>calls.push(['hostile',o.id,id,force]),dead:()=>c.dead??0,pc:o=>o===actor?c.pc??0:c.casterPC??0,
      scriptName:()=>c.name??'spell_script',runScript:(o,index)=>calls.push(['script',o.id,index]),broadcastState:o=>calls.push(['state',o.id]),
      initiative:o=>calls.push(['initiative',o.id]),excited:(o,state)=>calls.push(['excited',o.id,state]),removeInvisibility:o=>calls.push(['invisibility',o.id]),
      faction:()=>5,factionReputation:(o,id,delta)=>calls.push(['faction',o.id,id,delta>>>0]),associateCommand:(o,id)=>calls.push(['associate',o.id,id>>>0]),
      adjustReputations:(...args)=>calls.push(['reputations',...args])};
    await receiveSpellCastAt(actor,spellCastAtEvent(100,c.spell??1,c.harmful??1),p);
    assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(actor.nativeLastSpellCaster230,row.casterId,JSON.stringify(c));assert.equal(actor.nativeLastSpell234,row.spellId);assert.equal(actor.nativeLastSpellHarmful238,row.harmful);
  }
});
