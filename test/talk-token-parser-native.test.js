import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {parseTalkTokens,talkTokenHash} from '../src/talk_tokens.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-talk-token-parser-observations.json',import.meta.url))),hex=value=>Buffer.from(value).toString('hex');
test('token-name CRC matches original initializer/hash over all bytes and bounded NUL strings',()=>{
 assert.equal(native.hashRows.length,261);for(const row of native.hashRows)assert.equal(talkTokenHash(Buffer.from(row.value,'hex'),row.count),row.result);
 for(const[name,hash]of Object.entries(native.nameHashes))assert.equal(talkTokenHash(Buffer.from(name)),hash);
});
test('token parser matches complete original escaping, custom decimal wrapping, named lookup and suppression control flow',()=>{
 let compared=0,beyondBuffer=0;
 for(const row of native.rows){const c=row.case,state={suppression4c:77},calls=[],custom=c.tokens.map(r=>({id:r.id,bytes:Buffer.from(r.value,'hex')})),names=c.named?Object.entries(native.nameHashes).map(([name,hash],kind)=>({name:Buffer.from(name),hash,kind})):[];
  if(c.collision)names.splice(0,names.length,{name:Buffer.from('OTHER'),hash:native.nameHashes.NAME,kind:0});names.sort((a,b)=>a.hash-b.hash);
  let value;try{value=parseTalkTokens(Buffer.from(c.input,'hex'),state,{custom,named:names,resolve:(token,state)=>{calls.push(token.kind);if(token.kind===1||token.kind===2){state.suppression4c=token.kind===1?1:0;return new Uint8Array();}return Buffer.from(c.namedValue,'hex');}});}catch(error){if(/unterminated talk token/.test(error.message)){beyondBuffer++;continue;}throw error;}
  assert.equal(hex(value),row.value,JSON.stringify(c));assert.equal(state.suppression4c,row.suppression,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));compared++;
 }
 assert.equal(native.rows.length,580);assert.ok(compared>500);assert.ok(beyondBuffer>0);
});
