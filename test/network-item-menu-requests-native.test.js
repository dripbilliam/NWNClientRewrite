import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {splitItemRequest,learnScrollRequest} from '../src/network_player_requests.js';
import {NativeMessageWriter} from '../src/native_message.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
test('split and scroll learning packets match unchanged original senders',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-menu-request-observations-v1.json',import.meta.url)));
 assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,30);
 for(const row of oracle.cases){const actual=row.kind==='split'?splitItemRequest(row):learnScrollRequest(row),original=Buffer.from(row.packet,'hex');assert.equal(actual.length,original.length);assert.deepEqual(Buffer.from(actual.subarray(0,-1)),original.subarray(0,-1));const used=original.at(-1)>>>5,mask=255<<(8-used)&255;assert.equal(actual.at(-1)&mask,original.at(-1)&mask);}
 for(const amount of [0,-1,65536,1.5,NaN])assert.throws(()=>splitItemRequest({itemId:1,amount}));
 for(const itemId of [-1,2**32,NaN]){assert.throws(()=>splitItemRequest({itemId,amount:1}));assert.throws(()=>learnScrollRequest({itemId}));}
});
test('original learn acknowledgement is processing acknowledgement, without an invented success field',()=>{
 const writer=new NativeMessageWriter(1);writer.create(5,0xffffffff,1);writer.writeObjectIdClient(0x80000001);writer.writeBool(0);writer.setPrefix(Uint8Array.of(80,12,14));
 const message=decodeServerGameMessage(Uint8Array.from(writer.getWriteMessage().data));
 assert.deepEqual(message,{kind:'inventory-ack',itemId:0x80000001,alternate:0,operation:'learn',major:12,minor:14});assert.equal(Object.hasOwn(message,'success'),false);
});
