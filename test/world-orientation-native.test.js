import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {setCommonOrientation,setPlaceableOrientation} from '../src/world_object_orientation.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-world-orientation-observations.json',import.meta.url))),f=Math.fround,decode=value=>value==='nan'?NaN:value;
const bits=vector=>vector.map(value=>{const v=new DataView(new ArrayBuffer(4));v.setFloat32(0,value,true);return v.getUint32(0,true);});
test('common and placeable orientation owners match288 original vector/threshold/area/mesh executions',async()=>{
 assert.equal(capture.rows.length,288);
 for(const expected of capture.rows){const c=expected.case,calls=[],o={id:42,vector:c.old.map(decode).map(f)},p={
  threshold:capture.threshold,orientation:o=>o.vector,write:(o,v)=>{o.vector=[...v];},area:()=>{calls.push(['area']);return c.area?{}:null;},
  appearance:()=>17,mesh:id=>{calls.push(['tileSetManager'],['mesh',id]);return c.mesh?{}:null;},slot:()=>3,position:()=>[1,2,3],
  replace:(_a,slot,id,orientation,point)=>calls.push(['replace',slot>>>0,id,bits(orientation),bits(point),5,4]),points:()=>calls.push(['points']),
 };
 if(c.common)setCommonOrientation(o,c.new.map(decode),p);else await setPlaceableOrientation(o,c.new.map(decode),p);
 assert.deepEqual({calls,orientation:bits(o.vector)},{calls:expected.calls,orientation:expected.orientation},JSON.stringify(c));
 }
});
