import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {openLocalModule} from '../scripts/local-module.mjs';import {NetworkWorld} from '../src/network_world.js';import {decodeServerGameMessage} from '../src/network_game_messages.js';import {loadNetworkObjectRules} from '../src/network_object_rules.js';import {parse2da} from '../src/area.js';import {decodeResourceText} from '../src/resource_archive.js';import {NetworkDriveGeometry} from '../src/network_drive_geometry.js';

test('acknowledgement connectivity uses native tiny clearance and no creature membership or appearance reads',async()=>{
 const actor={id:1,objectType:5,areaId:7,replicated:{position:[5,5,0]}},other={id:2,objectType:5,areaId:7,replicated:{position:[5.5,5,0]}},scene={area:{id:7,resRef:'fixture',width:1,height:1,tileset:'fixture',tiles:[]},world:{registry:{objects:new Map([[1,actor],[2,other]])}},resolver:{getResource:()=>{throw Error('Unexpected resource demand');}},tables:{},report:()=>{throw Error('Unexpected collision diagnostic');}},geometry=new NetworkDriveGeometry(scene),widths=[];
 geometry.geometry.providers=()=>({tile:()=>({}),clippedWalkable:(_t,a,b)=>({status:1,entry:a.slice(0,2),exit:b.slice(0,2),minHeight:0,maxHeight:0}),noNonWalkTile:(_t,_a,_b,low,high,radius)=>{widths.push({low,high,radius});return 1;}});
 const membership={ids:[99],cursor:3};geometry.creatureMembership=membership;let trace;const clear=await geometry.query(actor,{acknowledgement:true,capture:t=>trace=t});assert.equal(await clear([5,5,0],[6,5,0]),true);assert.equal(trace.radius,1/64);assert.equal(trace.height,1/64);assert.equal(trace.objects.length,0);assert.equal(geometry.creatureMembership,membership);assert.ok(widths.every(w=>w.radius===1/64));
});
test('installed area WOK/PWK/DWK preview queries use private geometry and never mutate replicated objects',async()=>{
 const root='../FullDecomp/NwnRootInstall',resolver=await openLocalModule(root,root+'/data/nwm/Prelude.nwm'),rules=await loadNetworkObjectRules(resolver),world=new NetworkWorld(),report=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v65.json',import.meta.url)));let area;
 for(const hex of report.wireMessages){const message=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(message);if(message.kind==='client-area')area=message.area;if(area&&world.registry.get(world.localObjectId)?.appearance)break;}
 const names=['appearance','genericdoors','doortypes'],tables=Object.fromEntries(await Promise.all(names.map(async name=>[name,parse2da(decodeResourceText(await resolver.getResource(name,2017)))]))),before=structuredClone([...world.registry.objects]),issues=[],scene={world,area,resolver,tables,objects:new Map([...world.registry.objects]),report:(...args)=>issues.push(args)},geometry=new NetworkDriveGeometry(scene),actor=world.registry.get(world.localObjectId),p=actor.replicated.position;
 let projections=0;const prepare=geometry.obstacles.bind(geometry);geometry.obstacles=(...args)=>{projections++;return prepare(...args);};
 const query=await geometry.query(actor),result=[];for(const d of [[.1,0],[-.1,0],[0,.1],[0,-.1]])result.push(await query(p,[p[0]+d[0],p[1]+d[1],p[2]]));assert.equal(projections,1);assert.ok(result.some(Boolean));assert.deepEqual([...world.registry.objects],before);assert.equal(issues.length,0);assert.ok(geometry.geometry.tiles.size>0);
 await geometry.clear(p,[p[0]+.1,p[1],p[2]],actor);assert.equal(projections,2,'The next input tick refreshes the private collision projection');
 const warm=geometry.query(actor);assert.equal(typeof warm,'function','An unchanged physical projection must be ready without an async frame boundary');assert.equal(typeof warm(p,[p[0]+.1,p[1],p[2]]),'boolean','Already-loaded installed WOK/PWK/DWK must complete collision synchronously');
});

