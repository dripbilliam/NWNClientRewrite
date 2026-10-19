import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptSetMapPinEnabled} from '../src/map_pin_script.js';
test('SetMapPinEnabled post-pop body matches216 original executions: raw INT and all eligible clients',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-map-pin-script-observations.json',import.meta.url)));assert.equal(data.rows.length,216);
 for(const row of data.rows){const c=row.case,trace=[],waypoint={nativeMessageFields:{0x308:c.has,0x30c:123}},clients=c.clients.map((has,index)=>({has,index}));
  await scriptSetMapPinEnabled([c.id,c.enabled],{waypoint:id=>{trace.push(['waypoint',id]);return c.exists?waypoint:null;},message:()=>{trace.push(['message']);return{};},clients:()=>{trace.push(['clients']);return clients;},clientObject:v=>{trace.push(['clientObject',v.index]);return v.has?{}:null;},send:(_m,client,id,enabled)=>{trace.push(['send',client.index,id,enabled>>>0]);return c.sendResult;}});
  assert.deepEqual({result:0,enabled:waypoint.nativeMessageFields[0x30c],trace},{result:row.result,enabled:row.enabled,trace:row.trace},JSON.stringify(c));
 }
});
