import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {selectVisualEffects,visualIsRetired,visualHasCessation,detachCompetingVisual} from '../src/visual_selection.js';
test('visual selection priorities, visibility and retirement predicates match complete original owners',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-selection-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,895);
 for(const row of oracle.rows){
  const c=row.case,calls=[],entries=c.entries.map((v,id)=>({id,finishedF4:v.finished,field110:v.field110,attached114:v.attached,closedEc:v.closed,scope10c:v.scope,programType10d:v.type,visualF8:v.visual,retiredDc:v.retired,programPhaseFa:v.phase,models88:v.models.map(x=>x?{}:null),modelStates68:v.states}));
  const p={programType:e=>e.programType10d,selectedObjectId1406ac1c0:()=>{calls.push(['selectedObjectId1406ac1c0']);return c.controlledId;},viewGate1407dadb0:()=>{calls.push(['controlled'],['viewGate1407dadb0']);return c.viewGate1407dadb0;},attach:e=>{calls.push(['attach',e.id]);e.attached114=1;},detach:e=>{calls.push(['detach',e.id]);e.attached114=0;},start:e=>{calls.push(['start',e.id]);e.closedEc=0;},stop:(e,value)=>{calls.push(['stop',e.id,value]);e.closedEc=1;}};
  selectVisualEffects({id:123,suppressed108:c.suppressed,visuals80:entries},c.type,p);
  assert.deepEqual({calls,attached:entries.map(e=>e.attached114),closed:entries.map(e=>e.closedEc),retired:entries.map(e=>Number(visualIsRetired(e))),cessation:entries.map(e=>Number(visualHasCessation(e)))},Object.fromEntries(Object.entries(row).filter(([key])=>key!=='case')),JSON.stringify(c));
 }
});

test('competing visual removal matches the complete original backward search including an already-detached first match',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-competing-removal-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,326);
 for(const row of oracle.rows){
  const c=row.case,calls=[],entries=c.entries.map((v,id)=>({id,programType10d:v.type,scope10c:v.scope,finishedF4:v.finished,attached114:v.attached}));
  detachCompetingVisual({visuals80:entries},entries[c.remove],{programType:e=>e.programType10d,detach:e=>{calls.push(['detach',e.id]);e.attached114=0;}});
  assert.deepEqual({calls,attached:entries.map(e=>e.attached114)},{calls:row.calls,attached:row.attached},JSON.stringify(c));
 }
});
