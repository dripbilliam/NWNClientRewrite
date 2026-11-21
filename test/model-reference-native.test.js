import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {parseBinaryMdl} from '../src/binary_mdl.js';
import {remapModelController} from '../src/model_controller_remap.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-binary-reference-observations.json',import.meta.url)));
function fixture(c){
 const b=new ArrayBuffer(2048),d=new DataView(b),bytes=new Uint8Array(b),n=244,u=(at,v)=>d.setUint32(at,v,true),s=(at,v)=>bytes.set(new TextEncoder().encode(v),at);
 u(4,2036);s(20,'reference_probe');u(84,232);u(88,1);u(n+108,0x11);s(n+32,'reference_part');s(n+112,c.name);u(n+176,c.reattachable);s(180,'NULL');return b;
}
test('binary reference payload matches original dispatcher, including full64 bytes and signed reattachable DWORD',()=>{
 for(const row of native.rows){const node=parseBinaryMdl(fixture(row.case)).nodes[0];assert.equal(node.type,'reference');assert.deepEqual(node.reference.rawModel,row.rawModel);assert.equal(node.reference.model,row.case.name.split('\0')[0]);assert.equal(node.reference.reattachable,row.reattachable);assert.equal(node.properties.refmodel,node.reference.model);assert.equal(node.properties.reattachable,row.reattachable);assert.equal(node.nativeNode.flags98,row.flags);assert.deepEqual(node.nativeNode.referenceModelA0,row.rawModel);assert.equal(node.nativeNode.reattachableE0,row.reattachable);assert.deepEqual(row.controls.map(v=>remapModelController(v,row.flags)),row.controllers);assert.ok(node.unsupportedFeatures.includes('Referenced model attachment'));}
 assert.equal(native.rows.length,36);
});
test('truncated reference extension is rejected before its name/reattachable can be read',()=>{
 const b=fixture({name:'sample',reattachable:1}).slice(0,244+112+67),d=new DataView(b);d.setUint32(4,b.byteLength-12,true);assert.throws(()=>parseBinaryMdl(b),/range.*exceeds file size/);
});
