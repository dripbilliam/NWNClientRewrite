import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {finishEffectApplicationFlag,receiveCombatEffect} from '../src/effect_application_flag.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-effect-application-flag-observations.json',import.meta.url)));
test('linked combat-effect event and post-handler flag gates match bounded original instructions',async()=>{
 assert.equal(data.rows.length,1007);
 for(const row of data.rows){const c=row.case,object={nativeField180:c.flag??0},effect={type:c.type??40,id:'000000000000007b',integers:[c.visual??207]},trace=[];
  if(c.mode==='event'){if((c.event??5)===5)await receiveCombatEffect(object,c.payload===false?null:effect,(_effect,loading,special)=>{trace.push(['apply',object.nativeField180,loading,special]);if(c.after!==undefined&&c.after!==null)object.nativeField180=c.after;});}
  else await finishEffectApplicationFlag(object,effect,c.consumed??0,c.special??0,{remove:(_o,id)=>trace.push(['remove',id])});
  assert.equal(object.nativeField180,row.flag,JSON.stringify(c));assert.deepEqual(trace,row.trace.filter(r=>r[0]!=='dispose'),JSON.stringify(c));
 }
});
