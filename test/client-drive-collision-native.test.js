import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {clientDriveLine,clientDriveEdge,clientCreatureLine} from '../src/client_drive_collision.js';
test('512 original client line cases match per-tile call order, float inputs, return gates and edge clearance',async()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-drive-line-v1.json',import.meta.url)));assert.equal(oracle.cases.length,512);assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const [index,row]of oracle.cases.entries()){
  const c=row.case,trace=[],stage=(kind,args)=>{const result=c.failure===kind?c.failureResult:1;trace.push({kind,args,result});return result;};
  const p={tile:(_a,x,y)=>{const result=x>=0&&x<4&&y>=0&&y<4&&c.failure!=='tile';trace.push({kind:'tile',args:[x,y],result});return result?{x,y}:null;},
   clippedWalkable:tile=>{const value=row.clippings[`${tile.x}:${tile.y}`],result=c.failure==='clip'?c.failureResult:value.status;trace.push({kind:'clip',args:[tile.x,tile.y],result});return{...value,status:result};},
   noNonWalkTile:(_tile,a,b,...tail)=>stage('tilePoly',[...a,...b,...tail]),noNonWalkWorld:(a,b,...tail)=>stage('worldPoly',[...a,...b,...tail]),
   noCreatures:(a,b,...tail)=>stage('creatures',[...a,...b,...tail]),extensionWalkable:(...args)=>stage('extension',args)};
  const actual=await clientDriveLine({},c.from,c.to,c.radius,c.height,123,c.creatures,p);
  assert.equal(actual,row.result,`case${index}`);assert.deepEqual(trace,row.trace,`case${index} ${JSON.stringify(c)}`);
 }
});
test('32 original client endpoint traversals preserve coordinate-slot, clipping and return rules',async()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-drive-line-v1.json',import.meta.url)));assert.equal(oracle.edges.length,32);
 for(const [index,row]of oracle.edges.entries()){
  const c=row.case,trace=[],p={tile:(_a,x,y)=>{const result=x>=0&&x<4&&y>=0&&y<4&&c.failure!=='tile';trace.push({kind:'tile',args:[x,y],result});return result?{x,y}:null;},clippedWalkable:tile=>{const value=row.clippings[`${tile.x}:${tile.y}`],result=c.failure==='clip'?c.failureResult:value.status;trace.push({kind:'clip',args:[tile.x,tile.y],result});return{...value,status:result};}};
  assert.equal(await clientDriveEdge({},c.from,c.to,p),row.result,`edge${index}`);assert.deepEqual(trace,row.trace,`edge${index}`);
 }
});
test('234 original client creature queries match circle boundaries, ignored IDs, bypass and cyclic lookup state',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-creature-line-v1.json',import.meta.url)));assert.equal(oracle.cases.length,234);
 for(const [index,row]of oracle.cases.entries()){
  const c=row.case,lookups=[],objects=new Map(c.objects.filter(o=>!o.missing).map(o=>[o.id,{...o,objectType:o.type??5,radius:o.radius??.5}])),state={ids:c.ids??c.objects.map(o=>o.id),cursor:c.cursor??-1};
  const actual=clientCreatureLine(state,c.from,c.to,c.radius,c.ignoredId??123,{owner:()=>c.ownerAvailable===false?null:{id:123,field3b0_110:c.flag110??0,field3b0_114:c.flag114??0},controlledId:c.controlledId??999,controlFlag:c.controlFlag??0,object:id=>{lookups.push(id);return objects.get(id);},radius:o=>o.radius});
  assert.deepEqual({result:actual,cursor:state.cursor,lookups},{result:row.result,cursor:row.cursor,lookups:row.lookups},`case${index} ${JSON.stringify(c)}`);
 }
});
