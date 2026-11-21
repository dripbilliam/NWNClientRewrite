import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {receiveWorldSpellCastAt} from '../src/spell_notification.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-world-spell-notification-observations.json',import.meta.url)));
test('door/placeable spell notification matches original raw IDs, nonzero harmful flags, order and script indices',async()=>{
 assert.equal(data.rows.length,96);
 for(const row of data.rows){const c=row.case,actor={objectType:c.owner==='door'?10:9},trace=[];await receiveWorldSpellCastAt(actor,{type:2,objectIds:[c.caster],integers:[c.spell,c.harmful]},{setLastHostile:(_o,id,force)=>trace.push(['hostile',id,force]),creature:id=>{trace.push(['creature',id]);return c.creature?{}:null;},broadcastState:()=>trace.push(['broadcast']),excited:(_o,n)=>trace.push(['excited',n]),removeInvisibility:()=>trace.push(['invisibility']),runScript:(_o,i)=>trace.push(['script',i,0])});
  assert.deepEqual(trace,row.trace,JSON.stringify(c));assert.deepEqual([actor.nativeLastSpellCaster230,actor.nativeLastSpell234,actor.nativeLastSpellHarmful238],[row.caster,row.spell,row.harmful],JSON.stringify(c));
 }
});
