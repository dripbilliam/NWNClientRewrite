import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import {parseNativeTga} from '../src/native_tga.js';import {TGALoader} from 'three/addons/loaders/TGALoader.js';
const file=new URL('../backups/animations/native-tga-origin-v1.json',import.meta.url);
test('TGA image upload row/column order matches unchanged original resource servicing for all origin flags',()=>{
 const oracle=JSON.parse(fs.readFileSync(file));assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,288);let genericMismatches=0;
 for(const c of oracle.cases){assert.equal(c.returnValue,1);assert.equal(c.loaded,1);const bytes=Uint8Array.from(c.input),before=bytes.slice(),image=parseNativeTga(bytes);assert.equal(image.width,c.width);assert.equal(image.height,c.height);assert.equal(image.flipY,true);assert.deepEqual(bytes,before,'Decoder mutated selected resource');
  // The adapter retains Three's normalized image and flipY=true convention;
  // undo that upload flip to compare the original raw RGB/gray storage order.
  const raw=[];for(let y=c.height-1;y>=0;y--)for(let x=0;x<c.width;x++){const i=(y*c.width+x)*4;raw.push(...image.data.slice(i,i+c.depth/8));}
  assert.deepEqual(raw,c.rawRgb,JSON.stringify({depth:c.depth,descriptor:c.descriptor}));if(c.depth>=24){const generic=new TGALoader().parse(bytes.buffer);if(generic.data.some((v,i)=>v!==image.data[i]))genericMismatches++;}
 }assert.ok(genericMismatches>0,'Control did not expose the standards/native origin mismatch');
});
test('native TGA parsing respects byte-view boundaries and does not modify backing cache data',()=>{
 const c=JSON.parse(fs.readFileSync(file)).cases.find(c=>c.depth===32&&c.descriptor===36),backing=new Uint8Array(c.input.length+16).fill(0xa5),view=backing.subarray(7,7+c.input.length);view.set(c.input);const before=backing.slice(),image=parseNativeTga(view);assert.ok(image.data.length);assert.deepEqual(backing,before);assert.throws(()=>parseNativeTga(new Uint8Array(17)),/truncated/);
});
