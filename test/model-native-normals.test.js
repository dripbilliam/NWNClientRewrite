// Deferred under the actual-tests hold. No execution is claimed.
import test from 'node:test';
import assert from 'node:assert/strict';
import {serialize,deserialize} from 'node:v8';
import {parseBinaryMdl} from '../src/binary_mdl.js';
import {prepareModelGeometry} from '../src/prepared_model_geometry.js';

function fixture({normalOffset=64}={}){
 const buffer=new ArrayBuffer(12+2048+160),d=new DataView(buffer),bytes=new Uint8Array(buffer),base=12,raw=2060,node=244;
 const u=(at,value)=>d.setUint32(at,value,true),h=(at,value)=>d.setUint16(at,value,true),f=(at,value)=>d.setFloat32(at,value,true);
 u(4,2048);u(8,160);u(84,232);u(88,1);bytes.set(new TextEncoder().encode('normal_fixture'),20);
 bytes.set(new TextEncoder().encode('surface'),node+32);u(node+108,0x21);
 u(node+0x78,1100);u(node+0x7c,1);[0,1,2].forEach((value,i)=>h(base+1100+26+i*2,value));
 u(node+0xdc,1);u(node+0x21c,0xffffffff);u(node+0x224,3);u(node+0x22c,0);h(node+0x230,3);
 u(node+0x244,normalOffset);u(node+0x248,0xffffffff);
 [[0,0,0],[1,0,0],[0,1,0]].flat().forEach((value,i)=>f(raw+i*4,value));
 const normals=[.5,.25,.125,0,1,0,0,0,-1];normals.forEach((value,i)=>f(raw+64+i*4,value));
 return {buffer,normals,raw};
}

test('binary meshes retain independent authored normal values in native coordinates',()=>{
 const {buffer,normals,raw}=fixture(),node=parseBinaryMdl(buffer).nodes[0];
 assert.ok(node.nativeVertexNormals instanceof Float32Array);assert.deepEqual([...node.nativeVertexNormals],normals);
 assert.deepEqual(node.verts,[[0,0,0],[1,0,0],[0,1,0]]);assert.equal(node.nativeVertexNormals[8],-1);
 new DataView(buffer).setFloat32(raw+64,99,true);assert.equal(node.nativeVertexNormals[0],.5,'input archive does not remain mutable backing storage');
});

test('retained normals survive worker-style cloning and prepared-model serialization without becoming generated face normals',()=>{
 const {buffer,normals}=fixture(),model=parseBinaryMdl(buffer);prepareModelGeometry(model);
 for(const copy of [structuredClone(model),deserialize(serialize(model))]){
  assert.ok(copy.nodes[0].nativeVertexNormals instanceof Float32Array);assert.deepEqual([...copy.nodes[0].nativeVertexNormals],normals);
  assert.notDeepEqual([...copy.nodes[0].preparedGeometry.normal],normals,'existing prepared rendering normals stay separate');
 }
});

test('missing normal streams remain explicit and malformed ranges are still rejected',()=>{
 assert.equal(parseBinaryMdl(fixture({normalOffset:0xffffffff}).buffer).nodes[0].nativeVertexNormals,null);
 assert.throws(()=>parseBinaryMdl(fixture({normalOffset:159}).buffer),/exceeds file size/);
});
