import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import * as THREE from 'three';
import {ModelParticlePresentation} from '../../src/model_particles.js';
import {extractPreviewFactorySource,createPreviewFactory,authoredPreviewModel,fixtureTextures,previewCounts,disposePreviewFixture,particleState,particleGraphSignature} from './preview-factory.mjs';

const source = extractPreviewFactorySource(await fs.readFile(new URL('../../src/main.js',import.meta.url),'utf8'));
function fixture(previews,options={}) {
  const factory=createPreviewFactory(source),model=authoredPreviewModel(options),textures=fixtureTextures();
  const root=factory.buildObject(model,textures,null,{previews,shareGeometry:true,managedMatrices:true}),reports=[];
  const presentation=new ModelParticlePresentation({camera:new THREE.PerspectiveCamera(),seed:12345,report:(...row)=>reports.push(row)});
  return {factory,root,textures,presentation,reports,close(){disposePreviewFixture(root,factory,textures,presentation);}};
}

test('unchecked preview UI still allocates hidden sprites; explicit opt-out removes only preview nodes',()=>{
  const baseline=fixture(true),candidate=fixture(false);
  try {
    const a=previewCounts(baseline.root),b=previewCounts(candidate.root);
    assert.equal(a.sprites,64); assert.equal(a.previews,2); assert.equal(b.sprites,0); assert.equal(b.previews,0);
    assert.equal(a.emitters,b.emitters); assert.equal(b.emitters,2); assert.equal(a.nodes-b.nodes,66);
    baseline.root.traverse(node=>{if(node.userData.emitterPreview)assert.equal(node.visible,false);});
  } finally {baseline.close();candidate.close();}
});

test('dense 48-emitter case quantifies hidden hierarchy without changing emitter count',()=>{
  const baseline=fixture(true,{emitters:48}),candidate=fixture(false,{emitters:48});
  try {assert.equal(previewCounts(baseline.root).sprites,1536);assert.equal(previewCounts(candidate.root).emitters,48);}
  finally {baseline.close();candidate.close();}
});

test('both factories retain real emitter maps and independent per-instance metadata',()=>{
  const baseline=fixture(true),candidate=fixture(false);
  try {
    const emitters=[];for(const item of [baseline,candidate])item.root.traverse(node=>{if(node.userData.mdlEmitter){assert.equal(node.material.uniforms.particleMap.value,item.textures.get('spark'));emitters.push(node);}});
    assert.notEqual(emitters[0].geometry,emitters[1].geometry);assert.notEqual(emitters[0].userData.mdlEmitter.properties,emitters[1].userData.mdlEmitter.properties);
    assert.deepEqual(emitters[0].userData.mdlEmitter,emitters[2].userData.mdlEmitter);
  } finally {baseline.close();candidate.close();}
});

test('source viewer preview remains switchable and animates its sprite atlas',()=>{
  const item=fixture(true);
  try {
    item.factory.checkbox.checked=true;item.factory.updateEmitterPreviewVisibility(item.root);item.factory.updateEmitterPreviews(item.root,.3);
    let sprites=0;item.root.traverse(node=>{if(node.userData.emitterPreview)assert.equal(node.visible,true);if(node.isSprite){sprites++;assert.ok(node.material.map);assert.ok(node.position.toArray().every(Number.isFinite));}});
    assert.equal(sprites,64);item.factory.checkbox.checked=false;item.factory.updateEmitterPreviewVisibility(item.root);
    item.root.traverse(node=>{if(node.userData.emitterPreview)assert.equal(node.visible,false);});
  } finally {item.close();}
});

test('real particle buffers, native RNG and active/free records match through motion and live emitter changes',()=>{
  const baseline=fixture(true),candidate=fixture(false);
  try {
    for(let frame=0;frame<24;frame++) {
      for(const item of [baseline,candidate]) {
        item.root.position.set(Math.sin(frame*.1),0,frame*.05);item.root.rotation.y=frame*.04;item.root.scale.setScalar(1+frame*.005);
        item.root.traverse(node=>{if(node.userData.mdlNode==='flame0')node.userData.mdlEmitterProperties={...node.children.find(c=>c.userData.mdlEmitter).userData.mdlEmitter.properties,birthrate:frame<12?16:0};});
        item.presentation.update(item.root,[.016,.033,.05][frame%3]);
      }
      assert.deepEqual(particleState(baseline.presentation),particleState(candidate.presentation),'particle state at frame '+frame);
    }
    assert.ok(baseline.presentation.random.draws>0);assert.ok(baseline.presentation.snapshot().every(row=>!row.failed&&row.active>0));
    assert.deepEqual(baseline.reports,candidate.reports);assert.ok(!baseline.reports.some(row=>row[0]==='particle.runtime-unavailable'));
  } finally {baseline.close();candidate.close();}
});

test('zero birth rate still has a real emitter that can start later',()=>{
  const item=fixture(false,{birthRate:0});
  try {
    item.presentation.update(item.root,.1);assert.equal(item.presentation.entries.size,2);
    item.root.traverse(node=>{if(node.userData.mdlEmitter)node.parent.userData.mdlEmitterProperties={...node.userData.mdlEmitter.properties,birthrate:20};});
    item.presentation.update(item.root,.1);assert.ok(item.presentation.snapshot().every(row=>!row.failed&&row.active>0));
  } finally {item.close();}
});

test('shared geometry leases and fixture texture ownership all retire after both modes',()=>{
  for(const previews of [true,false]) {
    const item=fixture(previews);let disposed=0;const textures=new Set(item.textures.values());
    for(const texture of textures)texture.addEventListener('dispose',()=>disposed++);
    item.presentation.update(item.root,.1);item.close();const stats=item.factory.pool.snapshot();
    assert.equal(stats.active,0);assert.equal(stats.owners,0);assert.equal(stats.created,stats.retired);assert.equal(item.presentation.entries.size,0);assert.equal(disposed,textures.size);
  }
});

test('particle oracle preserves emitter back-references and catches changed cyclic particle data',()=>{
  const first={active:[]};first.active.push({emitter:first,position:[1,2,3]});const second=structuredClone(first);
  assert.equal(particleGraphSignature(first),particleGraphSignature(second));second.active[0].position[0]=4;assert.notEqual(particleGraphSignature(first),particleGraphSignature(second));
});
test('particle oracle distinguishes alias changes and exceptional scalar values',()=>{
  const shared=[1,2,3];assert.notEqual(particleGraphSignature([shared,shared]),particleGraphSignature([shared,[1,2,3]]));
  for(const [a,b]of [[NaN,null],[Infinity,null],[-0,0],[undefined,null]])assert.notEqual(particleGraphSignature(a),particleGraphSignature(b));
});
test('particle oracle includes typed buffer data and rejects silently omitted callbacks',()=>{
  assert.notEqual(particleGraphSignature(new Uint8Array([1,2])),particleGraphSignature(new Uint8Array([1,3])));assert.throws(()=>particleGraphSignature({callback(){}}),/Unsupported/);
});
