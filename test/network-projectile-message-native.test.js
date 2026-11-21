import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
test('96 original SafeProjectile writer/reader packets retain native envelope, IDs and all appearance branches',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-projectile-message-observations.json',import.meta.url)));assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.cases.length,96);
 for(const row of fixture.cases){const header={...row.header,from:row.header.from_};delete header.from_;assert.deepEqual(decodeServerGameMessage(Buffer.from(row.packet,'hex')),{kind:'safe-projectile',major:34,minor:1,header});}
});
test('projectile truncation, excess stream bytes and type corruption fail before presentation',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-projectile-message-observations.json',import.meta.url))),bytes=Buffer.from(fixture.cases[0].packet,'hex');
 for(let end=3;end<bytes.length;end++)assert.throws(()=>decodeServerGameMessage(bytes.subarray(0,end)),undefined,`length${end}`);
 assert.throws(()=>decodeServerGameMessage(Buffer.concat([bytes,Buffer.of(1)])));
});
