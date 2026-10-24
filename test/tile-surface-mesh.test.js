import test from 'node:test';
import assert from 'node:assert/strict';
import { computeTileAdjacency, intersectTileSegments, tilePlaneHeight, clippedTileSurfaceLine, parseTileSurfaceMesh, snapTileVertex, tileTriangleNormal, rotateTileQuaternion, rotateTilePoint, clippedAreaTileLine, noDeniedTilePolygons, noDeniedAreaTilePolygons } from '../src/tile_surface_mesh.js';
import { parse2da } from '../src/area.js';

function mesh(vertices, faces, normals = faces.map(() => [0, 0, 1]), constants = faces.map(() => 0)) {
  return { vertices, faces, normals, constants, adjacency: computeTileAdjacency(vertices, faces) };
}
const square = () => mesh([[0, 0, 0], [10, 0, 0], [10, 10, 0], [0, 10, 0]], [[0, 1, 2], [0, 2, 3]]);

test('native tile adjacency uses separate border and interior-hole sentinels and vertex identity', () => {
  assert.deepEqual(square().adjacency, [[-2, -2, 1], [0, -2, -2]]);
  const vertices = [[1, 1, 0], [9, 1, 0], [9, 9, 0], [1, 1, 0], [9, 9, 0], [1, 9, 0]];
  assert.deepEqual(computeTileAdjacency(vertices, [[0, 1, 2], [3, 4, 5]]), [[-3, -3, -3], [-3, -3, -3]]);
});

test('native adjacency accepts same-direction shared edges and retains last non-manifold match', () => {
  const vertices = [[1, 1, 0], [5, 1, 0], [1, 5, 0], [5, 5, 0], [3, 3, 0]];
  const adjacency = computeTileAdjacency(vertices, [[0, 1, 2], [0, 1, 3], [0, 1, 4]]);
  assert.equal(adjacency[0][0], 2);
  assert.equal(adjacency[1][0], 0);
  assert.equal(adjacency[2][0], 0);
});

test('tile borders use native float tolerance and override matching neighbors', () => {
  const f = Math.fround;
  const vertices = [[f(.0001), 1, 0], [f(.0001), 9, 0], [2, 2, 0], [3, 3, 0]];
  assert.deepEqual(computeTileAdjacency(vertices, [[0, 1, 2], [1, 0, 3]]).map(row => row[0]), [-2, -2]);
  vertices[0][0] = vertices[1][0] = f(.00010001);
  assert.deepEqual(computeTileAdjacency(vertices, [[0, 1, 2], [1, 0, 3]]).map(row => row[0]), [1, 0]);
});

test('native cached plane height returns zero for vertical planes and preserves float addition order', () => {
  assert.equal(tilePlaneHeight([1, 2, 0], -100, [3, 4, 0]), 0);
  assert.equal(tilePlaneHeight([-1, -2, 1], -3, [2, 4, 0]), 13);
  assert.equal(tilePlaneHeight([1, 1, 1], -16777216, [16777216, 1, 0]), -1);
});

test('native segment intersection accepts inclusive contacts, rejects collinear lines and interpolates edge height', () => {
  assert.deepEqual(intersectTileSegments([0, 2, 99], [4, 2, 99], [2, 0, 1], [2, 4, 9]), [2, 2, 5]);
  assert.deepEqual(intersectTileSegments([2, 0, 99], [2, 4, 99], [0, 2, 1], [4, 2, 9]), [2, 2, 5]);
  assert.deepEqual(intersectTileSegments([0, 0, 0], [2, 2, 0], [2, 2, 5], [4, 0, 9]), [2, 2, 5]);
  assert.equal(intersectTileSegments([0, 0, 0], [2, 2, 0], [1, 1, 0], [3, 3, 0]), null);
  assert.equal(intersectTileSegments([0, 0, 0], [1, 0, 0], [2, -1, 0], [2, 1, 0]), null);
});

