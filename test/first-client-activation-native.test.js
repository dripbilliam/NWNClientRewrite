import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {activateOnFirstClient,importPlaceableStatic} from '../src/creature_area_lifecycle.js';
test('first-client predicate and placeable static import match 201 original block executions',()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-first-client-activation-observations.json',import.meta.url)));assert.equal(data.rows.length,201);
 for(const row of data.rows){
  const c=row.case,calls=[],object={objectType:c.type,nativeStatic5a0:c.static??0},p={};
  for(const [name,kind]of [['asCreature',5],['asAreaEffect',11],['asTrigger',7],['asDoor',10],['asPlaceable',9]])p[name]=o=>{calls.push([name]);return o.objectType===kind?o:null;};
  p.scriptName=(_o,index)=>{calls.push(['scriptName',index]);return{length:c.length};};
  let result=false;
  if(c.operation==='predicate')result=activateOnFirstClient(object,p);
  else{const fields={};for(const key of ['Useable','Static'])if(c[key]!==null)fields[key]=c[key];importPlaceableStatic(object,fields,c.override);}
  assert.deepEqual({calls,result,static:object.nativeStatic5a0,usable:object.nativeUseable264??0},{calls:row.calls,result:row.result,static:row.static,usable:row.usable},JSON.stringify(c));
 }
});
