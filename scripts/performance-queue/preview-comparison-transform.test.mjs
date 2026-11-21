import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {transformPreviewComparison,previewComparisonHooks,previewComparisonModes,previewComparisonPairs} from './preview-comparison-transform.mjs';
const source=await fs.readFile(new URL('../../src/main.js',import.meta.url),'utf8');
test('QA transform changes precisely two gameplay call sites and preserves production builder/template',()=>{
  const result=transformPreviewComparison(source);
  assert.deepEqual(result.edits,['network-instance','gameplay-standalone']);
  assert.ok(result.code.includes('createRoot:asset=>buildObject(asset.model,asset.textures,asset.override,{previews:false,shareGeometry:true,managedMatrices:true})'));
  const a=source.slice(source.indexOf('function buildObject('),source.indexOf('function addModelLight('));
  assert.ok(result.code.includes(a));assert.ok(!source.includes('qaOmitGameplayPreviews'));
});
test('changed or duplicated gameplay call sites reject rather than applying an approximate patch',()=>{
  const anchor='buildObject(asset.model,asset.textures,asset.override,{shareGeometry:true,managedMatrices:true})';
  assert.throws(()=>transformPreviewComparison(source.replace(anchor,'unavailable()')),/call-site drift/);
  assert.throws(()=>transformPreviewComparison(source+'\n'+anchor),/call-site drift/);
});
test('QA source cannot be transformed twice',()=>{
  assert.throws(()=>transformPreviewComparison(transformPreviewComparison(source).code),/already present/);
});
test('baseline is default, toggling records no edits to an existing scene and invalid input rejects',()=>{
  const nodes=[{userData:{}},{userData:{emitterPreview:true}},{userData:{emitterParticle:{}}},{userData:{mdlEmitter:{}}}];
  const original=structuredClone(nodes),window={},networkPresentation={root:{traverse:fn=>nodes.forEach(fn)}};
  new Function('window','networkPresentation','previewEffectsEnabled','usePersistentModelPreparation','rendererMainBatches','prepareMatrixSubtrees','modelParticles',previewComparisonHooks)(window,networkPresentation,{checked:false},false,{enabled:false},false,{snapshot:()=>[]});
  assert.equal(window.gameplayPreviewAuditForTest().omit,false);window.setGameplayPreviewsForTest(true);
  assert.deepEqual(window.gameplayPreviewAuditForTest(),{omit:true,previewChecked:false,persistentModelPreparation:false,mainBatches:false,matrixSubtrees:false,failedEmitters:0,rootPresent:true,nodes:4,previews:1,previewSprites:1,emitters:1});
  assert.deepEqual(nodes,original);assert.throws(()=>window.setGameplayPreviewsForTest('true'),/requires boolean/);
});
test('paired sequence has warmups and same-area baseline neighbors for four candidate visits',()=>{
  assert.equal(previewComparisonModes.length,12);assert.deepEqual(previewComparisonModes.slice(0,4),[false,false,false,false]);
  assert.equal(previewComparisonPairs.length,4);
  for(const [before,candidate,after]of previewComparisonPairs){assert.equal(previewComparisonModes[before],false);assert.equal(previewComparisonModes[candidate],true);assert.equal(previewComparisonModes[after],false);assert.equal(before%2,candidate%2);assert.equal(after%2,candidate%2);}
});
