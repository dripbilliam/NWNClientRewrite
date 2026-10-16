import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {moduleTagKey,addModuleTag,scriptObjectByTag,scriptWaypointByTag} from '../src/module_tag_lookup.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-module-tag-add-observations.json',import.meta.url)));
test('tag projection matches original full insertion/key/sort-index owners after every addition',()=>{
 for(const row of native.rows){
  const tags=new Map(),objects=new Map();
  for(let n=0;n<row.steps.length;n++){
   const {tag,id}=row.steps[n];addModuleTag(tags,tag,id);objects.set(id,row.steps[n].present===false?null:{objectType:row.steps[n].objectType??12});
   const expected=new Map();for(const entry of row.observations[n].entries){if(!expected.has(entry.tag))expected.set(entry.tag,[]);expected.get(entry.tag).push(entry.id);}
   assert.deepEqual(new Set(tags.keys()),new Set(expected.keys()));for(const [key,ids]of expected)assert.deepEqual(tags.get(key),ids,JSON.stringify({n,tag,key}));
   assert.ok(tags.has(moduleTagKey(tag)));
   for(const q of row.observations[n].queries)assert.equal(q.kind==='object'?scriptObjectByTag(tags,q.tag,q.ordinal):scriptWaypointByTag(tags,q.tag,id=>objects.get(id)),q.result,JSON.stringify({n,q}));
  }
 }
 assert.equal(native.rows.length,92);
});
