import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {createReferenceObjects,destroyReferencePart,controlReferencePart} from '../src/model_references.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-model-reference-owner-observations.json',import.meta.url)));
test('reference creation traversal/storage/attachment and deleting destructor match original code',()=>{
 for(const row of native.rows){
  const c=row.case,calls=[],model={},flags=c.flags??[1,0,1,1],edges=c.children??[[1,2],[3],[],[]],parts=flags.map((ref,i)=>({reference:!!ref,index:i,header8:{flags98:0x11,modelA0:`model${i}`},model68:c.present?model:null,children38:[]}));parts.forEach((part,i)=>part.children38=edges[i].map(n=>parts[n]));
  const p={asReference:part=>part.reference?part:null,create:(name,a,b)=>{calls.push(['create',name,a??0,b??0]);return model;},name:part=>`part${part.index}`,attach:(_model,_owner,name,flag)=>calls.push(['attach',name,flag]),destroy:(_model,flag)=>calls.push(['destroy',flag]),destroyPart:()=>calls.push(['destroyPart']),freePart:(_p,size)=>calls.push(['free',size])};
  if(c.mode==='create')createReferenceObjects({},parts[0],p);else assert.equal(destroyReferencePart(parts[0],c.deleteFlags,p),parts[0]);
  assert.deepEqual({calls,owned:parts.map(p=>!!p.model68)},{calls:row.calls,owned:row.owned},JSON.stringify(c));
 }
 assert.equal(native.rows.length,62);
});
test('unavailable reference headers/models fail explicitly before fabricated attachment',()=>{
 const part={header8:{flags98:1},children38:[]};let calls=0;
 assert.throws(()=>createReferenceObjects({},part,{asReference:()=>part}),/invalid reference header/);
 part.header8={flags98:0x11,modelA0:'missing'};
 assert.throws(()=>createReferenceObjects({},part,{asReference:()=>part,create:()=>null,attach:()=>calls++}),/unavailable child model/);assert.equal(part.model68,null);assert.equal(calls,0);
});
test('reference control preserves original float arguments and ignores an unavailable reference cast',()=>{
 for(const row of native.controls){const c=row.case,calls=[];controlReferencePart({}, {},c.previous,c.time,c.weight,{asReference:part=>{calls.push(['asReference']);return c.flags[0]?part:null;},control:(_node,_part,...args)=>calls.push(['control',...args])});assert.deepEqual(calls,row.calls);}
 assert.equal(native.controls.length,32);
});
