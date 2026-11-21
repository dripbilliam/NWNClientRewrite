import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {animateModelHierarchy} from '../src/model_animation_hierarchy.js';
test('animation hierarchy matches original child ID dispatch, rotated duplicate search, dirty/light gates and shared depth cutoff',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-model-animation-hierarchy-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,512);
 for(const row of oracle.rows){
  const c=row.case,calls=[],parts=[0,...c.physicalIds,3].map((id30,i)=>({name:`part${i}`,id30,dirty60:i?c.childDirty:c.dirty,owner50:{},childCount40:0,children38:[]})),nodes=[0,...c.animationIds,3].map((id34,i)=>({name:`node${i}`,id34,childCount70:0,children68:[]}));
  parts[0].children38=parts.slice(1,4);parts[0].childCount40=3;parts[1].children38=[parts[4]];parts[1].childCount40=1;
  nodes[0].children68=nodes.slice(1,4);nodes[0].childCount70=3;nodes[c.grandchildAt].children68=[nodes[4]];nodes[c.grandchildAt].childCount70=1;
  const context={depth:c.depth};animateModelHierarchy(parts[0],nodes[0],-.25,.75,.3,context,{control:(node,part,previous,time,weight)=>calls.push(['control',node.name,part.name,previous,time,weight]),light:part=>{calls.push(['light',part.name]);return c.light?{field8c:c.lightFlag}:null;},animateStaticLight:()=>calls.push(['AnimateStaticLight','light'])});
  assert.deepEqual({calls,depth:context.depth},{calls:row.calls,depth:row.depth},JSON.stringify(c));
 }
});