test('tile triangle traversal crosses adjacency and succeeds at native tile borders', () => {
  const diagonal = clippedTileSurfaceLine(square(), 0, 0, [8, 2], [2, 8]);
  assert.equal(diagonal.status, 1);
  assert.deepEqual(diagonal.entry, [8, 2]);
  const border = clippedTileSurfaceLine(square(), 1, 2, [12, 25], [25, 25]);
  assert.equal(border.status, 1);
  assert.deepEqual(border.exit, [20, 25]);
});

test('triangle walking fails on interior holes and clockwise surfaces rather than treating them as tile exits', () => {
  const island = mesh([[1, 1, 0], [9, 1, 0], [9, 9, 0]], [[0, 1, 2]]);
  assert.equal(clippedTileSurfaceLine(island, 0, 0, [8, 2], [2, 8]).status, 0);
  const reversed = mesh([[0, 0, 0], [10, 0, 0], [10, 10, 0]], [[2, 1, 0]]);
  assert.equal(clippedTileSurfaceLine(reversed, 0, 0, [8, 2], [9, 2]).status, 0);
});

test('height bounds include the crossed edge and final original endpoint plane', () => {
  const slope = mesh([[0, 0, 0], [10, 0, 10], [10, 10, 10], [0, 10, 0]], [[0, 1, 2], [0, 2, 3]], [[-1, 0, 1], [-1, 0, 1]]);
  const crossing = clippedTileSurfaceLine(slope, 0, 0, [8, 2], [2, 8]);
  assert.equal(crossing.status, 1);
  assert.equal(crossing.minHeight, 2);
  assert.equal(crossing.maxHeight, 8);
  const exit = clippedTileSurfaceLine(slope, 0, 0, [2, 5], [12, 5]);
  assert.equal(exit.status, 1);
  assert.equal(exit.minHeight, 2);
  assert.equal(exit.maxHeight, 10);
});

test('native triangle walk bounds cyclic adjacency and reports the failure', () => {
  const cyclic = square(); cyclic.adjacency[0][2] = 0;
  const warnings = [];
  assert.equal(clippedTileSurfaceLine(cyclic, 0, 0, [8, 2], [2, 8], message => warnings.push(message)).status, 0);
  assert.equal(warnings.length, 1);
});

test('tile geometry requires actual indices, adjacency and cached native planes', () => {
  assert.throws(() => computeTileAdjacency([[0, 0, 0]], [[0, 1, 2]]), /invalid/);
  assert.throws(() => clippedTileSurfaceLine({ vertices: [], faces: [] }, 0, 0, [0, 0], [1, 1]), /cached planes/);
});

const tileText = (orientation = '0 0 1 0') => `#MAXWALKMESH ASCII
node trimesh ignored
  verts 1
  999 999 999
endnode
node aabb tile
  position 0 0 0
  orientation ${orientation}
  verts 5
  -5 -5 0
  5 -5 0
  5 5 0
  -5 5 0
  -5.00001 -5.00001 0
  faces 2
  4 1 2 0 0 0 0 0
  4 2 3 0 0 0 0 1
endnode`;
const surfaces = () => parse2da('2DA V2.0\n\nWalk\n900 1\n901 0\n');

test('native ASCII tile loader snaps and merges vertices before classifying faces using physical 2DA rows', () => {
  const loaded = parseTileSurfaceMesh(tileText(), surfaces());
  assert.deepEqual(loaded.vertices, [[0, 0, 0], [10, 0, 0], [10, 10, 0]]);
  assert.deepEqual(loaded.faces, [[0, 1, 2]]);
  assert.deepEqual(loaded.adjacency, [[-2, -2, -3]]);
  assert.deepEqual(loaded.sourceFaces, [0]);
  assert.deepEqual(loaded.denied.vertices, [[0, 0, 0], [10, 10, 0], [0, 10, 0]]);
  assert.deepEqual(loaded.denied.faces, [[0, 1, 2]]);
  assert.deepEqual(loaded.normals, [[0, 0, 1]]);
});

