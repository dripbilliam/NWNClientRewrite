import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {executeRandomWalk,scriptRandomWalk} from '../src/random_walk.js';
import {getObjectLocked} from '../src/lock_query.js';
import {getItemBaseType} from '../src/item_query.js';
import {NativeAIMaster} from '../src/native_ai_master.js';
import {ModuleSession} from '../src/module_session.js';
import {createObjectActionState,addObjectAction} from '../src/object_actions.js';
import {normalizeOrientation} from '../src/combat_lifecycle.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-wandering-observations.json',import.meta.url))),f=Math.fround;
const bits=v=>{const a=new DataView(new ArrayBuffer(4));a.setFloat32(0,v,true);return a.getInt32(0,true);};
const action=n=>['action',n.actionId,n.groupId,Array.from({length:n.parameterCount},(_,i)=>[n.parameterTypes[i],n.parameterData[i]])];
test('random-walk full native body agrees on disposal, level waits, CRT draws, shortening and front-move flags',async()=>{
  assert.equal(capture.walk.length,194);
  for(const row of capture.walk){const c=row.case,calls=[],state=createObjectActionState(),area={},o={objectActionState:state,nativeAILevel7c:c.level,nativePathInfo:c.hasPath?{field4:f(.5),fieldC:f(1.7)}:null};
    for(let i=0;i<c.queued;i++)addObjectAction(state,30,9);
    const node=addObjectAction(createObjectActionState(),45,9,[...c.origin.map(v=>({type:2,value:bits(v)})),{type:3,value:77}]);let disposed=0,draw=0,line=0;
    const result=await executeRandomWalk(o,node,{areaById:()=>c.hasArea?area:null,position:()=>c.position,dispose:()=>calls.push(['dispose',++disposed]),random:()=>{const n=c.draws[draw++];calls.push(['rand',n]);return n;},height:(_a,p)=>{calls.push(['height',p.slice()]);return c.height;},
      magnitude:v=>f(Math.sqrt(f(f(f(v[0]*v[0])+f(v[1]*v[1]))+f(v[2]*v[2])))),normalize:v=>{const n=normalizeOrientation([v[0],v[2],-v[1]]);return[n[0],-n[2],n[1]];},
      directLine:(_a,from,to,r,h,flag)=>{calls.push(['line',from.slice(0,2),to.slice(0,2),r,h,flag]);return Number(line++>=c.blocked);},moveFront:(_o,...args)=>calls.push(['move',...args])});
    // Capture front additions at their insertion points, before random/height.
    const additions=result===3?[]:[...state.list].reverse().map(action),offset=c.queued;
    calls.splice(offset,0,...additions);
    assert.deepEqual({result,calls},{result:row.result,calls:row.calls},JSON.stringify(c));
  }
});
test('base-item query matches20 raw signed native field and invalid-item wrapper returns',()=>{
  assert.equal(capture.baseitems.length,20);
  for(const row of capture.baseitems){const c=row.case,o=c.found?{objectType:c.kind==='item'?6:5,baseItem:c.baseItem}:null;assert.equal(getItemBaseType(o)>>>0,row.pushed);}
});
test('native random-walk wrapper preserves XYZ float bits, area ID and commandability gate',()=>{
  assert.equal(capture.commands.length,24);
  for(const row of capture.commands){const c=row.case,state=createObjectActionState(),o={objectType:5,nativeFieldEc:c.commandable,objectActionState:state};
    scriptRandomWalk(c.selfValid===1&&c.found?o:null,{position:()=>[1,2,3],area:()=>c.hasArea?{id:77}:null});
    const actual=[...state.list].map(n=>action({...n,groupId:65535}));assert.deepEqual(actual,row.calls,JSON.stringify(c));
  }
});
test('native lock query retains raw signed values and rejects unrelated/missing canonical objects',()=>{
  assert.equal(capture.locks.length,30);
  for(const row of capture.locks){const c=row.case,o=c.found?{objectType:({door:10,placeable:9,creature:5})[c.kind],locked:c.locked}:null;assert.equal(getObjectLocked(o)>>>0,row.pushed);}
});
test('location area accessor retains stale and high-bit area IDs without object lookup',()=>{
  const s=new ModuleSession({}),query=s.commands.GetAreaFromLocation;
  for(const row of capture.locations)assert.equal(query([{areaId:row.case.areaId}]),row.pushed);
});
test('native AI removal preserves locked metadata, capacity and cursor, including >16 last-match selection',()=>{
  assert.equal(capture.removals.length,100);
  for(const row of capture.removals){const c=row.case,m=new NativeAIMaster();for(const list of m.levels){for(const id of c.ids)list.append(id);list.cursor=7;}
    const capacities=m.levels.map(l=>l.capacity),o={id:123,nativeAILevel7c:c.level,nativeAILocked80:1};
    assert.equal(m.removeObject(o),row.result);assert.equal(o.nativeAILevel7c,row.level);assert.equal(o.nativeAILocked80,row.lock);
    assert.deepEqual(m.levels.map(l=>[...l.view()]),row.lists);assert.deepEqual(m.levels.map(l=>l.cursor),row.cursors);assert.deepEqual(m.levels.map(l=>l.capacity),capacities);
  }
});
