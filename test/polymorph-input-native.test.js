import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {receiveCancelPolymorphInput} from '../src/combat_input.js';
import {buildRadialActions} from '../src/radial_actions.js';
test('decoded cancellation preserves native lock guards and first ID-group selection',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-polymorph-input-observations.json',import.meta.url)));assert.equal(data.rows.length,144);
 for(const row of data.rows){const c=row.case,calls=[],o={nativeField8ac:c.blocked,nativeField9f8:c.locked,effects:c.effects.map((type,n)=>({type,id:(500+n).toString(16).padStart(16,'0')}))};
  assert.equal(await receiveCancelPolymorphInput(null,{readObjectId:()=>{calls.push(['readObject']);return 99;},overflow:()=>{calls.push(['overflow']);return c.overflow;},creature:id=>{calls.push(['creature',id]);return c.exists?o:null;},effects:o=>o.effects,remove:(_o,id)=>calls.push(['remove',id])}),0);assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
test('self radial offers cancellation only while transformed and unlocked',()=>{
 for(const form of [0,1,-1])for(const lock of [0,1,-1]){const o={id:99,kind:'player',nativeField97c:form,nativeField9f8:lock};const entry=buildRadialActions(o,o).entries.find(e=>e.slot===4);assert.equal(!!entry,form!==0&&lock===0);if(entry)assert.equal(entry.action,'character.cancelPolymorph');}
});
