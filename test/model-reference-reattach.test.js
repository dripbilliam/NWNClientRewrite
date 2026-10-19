import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {reattachModelReferences} from '../src/model_references.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-reference-reattach-observations.json',import.meta.url)));
test('reference reattachment matches complete original BFS/eligibility/float quaternion results',()=>{
 for(const row of native.rows){
  const c=row.case,calls=[],owner={position:c.position.map(Math.fround),quaternion:c.quaternion.map(Math.fround)},target={},parts=c.references.map((reference,i)=>({index:i,reference,header8:{flags98:c.flags[i],reattachableE0:c.reattachable[i]},model68:c.present[i]?{index:i,position:c.childPositions[i].map(Math.fround)}:null,children38:[]}));parts.forEach((part,i)=>part.children38=c.children[i].map(n=>parts[n]));
  reattachModelReferences(owner,c.target?target:null,'impact',{root:()=>parts[0],asReference:p=>p.reference?p:null,name:p=>`part${p.index}`,
   attach:(model,parent,name,flags)=>calls.push(['attach',model.index,parent===target?'target':'owner',name,flags]),
   position:model=>{if(model!==owner)calls.push(['position',model.index,owner.quaternion.slice()]);return model.position;},orientation:o=>o.quaternion,setOrientation:(o,q)=>o.quaternion=q});
  assert.deepEqual({calls,quaternion:owner.quaternion},{calls:row.calls,quaternion:row.quaternion},JSON.stringify(c));
 }
 assert.equal(native.rows.length,783);
});
test('reattachment rereads the referenced model after attachment and leaves no-reference roots unchanged',()=>{
 const owner={q:[2,.2,.3,-.4]},first={},second={},part={header8:{flags98:0x11,reattachableE0:1},model68:first,children38:[]};let queried;
 reattachModelReferences(owner,{},'root',{root:()=>part,asReference:p=>p,name:()=>'',attach:()=>part.model68=second,position:o=>{if(o===owner)return[0,0,0];queried=o;return[1,2,3];},orientation:o=>o.q,setOrientation:(o,q)=>o.q=q});assert.equal(queried,second);
 const before=owner.q;reattachModelReferences(owner,null,null,{root:()=>({children38:[]}),asReference:()=>null});assert.equal(owner.q,before);
});
