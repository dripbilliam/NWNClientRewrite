import assert from 'node:assert/strict';
import test from 'node:test';
import { collidesWithObjectWalkmeshes, findWalkableHeight, moveOnWalkmesh, parseDoorWalkmesh, parseWalkmesh } from '../src/walkmesh.js';
import { activeObjectCollisions, doorCollision, nearestDoor, toggleDoor } from '../src/door.js';

function floor(x0, x1, z0 = -3, z1 = 3, height = 0) {
  const a = [x0, height, z0], b = [x1, height, z0], c = [x0, height, z1], d = [x1, height, z1];
  return [{ vertices: [a, b, c] }, { vertices: [b, d, c] }];
}
function wall(x, z0, z1, height = 2) {
  return [{ vertices: [[x, 0, z0], [x, height, z0], [x, 0, z1]] },
    { vertices: [[x, height, z0], [x, height, z1], [x, 0, z1]] }];
}
function dwkNode(state, x) {
  return `node trimesh 01_DWK_wg_${state}\nposition ${x} 0 0\norientation 0 0 1 0\nverts 3\n0 0 0\n0 0 2\n0 2 0\nfaces 1\n0 1 2 0 0 0 0 7\nendnode\n`;
}

test('NWmax walkmesh header used by shipped interior tiles is accepted', () => {
  const input = '# Exported from NWmax\n#NWmax WALKMESH ASCII\n' + dwkNode('closed', 0);
  assert.equal(parseWalkmesh(input).length, 1);
  assert.equal(parseWalkmesh(('#MAXMODEL ASCII\n' + dwkNode('closed', 0)).replace('01_DWK_wg_closed', 'bearpwk')).length, 1);
});

test('DWK states remain separate and preserve object rotation', () => {
  const states = parseDoorWalkmesh('#MAXDOOR ASCII\n' + dwkNode('closed', 0) + dwkNode('open1', 2) + dwkNode('open2', -2),
    { position: [10, 20, 3], angle: Math.PI / 2 });
  assert.deepEqual(states.map(state => state.length), [1, 1, 1]);
  assert.deepEqual(states[0][0].vertices[0], [10, 3, -20]);
  assert.deepEqual(states[1][0].vertices[0], [10, 3, -22]);
  assert.deepEqual(states[2][0].vertices[0], [10, 3, -18]);
  assert.deepEqual(parseDoorWalkmesh('#MAXDOOR ASCII\n' + dwkNode('closed', 0)).slice(1), [null, null]);
});

test('swept body blocks grazing short walls and stationary overlap without blocking other floors', () => {
  const short = wall(0, 0.12, 0.16);
  assert.equal(collidesWithObjectWalkmeshes(short, [-1, 0, 0], [1, 0, 0], 0.22), true);
  assert.equal(collidesWithObjectWalkmeshes(short, [0, 0, 0], [0, 0, 0], 0.22), true);
  assert.equal(collidesWithObjectWalkmeshes(short, [-1, 4, 0], [1, 4, 0], 0.22), false);
  assert.equal(collidesWithObjectWalkmeshes(floor(-2, 2), [-1, 0, 0], [1, 0, 0], 0.22), false);
});

test('movement cannot skip an arbitrarily narrow floor gap even with zero radius', () => {
  const triangles = [...floor(-3, -0.001), ...floor(0.001, 3)];
  assert.equal(moveOnWalkmesh(triangles, [-1, 0, 0], 2, 0, 0, 0.9), null);
  assert.equal(moveOnWalkmesh(triangles, [-1, 0, 0], 2, 0, 0.22, 0.9), null);
});

test('tile seams, slopes, steps and stacked floors retain the nearby height', () => {
  const seam = [...floor(-3, 0), ...floor(0, 3)];
  assert.deepEqual(moveOnWalkmesh(seam, [-1, 0, 0], 2, 0, 0.22, 0.9), [1, 0, 0]);
  const stacked = [...seam, ...floor(-3, 3, -3, 3, 4)];
  assert.equal(findWalkableHeight(stacked, 0, 0, 0, 0.9), 0);
  assert.deepEqual(moveOnWalkmesh(stacked, [-1, 4, 0], 2, 0, 0.22, 0.9), [1, 4, 0]);
  const slope = floor(-3, 3).map(triangle => ({ vertices: triangle.vertices.map(v => [v[0], (v[0] + 3) / 6, v[2]]) }));
  const moved = moveOnWalkmesh(slope, [-1, 1 / 3, 0], 2, 0, 0.22, 0.9);
  assert.ok(Math.abs(moved[1] - 2 / 3) < 1e-8);
  assert.equal(moveOnWalkmesh([...floor(-3, 0), ...floor(0, 3, -3, 3, 2)], [-1, 0, 0], 2, 0, 0.22, 0.9), null);
  assert.equal(moveOnWalkmesh(floor(-3, 3, -0.15, 0.15), [-1, 0, 0], 2, 0, 0.22, 0.9), null);
});

test('door opening changes collision, respects locks and missing states, and closing rejects overlap', () => {
  const door = { animationState: 0, states: [wall(0, -2, 2), wall(0, 2, 4), wall(0, -4, -2)], position: [0, 0, 0], locked: true };
  const collisions = { placeables: [], doors: [door] };
  const triangles = floor(-3, 3);
  assert.equal(moveOnWalkmesh(triangles, [-1, 0, 0], 2, 0, 0.22, 0.9, activeObjectCollisions(collisions)), null);
  assert.equal(toggleDoor(door, [-1, 0, 0]).changed, false);
  door.locked = false;
  assert.equal(toggleDoor(door, [-1, 0, 0]).changed, true);
  assert.deepEqual(moveOnWalkmesh(triangles, [-1, 0, 0], 2, 0, 0.22, 0.9, activeObjectCollisions(collisions)), [1, 0, 0]);
  assert.equal(toggleDoor(door, [0, 0, 0]).changed, false);
  assert.equal(door.animationState, 1);
  assert.equal(toggleDoor(door, [1, 0, 0]).changed, true);
  door.states[1] = null;
  assert.equal(toggleDoor(door, [1, 0, 0]).changed, false);
  door.animationState = 2;
  assert.equal(doorCollision(door), door.states[2]);
  door.animationState = 3;
  assert.deepEqual(doorCollision(door), []);
});

test('targeting ignores doors on another floor and outside interaction range', () => {
  const near = { position: [1, 0, 0], animationState: 0 };
  const upper = { position: [0.1, 4, 0], animationState: 0 };
  assert.equal(nearestDoor([upper, near], [0, 0, 0]), near);
  assert.equal(nearestDoor([near], [5, 0, 0]), null);
});
