import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {canCarryUUID,loadObjectUUID,tryAssignObjectUUID,lookupObjectUUID,initializeObjectUUID,destroyObjectUUID,ObjectUUIDRegistry,invalidCanonicalUUID} from '../src/object_uuid.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-object-uuid-observations.json',import.meta.url)));
const textNative=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-uuid-text-observations.json',import.meta.url)));

test('UUID admission matches original parse/format field owners with generic stream boundaries',()=>{
 for(const row of textNative.rows)assert.equal(invalidCanonicalUUID(row.input),row.invalid,JSON.stringify(row));
 assert.equal(textNative.rows.length,2011);
});

test('UUID constructor, eligibility, load/assign, lookup and destructor match original owner bodies',async()=>{
 for(const row of native.rows){
  const c=row.case,calls=[],object={id:c.id??99,objectType:c.type??12};let state={parent:object,value:c.old??''},result;
  const p={read:()=>{calls.push(['read']);return{status:c.readStatus??1,value:c.input??''};},
   contains:key=>{calls.push(['find',key]);return c.found??false;},
   invalid:key=>{const value=c.roundTrip??'00000000-0000-0000-0000-000000000000';calls.push(['parse',key],['format',value]);return Number(key!==value);},
   put:(key,o)=>calls.push(['put',key,o.id]),warning:message=>calls.push(['warning',message]),
   find:key=>{calls.push(['find',key]);return c.found?object:null;},erase:key=>calls.push(['erase',key]),
  };
  if(c.mode==='static')result=canCarryUUID(c.type);
  else if(c.mode==='member')result=canCarryUUID(c.type&255);
  else if(c.mode==='ctor')state=initializeObjectUUID(object);
  else if(c.mode==='destroy')destroyObjectUUID(state,p);
  else if(c.mode==='lookup')result=lookupObjectUUID(c.input??'',p);
  else if(c.mode==='command'){
   calls.push(['popString']);
   if(c.pop===0)result=0xfffffd81;
   else{const value=lookupObjectUUID(c.input,p);calls.push(['pushObject',value]);assert.equal(value,row.pushed);result=c.push===0?0xfffffd82:0;}
  }
  else{
   let value=state.value;Object.defineProperty(state,'value',{get:()=>value,set:v=>{value=v;calls.push(['assign',v]);}});
   result=c.mode==='load'?await loadObjectUUID(state,p):await tryAssignObjectUUID(state,c.input??'',p);
  }
  const label=JSON.stringify(c);assert.deepEqual(calls,row.calls,label);
  if(result!==undefined)assert.equal(result,row.result,label);
  if(c.mode!=='destroy')assert.equal(state.value,row.value,label);
  assert.equal(state.parent,object,label);
 }
 assert.equal(native.rows.length,2533);
});

test('UUID map retains original old aliases and current-key-only destructor ownership without allocating IDs',async()=>{
 const warnings=[],map=new ObjectUUIDRegistry({warning:m=>warnings.push(m)}),a={id:99,objectType:12},b={id:100,objectType:5};map.initialize(a);map.initialize(b);
 const first='01234567-89ab-cdef-0123-456789abcdef',second='11234567-89ab-cdef-0123-456789abcdef';
 assert.equal(await map.tryAssign(a,first),1);assert.equal(map.lookup(first),99);
 assert.equal(await map.tryAssign(a,second),1);assert.equal(map.lookup(first),99);assert.equal(map.lookup(second),99);
 assert.equal(await map.tryAssign(b,first),0);assert.equal(b.nativeUUID.value,'');
 assert.equal(await map.load(a,()=>({status:0,value:''})),1);assert.equal(a.nativeUUID.value,second);
 assert.equal(await map.load(b,()=>({status:1,value:second})),0);
 assert.equal(await map.tryAssign(b,first.toUpperCase()),0);
 map.destroy(a);assert.equal(map.lookup(second),OBJECT_INVALID);assert.equal(map.lookup(first),99);
 // Native erase does not compare the mapped object's identity.
 map.objects.set(first,b);a.nativeUUID.value=first;map.destroy(a);assert.equal(map.lookup(first),OBJECT_INVALID);
 assert.equal(warnings.length,3);assert.equal(a.id,99);assert.equal(b.id,100);
});
