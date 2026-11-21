import test from 'node:test';
import assert from 'node:assert/strict';
import { NativeGeometryResources } from '../src/area_geometry.js';
import { NativeAreaObjectGeometry } from '../src/area_object_geometry.js';
import { nativePlacementOrientation } from '../src/object_surface_mesh.js';
import { RESOURCE_TYPE as types } from '../src/resource_archive.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

const face = name => `node trimesh ${name}\nverts 3\n2 -2 0\n2 2 0\n2 2 2\nfaces 1\n0 1 2 0 0 0 0 7\nendnode\n`;
function fixture(kind = 'placeable') {
  const calls = [], reports = [];
  const resolver = { async getResource(ref, type) {
    calls.push([ref, type]);
    if (ref === 'placeables') return '2DA V2.0\n\nModelName\n50 original\n0 override\n';
    if (ref === 'genericdoors') return '2DA V2.0\n\nModelName BlockSight\n50 original 0\n0 override 1\n';
    if (ref === 'doortypes') return '2DA V2.0\n\nModel VisibleModel BlockSight\n50 original 1 0\n0 override 0 1\n';
    if (type === types.PWK) return face('plc_pwk');
    if (type === types.DWK) return face('D0_DWK_wg_closed');
    throw new Error('Unexpected resource');
  } };
  // Resource API returns ArrayBuffers, never a string.
  const original = resolver.getResource.bind(resolver);
  resolver.getResource = async (...args) => new TextEncoder().encode(await original(...args));
  const object = { id: 0x80000002, objectType: kind === 'door' ? 10 : 9, areaId: 9, position: [0, 0, 0], bearing: 0, animationState: 0, authored: { Appearance: 0 },nativePlaceableActionPoints550:[[0,0,0],[0,0,0]] };
  const registry = new Map([[object.id, object]]), area = { id: 9, resRef: 'area', objects: [object.id] };
  const resources = new NativeGeometryResources(resolver, (error, context) => reports.push({ error, context }));
  return { calls, reports, resolver, resources, object, registry, area, geometry: new NativeAreaObjectGeometry(area, resources, registry) };
}
const query = geometry => geometry.query([0, 0], [4, 0], 0, 1, .1, OBJECT_INVALID, { id: OBJECT_INVALID }, 1, null, 0);

test('explicit native facing survives lazy geometry load and guarded orientation commits retain existing polygons',async()=>{
 const {geometry,object}=fixture();object.bearing=Math.PI/2;object.nativeOrientation=[2,0,0];await geometry.load();
 assert.deepEqual(object.nativeOrientation,[2,0,0]);assert.deepEqual(object.orientation,[2,0,-0]);
 const previous=geometry.preparePlaceableOrientation(object),vertices=geometry.store.vertices.slice();
 object.nativeOrientation=[2,Math.fround(.0001),0];object.orientation=[2,0,Math.fround(-.0001)];geometry.commitPlaceableOrientation(object,previous);
 assert.deepEqual(geometry.store.vertices,vertices);await query(geometry);
 object.position[0]=1;assert.throws(()=>geometry.preparePlaceableOrientation(object),/current collision state/);assert.throws(()=>geometry.commitPlaceableOrientation(object,'invalid'),/changed unexpectedly/);
});
test('native bearing uses quaternion arithmetic, normalized facing and signed-zero behavior', () => {
  assert.deepEqual(nativePlacementOrientation(0), [0, 1, 0]);
  assert.deepEqual(nativePlacementOrientation(Math.fround(Math.PI)), [Math.fround(8.742277657347586e-8), -1, 0]);
  // Native near-unit normalization bypass preserves the residual/short length.
  assert.deepEqual(nativePlacementOrientation(Math.fround(Math.PI / 2)), [Math.fround(-.9999999403953552), Math.fround(5.960464477539063e-8), 0]);
  assert.throws(() => nativePlacementOrientation(1000), /input branch is not implemented/);
});
test('active physical placeable rows drive canonical native collision arrays', async () => {
  const { geometry, object, resources, calls } = fixture();
  assert.equal(await query(geometry), 0);
  assert.equal(geometry.store.objectIds[0], object.id); assert.equal(object.nativeCollisionSlot, 0);
  assert.equal(geometry.store.vertexCount, 3); assert.equal(geometry.store.faceCount, 1);
  assert.deepEqual(calls, [['placeables', types.TWO_DA], ['original', types.PWK]]);
  assert.equal((await resources.placeableMesh(1)).model, 'override');
  assert.equal(await query(geometry), 0);
});
test('native missing PWK creates diagnosed zero-count mesh, while missing rules or decoding errors stop', async () => {
  const missing = fixture();
  missing.resolver.getResource = async (ref, type) => {
    if (type === types.TWO_DA) return new TextEncoder().encode('2DA V2.0\n\nModelName\n0 missing\n');
    const error = new Error('Missing PWK'); error.code = 'RESOURCE_NOT_FOUND'; error.resourceType = types.PWK; throw error;
  };
  assert.equal(await query(missing.geometry), 1);
  assert.equal(missing.object.nativeCollisionSlot, -1); assert.equal(missing.geometry.store.objectCount, 0);
  assert.equal(missing.reports[0].context.objectId, missing.object.id);
  assert.equal(missing.reports[0].context.operation, 'native-placeable-pwk-missing-empty-mesh');
  const rules = fixture(); rules.resolver.getResource = async () => {
    const error = new Error('Missing table'); error.code = 'RESOURCE_NOT_FOUND'; error.resourceType = types.TWO_DA; throw error;
  };
  await assert.rejects(query(rules.geometry), /Missing table/); assert.equal(rules.geometry.store, null);
  const corrupt = fixture(), read = corrupt.resolver.getResource.bind(corrupt.resolver);
  corrupt.resolver.getResource = async (ref, type) => type === types.PWK ? new TextEncoder().encode('node trimesh plc\nverts 3 b\n') : read(ref, type);
  await assert.rejects(query(corrupt.geometry), /binary/); assert.equal(corrupt.geometry.store, null);
});
test('door geometry tracks actual state, table selection and transparency against canonical objects', async () => {
  const { geometry, object, resources } = fixture('door');
  assert.equal(await query(geometry), 0); assert.equal(geometry.store.doorIds[0], object.id);
  object.animationState = 1; assert.equal(await query(geometry), 1);
  object.animationState = 3; assert.equal(await query(geometry), 1);
  object.animationState = 0;
  assert.equal(await geometry.query([0, 0], [4, 0], 0, 1, .1, OBJECT_INVALID, { id: OBJECT_INVALID }, 1, null, 1), 1);
  assert.equal(geometry.providers().object(object.id), object);
  assert.equal((await resources.doorDescriptor({ Appearance: 1, GenericType_New: 0 })).visibleModel, 0);
  assert.equal((await resources.doorDescriptor({ Appearance: 0, GenericType: 0, GenericType_New: 1 })).index, 1);
});
test('live geometry mutation is diagnosed before a stale collision result can be returned', async () => {
  const { geometry, object, reports, area, registry } = fixture();
  await query(geometry); object.position[0] = 5;
  await assert.rejects(query(geometry), /position\/orientation update lifecycle/);
  assert.equal(reports.at(-1).context.operation, 'native-area-object-collision-query');
  object.position[0] = 0; registry.delete(object.id);
  await assert.rejects(query(geometry), /removal lifecycle/);
  registry.set(object.id, object); area.objects = [];
  await assert.rejects(query(geometry), /membership update lifecycle/);
});
test('separate module resolvers retain their own collision meshes for the same model name', async () => {
  const first = fixture(), second = fixture();
  second.resolver.getResource = async (_ref, type) => new TextEncoder().encode(type === types.TWO_DA ? '2DA V2.0\n\nModelName\n0 original\n' : 'node dummy decorative\nendnode\n');
  assert.equal(await query(first.geometry), 0); assert.equal(await query(second.geometry), 1);
  assert.notEqual(await first.resources.objectMesh('original', 'placeable'), await second.resources.objectMesh('original', 'placeable'));
});

