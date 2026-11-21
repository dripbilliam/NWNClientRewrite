import test from 'node:test';
import assert from 'node:assert/strict';
import {MapPinRuntime} from '../src/map_pin_runtime.js';
test('failed initial client map loading is recorded and queued pin delivery returns failure without fabricating a scene',async()=>{
 const area={id:1},player={id:2},client={object:player},errors=[],failure=new Error('Authored map metadata could not be loaded');
 const session={currentArea:area,player,combat:{broadcastProviders:()=>({client:()=>client})},areaMessages:{providers:()=>{throw failure;}},diagnosticContext:()=>({objectId:player.id}),report:(error,context)=>errors.push({error,context})},runtime=new MapPinRuntime(session);
 const loading=runtime.loadArea(),delivery=runtime.deliver(client,6,{},{});
 await assert.rejects(loading,error=>error===failure);assert.equal(await delivery,0);assert.equal(runtime.scene,null);assert.equal(runtime.loading,null);assert.equal(errors.length,1);assert.equal(errors[0].error,failure);assert.equal(errors[0].context.operation,'local-initial-area-map-pins');
 assert.equal(await runtime.deliver(client,1,{},{}),0);assert.equal(runtime.scene,null);assert.equal(errors.length,1);
});

test('a pin waiting for initial loading cannot be delivered into a later area scene',async()=>{
 const area={id:1},next={id:3},player={id:2},client={object:player},session={currentArea:area,player,combat:{broadcastProviders:()=>({client:()=>client})}},runtime=new MapPinRuntime(session);
 let finish;const promise=new Promise(resolve=>{finish=resolve;});runtime.loading={area,player,promise};
 const delivery=runtime.deliver(client,6,{},{}),scene={areaId:next.id};session.currentArea=next;runtime.scene=scene;runtime.loading=null;finish();
 assert.equal(await delivery,0);assert.equal(runtime.scene,scene);assert.deepEqual(scene,{areaId:next.id});
});

test('an area preview without a connected local client does not attempt a client map load',async()=>{
 const session={currentArea:{id:1},player:{id:2},combat:{broadcastProviders:()=>({client:()=>null})},areaMessages:{providers:()=>assert.fail('No client body should be packed')},report:()=>assert.fail('No failed load occurred')},runtime=new MapPinRuntime(session);
 runtime.scene={areaId:1};assert.equal(await runtime.loadArea(),null);assert.equal(runtime.scene,null);assert.equal(runtime.loading,null);assert.equal(runtime.initialFailure,null);
});
