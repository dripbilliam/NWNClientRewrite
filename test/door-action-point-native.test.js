import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {doorActionPoint,nearestDoorActionPoint} from '../src/door_action_point.js';
import {parseObjectSurfaceMesh} from '../src/object_surface_mesh.js';
import {ModuleSession} from '../src/module_session.js';
test('door action and nearest placement match original state/transform/tie/fallback executions',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-door-action-point-observations.json',import.meta.url)));
 for(const row of data.rows){
  const c=row.case,calls=[],o={nativePosition:c.position??[10,20,3],nativeOrientation:c.orientation,nativeDoorSurface:{actionPoints:[c.points.slice(0,2),c.points.slice(2,4),c.points.slice(4,6)]}};
  let index=0;const p={animation:()=>c.animation,area:()=>{calls.push(['area']);return c.area?{}:null;},walkable:(_a,v)=>{calls.push(['walkable',v]);return c.walk[Math.min(index++,c.walk.length-1)];}};
  const point=c.operation==='point'?doorActionPoint(o,c.animation,c.side):await nearestDoorActionPoint(o,c.from??[10,19,3],c.force,p);
  assert.deepEqual(JSON.parse(JSON.stringify({point,calls})),JSON.parse(JSON.stringify({point:row.point,calls:row.calls})),JSON.stringify(c));
 }
});

test('normal and paired-door interaction events update the native animation cell used by landing queries',()=>{
 const door={id:2,kind:'door',animationState:0,nativeAnimationD8:22,eventObjects:{}},other={id:45,kind:'door',animationState:0,nativeAnimationD8:22},actor={id:565},scripts=[],visual=[];
 const session={transitionTarget:()=>other,queueScript:(...args)=>scripts.push(args),onDoorState:(o,previous)=>visual.push([o.id,previous,o.animationState,o.nativeAnimationD8])};
 for(const [state,animation]of [[1,50],[2,51],[0,22]]){
  door.animationState=state;ModuleSession.prototype.doorEvent.call(session,door,actor,{type:'door.stateChanged',state,script:'callback'});
  assert.equal(door.nativeAnimationD8,animation);assert.equal(other.nativeAnimationD8,animation);assert.equal(other.animationState,state);assert.equal(door.lastUsedBy,actor.id);
 }
 assert.deepEqual(visual,[[45,0,1,50],[45,1,2,51],[45,2,0,22]]);assert.equal(scripts.length,3);
});

test('DWK dummy action-point parse and default zeros match original constructor/loader',()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-door-point-loader-observations.json',import.meta.url)));
 for(const row of data.rows)assert.deepEqual(parseObjectSurfaceMesh(row.text,'door').actionPoints,row.points,row.text);
});
