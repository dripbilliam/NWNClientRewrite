import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PathInformation} from '../src/path_information.js';
import {createPathAlternatives,deletePathAlternatives,getPathAlternatives,setPathAlternatives} from '../src/path_alternatives.js';
test('resumable path alternatives match original pointer initialization, raw INT transfer and scalar disposal',()=>{
  const rows=JSON.parse(readFileSync(new URL('../backups/animations/native-path-alternative-observations.json',import.meta.url))).rows;
  for(const row of rows){const c=row.case,path=new PathInformation(77),old=Array.from({length:c.oldCount},(_,n)=>n%2?[]:null);
    path.raw.setInt32(0x104,c.oldCount,true);path.raw.setInt32(0xf8,1,true);path.raw.setInt32(0x100,9,true);
    if(c.present){path.allocations.set(0x118,old);path.allocations.set(0x108,Array(c.oldCount).fill(-4));path.allocations.set(0x110,Array(c.oldCount).fill(0));}
    const observations=[];
    if(c.mode==='delete')deletePathAlternatives(path);
    else{
      createPathAlternatives(path,c.newCount);assert.deepEqual(path.allocations.get(0x118),row.initialPointers.map(()=>null));
      assert.ok(row.dirty.every(v=>v===0xa5a5a5a5),'Native INT allocations must retain the allocator sentinel');
      assert.ok(path.allocations.get(0x108).every(v=>v===undefined));assert.ok(path.allocations.get(0x110).every(v=>v===undefined));
      for(let n=0;n<c.newCount;n++){
        const nodes=n%2?[]:null;setPathAlternatives(path,n,n-2,c.savedCount,nodes);const value=getPathAlternatives(path,n);assert.equal(value.nodes,nodes);
        observations.push({start:value.start,count:value.count,node:value.nodes===null?null:n});
      }
    }
    assert.deepEqual({count:path.raw.getInt32(0x104,true),flags:[path.raw.getInt32(0xf8,true),path.raw.getInt32(0x100,true)],pointers:[0x108,0x110,0x118].map(n=>path.allocations.has(n)),observations},
      {count:row.count,flags:row.flags,pointers:row.pointers,observations:row.observations},JSON.stringify(c));
    if(c.present)assert.deepEqual(old,row.oldNodeCells.map(()=>null));
  }
});
test('uninitialized saved INTs and unknown successor allocations remain explicit failures',()=>{
  const path=new PathInformation(77);createPathAlternatives(path,2);assert.throws(()=>getPathAlternatives(path,0),/saved start/);
  setPathAlternatives(path,0,1,2,[{x:1}]);path.resetInterTile();assert.equal(path.allocations.has(0x118),false);assert.equal(path.raw.getInt32(0x104,true),0);
  path.allocations.set(0x118,{opaque:true});assert.throws(()=>path.resetInterArea(),/disposal/);
});
