import test from 'node:test';
import assert from 'node:assert/strict';
import { parse2da } from '../src/area.js';
import { parseTileSurfaceMesh } from '../src/tile_surface_mesh.js';
import { tileLOSMaterials, intersectLOSBox, hitLOSPolygon, clearTileSurfaceLOS, clipAreaTileLOS, clearAreaTileLOS } from '../src/tile_los.js';

const table = parse2da('2DA V2.0\n\nWalk LineOfSight\n0 1 0\n1 0 1\n2 0 2\n32 0 1\n');
const text = `node aabb collision
position 0 0 0
verts 3
0 -2 0
0 2 0
0 0 4
faces 1
0 1 2 0 0 0 0 1
aabb 0 -2 0 0 2 4 0
endnode`;

test('LOS material mask reads physical rows, accepts only integer1 and retains64 bits', () => {
  assert.equal(tileLOSMaterials(table), 10n); // Authored label32 is physical row3.
  const rows = Array.from({ length: 64 }, (_, i) => `${i} 0 ${i === 63 ? 1 : 0}`).join('\n');
  assert.equal(tileLOSMaterials(parse2da(`2DA V2.0\n\nWalk LineOfSight\n${rows}\n`)), 1n << 63n);
});

test('native box query returns inside sentinel, six entry faces, shared-outcode rejection and inclusive contacts', () => {
  const min = [0, 0, 0], max = [2, 2, 2];
  assert.equal(intersectLOSBox([0, 1, 1], [-5, 1, 1], min, max), -1);
  for (let axis = 0; axis < 3; axis++) for (let high = 0; high < 2; high++) {
    const from = [1, 1, 1]; from[axis] = high ? 3 : -1;
    assert.equal(intersectLOSBox(from, [1, 1, 1], min, max), axis * 2 + high + 1);
  }
  assert.equal(intersectLOSBox([-1, -1, 1], [-2, 3, 1], min, max), 0);
  assert.equal(intersectLOSBox([-1, 1, 1], [1, 3, 1], min, max), 1);
});

test('native polygon LOS is one-sided with inclusive triangle edges and coplanar rejection', () => {
  const polygon = [[0, 0, 0], [2, 0, 0], [0, 2, 0]], normal = [0, 0, 1];
  assert.deepEqual(hitLOSPolygon(polygon, normal, 0, [1, 1, 2], [1, 1, -2]), [1, 1, 0]);
  assert.equal(hitLOSPolygon(polygon, normal, 0, [1, 1, -2], [1, 1, 2]), null);
  assert.equal(hitLOSPolygon(polygon, normal, 0, [1, 1, 0], [0, 0, 0]), null);
  assert.equal(hitLOSPolygon(polygon, normal, 0, [2, 2, 2], [2, 2, -2]), null);
});

test('authored AABB bounds retain unsnapped transformed corners, expansion and denied face remap', () => {
  const mesh = parseTileSurfaceMesh(text, table), f = Math.fround;
  assert.deepEqual(mesh.aabb.min, [f(5 - f(.01)), f(3 - f(.01)), f(-f(.01))]);
  assert.deepEqual(mesh.aabb.max, [f(5 + f(.01)), f(7 + f(.01)), f(4 + f(.01))]);
  assert.equal(mesh.aabb.denied, true); assert.equal(mesh.aabb.face, 0);
  assert.equal(mesh.faces.length, 0); assert.equal(mesh.denied.faces.length, 1);
});

test('tile LOS tests both face directions, shortens endpoint, filters materials and leaves clear output untouched', () => {
  const mesh = parseTileSurfaceMesh(text, table), hit = [99, 99, 99];
  assert.equal(clearTileSurfaceLOS(mesh, 1, [3, 5, 1], [7, 5, 1], hit, tileLOSMaterials(table)), 0);
  assert.deepEqual(hit, [5, 5, 1]);
  assert.equal(clearTileSurfaceLOS(mesh, 8, [7, 5, 1], [3, 5, 1], hit, tileLOSMaterials(table)), 0);
  assert.deepEqual(hit, [5, 5, 1]);
  hit.splice(0, 3, 99, 99, 99);
  assert.equal(clearTileSurfaceLOS(mesh, 1, [3, 5, 1], [7, 5, 1], hit, 0n), 1);
  assert.deepEqual(hit, [99, 99, 99]);
  mesh.denied.materials[0] = 33;
  assert.equal(clearTileSurfaceLOS(mesh, 1, [3, 5, 1], [7, 5, 1], hit, 2n), 0); // SHL wraps33 to1.
  assert.equal(clearTileSurfaceLOS(mesh, 1, [3, 5, 1], [7, 5, 1], hit, 1n << 33n), 1);
});

