import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NativeMessageReader} from '../src/native_message.js';
import {readItemTextBubbleOverride} from '../src/network_item_text_bubble.js';
import {NetworkWorld} from '../src/network_world.js';
const original=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-caption-wire-v1.json',import.meta.url)));
test('complete original item-caption sender packets preserve IDs, signed modes, CP1252 colors and empty text',()=>{
 assert.equal(original.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(original.rows.length,72);assert.equal(original.nullItemNoPacket,true);
 for(const row of original.rows){
  const packet=Buffer.from(row.packet,'hex'),expected={kind:'item-text-bubble-override',itemId:row.itemId,mode:row.mode,text:row.text};
  const r=new NativeMessageReader(row.format);assert.equal(r.setReadMessage(packet.subarray(3),packet.length-3,0xffffffff,1),1);assert.deepEqual(readItemTextBubbleOverride(r),expected);assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);
  // The production session uses current format1, like the existing native
  // inventory/barter protocol. Format0 remains explicit low-level coverage.
  if(row.format===1){assert.deepEqual(decodeServerGameMessage(packet),{...expected,major:24,minor:5});for(let length=3;length<packet.length-1;length++)assert.throws(()=>decodeServerGameMessage(packet.subarray(0,length)));}
 }
});
test('inventory/ground/update order retains one current received item caption and never creates an unknown item',()=>{
 const world=new NetworkWorld(),id=0x80000002;world.areaId=0x80000001;
 const apply=record=>world.apply({kind:'object-updates',complete:true,records:[record]});
 apply({action:'create',objectType:6,id,state:{item:{name:{text:'Item'},field2b8:1,field2c0:'Initial'}}});
 apply({action:'update',objectType:6,id,state:{light:{field270:2,field278:'World prefix'}}});
 assert.deepEqual([world.registry.get(id).item.field2b8,world.registry.get(id).item.field2c0],[2,'World prefix']);
 const packet=original.rows.find(v=>v.format===1&&v.itemId===id&&v.mode===3&&v.text==='Plain');
 assert.equal(world.apply(decodeServerGameMessage(Buffer.from(packet.packet,'hex'))),true);
 assert.deepEqual([world.registry.get(id).item.field2b8,world.registry.get(id).item.field2c0],[3,'Plain']);
 apply({action:'inventory',channel:'R',operation:'A',id,x:0,y:0,item:{field2b8:1,field2c0:'Carried'}});
 apply({action:'create',objectType:6,id,state:{item:{field2b8:0,field2c0:''}}});
 assert.deepEqual([world.registry.get(id).item.field2b8,world.registry.get(id).item.field2c0],[0,'']);assert.equal(world.registry.get(id).inventoryLocation,null);
 const before=structuredClone([...world.registry.objects]);
 assert.equal(world.apply({kind:'item-text-bubble-override',itemId:0x80000005,mode:1,text:'Unknown'}),false);
 assert.deepEqual([...world.registry.objects],before);
});
