import test from 'node:test';
import assert from 'node:assert/strict';
import { NativeGeometryResources, NativeAreaGeometry } from '../src/area_geometry.js';
import { RESOURCE_TYPE as types } from '../src/resource_archive.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

const text = '#MAXWALKMESH ASCII\nnode aabb surface\nposition 0 0 0\nverts 4\n-5 -5 0\n5 -5 0\n5 5 0\n-5 5 0\nfaces 2\n0 1 2 0 0 0 0 0\n0 2 3 0 0 0 0 0\nendnode\n';
function fixture(walk = 1) {
  const calls = [], diagnostics = [];
  const resolver = { async getResource(ref, type) {
    calls.push([ref, type]);
    if (type === types.SET) return new TextEncoder().encode('[GENERAL]\nTransition=2.5\n[TILES]\nCount=1\n[TILE0]\nModel=tilemodel\n');
    if (type === types.TWO_DA) return new TextEncoder().encode(`2DA V2.0\n\nWalk\n0 ${walk}\n`);
    if (type === types.WOK) return new TextEncoder().encode(text);
    throw new Error('Missing resource');
  } };
  const resources = new NativeGeometryResources(resolver, (error, context) => diagnostics.push({ error, context }));
  const area = { id: 9, resRef: 'testarea', width: 2, height: 1, tilesetResRef: 'tileset', tilePlacements: [{ Tile_ID: 0, Tile_Orientation: 1, Tile_Height: -2 }, { Tile_ID: 0 }] };
  return { calls, diagnostics, resources, area, geometry: new NativeAreaGeometry(area, resources) };
}

test('native module tile geometry loads active resources lazily, shares model identity and retains signed heights', async () => {
  const { calls, geometry, area } = fixture();
  assert.equal(calls.length, 0);
  const tile = await geometry.tile(0, 0), next = await geometry.tile(1, 0);
  assert.equal(tile.mesh, next.mesh); assert.equal(await geometry.tile(0, 0), tile);
  assert.equal(tile.heightOffset, -5);
  assert.equal(next.heightOffset, 0);
  assert.deepEqual(calls, [['tileset', types.SET], ['surfacemat', types.TWO_DA], ['tilemodel', types.WOK]]);
  assert.equal(await geometry.lineWalkable([5, 5], [15, 5]), 1);
  assert.equal(area.tilePlacements[0].Tile_Height, -2);
});

test('geometry resource caches stay within the active resolver and use new surfacemat values', async () => {
  const original = fixture(1), override = fixture(0);
  assert.equal(await original.geometry.lineWalkable([5, 5], [6, 5]), 1);
  assert.equal(await override.geometry.lineWalkable([5, 5], [6, 5]), 0);
  assert.notEqual((await original.geometry.tile(0, 0)).mesh, (await override.geometry.tile(0, 0)).mesh);
  const a=original.geometry.providers({cached:true}).tile(original.area,0,0),b=override.geometry.providers({cached:true}).tile(override.area,0,0);assert.notEqual(typeof a.then,'function');assert.notEqual(a,b);assert.notEqual(a.mesh,b.mesh);
});

test('unavailable tile resource failures are retained, reported with IDs and never replaced with free space', async () => {
  const { geometry, resources, diagnostics } = fixture();
  resources.resolver.getResource = async () => { throw new Error('Missing SET'); };
  await assert.rejects(geometry.tile(0, 0), /Missing SET/);
  await assert.rejects(geometry.tile(0, 0), /Missing SET/);
  assert.equal(diagnostics.length, 1);
  assert.equal(diagnostics[0].context.areaId, 9);
  assert.equal(diagnostics[0].context.tileIndex, 0);
  assert.equal(await geometry.tile(-1, 0), null);
});

test('native tile list accepts extra entries but rejects missing entries and missing height transition', async () => {
  const extra = fixture(); extra.area.tilePlacements.push({ Tile_ID: 900 });
  assert.ok(await extra.geometry.tile(1, 0));
  const missing = fixture(); missing.area.tilePlacements.pop();
  await assert.rejects(missing.geometry.tile(0, 0), /truncated/);
  const absent = fixture(); absent.resources.resolver.getResource = async () => new TextEncoder().encode('[TILES]\nCount=1\n[TILE0]\nModel=tilemodel');
  await assert.rejects(absent.geometry.tile(0, 0), /Transition/);
});

test('live area LOS loads native tile tree/material mask and object storage with canonical registry', async () => {
  const t = fixture(); t.area.objects = []; t.area.tilePlacements[0].Tile_Orientation = 0; t.area.tilePlacements[0].Tile_Height = 0;
  const read = t.resources.resolver.getResource.bind(t.resources.resolver);
  t.resources.resolver.getResource = async (ref, type) => {
    if (type === types.TWO_DA) return new TextEncoder().encode('2DA V2.0\n\nWalk LineOfSight\n0 1 0\n');
    if (type === types.WOK) return new TextEncoder().encode(text.replace('endnode', 'aabb -5 -5 0 5 5 0 -1\n-5 -5 0 5 5 0 0\n-5 -5 0 5 5 0 1\nendnode'));
    return read(ref, type);
  };
  const geometry = new NativeAreaGeometry(t.area, t.resources, new Map()), output = [], hit = {};
  assert.equal(await geometry.lineOfSight([2, 5, 1], [18, 5, 1], output, hit, 0x80000001, OBJECT_INVALID, 0), 1);
  assert.deepEqual(output, [0, 0, 0]); assert.equal(hit.id, OBJECT_INVALID);
  assert.equal(geometry.objects.store.objectCount, 0); assert.equal(t.diagnostics.length, 0);
  assert.equal((await geometry.tile(0, 0)).mesh.aabb.left.face, 0);
  assert.equal((await geometry.tile(0, 0)).mesh.aabb.right.face, 1);
  assert.equal(t.calls.filter(([ref]) => ref === 'surfacemat').length, 0); // Replaced provider served it; shared mask/mesh promise.
});

test('native LOS integration persists missing registry and tile failures with source/target IDs', async () => {
  const t = fixture();
  await assert.rejects(t.geometry.lineOfSight([2, 5, 1], [3, 5, 1], [], {}, 7, 8, 0), /registry/);
  assert.equal(t.diagnostics.at(-1).context.operation, 'native-area-line-of-sight');
  assert.equal(t.diagnostics.at(-1).context.sourceId, 7);
  t.area.objects = [];
  const geometry = new NativeAreaGeometry(t.area, t.resources, new Map());
  t.resources.resolver.getResource = async () => { throw new Error('Resource read failed'); };
  await assert.rejects(geometry.lineOfSight([2, 5, 1], [3, 5, 1], [], {}, 7, 8, 0), /read failed/);
  assert.equal(t.diagnostics.at(-1).context.targetId, 8);
});
