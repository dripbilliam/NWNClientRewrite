import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeAreaMessageFields,loadAreaMessageHeader,tileMessageMetadata,nativeMessageField} from '../src/area_message_metadata.js';

test('live area scalar import matches original constructor/defaults, narrowing and indoor weather clears',()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-area-message-fields-observations.json',import.meta.url)));assert.equal(data.headers.length,97);
 for(const row of data.headers){
  const area={id:4};initializeAreaMessageFields(area);
  for(const [offset,[kind,value]]of Object.entries(row.case.initial))area.nativeMessageFields[parseInt(offset,16)]=kind==='float'?Math.fround(value):kind==='byte'?value&255:value|0;
  loadAreaMessageHeader(area,row.case.values);
  for(const [offset,value]of Object.entries(row.fields))assert.equal(area.nativeMessageFields[offset],value,JSON.stringify({case:row.case,offset}));
  assert.equal(area.flags,row.fields[8]);assert.equal(area.nativeChanceRainE1,row.fields[0xe1]);assert.equal(area.nativeWindPowerE4,row.fields[0xe4]);
 }
});

test('loaded tile protocol fields match original typed GFF reads and actual tile setters',()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-area-message-fields-observations.json',import.meta.url)));assert.equal(data.tiles.length,55);
 for(const row of data.tiles)assert.deepEqual(tileMessageMetadata(row.case).nativeMessageFields,row.fields,JSON.stringify(row.case));
});

test('message field access shares live calendar, weather and canonical spatial state and diagnoses missing owners',()=>{
 const area={id:4,objectType:4,flags:1,width:2,height:3,nativeWeatherType330:4,nativeWeatherOn334:2,nativeWeatherOverride344:255,pvpSetting:1,nativeSpatial:{count:7}};initializeAreaMessageFields(area);loadAreaMessageHeader(area,{});
 assert.equal(nativeMessageField(area,0xc),2);assert.equal(nativeMessageField(area,0x10),3);assert.equal(nativeMessageField(area,0x230),7);
 area.nativeSpatial.count=3;area.nativeWeatherOn334=0;assert.equal(nativeMessageField(area,0x230),3);assert.equal(nativeMessageField(area,0x334),0);
 const module={objectType:3,nativeCalendarYear3c0:1372};assert.equal(nativeMessageField(module,0x3c0),1372);module.nativeCalendarYear3c0++;assert.equal(nativeMessageField(module,0x3c0),1373);
 assert.throws(()=>nativeMessageField({},0x594),/field 594 is unavailable/);
 assert.throws(()=>loadAreaMessageHeader(area,{MoonAmbientColor:'broken'}),/MoonAmbientColor/);
});
