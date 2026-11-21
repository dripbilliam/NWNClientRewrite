import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {scriptLocation,scriptObjectLocation} from '../src/script_location.js';
test('location construction matches40 complete native constructors with original SSE trig and normalization',()=>{
  const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-script-location-observations.json',import.meta.url)));assert.equal(capture.observations.length,40);
  for(const row of capture.observations){const location=scriptLocation(row.area,row.position,row.degrees);assert.deepEqual({area:location.areaId,position:location.position,orientation:location.nativeOrientation},{area:row.storedArea,position:row.position,orientation:row.orientation},JSON.stringify(row));}
});
test('GetLocation copies native position/orientation and raw area ID, including original invalid defaults',()=>{
 const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-get-location-observations.json',import.meta.url)));assert.equal(oracle.rows.length,387);
 for(const row of oracle.rows){const c=row.case;if(c.pop===0){assert.equal(row.result,0xfffffd81);assert.equal(row.output,null);continue;}if(c.push===0){assert.equal(row.result,0xfffffd82);continue;}
  const accepted=(c.lookup??0)===0&&(c.exists??true),point=c.position??[1,2,3],facing=c.orientation??[2,-3,4],value=scriptObjectLocation(accepted?{objectType:c.type??5,areaId:c.areaId??0x80000001,position:[point[0],point[2],-point[1]],orientation:[facing[0],facing[2],-facing[1]]}:null);
  assert.deepEqual({areaId:value.areaId,position:value.position,nativeOrientation:value.nativeOrientation},row.output,JSON.stringify(c));assert.equal(row.result,0);
 }
});