test('AABB traversal visits both branches and keeps the nearest endpoint even when farther face is first', () => {
  const mesh = parseTileSurfaceMesh(text, table);
  mesh.denied.vertices.push([6, 3, 0], [6, 7, 0], [6, 5, 4]);
  mesh.denied.faces.push([3, 4, 5]); mesh.denied.normals.push([1, 0, 0]); mesh.denied.constants.push(-6); mesh.denied.materials.push(1);
  const leaf = mesh.aabb;
  mesh.aabb = { min: [4, 2, -1], max: [7, 8, 5], sourceFace: -1,
    left: leaf, right: { ...leaf, min: [5.99, 2, -1], max: [6.01, 8, 5], face: 1 } };
  const hit = [];
  assert.equal(clearTileSurfaceLOS(mesh, 1, [3, 5, 1], [8, 5, 1], hit, 2n), 0);
  assert.deepEqual(hit, [5, 5, 1]);
});

test('missing native AABB blocks while malformed trees and missing planes fail explicitly', () => {
  const mesh = parseTileSurfaceMesh(text.replace(/aabb 0.*\n/, ''), table), hit = [8, 8, 8];
  assert.equal(clearTileSurfaceLOS(mesh, 1, [3, 5, 1], [7, 5, 1], hit, 2n), 0);
  assert.deepEqual(hit, [8, 8, 8]);
  assert.throws(() => parseTileSurfaceMesh(text.replace('4 0\nendnode', '4 -1\nendnode'), table), /AABB row/);
  assert.throws(() => parseTileSurfaceMesh(text.replace('4 0\nendnode', '4 8\nendnode'), table), /outside triangle/);
  mesh.aabb = { sourceFace: -1, min: [0, 0, 0], max: [10, 10, 10] };
  assert.throws(() => clearTileSurfaceLOS(mesh, 1, [3, 5, 1], [7, 5, 1], hit, 2n), /children/);
});

test('tile3D clipping preserves original endpoint heights and interpolates clipping on native axis', () => {
  const tile = { x: 1, y: 2, orientation: 0, mesh: {} };
  assert.deepEqual(clipAreaTileLOS(tile, [12, 25, 1], [18, 25, 7]), { status: 1, entry: [12, 25, 1], exit: [18, 25, 7] });
  assert.deepEqual(clipAreaTileLOS(tile, [5, 25, 0], [25, 25, 20]), { status: 1, entry: [10, 25, 5], exit: [20, 25, 15] });
  tile.orientation = 1;
  assert.throws(() => clipAreaTileLOS(tile, [5, 25, 0], [25, 25, 20]), /nonfinite/);
});

test('area tile LOS transforms hits and native zero local output through rotation and tile elevation', () => {
  const tile = { x: 1, y: 2, orientation: 0, heightOffset: 3, mesh: parseTileSurfaceMesh(text, table) }, hit = [];
  assert.equal(clearAreaTileLOS(tile, 1, [13, 25, 4], [17, 25, 4], hit, 2n), 0);
  assert.deepEqual(hit, [15, 25, 4]);
  tile.orientation = 1;
  assert.equal(clearAreaTileLOS(tile, 1, [15, 23, 4], [15, 27, 4], hit, 2n), 0);
  assert.deepEqual(hit, [15, 25, 4]);
  assert.equal(clearAreaTileLOS(tile, 1, [15, 23, 4], [15, 27, 4], hit, 0n), 1);
  assert.deepEqual(hit, [20, 20, 3]);
});
