import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {scriptLocation} from '../src/script_location.js';
test('location construction matches40 complete native constructors with original SSE trig and normalization',()=>{
  const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-script-location-observations.json',import.meta.url)));assert.equal(capture.observations.length,40);
  for(const row of capture.observations){const location=scriptLocation(row.area,row.position,row.degrees);assert.deepEqual({area:location.areaId,position:location.position,orientation:location.nativeOrientation},{area:row.storedArea,position:row.position,orientation:row.orientation},JSON.stringify(row));}
});
