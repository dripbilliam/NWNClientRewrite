import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {detachVisualModels} from '../src/visual_detachment.js';
test('visual detachment and Type4 context refresh match75 complete original executions',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-detachment-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,75);
 for(const row of oracle.rows){
  const c=row.case,calls=[],models=Array.from({length:4},(_,id)=>({id}));if(c.alias)models[2]=models[0];
  const area={context30:c.scene?{}:null},other={},e={target54:123,attached114:7,models88:models.slice(0,3).map((v,i)=>c.models[i]?v:null),proceduralB8:c.procedural?models[3]:null,programType10d:c.type};
  const p={setParent:(model,...args)=>{calls.push(['parent',model.id,...args]);if(c.mutateNext&&model.id===0)e.models88[1]=null;},setScene:(model,...args)=>calls.push(['scene',model.id,...args]),clientObject:id=>{calls.push(['client',id]);return c.client?{}:null;},renderObject:()=>{calls.push(['render']);return c.render?{}:null;},view58:()=>{calls.push(['view58']);return c.area?area:null;},view1406ac1a0:()=>{calls.push(['view1406ac1a0']);return c.active?area:other;},refreshContext1407e9bc0:()=>calls.push(['refresh'])};
  detachVisualModels(e,p);assert.deepEqual({calls,attached:e.attached114,models:e.models88.map(model=>model?.id??null)},{calls:row.calls,attached:row.attached,models:row.models},JSON.stringify(c));
 }
});
