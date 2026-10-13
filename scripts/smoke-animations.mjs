// Reads installed models directly; never copies proprietary assets into the repo.
import assert from 'node:assert/strict';
import * as THREE from 'three';
import { openLocalModule } from './local-module.mjs';
import { RESOURCE_TYPE } from '../src/resource_archive.js';
import { parseModel } from '../src/model_parser.js';
import { inheritAnimations } from '../src/mdl_animation.js';
import { createModelHierarchy } from '../src/model_hierarchy.js';
import { ModelAnimator } from '../src/model_animation.js';
import { modelMaterialOptions } from '../src/model_material.js';
import { deformSkinnedVertices } from '../src/model_skinning.js';
import { animateDoorState } from '../src/door_animation.js';
import { doorCollision, toggleDoor } from '../src/door.js';

const [install, modulePath] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-animations.mjs <install> <module>');
const resolver = await openLocalModule(install, modulePath, process.env.NWN_HAK_PATH);
const models = new Map();
async function load(name) {
  if (!models.has(name)) models.set(name, parseModel(await resolver.getResource(name, RESOURCE_TYPE.MDL)));
  return models.get(name);
}
for (const name of ['ttr01_t11_01', 't_door01', 't_door02', 't_door05', 'ttr_udoor_02', 'ttr_udoor_05', 'plc_l01', 'pmd0', 'pmh0', 'c_deer', 'c_magetail']) {
  const model = await load(name);
  await inheritAnimations(model, load);
  assert.ok(model.animations.length, `${name}: no clips`);
  assert.deepEqual(model.unsupportedAnimations, [], `${name}: parser diagnostics`);
  const { root, groups } = createModelHierarchy(model);
  for (const node of model.nodes.filter(node => node.type === 'trimesh')) {
    groups.get(node.name).add(new THREE.Mesh(new THREE.BufferGeometry(), new THREE.MeshBasicMaterial(modelMaterialOptions(node))));
  }
  const helper = model.nodes.find(node=>node.name.toLowerCase()==='sam');
  if (helper) {
    const material = groups.get(helper.name).children[0].material;
    assert.equal(material.opacity,0,`${name}: helper base opacity`);
    assert.equal(material.visible,false,`${name}: helper covers visible leaf`);
    assert.equal(material.depthWrite,false,`${name}: helper writes depth`);
  }
  const skins = model.nodes.filter(node => node.skinned);
  let vertices;
  const animator = new ModelAnimator(model, root, () => {
    vertices = skins.flatMap(node => deformSkinnedVertices(node, model.nodes, groups, groups.get(node.name)));
    assert.ok(vertices.every(vertex => vertex.every(Number.isFinite)), `${name}: non-finite skin pose`);
  });
  let changedClips = 0;
  const unbound = new Set();
  const snapshot = () => [...groups.values()].flatMap(group => [
    ...group.matrixWorld.toArray(), ...group.children.filter(child => child.isMesh).map(mesh => mesh.material.opacity)
  ]).concat(vertices?.flat() ?? []);
  for (const clip of model.animations) {
    animator.play(clip.name, { loop: false });
    const before = snapshot();
    animator.update(clip.length * 0.43);
    const after = snapshot();
    assert.ok(after.every(Number.isFinite), `${name}/${clip.name}: non-finite transform`);
    if (after.some((value, index) => Math.abs(value - before[index]) > 1e-6)) changedClips++;
    for (const node of animator.missingNodes) unbound.add(node);
  }
  assert.ok(changedClips, `${name}: no clip changed a bound transform`);
  if (name === 'ttr_udoor_02') {
    const closed = {}, opened = {};
    const door = { animator, animationState: 1, states: { 0: [closed], 1: [opened] } };
    assert.equal(animateDoorState(door, 0), true);
    assert.equal(animator.clip.name, 'opening1');
    assert.deepEqual(doorCollision(door), [closed, opened]);
    assert.equal(toggleDoor(door, [0, 0, 0]).changed, false);
    animator.update(animator.clip.length + 0.01);
    assert.equal(animator.clip.name, 'opened1');
    assert.equal(animator.playing, false);
    assert.equal(animator.gameplayTransition, false);
    assert.deepEqual(doorCollision(door), [opened]);
    door.animationState = 0;
    animateDoorState(door, 1);
    assert.equal(animator.clip.name, 'closing1');
    animator.update(animator.clip.length + 0.01);
    assert.equal(animator.clip.name, 'closed');
    assert.deepEqual(doorCollision(door), [closed]);
  }
  // Equipment attached to a skeleton anchor must move without receiving its own clip.
  if (name === 'pmh0') {
    const attachment = new THREE.Group();
    const anchor = [...groups.values()].find(group => /rhand/i.test(group.name));
    assert.ok(anchor, 'Human hand attachment anchor missing');
    anchor.add(attachment);
    animator.play('walk', { loop: false });
    const before = attachment.getWorldPosition(new THREE.Vector3());
    animator.update(animator.clip.length * 0.43);
    assert.ok(before.distanceTo(attachment.getWorldPosition(new THREE.Vector3())) > 0.001, 'Hand attachment did not follow walk pose');
  }
  animator.apply(null,0);
  if (helper) assert.equal(groups.get(helper.name).children[0].material.visible,false,`${name}: helper visible after clip reset`);
  console.log(JSON.stringify({ model: name, clips: model.animations.length, changedClips, hiddenBaseHelper:Boolean(helper), skinnedMeshes: skins.length, unboundNodes: [...unbound] }));
  root.traverse(object => { if (object.isMesh) { object.geometry.dispose(); object.material.dispose(); } });
}
