import assert from 'node:assert/strict';
import test from 'node:test';
import * as THREE from 'three';
import { inheritAnimations, parseAsciiAnimations, parseBinaryAnimations } from '../src/mdl_animation.js';
import { ModelAnimator, sampleTrack } from '../src/model_animation.js';
import { deformSkinnedVertices } from '../src/model_skinning.js';
import { animateDoorState } from '../src/door_animation.js';
import { doorCollision, toggleDoor } from '../src/door.js';

const ascii = `#MAXMODEL ASCII
setsupermodel sample NULL
newanim turn sample
length 1
transtime 0.2
node dummy Bone
positionkey
0 0 0 0
1 2 4 6
endlist
orientationkey 2
0 0 0 1 0
1 0 0 1 3.141592653589793
endnode
doneanim turn sample
`;

function makeBinaryAnimation() {
  const buffer = new ArrayBuffer(1012), view = new DataView(buffer), bytes = new Uint8Array(buffer);
  const base = 12, anim = base + 240, node = base + 448;
  const str = (offset, value) => bytes.set(new TextEncoder().encode(value), offset);
  const u32 = (offset, value) => view.setUint32(offset, value, true);
  const f32 = (offset, value) => view.setFloat32(offset, value, true);
  u32(4, 1000); u32(base + 120, 232); u32(base + 124, 1); u32(base + 232, 240);
  f32(base + 164, 1); str(base + 168, 'NULL');
  str(anim + 8, 'move'); u32(anim + 72, 448); u32(anim + 76, 1); f32(anim + 112, 1); str(anim + 120, 'sample');
  str(node + 32, 'Bone'); u32(node + 84, 600); u32(node + 88, 1); u32(node + 96, 624); u32(node + 100, 8);
  u32(base + 600, 8); view.setUint16(base + 604, 2, true); view.setUint16(base + 608, 2, true); bytes[base + 610] = 3;
  [0, 1, 0, 0, 0, 2, 4, 6].forEach((value, index) => f32(base + 624 + index * 4, value));
  return buffer;
}

test('binary animation controller pools are bounded and retain every key', () => {
  const buffer = makeBinaryAnimation();
  const parsed = parseBinaryAnimations(buffer);
  assert.equal(parsed.animations[0].length, 1);
  assert.deepEqual(sampleTrack(parsed.animations[0].tracks[0], 0.5), [1, 2, 3]);
  new DataView(buffer).setUint16(12 + 608, 7, true);
  assert.throws(() => parseBinaryAnimations(buffer), /indices exceed/);
});

test('ASCII animations accept counted and endlist curves and convert axis-angle keys', () => {
  const { animations } = parseAsciiAnimations(ascii);
  assert.equal(animations[0].tracks.length, 2);
  const rotation = sampleTrack(animations[0].tracks[1], 0.5);
  assert.ok(Math.abs(rotation[2] - Math.SQRT1_2) < 1e-8);
  assert.ok(Math.abs(rotation[3] - Math.SQRT1_2) < 1e-8);
  assert.throws(() => parseAsciiAnimations(ascii.replace('1 2 4 6', '1 invalid 4 6')), /values/);
  assert.throws(() => parseAsciiAnimations(ascii.replace('doneanim turn sample', '')), /Truncated/);
});

test('Bezier position channels use relative handles and clamp endpoints', () => {
  const track = { interpolation: 'bezier', frames: [{ time: 0, value: [0], in: [0], out: [1] }, { time: 1, value: [2], in: [-1], out: [0] }] };
  assert.deepEqual(sampleTrack(track, -1), [0]);
  assert.deepEqual(sampleTrack(track, 0.5), [1]);
  assert.deepEqual(sampleTrack(track, 3), [2]);
});

function makeAnimator() {
  const model = { modelName: 'sample', nodes: [{ name: 'Bone' }], animations: parseAsciiAnimations(ascii).animations };
  const root = new THREE.Group(), bone = new THREE.Group();
  bone.userData = { mdlNode: 'Bone', mdlModel: 'sample' };
  bone.position.set(5, 6, 7); root.add(bone);
  return { model, root, bone, animator: new ModelAnimator(model, root) };
}

test('playback transforms source axes, supports pause/loop, and keeps instances independent', () => {
  const a = makeAnimator(), b = makeAnimator();
  a.animator.play('turn'); a.animator.update(0.5);
  assert.deepEqual(a.bone.position.toArray(), [1, 3, -2]);
  assert.deepEqual(b.bone.position.toArray(), [5, 6, 7]);
  a.animator.playing = false; a.animator.update(0.3); assert.equal(a.animator.time, 0.5);
  a.animator.playing = true; a.animator.update(0.75); assert.equal(a.animator.time, 0.25);
  a.animator.apply(null, 0); assert.deepEqual(a.bone.position.toArray(), [5, 6, 7]);
});

