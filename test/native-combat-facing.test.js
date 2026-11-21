import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NetworkWorld} from '../src/network_world.js';
import {facingDeliveryFixture} from '../godot-client/tests/native_combat_facing_fixture.mjs';
const ID=0xffffffce,AREA=0x80000001,INVALID=0x7f000000;
function world(){const value=new NetworkWorld({onDiagnostic:()=>{}});value.areaId=AREA;value.applyObjectUpdates([{action:'create',id:ID,objectType:5,state:{areaId:AREA,position:[0,0,0],orientation:{vector:[0,1,0]},animation:0}}]);return value;}
test('a received facing-only change enters the immediate movement boundary',()=>{
 const value=world();value.applyObjectUpdates([{action:'update',id:ID,objectType:5,state:{facingTarget:7}}]);
 assert.deepEqual(value.presentationChanges,[{action:'movement',id:ID,created:false,changes:{facingTarget:7}}]);assert.equal(value.registry.get(ID).replicated.facingTarget,7);
});
test('orientation and lock remain one ordered received event, with no inferred target',()=>{
 const value=world(),state={orientation:{vector:[1,0,0]},facingTarget:9},before=structuredClone(state);
 value.applyObjectUpdates([{action:'update',id:ID,objectType:5,state}]);assert.equal(value.presentationChanges.length,1);assert.deepEqual(value.presentationChanges[0].changes,state);assert.deepEqual(state,before);
 value.applyObjectUpdates([{action:'update',id:ID,objectType:5,state:{orientation:{vector:[0,1,0]}}}]);assert.equal(Object.hasOwn(value.presentationChanges[0].changes,'facingTarget'),false);
});
test('explicit native unlock is delivered and unrelated updates cannot replay it',()=>{
 const value=world();value.applyObjectUpdates([{action:'update',id:ID,objectType:5,state:{facingTarget:INVALID}}]);assert.deepEqual(value.presentationChanges[0].changes,{facingTarget:INVALID});
 value.applyObjectUpdates([{action:'update',id:ID,objectType:5,state:{hitPoints:{current:10}}}]);assert.deepEqual(value.presentationChanges,[]);
});
test('a rejected transaction cannot expose a partial facing event',()=>{
 const value=world(),before=structuredClone(value.registry.get(ID)),events=structuredClone(value.presentationChanges);
 assert.throws(()=>value.applyObjectUpdates([{action:'update',id:ID,objectType:5,state:{facingTarget:11}},{action:'create',id:ID,objectType:10,state:{}}]),/Conflicting/);
 assert.deepEqual(value.registry.get(ID),before);assert.deepEqual(value.presentationChanges,events);
});
test('host initial-state whitelist and cross-runtime fixture retain exact received locks',()=>{
 const source=fs.readFileSync(new URL('../godot-client/tools/native-session-host.cjs',import.meta.url),'utf8'),keys=source.match(/const movementKeys=(\[[^;]+\]);/)?.[1];assert.ok(keys);assert.match(keys,/'facingTarget'/);
 const fixture=facingDeliveryFixture();assert.equal(fixture.steps.length,3);for(const step of fixture.steps){assert.equal(step.records.length,1);assert.deepEqual(step.records[0].changes,{facingTarget:step.target});assert.equal(step.records[0].initial.facingTarget,step.target);}
});
