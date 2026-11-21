import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {updateVisualNoOrientation} from '../src/visual_orientation.js';
test('no-orientation update matches original including nonunit quaternions, failure, object replacement and DWORD return',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-orientation-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,72);
 for(const row of oracle.rows){
  const c=row.case,calls=[],original={quaternion:[...c.before]},replacement={quaternion:[0,0,0,0]},behavior={object18:original};
  const result=updateVisualNoOrientation(behavior,c.delta,{orientation:o=>[...o.quaternion],setOrientation:(o,q)=>o.quaternion=q,
   baseUpdate:(b,delta)=>{calls.push(['base',delta]);if(c.replace)b.object18=replacement;b.object18.quaternion=[...c.after];return c.result;}});
  assert.deepEqual({result,calls,original:original.quaternion,replacement:replacement.quaternion},Object.fromEntries(Object.entries(row).filter(([key])=>key!=='case')),JSON.stringify(c));
 }
});
