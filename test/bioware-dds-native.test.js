import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {parseBioWareDds} from '../src/bioware_dds.js';
const buffer=(width,height,marker,size)=>{const bytes=new Uint8Array(20+size),view=new DataView(bytes.buffer);for(const[o,n]of[[0,width],[4,height],[8,marker],[12,size]])view.setUint32(o,n,true);return bytes;};
test('legacy DDS dimensions and block sizes agree with original header/attribute instructions',()=>{
 const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-dds-attributes-v1.json',import.meta.url)));assert.equal(native.cases.length,192);
 for(const row of native.cases){const texture=parseBioWareDds(buffer(row.width,row.height,row.marker,row.topMipSize));try{assert.equal(texture.image.width,row.width);assert.equal(texture.image.height,row.height);assert.equal(texture.mipmaps[0].data.length,texture.isDataTexture?row.width*row.height*4:row.topMipSize);assert.equal(Boolean(texture.isDataTexture),row.width%4!==0||row.height%4!==0);assert.equal(row.payloadOffset,row.standard?128:20);}finally{texture.dispose();}}
});
test('legacy DDS rejects truncated partial edge blocks and invalid dimensions instead of accepting an empty texture',()=>{
 assert.throws(()=>parseBioWareDds(buffer(209,273,3,209*273/2)),/top mip size/);assert.throws(()=>parseBioWareDds(buffer(0,16,3,8)),/dimensions/);assert.throws(()=>parseBioWareDds(buffer(32768,1,3,8)),/dimensions/);assert.throws(()=>parseBioWareDds(buffer(4,4,2,8)),/compression marker/);
});
