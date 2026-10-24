import test from 'node:test';import assert from 'node:assert/strict';
import {CompressedTexture,RGB_S3TC_DXT1_Format,RGBA_S3TC_DXT1_Format,RGBA_S3TC_DXT3_Format,RGBA_S3TC_DXT5_Format,RepeatWrapping,LinearMipmapLinearFilter} from 'three';
import {repeatS3tcMip,s3tcBlockBytes,compressedArrayShape} from '../src/compressed_texture_array.js';import {decodeS3tc} from '../src/s3tc_decode.js';import {RendererPaletteArrays} from '../src/renderer_palette_arrays.js';
const formats=[RGB_S3TC_DXT1_Format,RGBA_S3TC_DXT1_Format,RGBA_S3TC_DXT3_Format,RGBA_S3TC_DXT5_Format],data=(w,h,format,seed)=>Uint8Array.from({length:Math.ceil(w/4)*Math.ceil(h/4)*s3tcBlockBytes(format)},(_,i)=>(i*73+seed*19)&255);
function texture(w,h,format,seed=1){const levels=Array.from({length:1+Math.floor(Math.log2(Math.max(w,h)))},(_,i)=>{const width=Math.max(1,w>>i),height=Math.max(1,h>>i);return{width,height,data:data(width,height,format,seed+i)};}),t=new CompressedTexture(levels,w,h,format);t.wrapS=t.wrapT=RepeatWrapping;t.minFilter=LinearMipmapLinearFilter;t.needsUpdate=true;t.needsUpdate=true;return t;}
test('encoded repeat preserves every decoded texel, including padded final mip selectors, for all S3TC variants',()=>{
 for(const format of formats)for(const[w,h]of [[1,1],[2,2],[1,8],[2,8],[8,1],[4,2],[8,2],[4,4],[8,8]])for(const seed of [1,7,13]){const source=data(w,h,format,seed),before=decodeS3tc(source,w,h,format),encoded=repeatS3tcMip(source,w,h,16,16,format),after=decodeS3tc(encoded,16,16,format);for(let y=0;y<16;y++)for(let x=0;x<16;x++)assert.deepEqual(after.subarray((y*16+x)*4,(y*16+x+1)*4),before.subarray((y%h*w+x%w)*4,(y%h*w+x%w+1)*4));}
 assert.throws(()=>repeatS3tcMip(data(6,4,formats[0],1),6,4,12,4,formats[0]),/power-of-two/);
});
test('compressed slabs preserve authored mip sampling through growth, source-size normalization and retirement',()=>{
 for(const format of formats){const owner=new RendererPaletteArrays({compressed:true,minRepeatSize:16,maxLayers:8,maxBytes:65536}),a=texture(4,8,format),b=texture(8,16,format,2),maps=[a,b,...Array.from({length:4},(_,i)=>texture(8,8,format,i+3))],rows=maps.map(t=>owner.get(t));assert.ok(rows.every(Boolean));assert.ok(rows.every(r=>r.array===rows[0].array));assert.deepEqual(rows[0].uvScale,[.25,.5]);assert.deepEqual(rows[1].uvScale,[.5,1]);const array=rows[0].array;assert.equal(array.capacity,8);assert.equal(array.texture.mipmaps.length,5);assert.equal(array.texture.generateMipmaps,false);
  for(let layer=0;layer<maps.length;layer++)for(let mip=0;mip<5;mip++){const source=maps[layer].mipmaps[Math.min(mip,maps[layer].mipmaps.length-1)],target=array.texture.mipmaps[mip],length=target.data.length/array.capacity,decoded=decodeS3tc(target.data.subarray(layer*length,(layer+1)*length),target.width,target.height,format),expected=decodeS3tc(source.data,source.width,source.height,format);for(let y=0;y<target.height;y++)for(let x=0;x<target.width;x++)assert.deepEqual(decoded.subarray((y*target.width+x)*4,(y*target.width+x+1)*4),expected.subarray((y%source.height*source.width+x%source.width)*4,(y%source.height*source.width+x%source.width+1)*4));}
  assert.equal(owner.bytes,array.texture.mipmaps.reduce((n,m)=>n+m.data.length,0));owner.dispose();assert.deepEqual(owner.snapshot(),{arrays:0,layers:0,bytes:0});
 }
});
test('unsupported mutations, malformed mips, callback semantics and memory exhaustion keep ordinary textures',()=>{
 const a=texture(8,8,formats[0]);assert.equal(a.version,2);assert.equal(new RendererPaletteArrays().get(a),null);
 const owner=new RendererPaletteArrays({compressed:true,minRepeatSize:16,maxBytes:16});assert.equal(owner.get(a),null);owner.dispose();
 for(const change of [t=>t.needsUpdate=true,t=>t.onUpdate=()=>{},t=>t.flipY=true,t=>t.mipmaps[1].data=new Uint8Array(1),t=>t.mipmaps[1].width=99,t=>t.generateMipmaps=true]){const t=texture(8,8,formats[0]),o=new RendererPaletteArrays({compressed:true});change(t);assert.equal(o.get(t),null);o.dispose();}
 const partial=texture(16,16,formats[0]);partial.mipmaps.length=2;assert.deepEqual(compressedArrayShape(partial,1024),{width:16,height:16,levels:2,layerBytes:160});
});

test('the second initial upload cannot reuse stale compressed source bytes',()=>{
 const source=texture(8,8,formats[0]),owner=new RendererPaletteArrays({compressed:true,minRepeatSize:8});
 // Model a decoder-owned first upload followed by the loader's final upload.
 source.version=1;source.source.version=1;
 owner.beginPass();const first=owner.get(source);owner.endPass();
 const before=first.array.texture.mipmaps[0].data.slice(0,32);
 source.mipmaps[0].data[0]^=255;source.needsUpdate=true;
 owner.beginPass();const second=owner.get(source);owner.endPass();
 assert.notEqual(first,second);assert.equal(second.version,2);assert.equal(second.sourceVersion,2);
 const bytes=second.array.texture.mipmaps[0].data.subarray(second.layer*32,(second.layer+1)*32);
 assert.notDeepEqual(bytes,before);assert.deepEqual(bytes,source.mipmaps[0].data);
 source.needsUpdate=true;assert.equal(owner.get(source),null);owner.dispose();
});
