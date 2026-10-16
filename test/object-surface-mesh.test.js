import test from 'node:test';
import assert from 'node:assert/strict';
import { parseObjectSurfaceMesh, doorMeshBoundingBox, noDoorSurfacePolygons, noDoorPolygons, intersectDoorSurfaceSegments } from '../src/object_surface_mesh.js';

const section = (name, position = '', orientation = '') => `node trimesh ${name}
${position}
${orientation}
verts 4
0 0 0
1 0 1
0 1 2
0 0 0
faces 2
0 1 2 0 0 0 0 0
3 1 2 0 0 0 0 7
endnode`;
test('placeable surface preserves local transforms, duplicates, indices and all materials', () => {
  const mesh = parseObjectSurfaceMesh(section('plc_pwk', 'position 1 2 3'), 'placeable');
  assert.deepEqual(mesh.vertices, [[1, 2, 3], [2, 2, 4], [1, 3, 5], [1, 2, 3]]);
  assert.deepEqual(mesh.faces, [[0, 1, 2], [3, 1, 2]]); assert.deepEqual(mesh.materials, [0, 7]);
});
test('object quaternion transforms use native f32 math without tile snapping', () => {
  const mesh = parseObjectSurfaceMesh(section('plc_pwk', '', 'orientation 0 0 1 1.57079637'), 'placeable');
  assert.equal(mesh.vertices[1][0], Math.fround(5.960464477539063e-8));
  assert.equal(mesh.vertices[1][1], Math.fround(.9999999403953552));
  assert.equal(mesh.vertices[1][2], 1);
});
test('door mesh state selection uses native naming offset and retains cross-node position', () => {
  const surface = parseObjectSurfaceMesh(`${section('D0_DWK_wg_closed', 'position 1 2 3')}
${section('D0_DWK_wg_open1')}
${section('ignored_DWK_wg_open2', 'position 99 99 99')}`, 'door');
  assert.deepEqual(surface.states[0].vertices, surface.states[1].vertices);
  assert.deepEqual(surface.states[2].vertices, []);
  assert.equal(surface.states[0].faces.length, 2);
});
test('door bounds include every state, mutate supplied orientation and return0 for no vertices', () => {
  const surface = { states: [{ vertices: [[1, 2, 3]] }, { vertices: [[-1, -2, -3]] }, { vertices: [[2, 1, 0]] }] };
  const orientation = [1, 0, 9], result = doorMeshBoundingBox(surface, [10, 20, 30], orientation);
  assert.deepEqual(orientation, [0, -1, 9]); assert.equal(result.status, 1);
  assert.deepEqual(result.bounds, [[8, 19, 27], [12, 22, 33]]);
  assert.deepEqual(doorMeshBoundingBox({ states: [{ vertices: [] }, { vertices: [] }, { vertices: [] }] }, [0, 0, 0], [0, 1, 0]), { status: 0, bounds: null });
});
test('door surface collision has no radius clamp and diagnoses uninitialized scratch ambiguity', () => {
  const surface = { states: [{ vertices: [[2, .2, 0], [3, .2, 0], [2, .3, 0]], faces: [[0, 1, 2]] }] };
  assert.equal(noDoorSurfacePolygons(surface, 0, [0, 0], [4, 0], 0, 1, .65, [1, 1, 1]), 0);
  assert.throws(() => noDoorSurfacePolygons(surface, 0, [0, 0], [4, 0], 0, 1, .65), /Native door collision result depends/);
  assert.equal(noDoorSurfacePolygons(surface, 0, [0, 0], [4, 0], 0, 1, .1), 1);
});
test('door animation query preserves native unsupported-state blocking, destroyed state and normalized transform', () => {
  const wall = { vertices: [[2, -2, 0], [2, 2, 0], [2, 2, 2]], faces: [[0, 1, 2]] };
  const door = { nativeAnimation: 22, nativeOrientation: [0, 2, 0], nativePosition: [10, 20, 30], nativeDoorSurface: { states: [wall, { vertices: [], faces: [] }, wall] } };
  const run = () => noDoorPolygons(door, [10, 20], [14, 20], 30, 31, .1, { 22: 0, 50: 1, 51: 2 });
  assert.equal(run(), 0); door.nativeAnimation = 50; assert.equal(run(), 1);
  door.nativeAnimation = 51; assert.equal(run(), 0); door.nativeAnimation = 72; assert.equal(run(), 1);
  door.nativeAnimation = 999; assert.equal(run(), 0); door.nativeAnimation = 22;
  assert.throws(() => noDoorPolygons(door, [10, 20], [14, 20], 30, 31, .1), /state global is unavailable/);
});
test('door intersection retains normalized parallel-direction rejection and endpoint contact', () => {
  assert.equal(intersectDoorSurfaceSegments([0, 0], [4, 0], [1, 0], [2, 0]), null);
  assert.deepEqual(intersectDoorSurfaceSegments([0, 0], [4, 0], [2, -1], [2, 1]), [2, 0]);
  assert.deepEqual(intersectDoorSurfaceSegments([0, 0], [2, 2], [2, 2], [4, 0]), [2, 2]);
});
test('unsupported object mesh formats, duplicate sections and invalid indices fail explicitly', () => {
  assert.throws(() => parseObjectSurfaceMesh(section('plc_pwk').replace('verts 4', 'verts 4 b'), 'placeable'), /binary/);
  assert.throws(() => parseObjectSurfaceMesh(`${section('plc_pwk')}\n${section('plc_pwk')}`, 'placeable'), /Repeated/);
  assert.throws(() => parseObjectSurfaceMesh(section('plc_pwk').replace('0 1 2 0 0 0 0 0', '-1 1 2 0 0 0 0 0'), 'placeable'), /negative or invalid/);
  assert.ok(parseObjectSurfaceMesh(section('ignored_DWK_wg_closed'), 'door').states.every(state => state.vertices.length === 0));
  assert.deepEqual(parseObjectSurfaceMesh('node dummy plc_root\nendnode', 'placeable'), { vertices: [], faces: [], materials: [],actionPoints:[[0,0,0],[0,0,0]] });
});
