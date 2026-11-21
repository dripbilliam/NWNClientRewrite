import test from 'node:test';
import assert from 'node:assert/strict';
import {auditModelTextureUsage as audit} from '../performance-candidates/model-texture-usage.mjs';

const mesh = (patch = {}) => ({name:'mesh', type:'trimesh', verts:[[0,0,0],[1,0,0],[0,1,0]], faces:[[0,1,2,0,0,1,2,0]], bitmap:'visible', ...patch});
const run = (nodes, materialNames = ['visible','hidden','particle']) => audit({nodes,materialNames});

test('visible rigid and skinned meshes retain their maps', () => {
  for (const skinned of [false,true]) assert.deepEqual(run([mesh({skinned})]).selected,['visible']);
});
test('each static render suppression excludes an otherwise valid map', () => {
  for (const patch of [{render:false},{properties:{render:0}},{properties:{render:'0'}}]) assert.deepEqual(run([mesh(patch)]).selected,[]);
});
test('live opacity, scale, visibility and alpha are not pruning conditions', () => {
  assert.deepEqual(run([mesh({scale:0,alpha:0,visible:false,properties:{alpha:0}})]).selected,['visible']);
});
test('negative and animated scales retain maps', () => {
  for (const scale of [-1,1]) assert.deepEqual(run([mesh({scale,controllers:[{type:'scale'}]})]).selected,['visible']);
});
test('empty vertex and face buffers do not consume textures', () => {
  for (const patch of [{verts:[]},{faces:[]}]) assert.deepEqual(run([mesh(patch)]).selected,[]);
});
test('faces discarded by geometry construction do not consume textures', () => {
  assert.deepEqual(run([mesh({faces:[null,[],[0,1,2]]})]).selected,[]);
});
test('bad face indices fall back conservatively rather than masking errors', () => {
  const result = run([mesh({faces:[[0,1,99,0,0,1,2]]})]);
  assert.equal(result.fallback,true); assert.deepEqual(result.selected,result.catalog); assert.deepEqual(result.uncertain,['mesh']);
});
test('unknown mesh buffer representation falls back', () => {
  assert.equal(run([mesh({verts:null})]).fallback,true);
});
test('ASCII material slots are retained even when no face references them', () => {
  assert.deepEqual(run([mesh({bitmaps:['visible','hidden']})]).selected,['visible','hidden']);
});
test('binary secondary layers are recorded separately from scalar consumption', () => {
  const result = run([mesh({textureLayers:['visible','hidden']})]);
  assert.deepEqual(result.selected,['visible']); assert.deepEqual(result.skipped,['hidden','particle']);
});
test('empty ASCII material list falls back to scalar bitmap', () => {
  assert.deepEqual(run([mesh({bitmaps:[]})]).selected,['visible']);
});
test('dormant emitters keep texture despite zero birth rate or alpha', () => {
  assert.deepEqual(run([{type:'emitter',properties:{texture:'PARTICLE',birthrate:0,alphastart:0,render:0}}]).selected,['particle']);
});
test('NULL and missing emitter maps do not issue texture reads', () => {
  assert.deepEqual(run([{type:'emitter',properties:{texture:'NULL'}},{type:'emitter'}]).selected,[]);
});
test('map shared by hidden and visible meshes remains selected', () => {
  assert.deepEqual(run([mesh({render:false}),mesh()]).selected,['visible']);
});
test('case folds and deduplicates without stripping resref spaces', () => {
  assert.deepEqual(run([mesh({bitmap:' Map '})],[' Map ',' map ','NULL','']).selected,[' map ']);
});
test('catalog order is stable and distinct from node traversal order', () => {
  assert.deepEqual(run([mesh({bitmap:'hidden'}),mesh()]).selected,['visible','hidden']);
});
test('missing catalog consumption fails closed', () => {
  const result = run([mesh({bitmap:'unlisted'})]);
  assert.equal(result.fallback,true); assert.deepEqual(result.unlistedConsumed,['unlisted']); assert.deepEqual(result.selected,result.catalog);
});
test('non-mesh material-like metadata is not a renderer consumer', () => {
  assert.deepEqual(run([{type:'dummy',bitmap:'hidden'}]).selected,[]);
});
test('source metadata remains unchanged and returned lists are detached', () => {
  const model = {nodes:[mesh()],materialNames:['VISIBLE','hidden']}, copy = structuredClone(model);
  const result = audit(model); result.selected.push('new'); assert.deepEqual(model,copy);
});
