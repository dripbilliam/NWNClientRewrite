import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {budgeCreatures,setDoorOpenState,updatePlayerAutomaps} from '../src/world_displacement.js';
import {NativeAreaSpatialArray} from '../src/area_spatial.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-world-displacement-observations.json',import.meta.url))),basePositions=[[0,10,0],[3,10,0],[4,3,0],[10,10,0],[16,16,10],[17,10,0],[20,10,0],[30,30,0]],f=Math.fround;
const next=(values,index)=>values[Math.min(index,values.length-1)];

test('BudgeCreatures matches original bounds, candidate retention, flags and live sorted-array mutations',async()=>{
 for(const row of data.rows.filter(r=>r.mode==='budge')){
  const c=row.case,calls=[],objects=new Map((c.positions??basePositions).map((v,i)=>[100+i,{id:100+i,position:v.map(f),nativePathInfo:{ownerId:100+i}}])),spatial=new NativeAreaSpatialArray(objects),moved=new Set(),area={id:88};
  for(const id of c.ids??[100,101,102,103,104,105,106])spatial.append(id);
  let safeIndex=0,placeIndex=0;
  await budgeCreatures(area,c.origin??[10,10,0],c.min??[8,8,-1],c.max??[12,12,1],c.targetId??99,c.flag??0,{
   firstByX:(_a,x)=>{calls.push(['firstX',x]);return c.start??[...spatial.view()].findIndex(id=>objects.get(id).position[0]>=x);},ids:()=>spatial.view(),
   creature:id=>{calls.push(['creature',id]);return(c.noncreatures??[101]).includes(id)?null:objects.get(id);},position:o=>o.position,
   safePoint:(_a,point,path,flag)=>{const result=c.reorder&&moved.has(path.ownerId)?1:next(c.safe??[0],safeIndex);safeIndex++;calls.push(['safePoint',path.ownerId,point,flag]);return result;},
   door:id=>{calls.push(['door',id]);return c.target==='door'?{}:null;},placeable:id=>{calls.push(['placeable',id]);return c.target==='placeable'?{}:null;},
   doorPoint:(_o,point,flag)=>{calls.push(['doorPoint',point,flag]);return c.actionPoint??[11,11,0];},placeablePoint:(_o,point)=>{calls.push(['placeablePoint',point,null]);return c.actionPoint??[11,11,0];},
   safeLocation:(_a,point,range,path,flag,out)=>{calls.push(['safeLocation',path.ownerId,point,range,flag,[...out]]);out.splice(0,3,...next(c.outputs??[[8,9,0]],placeIndex));return next(c.placed??[1],placeIndex++);},
   setPosition:(o,point,flag)=>{calls.push(['position',o.id,point,flag]);o.position=point;moved.add(o.id);if(c.reorder)spatial.update(o);},
  });
  const label=JSON.stringify(c);assert.deepEqual(calls,row.calls,label);assert.deepEqual([...spatial.view()],row.ids,label);assert.deepEqual(Object.fromEntries([...objects].map(([id,o])=>[id,o.position])),row.positions,label);
 }
});

test('door state matches original BYTE coercion, animation, map updates and closing/opening displacement',async()=>{
 for(const row of data.rows.filter(r=>r.mode==='door')){
  const c=row.case,calls=[],door={id:99,animationState:c.old??0,nativeDoorField498:c.visible??1,nativeDoorBounds4c8:[c.min??[8,8,-1],c.max??[12,12,1]],position:c.origin??[10,10,0],nativeAnimationD8:0};
  await setDoorOpenState(door,c.state,{
   animation:(o,value)=>{calls.push(['animation',value]);o.nativeAnimationD8=value;},area:()=>{calls.push(['area']);return c.area===false?null:{};},
   updateMaps:()=>calls.push(['maps']),position:o=>o.position,budge:(_a,point,min,max,id,flag)=>calls.push(['budge',point,min,max,id,flag]),
  });
  const label=JSON.stringify(c);assert.deepEqual(calls,row.calls,label);assert.equal(door.animationState,row.state,label);assert.equal(door.nativeAnimationD8,row.animation,label);
 }
});

test('area map refresh matches original flag gate and canonical same-area creature enumeration',async()=>{
 for(const row of data.rows.filter(r=>r.mode==='maps')){
  const c=row.case,calls=[];await updatePlayerAutomaps({id:88,flags:c.flags},{
   clients:()=>{calls.push(['clients']);return c.clients.map((_,i)=>i);},clientObject:i=>{calls.push(['clientObject',i]);return c.clients[i]===null?null:{id:100+i,areaId:c.clients[i]};},
   asCreature:o=>{calls.push(['asCreature',o.id]);return c.noncreatures.includes(o.id)?null:o;},update:(o,id)=>calls.push(['update',o.id,id]),
  });assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
 assert.equal(data.rows.length,501);
});
