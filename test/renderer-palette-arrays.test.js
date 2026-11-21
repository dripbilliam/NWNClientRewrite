import test from 'node:test';import assert from 'node:assert/strict';import {DataTexture,Texture,RGBAFormat,RepeatWrapping} from 'three';import {RendererPaletteArrays} from '../src/renderer_palette_arrays.js';
const texture=(n=1)=>{const t=new DataTexture(Uint8Array.from({length:16},(_,i)=>i%4===3?255:n),2,2,RGBAFormat);t.needsUpdate=true;return t;};
test('palette layers keep every source RGBA byte and sampling transform, with bounded slab ownership',()=>{
 const owner=new RendererPaletteArrays({maxLayers:2,maxBytes:64}),a=texture(3),b=texture(19),c=texture(77),d=texture(99),e=texture(33),ra=owner.get(a),rb=owner.get(b);assert.equal(ra.array,rb.array);assert.equal(ra.layer,0);assert.equal(rb.layer,1);assert.deepEqual([...ra.array.texture.image.data],[...a.image.data,...b.image.data]);assert.equal(owner.get(a),ra);const rc=owner.get(c);assert.notEqual(rc.array,ra.array);assert.equal(owner.get(d).array,rc.array);assert.equal(owner.get(e),null);assert.deepEqual(owner.snapshot(),{arrays:2,layers:4,bytes:64});let disposed=0;for(const list of owner.pools.values())for(const r of list)r.texture.addEventListener('dispose',()=>disposed++);owner.reset();assert.equal(disposed,2);assert.deepEqual(owner.snapshot(),{arrays:0,layers:0,bytes:0});
});
test('changed samplers split layers and unsupported dynamic or custom upload semantics retain 2D draws',()=>{
 const owner=new RendererPaletteArrays({maxLayers:2,maxBytes:1024}),a=texture(),r=owner.get(a);a.offset.x=.25;const changed=owner.get(a);assert.notEqual(changed.array,r.array);assert.equal(changed.array.texture.offset.x,.25);assert.deepEqual(changed.array.texture.matrix.elements,a.matrix.elements);a.needsUpdate=true;assert.equal(owner.get(a),null);for(const change of [t=>t.flipY=true,t=>t.premultiplyAlpha=true,t=>t.channel=1,t=>t.onUpdate=()=>{},t=>t.updateMatrix=()=>{},t=>t.mipmaps.push({}),t=>t.image.data=new Float32Array(16)]){const t=texture();change(t);assert.equal(owner.get(t),null);}assert.equal(owner.get(new Texture()),null);assert.equal(owner.get(null),null);owner.dispose();
});
test('power-of-two repeat images share a larger periodic layer without resampling source bytes',()=>{
 const owner=new RendererPaletteArrays({maxLayers:2,maxBytes:1024,minRepeatSize:4}),a=texture(17),b=new DataTexture(new Uint8Array(4*2*4).fill(23),4,2);a.wrapS=a.wrapT=b.wrapS=b.wrapT=RepeatWrapping;b.needsUpdate=true;const x=owner.get(a),y=owner.get(b);assert.equal(x.array,y.array);assert.deepEqual(x.uvScale,[.5,.5]);assert.deepEqual(y.uvScale,[1,.5]);assert.equal(x.array.texture.image.width,4);for(let row=0;row<4;row++)for(let col=0;col<4;col++)assert.deepEqual([...x.array.texture.image.data.slice((row*4+col)*4,(row*4+col+1)*4)],[...a.image.data.slice((row%2*2+col%2)*4,(row%2*2+col%2+1)*4)]);owner.dispose();
});

test('adaptive storage admits large textures, grows existing layer identities and stays within its bound',()=>{
 const size=1024,bytes=size*size*4,owner=new RendererPaletteArrays({maxBytes:bytes*4,maxLayers:32}),maps=Array.from({length:5},(_,i)=>{const t=new DataTexture(new Uint8Array(bytes).fill(i+1),size,size);t.needsUpdate=true;return t;});
 const first=owner.get(maps[0]),texture=first.array.texture;assert.equal(texture.image.depth,1);assert.equal(owner.bytes,bytes);let retired=0;texture.addEventListener('dispose',()=>retired++);
 const second=owner.get(maps[1]);assert.equal(second.array,first.array);assert.equal(second.array.texture,texture);assert.equal(texture.image.depth,2);assert.equal(retired,1);
 const third=owner.get(maps[2]);assert.equal(third.array,first.array);assert.equal(texture.image.depth,4);assert.equal(retired,2);owner.get(maps[3]);assert.equal(owner.get(maps[4]),null);assert.equal(owner.bytes,bytes*4);
 for(let i=0;i<4;i++)assert.ok(texture.image.data.subarray(i*bytes,(i+1)*bytes).every(v=>v===i+1));assert.equal(owner.get(maps[0]),first);owner.dispose();assert.equal(owner.bytes,0);assert.equal(retired,3);
});

test('explicit pass memo avoids repeat descriptor work and observes changes on the next pass',()=>{
 const owner=new RendererPaletteArrays({maxLayers:8,maxBytes:1024}),a=texture();let calls=0;const descriptor=owner.descriptor.bind(owner);owner.descriptor=m=>{calls++;return descriptor(m);};owner.beginPass();const first=owner.get(a);assert.equal(owner.get(a),first);assert.equal(calls,1);owner.endPass();a.offset.x=.2;owner.beginPass();assert.notEqual(owner.get(a),first);assert.equal(calls,2);owner.endPass();owner.dispose();assert.equal(owner.pass,null);
});
test('explicit larger slabs preserve all layer identities and bytes across the old 32-layer boundary',()=>{
 const owner=new RendererPaletteArrays({maxLayers:128,maxBytes:4096}),maps=Array.from({length:129},(_,i)=>texture(i)),records=maps.map(map=>owner.get(map)),first=records[0].array;
 assert.equal(first.used,128);assert.equal(first.texture.image.depth,128);assert.ok(records.slice(0,128).every(r=>r.array===first));assert.notEqual(records[128].array,first);
 for(let i=0;i<128;i++){assert.equal(records[i].layer,i);assert.deepEqual([...first.texture.image.data.subarray(i*16,(i+1)*16)],[...maps[i].image.data]);assert.equal(owner.get(maps[i]),records[i]);}
 assert.ok(owner.bytes<=4096);owner.dispose();assert.deepEqual(owner.snapshot(),{arrays:0,layers:0,bytes:0});
});
