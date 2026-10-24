import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {clientParryVisual} from '../src/client_parry_visual.js';

test('parry spark placement and service order match52 complete original mode0 executions',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-parry-visual-observations.json',import.meta.url)));
 assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,52);
 for(const {case:c,calls:expected,result}of oracle.cases){
  const source={},target={},calls=[],p={targetId:()=>c.targetId,object:id=>{calls.push(['target',id]);return c.missingTarget?null:target;},creatureSpace:()=>{calls.push(['space']);return c.space;},impactPose:()=>{calls.push(['impact']);return c.missingImpact?null:c.impact;},position:o=>o===source?c.position:c.target,orientation:()=>c.orientation,warning:()=>calls.push(['warning']),areaVisual:(_o,id,position)=>{calls.push(['area',id,position]);return c.areaResult??1;}};
  assert.equal(clientParryVisual(source,p),result,JSON.stringify(c));assert.deepEqual(calls,expected,JSON.stringify(c));
 }
});
