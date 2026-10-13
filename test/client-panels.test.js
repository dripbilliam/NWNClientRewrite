import test from 'node:test';
import assert from 'node:assert/strict';
import { autoClosePanels,createLocalClientPanelState } from '../src/client_panels.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

test('local GUI constructor IDs/position are native defaults; no client/closed owners produce no closes',async()=>{
  const actor={id:0x80000001,nativeBarter:null,position:[0,0,0]},client=createLocalClientPanelState(actor);
  assert.equal(client.inventoryGUI.openInventory.id,invalid);assert.equal(client.storeGUI.id,invalid);assert.equal(client.storeGUI.field4,5);
  await autoClosePanels(actor,1,{client:()=>null});await autoClosePanels(actor,1,{client:()=>client});
});
test('native panel closure ordering and full 3D store/barter distance are evaluated at old actor position',async()=>{
  const actor={id:0x80000001,nativeBarter:{peerId:0x80000002},position:[0,0,0]},client=createLocalClientPanelState(actor),trace=[];
  client.inventoryGUI.openInventory.id=0x80000003;client.storeGUI.id=0x80000004;client.storeGUI.position=[0,3,0];
  const p={client:()=>client,object:()=>({id:0x80000003,objectType:9}),clientObject:c=>c.object,creature:()=>({position:[0,11,0]}),talkRange:()=>10,
    closePlaceableInventory:(o,id,flag)=>trace.push(['container',o.id,id,flag]),closeStore:(store,c,flag)=>trace.push(['store',flag]),
    closeStoreMessage:()=>trace.push(['message']),cleanBarter:()=>trace.push(['barter'])};
  await autoClosePanels(actor,1,p);assert.deepEqual(trace,[['container',0x80000003,actor.id,1],['store',1],['message'],['barter']]);
  trace.length=0;client.storeGUI.position=[0,2,0];p.creature=()=>({position:[0,10,0]});await autoClosePanels(actor,1,p);assert.deepEqual(trace,[['container',0x80000003,actor.id,1]]);
});
test('open unsupported inventory owner fails explicitly instead of just clearing its ID',async()=>{
  const actor={id:1,nativeBarter:null},client=createLocalClientPanelState(actor);client.inventoryGUI.openInventory.id=2;
  await assert.rejects(autoClosePanels(actor,1,{client:()=>client,object:()=>({id:2,objectType:6})}),/closeItemInventory/);
  assert.equal(client.inventoryGUI.openInventory.id,2);
});