test('explicit placeable area operations compact geometry and reuse native holes without rebuilding the store',async()=>{
 const {geometry,object,area,registry}=fixture();await query(geometry);const store=geometry.store;
 const add=async(id,x)=>{
  const next={id,objectType:9,areaId:area.id,authored:{Appearance:0},position:[x,0,0],bearing:0,nativePosition:[x,0,0],nativeOrientation:[0,1,0],nativeCollisionSlot:-1};
  registry.set(id,next);await geometry.insertPlaceable(next);area.objects.push(id);return next;
 };
 const second=await add(0x80000003,10);assert.equal(second.nativeCollisionSlot,1);assert.equal(await query(geometry),0);
 await geometry.removePlaceable(object);area.objects.splice(area.objects.indexOf(object.id),1);object.areaId=OBJECT_INVALID;
 assert.equal(object.nativeCollisionSlot,-1);assert.equal(await query(geometry),1);assert.equal(store.objectIds[0],OBJECT_INVALID);assert.equal(store.faceStarts[1],0);assert.equal(store.vertexStarts[1],0);
 const third=await add(0x80000004,0);assert.equal(third.nativeCollisionSlot,0);assert.equal(store.objectCount,2);assert.equal(store.faceStarts[0],1);assert.equal(store.faceStarts[1],0);assert.equal(store.vertexCount,6);assert.equal(store.faceCount,2);assert.equal(await query(geometry),0);
 third.position=[5,0,0];third.nativePosition=[5,0,0];await geometry.replacePlaceable(third);
 assert.equal(await query(geometry),1);assert.deepEqual(store.getBounds(0),[[7,-2,0],[7,2,2]]);assert.equal(geometry.store,store);assert.equal(store.objectCapacity,16);
 third.orientation=[1,0,0];await assert.rejects(query(geometry),/position\/orientation update lifecycle/);
});

test('dynamic empty/missing placeable meshes retain canonical membership and diagnosed load failures',async()=>{
 const {geometry,object,area,registry,resources,reports}=fixture();await query(geometry);await geometry.removePlaceable(object);area.objects=[];
 const next={id:0x80000009,objectType:9,areaId:area.id,position:[0,0,0],bearing:0,nativePosition:[0,0,0],nativeOrientation:[0,1,0],authored:{Appearance:123},nativeMessageFields:{0x32c:1},nativeCollisionSlot:-1};registry.set(next.id,next);
 const appearances=[];resources.placeableMesh=async appearance=>{appearances.push(appearance);const error=new Error('Missing runtime PWK');error.code='RESOURCE_NOT_FOUND';error.resourceType=types.PWK;throw error;};
 assert.equal(await geometry.insertPlaceable(next),-1);area.objects.push(next.id);assert.deepEqual(appearances,[1]);assert.equal(await query(geometry),1);assert.equal(reports.at(-1).context.objectId,next.id);
 assert.equal(reports.at(-1).context.operation,'native-placeable-pwk-missing-empty-mesh');
 await geometry.removePlaceable(next);area.objects=[];assert.equal(await query(geometry),1);
 resources.placeableMesh=async()=>{throw new Error('Corrupt runtime PWK');};await assert.rejects(geometry.insertPlaceable(next),/Corrupt runtime/);assert.equal(geometry.snapshots.has(next.id),false);assert.equal(reports.at(-1).context.operation,'native-area-object-collision-insert');
 await assert.rejects(geometry.insertPlaceable({...next}),/canonical object/);
});
