import test from 'node:test';import assert from 'node:assert/strict';
import {CompressedTexture,RGB_S3TC_DXT1_Format as RGB,RGBA_S3TC_DXT1_Format as BC1,RGBA_S3TC_DXT3_Format as BC2,RGBA_S3TC_DXT5_Format as BC3,Scene,Mesh,BoxGeometry,MeshLambertMaterial} from 'three';
import {compressedAlphaMinimum} from '../src/renderer_texture_alpha.js';
import {RendererOpaqueAlpha} from '../src/renderer_opaque_alpha.js';
const texture=(format,data,width=4,height=4)=>new CompressedTexture([{data:new Uint8Array(data),width,height}],width,height,format);
function bc3(a0,a1,code){const data=new Uint8Array(16);data[0]=a0;data[1]=a1;let indices=0;for(let i=0;i<16;i++)indices=indices*8+code;for(let i=2;i<8;i++){data[i]=indices%256;indices=Math.floor(indices/256);}return data;}
test('BC1 RGB alpha stays opaque while RGBA selector three uses endpoint ordering',()=>{
 const data=new Uint8Array(8);data.fill(255,4);assert.equal(compressedAlphaMinimum(texture(RGB,data)),255);assert.equal(compressedAlphaMinimum(texture(BC1,data)),0);
 data[0]=1;assert.equal(compressedAlphaMinimum(texture(BC1,data)),255);data[0]=0;data.fill(0,4);assert.equal(compressedAlphaMinimum(texture(BC1,data)),255);
});
test('BC2 checks all explicit alpha nibbles and every mip',()=>{
 const data=new Uint8Array(16).fill(255),map=texture(BC2,data);assert.equal(compressedAlphaMinimum(map),255);map.mipmaps[0].data[7]=0xa3;assert.equal(compressedAlphaMinimum(map),51);
 map.mipmaps[0].data.fill(255);map.mipmaps.push({data:new Uint8Array(16),width:2,height:2});assert.equal(compressedAlphaMinimum(map),0);
});
test('BC3 selector extraction covers the full 48-bit field and both endpoint modes',()=>{
 const descending=[250,5,215,180,145,110,75,40],ascending=[5,250,54,103,152,201,0,255];
 for(let code=0;code<8;code++){assert.equal(compressedAlphaMinimum(texture(BC3,bc3(250,5,code))),descending[code]);assert.equal(compressedAlphaMinimum(texture(BC3,bc3(5,250,code))),ascending[code]);}
 const data=bc3(255,0,0);data[7]=128;assert.equal(compressedAlphaMinimum(texture(BC3,data)),145,'last selector crosses into the high 32 bits');
 assert.equal(compressedAlphaMinimum(texture(BC3,bc3(255,255,0))),255);assert.equal(compressedAlphaMinimum(texture(BC3,bc3(255,255,6))),0);
});
test('unknown formats, malformed blocks and malformed mip dimensions stay uncertified',()=>{
 for(const map of [texture(0,new Uint8Array(8)),texture(BC3,new Uint8Array(15)),texture(RGB,new Uint8Array(8),5,4),{format:RGB,image:{width:0,height:4},mipmaps:[]}])assert.equal(compressedAlphaMinimum(map),null);
 const map=texture(RGB,new Uint8Array(8));map.mipmaps.push({data:new Uint8Array(8),width:3,height:2});assert.equal(compressedAlphaMinimum(map),null);
});
test('compressed certificates participate in alpha restoration and texture-version invalidation',()=>{
 const map=texture(BC3,bc3(255,0,0)),material=new MeshLambertMaterial({map,alphaTest:.035}),mesh=new Mesh(new BoxGeometry(),material),scene=new Scene(),owner=new RendererOpaqueAlpha();scene.add(mesh);owner.enabled=true;
 owner.prepare(scene);assert.equal(material.alphaTest,0);assert.equal(owner.snapshot().removed,1);owner.prepare(scene);assert.equal(owner.snapshot().scannedTextures,0);
 map.mipmaps[0].data.set(bc3(255,0,1));map.needsUpdate=true;owner.prepare(scene);assert.equal(material.alphaTest,.035);
 owner.dispose();map.dispose();material.dispose();mesh.geometry.dispose();
});
