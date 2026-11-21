import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
const {exactNpcCharacter}=createRequire(import.meta.url)('../godot-client/tools/native-npc-combat-character.cjs');
test('NPC fixture returns the same exact read buffer and independent original/upload hashes without adding fields',()=>{const input=Buffer.from([0,1,2,3,127,128,255]),before=Buffer.from(input),result=exactNpcCharacter(input);assert.equal(result.bytes,input);assert.deepEqual(input,before);assert.equal(result.metadata.originalSha256,createHash('sha256').update(before).digest('hex'));assert.equal(result.metadata.uploadedSha256,result.metadata.originalSha256);assert.equal(result.metadata.uploadedUnchanged,true);assert.equal('xp'in result.metadata,false);assert.deepEqual(Object.keys(result),['bytes','metadata']);});
test('empty or absent fixture bytes are unavailable',()=>{for(const value of [null,undefined,Buffer.alloc(0),'BIC V3.2'])assert.throws(()=>exactNpcCharacter(value));});
test('typed arrays are not silently reinterpreted as the actual file read',()=>{assert.throws(()=>exactNpcCharacter(Uint8Array.from([1,2])));});