test('one-shot clips complete once and pose switching resets omitted channels', () => {
  const { animator, bone, model } = makeAnimator();
  model.animations.push({ name: 'still', length: 0, tracks: [] });
  let completed = 0;
  animator.play('turn', { loop: false, onComplete: () => completed++ }); animator.update(5); animator.update(5);
  assert.equal(completed, 1); assert.equal(animator.playing, false);
  assert.deepEqual(bone.position.toArray(), [2, 6, -4]);
  animator.pose('still'); assert.deepEqual(bone.position.toArray(), [5, 6, 7]);
});

test('door transitions use shared clips and hold collision until the authored end pose', () => {
  const { animator, model } = makeAnimator();
  model.animations[0].name = 'opening1';
  model.animations.push({ name: 'opened1', length: 0, tracks: [] }, { name: 'closed', length: 0, tracks: [] });
  const closed = {}, opened = {};
  const door = { animator, animationState: 1, states: { 0: [closed], 1: [opened] } };
  let settled = 0;
  assert.equal(animateDoorState(door, 0, () => settled++), true);
  assert.equal(animator.gameplayTransition, true);
  assert.deepEqual(doorCollision(door), [closed, opened]);
  assert.equal(toggleDoor(door, [0, 0, 0]).changed, false);
  animator.update(0.5); assert.equal(door.animating, true);
  animator.update(0.5); assert.equal(door.animating, false);
  assert.equal(animator.clip.name, 'opened1');
  assert.equal(animator.gameplayTransition, false);
  assert.deepEqual(doorCollision(door), [opened]);
  assert.equal(settled, 1);
  // Missing authored transition still selects the resting pose and releases the guard.
  door.animationState = 0;
  animateDoorState(door, 1, () => settled++);
  assert.equal(animator.clip.name, 'closed'); assert.equal(door.animating, false);
  assert.equal(settled, 2);
});

test('opacity tracks isolate instance materials', () => {
  const a = makeAnimator(), material = new THREE.MeshBasicMaterial();
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(), material); a.bone.add(mesh);
  a.model.animations[0].tracks.push({ node: 'Bone', property: 'alpha', interpolation: 'linear', frames: [{ time: 0, value: [0.25] }] });
  const animator = new ModelAnimator(a.model, a.root); animator.pose('turn');
  assert.equal(mesh.material.opacity, 0.25); assert.equal(material.opacity, 1);
  animator.apply(null, 0);
  assert.equal(mesh.material.opacity, 1); assert.equal(mesh.material.transparent, false);
  assert.equal(mesh.material.userData.animationTransparent, false);
  mesh.geometry.dispose(); mesh.material.dispose(); material.dispose();
});

test('weighted skin vertices and attached equipment follow bone playback in model space', () => {
  const { model, root, bone } = makeAnimator();
  const skin = new THREE.Group(); root.add(skin);
  root.position.set(100, 20, -70); // Placement must not get baked into mesh vertices.
  const attachment = new THREE.Group(); bone.add(attachment);
  const node = { verts: [[0, 0, 0], [1, 0, 0]], skinData: {
    boneConstantSlots: [0], weights: [[1, 0, 0, 0], [1, 0, 0, 0]], boneIndices: [[0, 65535, 65535, 65535], [0, 65535, 65535, 65535]]
  } };
  const base = JSON.stringify(node.verts);
  let vertices;
  const animator = new ModelAnimator(model, root, () => {
    vertices = deformSkinnedVertices(node, model.nodes, new Map([['Bone', bone]]), skin);
  });
  animator.play('turn', { loop: false }); animator.update(0.5);
  assert.ok(new THREE.Vector3(...vertices[0]).distanceTo(new THREE.Vector3(1, 3, -2)) < 1e-8);
  assert.ok(new THREE.Vector3(...vertices[1]).distanceTo(new THREE.Vector3(1, 3, -3)) < 1e-8);
  assert.ok(attachment.getWorldPosition(new THREE.Vector3()).distanceTo(new THREE.Vector3(101, 23, -72)) < 1e-8);
  assert.equal(JSON.stringify(node.verts), base);
});

test('inheritance preserves overrides, remaps roots, scales positions, and detects cycles', async () => {
  const parent = { modelName: 'parent', animationScale: 1, supermodel: 'NULL', animations: [{ name: 'walk', tracks: [{ node: 'parent', property: 'position', frames: [{ time: 0, value: [1, 2, 3] }] }] }, { name: 'idle', tracks: [] }] };
  const child = { modelName: 'child', animationScale: 2, supermodel: 'parent', animations: [{ name: 'idle', length: 4, tracks: [] }] };
  await inheritAnimations(child, async () => parent);
  assert.equal(child.animations.length, 2); assert.equal(child.animations[0].length, 4);
  assert.equal(child.animations[1].tracks[0].node, 'child'); assert.deepEqual(child.animations[1].tracks[0].frames[0].value, [2, 4, 6]);
  await inheritAnimations(child, async () => parent); assert.equal(child.animations.length, 2);
  assert.deepEqual(parent.animations[0].tracks[0].frames[0].value, [1, 2, 3]);
  const cycle = { modelName: 'cycle', supermodel: 'cycle', animations: [] };
  await assert.rejects(inheritAnimations(cycle, async () => cycle), /cycle/);
});
