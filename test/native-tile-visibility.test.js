import test from 'node:test';
import assert from 'node:assert/strict';
import {projectNativeTileVisibility as project,NATIVE_TILE_VISIBILITY_MAX_TILES} from '../src/native_tile_visibility.js';

const input=(previous,change,width=3,height=2)=>({previous,change,width,height});
const state=(value,x,y)=>({state:value,x,y});
const pair=op=>[op.x,op.y,op.previous,op.new_state,op.suppress_object_updates,op.changed,op.notify_objects];

test('delta points preserve order, repeated coordinates and setter no-ops',()=>{
 const result=project(input([0,0,1,0,0,0],{mode:[false,false],points:[state(true,1,0),state(false,1,0),state(1,1,0),state(1,2,0)]}));
 assert.equal(result.available,true);
 assert.deepEqual(result.operations.map(pair),[[1,0,0,1,0,true,true],[1,0,1,0,1,true,false],[1,0,0,1,0,true,true],[2,0,1,1,0,false,false]]);
 assert.deepEqual(result.states,[0,1,1,0,0,0]);
 assert.deepEqual(result.operations.map(op=>op.sequence),[0,1,2,3]);
});

test('full nonempty replacement hides X-major before received reveals, including unchanged final state',()=>{
 const result=project(input([1,0,0,0,0,0],{mode:[1,0],points:[{x:0,y:0},{x:2,y:1}]}));
 assert.deepEqual(result.operations.slice(0,6).map(op=>[op.x,op.y]),[[0,0],[0,1],[1,0],[1,1],[2,0],[2,1]]);
 assert.equal(result.operations[0].suppress_object_updates,1);
 assert.deepEqual(pair(result.operations[6]),[0,0,0,1,0,true,true]);
 assert.equal(result.states[0],1); // Same final value still has native reveal.
 assert.deepEqual(result.states,[1,0,0,0,0,1]);
});

test('full count0 reveals all tiles; already1 tiles do not notify',()=>{
 const result=project(input([1,0,0,0,1,0],{mode:[true,false],points:[]}));
 assert.deepEqual(result.states,[1,1,1,1,1,1]);
 assert.equal(result.operations.length,6);
 assert.equal(result.operations.filter(op=>op.notify_objects).length,4);
 assert.ok(result.operations.every(op=>op.suppress_object_updates===0));
});

test('packed mode visits low-to-high bits linearly and preserves unsupplied tail',()=>{
 const previous=Array(12).fill(1);
 const result=project(input(previous,{mode:[0,1],bytes:new Uint8Array([0b10000001])},4,3));
 assert.equal(result.available,true);
 assert.deepEqual(result.states,[1,0,0,0,0,0,0,1,1,1,1,1]);
 assert.deepEqual(result.operations.map(op=>op.tile_index),[0,1,2,3,4,5,6,7]);
 assert.deepEqual(result.operations.map(op=>[op.x,op.y]),[[0,0],[1,0],[2,0],[3,0],[0,1],[1,1],[2,1],[3,1]]);
 assert.deepEqual(previous,Array(12).fill(1));
});

test('native bothtrue selects packed mode, ignoring points',()=>{
 const a=project(input([0,0,0,0,0,0],{mode:[1,1],bytes:[0b00101001],points:'unused'}));
 const b=project(input([0,0,0,0,0,0],{mode:[0,1],bytes:[0b00101001]}));
 assert.deepEqual(a,b);
 assert.equal(a.operations.length,6); // Out-of-grid high bits are ignored.
 assert.deepEqual(a.states,[1,0,0,1,0,1]);
});

test('empty packed change leaves the full map untouched',()=>{
 const result=project(input([1,0,1,0,1,0],{mode:[true,true],bytes:[]}));
 assert.deepEqual(result.states,[1,0,1,0,1,0]);
 assert.deepEqual(result.operations,[]);
});

test('JSON-number flag domain includes negative zero but normalizes native BOOL output',()=>{
 const result=project(input([1,0,0,0,0,0],{mode:[-0,0.0],points:[state(-0,0,0),state(1.0,1,0)]}));
 assert.equal(result.available,true);
 assert.ok(Object.is(result.states[0],0));
 assert.ok(Object.is(result.operations[0].new_state,0));
 assert.deepEqual(result.states,[0,1,0,0,0,0]);
});

