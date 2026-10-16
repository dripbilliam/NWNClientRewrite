import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {loadWaypointData} from '../src/waypoint_template.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-waypoint-template-observations.json',import.meta.url)));
const canonical=value=>JSON.parse(JSON.stringify(value));

test('full waypoint loader matches original tag override, float normalization, map-note commit, tag insertion and UUID ordering',async()=>{
 for(const row of native.rows){
  const c=row.case,calls=[],o={id:99,nativeMessageFields:{0x308:c.has??0,0x30c:c.enabled??0},note:c.note??{strRef:0xffffffff,entries:[]}};
  const result=await loadWaypointData(o,c.tag??null,{
   read:(kind,name,fallback)=>{calls.push(['read',kind,name,fallback]);return c.fields?.[name]??{status:0,value:fallback};},
   setTag:(obj,value)=>{assert.equal(obj,o);obj.tag=value;calls.push(['tag',value]);},
   localized:(obj,offset,value)=>{assert.equal(obj,o);calls.push(['localized',offset,value]);if(offset===0x310)obj.note=value;},
   position:(obj,v,flag)=>{assert.equal(obj,o);calls.push(['position',v,flag]);},
   orientation:(obj,v)=>{assert.equal(obj,o);calls.push(['orientation',v]);},
   setTemplate:(obj,value)=>{assert.equal(obj,o);calls.push(['template',value]);},
   addTag:obj=>calls.push(['addTag',obj.tag,obj.id]),loadUUID:obj=>{assert.equal(obj,o);calls.push(['uuid']);return c.uuidResult??0;},
  });
  const label=JSON.stringify(c);assert.equal(result,row.result,label);assert.deepEqual(canonical(calls),row.calls,label);assert.equal(o.nativeMessageFields[0x308],row.has,label);assert.equal(o.nativeMessageFields[0x30c],row.enabled,label);assert.deepEqual(o.note,row.note,label);
 }
 assert.equal(native.rows.length,698);
});
