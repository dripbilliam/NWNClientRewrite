import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {executeJumpToPoint,executeJumpToObject} from '../src/jump_actions.js';
import {createObjectAction,setActionParameter} from '../src/object_actions.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {PathInformation} from '../src/path_information.js';
import {cutWaypointPath} from '../src/path_walk.js';

const bits=n=>{const d=new DataView(new ArrayBuffer(4));d.setFloat32(0,n,true);return d.getInt32(0,true);};
const clean=v=>JSON.parse(JSON.stringify(v));
test('both jump owners match 1,980 original action executions and ordered lower calls',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-jump-action-observations.json',import.meta.url)));
 assert.equal(data.rows.length,1980);
 for(const row of data.rows){
  const c=row.case,calls=[],a={id:88,objectType:c.areaType??4},b={id:89,objectType:c.areaType??4},
   target={id:77,objectType:c.targetType??12,position:[3,4,5],orientation:c.orientation??[3,4,2],nativeLastClientArea4f4:89,nativePendingAreaPosition4f8:[11,12,13]},
   actor={id:99,orientation:c.orientation??[3,4,2],nativeLastClientArea4f4:c.lastArea??OBJECT_INVALID,nativeField8f8:0},associate={id:100};
  const path={raw:new DataView(new ArrayBuffer(0x100)),field8:Math.fround(c.radius??.6),
   resetInterTile:()=>calls.push(['resetInterTile']),resetGrid:()=>calls.push(['resetGrid']),resetInterArea:()=>calls.push(['resetInterArea'])};
  if(c.path!==false)actor.nativePathInfo=path;
  const n=createObjectAction(c.operation==='point'?5:48,42),values=c.operation==='point'?
   [[2,bits(1)],[2,bits(2)],[2,bits(3)],[3,c.cross?89:88],[1,c.straight??1],[2,bits(c.range??1)],[2,bits(c.facing?.[0]??0)],[2,bits(c.facing?.[1]??2)]]:
   [[3,77],[1,c.straight??1]];
  values.forEach(([type,v],i)=>setActionParameter(n,i,type,v));n.parameterCount=c.count??8;
  const p={
   dead:()=>{calls.push(['dead']);return c.dead??0;},dying:()=>{calls.push(['dying']);return c.dying??0;},
   client:id=>{calls.push(['client',id]);return c.client?{}:null;},internalClient:id=>{calls.push(['internalClient',id]);return c.client?{}:null;},
   area:o=>{calls.push(['area',o.id]);return o===actor?(c.actorArea===false?null:a):c.targetArea===false?null:c.cross?b:a;},
   inLimbo:id=>{calls.push(['inLimbo',id]);return c.limbo??0;},removeLimbo:id=>calls.push(['removeLimbo',id]),
   lookup:id=>{calls.push(['lookup',id]);return c.exists===false?null:c.cross?b:a;},
   object:id=>{calls.push(['object',id]);return c.exists===false?null:target;},
   asArea:o=>{calls.push(['asArea',o.id]);return o;},
   asObject:o=>{calls.push(['asObject',o.id]);return c.noObject?null:o;},asDoor:o=>{calls.push(['asDoor',o.id]);return o;},
   asCreature:o=>{calls.push(['asCreature',o.id]);return o.objectType===5?o:null;},
   areaById:id=>{calls.push(['areaById',id]);return c.pendingArea===false?null:b;},
   position:o=>o.position,orientation:o=>o.orientation,
   doorPoint:(_o,point,flag)=>{calls.push(['doorPoint',point,flag]);return c.doorPoint??[8,9,2];},
   openState:()=>{calls.push(['openState']);return c.open??0;},
   setAnimation:(_o,id)=>calls.push(['animation',id]),
   safeLocation:(area,point,range,path,flag,out)=>{calls.push(['safe',area.id,point,range,path.raw.getInt32(0x24,true),flag]);out.point=c.safePoint??[5,6,7];return c.safe??1;},
   closePanels:(_o,n)=>calls.push(['closePanels',n]),cutPath:()=>calls.push(['cutPath']),
   setOrientation:(_o,v)=>calls.push(['orientation',v]),setPosition:(_o,v,n)=>calls.push(['position',v,n]),
   subareas:(_o,v,id)=>calls.push(['subareas',v,id]),addToArea:(_o,a,...v)=>calls.push(['addArea',a.id,...v]),
   front:(o,id,group,params)=>calls.push(['front',o.id,id,group,params]),
   associates:()=>c.associates??[100,101],creature:id=>{calls.push(['creature',id]);return id===100?associate:null;},
  };
  const result=await(c.operation==='point'?executeJumpToPoint:executeJumpToObject)(actor,n,p);
  assert.deepEqual(clean({result,calls,field8f8:actor.nativeField8f8,pathOwner:path.raw.getInt32(0x24,true)}),clean({result:row.result,calls:row.calls,field8f8:row.field8f8,pathOwner:row.pathOwner}),JSON.stringify(c));
 }
});

test('native CutWaypointPath scalar writes accept an absent waypoint allocation',()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-cut-path-observations.json',import.meta.url)));
 for(const row of data.rows){
  const path=new PathInformation(99),r=path.raw,actor={nativePathInfo:path,position:[1,3,-2],orientation:[4,6,-5]};
  r.setInt32(0x7c,row.count,true);r.setInt32(0x98,row.index,true);r.setUint8(0x130,row.sequence);assert.equal(path.allocations.size,0);
  cutWaypointPath(actor);assert.equal(path.allocations.size,0);
  assert.deepEqual({sequence:r.getUint8(0x130),flag:r.getInt32(0x128,true),field12c:r.getInt32(0x12c,true),remaining:r.getInt32(0x134,true),position:[0,4,8].map(i=>r.getFloat32(0x138+i,true)),orientation:[0,4,8].map(i=>r.getFloat32(0x144+i,true))},row.after);
 }
});