test('out-of-area decoded BYTE points warn without inventing tiles',()=>{
 const result=project(input([0,0,0,0,0,0],{mode:[0,0],points:[state(1,3,0),state(1,2,1),state(0,255,255)]}));
 assert.equal(result.available,true);
 assert.equal(result.operations.length,1);
 assert.deepEqual(result.warnings,[{code:'missing-tile',x:3,y:0,point_index:0},{code:'missing-tile',x:255,y:255,point_index:2}]);
 assert.equal(result.states[5],1);
});

test('native integer previous state compares exactly instead of Boolean coercion',()=>{
 const result=project(input([2,-1,0,0,0,0],{mode:[0,0],points:[state(1,0,0),state(0,1,0)]}));
 assert.deepEqual(result.operations.map(pair),[[0,0,2,1,0,true,true],[1,0,-1,0,1,true,false]]);
});

test('projection is detached, does not mutate frozen inputs, and carries only copied delivery evidence',()=>{
 const previous=Object.freeze([0,0,0,0,0,0]),point=Object.freeze(state(1,0,0));
 const change=Object.freeze({mode:Object.freeze([false,false]),points:Object.freeze([point])});
 const delivery=Object.freeze({scope:'connection7/area4/observer8',serial:92});
 const value=Object.freeze({...input(previous,change),delivery});
 const a=project(value),b=project(value);
 assert.equal(a.available,true);assert.deepEqual(a,b);
 assert.notEqual(a.states,previous);assert.notEqual(a.delivery,delivery);
 a.states[0]=99;a.operations[0].previous=99;a.delivery.serial=99;
 assert.equal(previous[0],0);assert.equal(b.operations[0].previous,0);assert.equal(delivery.serial,92);
 // Separate actual deliveries may have identical payloads. This pure helper
 // must not infer duplicate traffic from bytes or maintain a hidden world map.
 assert.equal(project({...value,delivery:{scope:delivery.scope,serial:93}}).operations[0].notify_objects,true);
});

test('returned operations permit original callback-before-store replay',()=>{
 const previous=[0,0,0,0,0,0];
 const result=project(input(previous,{mode:[0,0],points:[state(1,1,0),state(0,1,0),state(1,1,0)]}));
 const live=[...previous],observed=[];
 for(const op of result.operations){
  assert.equal(live[op.tile_index],op.previous);
  if(op.notify_objects)observed.push(live[op.tile_index]);
  if(op.changed)live[op.tile_index]=op.new_state;
 }
 assert.deepEqual(observed,[0,0]);assert.deepEqual(live,result.states);
});

test('missing state and invalid flags are explicitly unavailable, with no partial operations',()=>{
 const base=input([0,0,0,0,0,0],{mode:[0,0],points:[]});
 const cases=[null,{...base,previous:null},{...base,previous:[0]},{...base,width:0},{...base,width:NaN},{...base,width:NATIVE_TILE_VISIBILITY_MAX_TILES,height:2},
  {...base,change:{}},{...base,change:{mode:[false]}},{...base,change:{mode:['0',false],points:[]}},{...base,change:{mode:[NaN,0],points:[]}},
  {...base,change:{mode:[0,0],points:[{x:0,y:0}]}},{...base,change:{mode:[0,0],points:[state('1',0,0)]}},{...base,change:{mode:[0,0],points:[state(1,-1,0)]}},
  {...base,change:{mode:[0,1],bytes:[256]}},{...base,change:{mode:[0,1]}},{...base,delivery:{scope:'',serial:1}},{...base,delivery:{scope:'x',serial:-1}}];
 for(const value of cases){const result=project(value);assert.equal(result.available,false,JSON.stringify(value));assert.equal(result.states,null);assert.deepEqual(result.operations,[]);assert.equal(typeof result.reason,'string');}
});

test('bounded full map is allowed, but excessive operation/payload lists are rejected',()=>{
 const previous=new Uint8Array(NATIVE_TILE_VISIBILITY_MAX_TILES);
 const result=project(input(previous,{mode:[1,0],points:[]},256,256));
 assert.equal(result.available,true);assert.equal(result.states.length,65536);assert.equal(result.operations.length,65536);
 assert.equal(project(input([0],{mode:[0,1],bytes:new Uint8Array(256)},1,1)).available,false);
 const points=Array(131073).fill({state:1,x:0,y:0});
 assert.equal(project(input([0],{mode:[0,0],points},1,1)).reason,'operation-limit');
});