test('native tile loader treats every nonzero Walk integer as walkable and retains original order', () => {
  const table = parse2da('2DA V2.0\n\nWalk\n0 2\n1 -1\n');
  const loaded = parseTileSurfaceMesh(tileText(), table);
  assert.deepEqual(loaded.sourceFaces, [0, 1]);
  assert.deepEqual(loaded.adjacency, [[-2, -2, 1], [0, -2, -2]]);
  assert.equal(clippedTileSurfaceLine(loaded, 0, 0, [8, 2], [2, 8]).status, 1);
});

test('native vertex snapping preserves integer-conversion asymmetry and non-integer coordinates', () => {
  assert.equal(snapTileVertex(4.99999), 5);
  assert.equal(snapTileVertex(5.001), Math.fround(5.001));
  assert.equal(snapTileVertex(-1), -1);
  assert.equal(snapTileVertex(-1.00001), Math.fround(-1.00001));
  assert.equal(snapTileVertex(-1.001), -1);
});

test('native triangle normals use the near-unit bypass and defined zero-vector fallback', () => {
  assert.deepEqual(tileTriangleNormal([0, 0, 0], [0, 0, 0], [0, 0, 0]), [1, 0, 0]);
  const near = Math.fround(1.000004);
  assert.deepEqual(tileTriangleNormal([0, 0, 0], [1, 0, 0], [1, near, 0]), [0, 0, near]);
  assert.deepEqual(tileTriangleNormal([0, 0, 0], [10, 0, 0], [10, 10, 0]), [0, 0, 1]);
});

test('native quaternion-vector identity branches and transform preserve component order', () => {
  assert.deepEqual(rotateTileQuaternion([1, 4, 5, 6], [2, 3, 4]), [2, 3, 4]);
  assert.deepEqual(rotateTileQuaternion([0, 0, 0, 1], [2, 3, 4]), [-2, -3, 4]);
  assert.deepEqual(rotateTileQuaternion([0, 1, 0, 0], [2, 3, 4]), [2, -3, -4]);
});

test('tile loader diagnoses unimplemented math branches/binary sections and malformed geometry instead of accepting viewer approximations', () => {
  // The mapped CRT reduction now supports half-angles below500000. Keep
  // testing the unsupported boundary rather than rejecting a supported angle.
  assert.throws(() => parseTileSurfaceMesh(tileText('0 0 1 1000000'), surfaces()), /trigonometric input/);
  assert.throws(() => parseTileSurfaceMesh(tileText().replace('verts 5', 'verts 5 b'), surfaces()), /binary/);
  assert.throws(() => parseTileSurfaceMesh(tileText().replace('4 1 2', '5 1 2'), surfaces()), /outside/);
  assert.throws(() => parseTileSurfaceMesh(tileText(), null), /surfacemat/);
});

test('native node half-angle quaternion applies nonzero resource rotation before vertex snapping', () => {
  const loaded = parseTileSurfaceMesh(tileText('0 0 1 3.141592653589793'), surfaces());
  assert.deepEqual(loaded.vertices, [[10, 10, 0], [0, 10, 0], [0, 0, 0]]);
});

test('native tile quarter turns preserve exact corners and invert world coordinates for all orientations', () => {
  for (let orientation = 0; orientation < 4; orientation++) {
    const tile = { x: 2, y: 3, orientation };
    for (const point of [[20, 30], [30, 40], [22, 33]])
      assert.deepEqual(rotateTilePoint(tile, rotateTilePoint(tile, point, true), false), point);
  }
  assert.deepEqual(rotateTilePoint({ x: 2, y: 3, orientation: 1 }, [22, 33], true), [23, 38]);
  assert.deepEqual(rotateTilePoint({ x: 2, y: 3, orientation: 3 }, [22, 33], true), [27, 32]);
});

