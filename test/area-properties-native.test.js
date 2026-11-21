import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeAreaMessageFields} from '../src/area_message_metadata.js';
import {loadAreaMessageProperties} from '../src/area_message_properties.js';
import {decodeGffText} from '../src/gff_text.js';
const raw=hex=>Uint8Array.from(Buffer.from(hex,'hex'));
const parsed=value=>{
 if(typeof value==='string')return decodeGffText(Uint8Array.from(Buffer.from(value,'latin1')));
 if(Array.isArray(value))return value.map(parsed);
 if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([key,v])=>[key,parsed(v)]));return value;
};

test('complete GIT properties, ambient state, keyed grass insertion/rehash and reload match original owners',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-area-properties-observations.json',import.meta.url)));assert.equal(fixture.rows.length,88);
 let executions=0;
 for(const [index,row]of fixture.rows.entries()){
  const c=row.case,area={id:c.id??4,nativeCustomName358:null,nativeCustomNameLength360:0};initializeAreaMessageFields(area);
  for(const [offset,[kind,value]]of Object.entries(c.initial??{}))area.nativeMessageFields[parseInt(offset,16)]=kind==='byte'?value&255:kind==='dword'?value>>>0:kind==='float'?Math.fround(value):value|0;
  for(const [offset,[kind,value]]of Object.entries(c.ambient??{}))area.nativeAmbientSound328.nativeMessageFields[parseInt(offset,16)]=kind==='byte'?value&255:value|0;
  if(c.name){area.nativeCustomName358=raw(c.name);area.nativeCustomNameLength360=c.name.length/2;}
  let previous=new Map();
  for(const [step,input]of c.steps.entries()){
   const result=loadAreaMessageProperties(area,parsed(input)),expected=row.observations[step].value,fields=Object.fromEntries(Object.keys(expected.fields).map(key=>[key,area.nativeMessageFields[key]])),entries=area.nativeMessageGrassEntries;
   const value={fields,ambient:area.nativeAmbientSound328.nativeMessageFields,name:area.nativeCustomName358?Buffer.from(area.nativeCustomName358).toString('hex'):'',nameLength:area.nativeCustomNameLength360,
    grass:entries.map(e=>({fields:e.nativeMessageFields,name:Buffer.from(e.nativeName18).toString('hex')})),buckets:area.nativeMessageGrassMap370.bucketCount,retained:entries.filter(e=>previous.get(e.nativeMessageFields[0x10])===e).map(e=>e.nativeMessageFields[0x10])};
   assert.deepEqual({result,value},{result:row.observations[step].result,value:expected},JSON.stringify({index,step,case:c}));
   previous=new Map(entries.map(e=>[e.nativeMessageFields[0x10],e]));executions++;
  }
 }
 assert.equal(executions,115);
});
