import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {getVisualNodePose,setVisualNodePose,getVisualLocalNodePose,setVisualLocalNodePose} from '../src/visual_node_pose.js';
test('visual anchor global-pose reads and local reset math match complete original owners',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-node-pose-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,288);
 for(const row of oracle.rows){
  const c=row.case,calls=[],node={position10:[7.25,-8.5,9.75],quaternion1c:[.1,.2,.3,.4].map(Math.fround),dirty60:7},position=c.position.map(Math.fround),quaternion=c.quaternion.map(Math.fround);
  const p={findNode:(_model,name)=>{calls.push(['find',name]);return c.found?node:null;},globalPose:n=>{calls.push(['globalPose',[...n.position10],[...n.quaternion1c]]);return{position:c.basePosition.map(Math.fround),quaternion:c.baseQuaternion.map(Math.fround)};}};
  const setter=c.mode==='set'?setVisualNodePose:c.mode==='setLocal'?setVisualLocalNodePose:null;
  const getter=c.mode==='getLocal'?getVisualLocalNodePose:getVisualNodePose;
  const result=setter?setter({},'root',position,quaternion,p):getter({},'root',c.outPosition?position:null,c.outQuaternion?quaternion:null,p);
  assert.deepEqual({calls,result,nodePosition:node.position10,nodeQuaternion:node.quaternion1c,dirty:node.dirty60,position,quaternion},Object.fromEntries(Object.entries(row).filter(([key])=>key!=='case')),JSON.stringify(c));
 }
});
