import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializePlaceableMessageState,loadPlaceableMessageState} from '../src/placeable_message.js';

test('placeable appearance narrowing, light defaults/repeated queries and dirty commits match native blocks',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-placeable-message-observations.json',import.meta.url)));assert.equal(data.rows.length,288);
 for(const row of data.rows){
  const c=row.case,object={id:123};initializePlaceableMessageState(object);object.nativeMessageFields[0x594]=c.old;
  for(const [index,step]of c.steps.entries()){
   const queries=[],p={field:(o,offset)=>o.nativeMessageFields[offset],lightColor:(id,key)=>{const status=c.statuses[Math.min(queries.length,c.statuses.length-1)];queries.push([id,key,status]);return{status,value:0x112233};}};
   await loadPlaceableMessageState(object,step,p);
   assert.deepEqual({appearance:object.nativeMessageFields[0x32c],light:object.nativeMessageFields[0x594],dirty:object.nativeMessageFields[0x598],queries},row.observations[index],JSON.stringify({case:c,index}));assert.equal(object.id,123);
  }
 }
});
