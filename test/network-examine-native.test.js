import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {NativeMessageWriter} from '../src/native_message.js';import {decodeServerGameMessage} from '../src/network_game_messages.js';import {examineRequest} from '../src/network_player_requests.js';import {NetworkWorld} from '../src/network_world.js';
const build={number:8193,revision:37,postfix:17},str=(w,s)=>w.writeStringBytes(new TextEncoder().encode(s)),loc=(w,s)=>{w.writeBool(0);str(w,s);},desc=(w,s)=>{w.writeBool(0);loc(w,s);};
const packet=(minor,write)=>{const w=new NativeMessageWriter(1);w.create(128,0xffffffff,1);write(w);w.setPrefix(Uint8Array.of(80,27,minor));return Uint8Array.from(w.getWriteMessage().data);},decode=p=>decodeServerGameMessage(p,{clientBuild:build});
test('complete original Examine writer agrees for seven IDs in native format1',()=>{
 const o=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-examine-request-observations.json',import.meta.url)));assert.equal(o.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(o.cases.length,14);for(const r of o.cases.filter(r=>r.format===1)){const a=Buffer.from(examineRequest(r)),b=Buffer.from(r.packet,'hex');assert.equal(a.length,b.length);assert.deepEqual(a.subarray(0,-1),b.subarray(0,-1));const used=b.at(-1)>>>5,mask=255<<(8-used)&255;assert.equal(a.at(-1)&mask,b.at(-1)&mask);}assert.throws(()=>examineRequest({targetId:-1}));
});
test('door/placeable descriptions preserve localized and custom forms, including empty descriptions',()=>{
 for(const minor of [4,6])for(const text of ['', 'Server description']){const v=decode(packet(minor,w=>{w.writeObjectIdServer(0x80000002);desc(w,text);}));assert.equal(v.targetId,0x80000002);assert.equal(v.description.text,text);}
 const custom=decode(packet(6,w=>{w.writeObjectIdServer(2);w.writeBool(1);str(w,'Custom override');}));assert.equal(custom.description.text,'Custom override');
});
test('creature disclosure gates preserve server name, condition, portrait, CR and wide effect IDs without local calculation',()=>{
 const v=decode(packet(3,w=>{w.writeObjectIdServer(0x80000002);desc(w,'Creature biography');w.writeBool(1);w.writeBool(1);loc(w,'Native');loc(w,'Creature');w.writeWord(3);w.writeByte(2);w.writeByte(1);w.writeBool(1);w.writeFloat(2.5);w.writeBool(1);w.writeWord(2);w.writeWord(2);w.writeWord(450);w.writeBool(0);}));assert.equal(v.challengeRating,2.5);assert.equal(v.damageLevel,2);assert.deepEqual(v.effects,[2,450]);assert.equal(v.name.firstName.text,'Native');
 const hidden=decode(packet(3,w=>{w.writeObjectIdServer(2);desc(w,'Hidden');w.writeBool(0);}));assert.equal(hidden.hasDetails,0);assert.equal(hidden.effects,undefined);assert.equal(hidden.challengeRating,undefined);
});
test('item description/identification properties use only server disclosure and invalid item closes the panel',()=>{
 const p=packet(2,w=>{w.writeObjectIdServer(0x80000003);w.writeObjectIdServer(0x80000002);w.writeBool(1);w.writeBool(0);desc(w,'Identified by server');w.writeBool(0);w.writeByte(5);w.writeInt(1);w.writeInt(35);w.writeBool(1);w.writeDword(100);w.writeWord(1);w.writeWord(1);w.writeWord(2);w.writeWord(3);w.writeByte(4);w.writeBool(1);}),v=decode(p);assert.equal(v.charges,1);assert.equal(v.baseItem,undefined);assert.equal(v.minimumLevel,5);assert.equal(v.canUse,0);assert.deepEqual(v.properties,[{type:1,subtype:2,costValue:3,uses:4,usable:1}]);
 const world=new NetworkWorld(),item={id:v.targetId,objectType:6,item:{identified:0,canUse:1}};world.registry.addObjectAtPos(item.id,item);world.apply(v);assert.equal(item.item.identified,1);assert.equal(item.item.canUse,0);assert.equal(world.registry.objects.size,1);
 assert.equal(decode(packet(2,w=>w.writeObjectIdServer(0x7f000000))).close,true);for(const length of [0,1,3,p.length-2])assert.throws(()=>decode(p.subarray(0,length)));
});
test('unidentified items omit use permission and property list; charges remain a separate wire field',()=>{
 const v=decode(packet(2,w=>{w.writeObjectIdServer(3);w.writeObjectIdServer(2);w.writeBool(0);desc(w,'Unknown item');w.writeBool(1);w.writeInt(8);w.writeInt(10);w.writeBool(0);}));assert.equal(v.charges,8);assert.equal(v.canUse,undefined);assert.equal(v.properties,undefined);assert.equal(v.value,undefined);assert.equal(v.baseItem,undefined);
});
test('trap examination preserves server success, optional name and assessment',()=>{
 for(const success of [0,1]){const v=decode(packet(5,w=>{w.writeObjectIdServer(7);w.writeBool(success);w.writeBool(1);str(w,'Server trap');w.writeByte(4);w.writeByte(2);}));assert.equal(v.success,success);assert.equal(v.name.text,'Server trap');assert.equal(v.trapType,4);assert.equal(v.assessment,2);}
});