test('client collision snapshots use the active server radius table, retain their tick pose and do not leak across scenes',async()=>{
 const make=radius=>{
  const actor={id:1,objectType:5,areaId:7,appearance:{appearance:0},replicated:{position:[5,5,0]}},other={id:2,objectType:5,areaId:7,appearance:{appearance:0},replicated:{position:[5.5,5.5,0]}},objects=new Map([[1,actor],[2,other]]);
  const scene={area:{id:7,resRef:'fixture',width:1,height:1,tileset:'same_name',tiles:[]},world:{registry:{objects}},resolver:{getResource:()=>{throw Error('Unexpected resource read');}},tables:{appearance:{columns:['PERSPACE','HEIGHT'],orderedRows:[{PERSPACE:String(radius),HEIGHT:'1'}]}},report:()=>{throw Error('Unexpected collision diagnostic');}},geometry=new NetworkDriveGeometry(scene);
  geometry.geometry.providers=()=>({tile:()=>({}),clippedWalkable:(_tile,a,b)=>({status:1,entry:a.slice(0,2),exit:b.slice(0,2),minHeight:0,maxHeight:0}),noNonWalkTile:()=>1});return{geometry,actor,other,objects};
 };
 const a=make(.3),b=make(.1),before=structuredClone([...a.objects]),qa=await a.geometry.query(a.actor),qb=await b.geometry.query(b.actor);
 assert.equal(await qa([5,5,0],[6,5,0]),false);assert.equal(await qb([5,5,0],[6,5,0]),true);assert.deepEqual([...a.objects],before);
 a.other.replicated.position=[8,8,0];assert.equal(await qa([5,5,0],[6,5,0]),false,'A tick retains its private pose');
 assert.equal(await(await a.geometry.query(a.actor))([5,5,0],[6,5,0]),true,'The next tick observes the updated canonical position');assert.equal(await qb([5,5,0],[6,5,0]),true);
 a.other.replicationRemoved=true;const removed=await a.geometry.query(a.actor);assert.equal(await removed([5,5,0],[6,5,0]),true);assert.equal(await qa([5,5,0],[6,5,0]),false,'A later membership change must not erase the old query snapshot');
 a.objects.set(3,{id:3,objectType:5,areaId:7,appearance:{appearance:0},replicated:{position:[8,8,0]}});await a.geometry.query(a.actor);assert.equal(await qa([5,5,0],[6,5,0]),false,'An added ID cannot terminate an older query with an absent lookup');
});

function obstacleFixture(){
 const placeable={id:7,objectType:9,areaId:1,replicated:{appearance:0,position:[2,3,0],orientation:[1,0,0],hitPoints:10}},objects=new Map([[7,placeable]]),scene={area:{id:1,tiles:[]},world:{registry:{objects}},resolver:{},tables:{},report:()=>{}},geometry=new NetworkDriveGeometry(scene),mesh={vertices:[[0,0,0],[1,0,0],[0,1,0]],faces:[[0,1,2]]};let reads=0;
 geometry.resources.placeableMesh=async()=>{reads++;return{mesh};};return{geometry,placeable,objects,reads:()=>reads,mesh};
}

test('obstacle cache ignores nonphysical replication but invalidates poses, appearance and membership',async()=>{
 const f=obstacleFixture(),before=structuredClone(f.placeable),initial=await f.geometry.obstacles();assert.equal(initial.store.objectCount,1);
 f.placeable.replicated.hitPoints--;f.placeable.replicated.visualEffects=[{id:5}];f.placeable.replicated.inventory={items:[1,2,3]};
 assert.equal(await f.geometry.obstacles(),initial);assert.equal(f.reads(),1,'Nonphysical traffic must not rebuild obstacle polygons');
 for(const change of [()=>f.placeable.replicated.position[0]++,()=>f.placeable.replicated.orientation=[0,1,0],()=>f.placeable.replicated.appearance++]){
  const previous=await f.geometry.obstacles();change();assert.notEqual(await f.geometry.obstacles(),previous);
 }
 assert.equal(f.reads(),4);f.placeable.replicationRemoved=true;assert.equal((await f.geometry.obstacles()).store.objectCount,0);f.placeable.replicationRemoved=false;assert.equal((await f.geometry.obstacles()).store.objectCount,1);f.placeable.areaId=2;assert.equal((await f.geometry.obstacles()).store.objectCount,0);
 assert.deepEqual(before.replicated.position,[2,3,0]);
});

