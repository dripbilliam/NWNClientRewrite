import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {deflateSync,createDeflate,constants} from 'node:zlib';
import {NetworkMessageInflater} from '../electron/network_message_inflater.mjs';
import {NetworkMessageAssembler} from '../src/network_messages.js';

function record(payload,expected,stream=false){const bytes=Buffer.alloc(payload.length+16);bytes[7]=4|(stream?1:0);bytes.writeUInt32LE(expected,12);bytes.set(payload,16);return bytes;}
test('original server persistent compressed module information decodes after packed record assembly',async()=>{
 const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-character-v1.json',import.meta.url))),assembler=new NetworkMessageAssembler(),inflater=new NetworkMessageInflater();
 for(const hex of capture.transport.applicationFrames)assembler.push(Buffer.from(hex,'hex'));
 let found=false;try{for(const message of assembler.drain()){
  const output=await inflater.decode(message.bytes);if(message.bytes[7]&4){assert.equal(output.length,157);assert.deepEqual([...output.subarray(0,3)],[80,3,1]);assert.equal(output.readUInt32LE(3),156);found=true;}
 }}finally{inflater.close();}assert.equal(found,true);
});
test('block/stream output is bounded and stream state survives consecutive sync-flush messages',async()=>{
 const inflater=new NetworkMessageInflater();try{
  assert.deepEqual(await inflater.decode(record(deflateSync(Buffer.from('block')),5)),Buffer.from('block'));
  await assert.rejects(inflater.decode(record(deflateSync(Buffer.from('oversize')),2)),/decompression failed/);
  await assert.rejects(inflater.decode(record(Buffer.alloc(0),0x1400001)),/size/);
  const deflater=createDeflate({level:7});
  async function encode(bytes){return new Promise((resolve,reject)=>{const chunks=[];const onData=b=>chunks.push(b);deflater.on('data',onData);deflater.write(bytes);deflater.flush(constants.Z_SYNC_FLUSH,error=>{deflater.removeListener('data',onData);if(error)reject(error);else resolve(Buffer.concat(chunks));});});}
  try{for(const data of [Buffer.from('first message'.repeat(60)),Buffer.from('first message'.repeat(80))])assert.deepEqual(await inflater.decode(record(await encode(data),data.length,true)),data);}finally{deflater.destroy();}
 }finally{inflater.close();}await assert.rejects(inflater.decode(Buffer.alloc(12)),/unavailable/);
});
