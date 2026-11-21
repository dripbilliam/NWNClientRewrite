import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {remapModelController,readModelControllerStorage} from '../src/model_controller_remap.js';
test('controller offset relocation matches results of complete original loader and actual subtype queries',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-model-controller-remap-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,16);
 for(const row of oracle.rows){
  assert.deepEqual(row.offsets.map(v=>remapModelController(v,row.flags)),row.controllers.map(v=>v[0]),String(row.flags));
  const buffer=new ArrayBuffer(4096),data=new DataView(buffer),start=128;data.setInt32(start+28,-123,true);data.setUint32(start+108,row.flags,true);data.setUint32(start+84,512,true);data.setUint32(start+88,row.offsets.length,true);data.setUint32(start+96,2048,true);data.setUint32(start+100,3,true);
  row.offsets.forEach((v,i)=>{const at=524+i*12;data.setInt32(at,v,true);data.setUint16(at+4,2,true);data.setUint16(at+6,4,true);data.setUint16(at+8,5,true);data.setUint8(at+10,17);data.setUint8(at+11,0xa5);});row.values.forEach((v,i)=>data.setFloat32(2060+i*4,v,true));
  const storage=readModelControllerStorage(data,start,(at,size)=>assert.ok(at>=12&&at+size<=buffer.byteLength));
  assert.equal(storage.id34,-123);assert.equal(storage.flags98,row.flags);assert.deepEqual(storage.values88,row.values);
  assert.deepEqual(storage.controllers78.map(v=>[v.displacement0,v.rows4,v.timeIndex6,v.valueIndex8,v.columnsA,v.paddingB]),row.controllers);
 }
});