test('obstacle pose is a tick snapshot even if canonical arrays change during an asynchronous mesh read',async()=>{
 const f=obstacleFixture();let ready;const gate=new Promise(resolve=>ready=resolve);f.geometry.resources.placeableMesh=async()=>{await gate;return{mesh:f.mesh};};
 const pending=f.geometry.obstacles();f.placeable.replicated.position[0]=12;ready();const first=await pending,next=await f.geometry.obstacles();
 assert.notEqual(first,next);assert.equal(first.store.bounds[0],2);assert.equal(next.store.bounds[0],12);
});

test('door collision cache observes opening state, model selectors and pose while ignoring HP',async()=>{
 const f=obstacleFixture(),door=f.placeable;door.objectType=10;door.replicated={doorType:0,genericType:0,doorOpenState:0,position:[2,3,0],orientation:[1,0,0]};
 f.geometry.scene.tables={genericdoors:{rows:new Map([[0,{ModelName:'door_a'}],[1,{ModelName:'door_b'}]])},doortypes:{rows:new Map([[1,{Model:'door_c'}]])}};const selected=[];f.geometry.resources.objectMesh=async name=>{selected.push(name);return{states:[f.mesh,f.mesh,f.mesh]};};
 let prior=await f.geometry.obstacles();assert.equal(prior.doors.get(door.id).nativeAnimation,22);door.replicated.hitPoints=15;assert.equal(await f.geometry.obstacles(),prior);
 for(const change of [()=>door.replicated.doorOpenState=1,()=>door.replicated.genericType=1,()=>door.replicated.doorType=1,()=>door.replicated.position[1]++,()=>door.replicated.orientation=[0,1,0]]){change();const next=await f.geometry.obstacles();assert.notEqual(next,prior);assert.equal(next.doors.get(door.id).nativeAnimation,50);prior=next;}
 assert.deepEqual(selected,['door_a','door_a','door_b','door_c','door_c','door_c']);
});

test('opt-in collision trace captures exact private inputs and query results without changing them',async()=>{
 const f=obstacleFixture(),actor={id:1,objectType:5,areaId:1,appearance:{appearance:0},replicated:{position:[5,5,0]}},other={id:2,objectType:5,areaId:1,appearance:{appearance:0},replicated:{position:[5.5,5.5,0]}};
 f.objects.set(1,actor);f.objects.set(2,other);f.geometry.scene.tables.appearance={columns:['PERSPACE','HEIGHT'],orderedRows:[{PERSPACE:'.3',HEIGHT:'1'}]};
 f.geometry.geometry.providers=()=>({tile:()=>({}),clippedWalkable:(_tile,a,b)=>({status:1,entry:a.slice(0,2),exit:b.slice(0,2),minHeight:0,maxHeight:0}),noNonWalkTile:()=>1});
 let trace;const query=await f.geometry.query(actor,{capture:t=>trace=t}),from=[5,5,0],to=[6,5,0];assert.equal(trace.actorId,1);assert.equal(trace.radius,Math.fround(.3));assert.deepEqual(trace.queries,[]);
 other.replicated.position=[8,8,0];assert.equal(await query(from,to),false);assert.deepEqual(trace.queries,[{from,to,clear:false}]);assert.deepEqual(trace.objects.find(o=>o.id===2).position,[5.5,5.5,0]);
 trace.objects.find(o=>o.id===2).position[0]=100;trace.obstacles[0].position[0]=100;assert.equal(await query(from,to),false);assert.equal((await f.geometry.obstacles()).inputs[0].position[0],2);
 assert.equal(await(await f.geometry.query(actor))(from,to),true,'A normal query still uses fresh inputs without a trace');
});
