import test from 'node:test';import assert from 'node:assert/strict';import * as T from 'three';
import {decodeS3tc,s3tcTexture} from '../src/s3tc_decode.js';
const colorBlock=(c0,c1,offset=0,size=8)=>{const b=new Uint8Array(size),v=new DataView(b.buffer);v.setUint16(offset,c0,true);v.setUint16(offset+2,c1,true);v.setUint32(offset+4,0xe4e4e4e4,true);return b;};
test('DXT1 RGB/RGBA palettes retain RGB-only opaque black and RGBA transparent black',()=>{
 for(const c0Greater of[true,false])for(const format of[T.RGB_S3TC_DXT1_Format,T.RGBA_S3TC_DXT1_Format]){
  const c0=c0Greater?0xf800:0x001f,c1=c0Greater?0x001f:0xf800,data=decodeS3tc(colorBlock(c0,c1),4,4,format),expected=c0Greater?[[255,0,0],[0,0,255],[170,0,85],[85,0,170]]:[[0,0,255],[255,0,0],[128,0,128],[0,0,0]];
  for(let p=0;p<16;p++){assert.deepEqual([...data.slice(p*4,p*4+3)],expected[p%4]);assert.equal(data[p*4+3],!c0Greater&&p%4===3&&format===T.RGBA_S3TC_DXT1_Format?0:255);}
 }
});
test('DXT3 honors every four-bit alpha code and uses four-color RGB even for reversed endpoints',()=>{
 const b=colorBlock(0x001f,0xf800,8,16);for(let p=0;p<16;p++)b[p>>1]|=p<<((p%2)*4);const data=decodeS3tc(b,4,4,T.RGBA_S3TC_DXT3_Format);
 for(let p=0;p<16;p++)assert.equal(data[p*4+3],p*17);assert.deepEqual([...data.slice(8,11)],[85,0,170]);
});
test('color interpolation rounds only after mixing normalized565 endpoints',()=>{
 const pixels=decodeS3tc(colorBlock(9<<11,2<<11),4,4,T.RGB_S3TC_DXT1_Format);assert.deepEqual([...pixels.slice(12,16)],[36,0,0,255]);
});
test('DXT5 covers both alpha interpolation modes and every selector including cross-byte and high bits',()=>{
 for(const[a0,a1,expected]of[[255,0,[255,0,219,182,146,109,73,36]],[0,255,[0,255,51,102,153,204,0,255]]]){
  const b=colorBlock(0x001f,0xf800,8,16);b[0]=a0;b[1]=a1;let bits=0n;for(let p=0;p<16;p++)bits|=BigInt(p%8)<<BigInt(p*3);for(let i=0;i<6;i++)b[i+2]=Number((bits>>BigInt(i*8))&255n);const data=decodeS3tc(b,4,4,T.RGBA_S3TC_DXT5_Format);
  for(let p=0;p<16;p++)assert.equal(data[p*4+3],expected[p%8]);assert.deepEqual([...data.slice(8,11)],[85,0,170]);
 }
});
test('partial edge blocks keep their exact dimensions and mip levels; aligned textures remain compressed',()=>{
 const data=new Uint8Array(32);for(let i=0;i<4;i++)data.set(colorBlock(i<2?0xf800:0x001f,0),i*8);const decoded=decodeS3tc(data,5,5,T.RGB_S3TC_DXT1_Format);assert.equal(decoded.length,100);assert.deepEqual([...decoded.slice(4*4,4*4+4)],[255,0,0,255]);assert.deepEqual([...decoded.slice(4*5*4,4*5*4+4)],[0,0,255,255]);
 const t=s3tcTexture([{width:5,height:5,data},{width:2,height:2,data:colorBlock(0xf800,0)}],5,5,T.RGB_S3TC_DXT1_Format),c=s3tcTexture([{width:4,height:4,data:colorBlock(0xf800,0)}],4,4,T.RGB_S3TC_DXT1_Format);try{assert.equal(t.isDataTexture,true);assert.equal(t.mipmaps.length,2);assert.equal(t.mipmaps[1].data.length,16);assert.equal(c.isCompressedTexture,true);}finally{t.dispose();c.dispose();}
 assert.throws(()=>decodeS3tc(new Uint8Array(8),5,5,T.RGB_S3TC_DXT1_Format),/length/);
});
