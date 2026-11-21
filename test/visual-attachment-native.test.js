import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {attachVisualModels} from '../src/visual_attachment.js';
test('selection-time visual attachment matches full original owner and procedural dispatch',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-attachment-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,1169);
 for(const row of oracle.rows){
  const c=row.case,calls=[],models=Array.from({length:5},(_,id)=>({id})),e={target54:123,attached114:7,orient120:c.orient,programPhaseFa:c.phase,programsD0:[10,20,30],models88:models.slice(0,3).map((v,i)=>c.models[i]?v:null),proceduralB8:c.procedural?models[3]:null,targetAnchor38:'target_anchor',vector18:[1.25,-2.5,3.75]};
  const p={clientObject:id=>{calls.push(['client',id]);return c.client?{}:null;},renderObject:()=>{calls.push(['render']);return c.render?{}:null;},modelHandle:(_r,...args)=>{calls.push(['modelHandle',...args]);return c.host?{id:9}:null;},prefixViewA0:()=>{calls.push(['viewA']);return c.first?{prefix1e0:c.prefixA}:null;},prefixView28:()=>{calls.push(['viewB']);return c.second?{prefix1c8:c.prefixB}:null;},setParent:(model,parent,...args)=>calls.push(['parent',model.id,parent.id,...args]),nodePose:(model,name)=>{calls.push(['pose',model.id,name]);return{position:[model.id+.25,model.id+.5,model.id+.75]};},setNodePose:(model,...args)=>calls.push(['setPose',model.id,...args]),programType:(_e,id)=>{calls.push(['programType',id]);return c.type;},renderSetting158:(_r,...args)=>calls.push(['renderSetting158',...args])};
  for(const address of ['14096ba80','14096bbb0','14096b630','140969ef0','14096aff0','1409689f0'])p[`programAttach${address}`]=(_e,...args)=>{calls.push([`programAttach${address}`,...args]);if(c.replace)e.proceduralB8=models[4];};
  attachVisualModels(e,p);assert.deepEqual({calls,attached:e.attached114,procedural:e.proceduralB8?.id??null},{calls:row.calls,attached:row.attached,procedural:row.procedural},JSON.stringify(c));
 }
});