test('area tile wrapper rotates asymmetric walkable geometry and adds native height offset', () => {
  const nativeMesh = mesh([[0, 0, 0], [10, 0, 0], [10, 10, 0]], [[0, 1, 2]]);
  const tile = { x: 2, y: 3, orientation: 1, heightOffset: 7, mesh: nativeMesh };
  const pass = clippedAreaTileLine(tile, [28, 37], [27, 37]);
  assert.equal(pass.status, 1);
  assert.deepEqual(pass.entry, [28, 37]);
  assert.deepEqual(pass.exit, [27, 37]);
  assert.equal(pass.minHeight, 7); assert.equal(pass.maxHeight, 7);
  assert.equal(clippedAreaTileLine(tile, [22, 33], [23, 33]).status, 0);
});

function denied(vertices, faces = [[0, 1, 2]]) { return { denied: { vertices, faces } }; }
test('native denied tile polygons block crossing walls in all movement quadrants', () => {
  const wall = denied([[5, 0, 0], [5, 10, 0], [5, 10, 2]]);
  for (const [start, end] of [[[1, 5], [9, 5]], [[9, 5], [1, 5]], [[1, 1], [9, 9]], [[9, 9], [1, 1]]])
    assert.equal(noDeniedTilePolygons(wall, start, end, 0, 1, .1, 0), 0);
});
test('native tile polygon bounds retain inclusive vertical contacts, zero-length success and reversed-height success', () => {
  const wall = denied([[5, 0, 2], [5, 10, 2], [5, 10, 4]]);
  assert.equal(noDeniedTilePolygons(wall, [1, 5], [9, 5], 0, 1.99, .1, 0), 1);
  assert.equal(noDeniedTilePolygons(wall, [1, 5], [9, 5], 0, 2, .1, 0), 0);
  assert.equal(noDeniedTilePolygons(wall, [5, 5], [5, 5], 0, 4, .1, 0), 1);
  assert.equal(noDeniedTilePolygons(wall, [1, 5], [9, 5], 4, 0, .1, 0), 1);
});
test('native flag0 clamps radii above .1 through .65, retaining larger and nonzero-flag radii', () => {
  const wall = denied([[5, 5.2, 0], [5, 10, 0], [5, 10, 2]]);
  assert.equal(noDeniedTilePolygons(wall, [1, 5], [9, 5], 0, 1, .5, 0), 1);
  assert.equal(noDeniedTilePolygons(wall, [1, 5], [9, 5], 0, 1, .65, 0), 1);
  assert.equal(noDeniedTilePolygons(wall, [1, 5], [9, 5], 0, 1, .66, 0), 0);
  assert.equal(noDeniedTilePolygons(wall, [1, 5], [9, 5], 0, 1, .5, 1), 0);
});
test('native polygon scratch ambiguity is recorded only when it can change the final result', () => {
  const inside = denied([[4, 4, 0], [6, 4, 0], [5, 6, 0]]);
  assert.throws(() => noDeniedTilePolygons(inside, [1, 5], [9, 5], -1, 1, 3, 1), /uninitialized/);
  assert.equal(noDeniedTilePolygons(inside, [1, 5], [9, 5], -1, 1, 3, 1, [0, 0, 0]), 1);
  assert.equal(noDeniedTilePolygons(inside, [1, 5], [9, 5], -1, 1, 3, 1, [1, 1, 1]), 0);
  const actualCrossing = denied([[4, 4, 0], [6, 4, 0], [5, 6, 0], [8, 0, 0], [8, 10, 0], [8, 10, 2]], [[0, 1, 2], [3, 4, 5]]);
  assert.equal(noDeniedTilePolygons(actualCrossing, [1, 5], [9, 5], -1, 1, 3, 1), 0);
});
test('native tile collision wrapper applies local rotation without adding translation back, and subtracts height offset', () => {
  const tile = { x: 2, y: 3, orientation: 1, heightOffset: 7, mesh: denied([[3, 0, 0], [3, 10, 0], [3, 10, 2]]) };
  assert.equal(noDeniedAreaTilePolygons(tile, [25, 31], [25, 39], 7, 8, .1, 0), 0);
  assert.equal(noDeniedAreaTilePolygons(tile, [25, 31], [25, 39], 10, 11, .1, 0), 1);
});
