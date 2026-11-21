import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {attachType4Visual} from '../src/visual_type4.js';
test('Type4 local pose offsets, native anchors and context refresh match134 complete original executions',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-type4-attachment-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,134);
 for(const row of oracle.rows){
  const c=row.case,calls=[],models=[{id:0},{id:1}],context={context30:c.context?{}:null},other={},e={target54:123,proceduralB8:c.procedural?models[0]:null};
  const p={clientObject:id=>{calls.push(['client',id]);return c.client?{}:null;},renderObject:()=>{calls.push(['render']);return c.render?{}:null;},modelHandle:(_render,...args)=>{calls.push(['modelHandle',...args]);return c.host?{id:9}:null;},prefixViewA0:()=>{calls.push(['viewA']);return c.first?{prefix1e0:c.prefixA}:null;},prefixView28:()=>{calls.push(['viewB']);return c.second?{prefix1c8:c.prefixB}:null;},view58:()=>{calls.push(['view58']);return c.creature?context:null;},view1406ac1a0:()=>{calls.push(['view1406ac1a0']);return c.selected?context:other;},refreshContext1407e9bc0:()=>calls.push(['refreshContext1407e9bc0']),localNodePose:(_model,name,defaults)=>{calls.push(['localNodePose',name,defaults.position,defaults.quaternion]);return c.pose?{position:[.25,.5,.75],quaternion:[.5,.5,.5,.5]}:defaults;},setLocalNodePose:(model,...args)=>{calls.push(['setLocalNodePose',model.id,...args]);if(c.replace)e.proceduralB8=models[1];},setParent:(model,parent,...args)=>calls.push(['parent',model.id,parent.id,...args])};
  attachType4Visual(e,p);assert.deepEqual({calls,procedural:e.proceduralB8?.id??null},{calls:row.calls,procedural:row.procedural},JSON.stringify(c));
 }
});
