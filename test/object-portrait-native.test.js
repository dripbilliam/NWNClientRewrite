import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {objectPortraitId,objectPortraitRef} from '../src/placeable_fields.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-object-portrait-observations.json',import.meta.url)));
test('common portrait setters match168 original executions and direct refs retain the numeric ID',async()=>{
 assert.equal(capture.rows.length,168);
 for(const expected of capture.rows){
  const c=expected.case,object={nativePortraitId:7,nativePortraitResRef:'old_ref'},calls=[];
  const setRef=(o,ref)=>{calls.push(['ref',ref,o.nativePortraitId]);objectPortraitRef(o,ref);};
  if(c.direct)setRef(object,c.value.split('\0')[0].slice(0,16));
  else await objectPortraitId(object,c.id,{setRef,baseResRef:(id,column)=>{calls.push(['table',id,column]);return{status:c.status,value:c.value};}});
  assert.deepEqual({id:object.nativePortraitId,reference:object.nativePortraitResRef,calls},{id:expected.id,reference:expected.reference,calls:expected.calls},JSON.stringify(c));
 }
});
