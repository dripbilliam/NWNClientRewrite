import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {storeRequest,networkStorePrice} from '../src/network_store.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NetworkWorld} from '../src/network_world.js';
import {NativeMessageWriter} from '../src/native_message.js';
const build={number:8193,revision:37,postfix:17};
test('store request encoders and open/transaction decoding agree with complete original writers',()=>{
 const f=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-store-observations.json',import.meta.url)));assert.equal(f.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(f.cases.length,80);
 for(const c of f.cases.filter(c=>c.format===1)){
  const native=Buffer.from(c.packet,'hex');if(c.kind==='open'){const m=decodeServerGameMessage(native,{clientBuild:build});assert.deepEqual([m.panel,m.sellRate,m.buyRate,m.blackMarketRate,m.identifyPrice,m.maxBuyPrice,m.gold,m.blackMarket,m.restricted,m.baseItems],[2,c.sellRate,37,20,100,25000,-1,Number(c.blackMarket),Number(c.restricted),[1,255]]);for(let n=3;n<native.length;n++)assert.throws(()=>decodeServerGameMessage(native.subarray(0,n),{clientBuild:build}));continue;}
  if(c.kind==='transaction'){const m=decodeServerGameMessage(native,{clientBuild:build});assert.equal(m.itemId,c.itemId===0x7f000000?c.itemId:(c.itemId|0x80000000)>>>0);assert.equal(m.gold,-1);assert.equal(m.success,undefined);continue;}
  const actual=Buffer.from(storeRequest({operation:c.kind,itemId:c.itemId,x:255,y:6,destinationId:0xffffffff,page:3,panel:3}));assert.equal(actual.length,native.length);if(c.kind==='close'){assert.deepEqual(actual,native);continue;}assert.deepEqual(actual.subarray(0,-1),native.subarray(0,-1));const used=native.at(-1)>>>5,mask=(255<<(8-used))&255;assert.equal(actual.at(-1)&mask,native.at(-1)&mask);
 }
 assert.throws(()=>storeRequest({operation:'buy',itemId:-1}));assert.throws(()=>storeRequest({operation:'page',page:256}));assert.throws(()=>storeRequest({operation:'open'}));
});
test('merchant coordinate/page records preserve exact following record boundaries',()=>{
 const w=new NativeMessageWriter(1);w.create(40,0xffffffff,1);const tag=s=>{for(const c of s)w.writeByte(c.charCodeAt(0));};tag('GMP');w.writeByte(4);w.writeByte(2);tag('GMU');w.writeByte(9);w.writeByte(29);w.writeObjectIdServer(123);tag('GMD');w.writeObjectIdServer(124);w.setPrefix(Uint8Array.of(80,5,1));const m=decodeServerGameMessage(Uint8Array.from(w.getWriteMessage().data),{clientBuild:build});assert.equal(m.complete,true);assert.deepEqual(m.records,[{action:'inventory',channel:'M',operation:'P',pageCount:4,panel:2},{action:'inventory',channel:'M',operation:'U',x:9,y:29,id:0x8000007b},{action:'inventory',channel:'M',operation:'D',id:0x8000007c}]);
});
test('merchant view owns no invented store ID; server changes move canonical items and replies never imply success',()=>{
 const w=new NetworkWorld(),id=0x80000011;w.localObjectId=0xffffffff;w.apply({kind:'store-open',panel:2,gold:100});const generation=w.store.generation;assert.equal(w.store.id,undefined);
 w.applyObjectUpdates([{action:'inventory',channel:'M',operation:'A',id,x:0,y:0,item:{cost:3,field454:2}}]);const item=w.registry.get(id);assert.equal(item.inventoryLocation.ownerId,null);assert.equal(item.inventoryLocation.channel,'M');w.apply({kind:'store-transaction',itemId:id,gold:103});assert.equal(item.inventoryLocation.channel,'M');assert.equal(w.store.success,undefined);
 w.applyObjectUpdates([{action:'inventory',channel:'R',operation:'A',id,x:2,y:3,item:{cost:3,field454:2}},{action:'inventory',channel:'M',operation:'D',id}]);assert.equal(w.registry.get(id),item);assert.equal(item.inventoryLocation.ownerId,w.localObjectId);assert.equal(w.inventories.get('M').entries.length,0);w.apply({kind:'store-close'});w.apply({kind:'store-open',panel:0,gold:103});assert.equal(w.store.generation,generation+1);assert.equal(w.registry.get(id),item);w.reset();assert.equal(w.store,null);
});
test('price display uses replicated rate/cost, zero/minimum and signed maximum semantics',()=>{
 const store={sellRate:150,buyRate:37,blackMarketRate:20,maxBuyPrice:-1};assert.equal(networkStorePrice(store,{cost:123},true),184);assert.equal(networkStorePrice(store,{cost:123},false),45);assert.equal(networkStorePrice(store,{cost:123,field458:1},false),24);assert.equal(networkStorePrice(store,{cost:1},false),1);assert.equal(networkStorePrice(store,{cost:0},true),0);assert.equal(networkStorePrice({...store,maxBuyPrice:20},{cost:123},false),20);
});
