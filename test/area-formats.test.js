import assert from 'node:assert/strict';
import test from 'node:test';
import { creaturePltCandidates, decodeNwnColor, parse2da, parseTileset, resolveCreatureModels, resolveDoorModel } from '../src/area.js';
import { parseErf } from '../src/resource_archive.js';
import { parseGff, getGffStructType } from '../src/gff.js';
import { groupFacesByMaterial } from '../src/mdl_mesh.js';
import { parseBioWareDds } from '../src/bioware_dds.js';
import { isEmptyBinaryMeshRecord } from '../src/binary_mdl.js';
import { decodeModelOrientation, isAsciiMdl } from '../src/mdl_format.js';
import { decodeBioWarePlt } from '../src/bioware_plt.js';
import { sampleEmitterParticle } from '../src/particle_preview.js';
import { collidesWithObjectWalkmeshes, findWalkableHeight, moveOnWalkmesh, parseWalkmesh } from '../src/walkmesh.js';

function makeGff() {
  const bytes = new Uint8Array(288);
  const view = new DataView(bytes.buffer);
  bytes.set(new TextEncoder().encode('ARE V3.2'), 0);
  [56, 2, 80, 6, 152, 6, 248, 8, 256, 24, 280, 8].forEach((value, index) => {
    view.setUint32(8 + index * 4, value, true);
  });
  writeStruct(view, 56, 0xffffffff, 0, 4);
  writeStruct(view, 68, 42, 16, 2);
  writeField(view, 80, 4, 0, 8);
  writeField(view, 92, 4, 1, 6);
  writeField(view, 104, 11, 2, 0);
  writeField(view, 116, 15, 3, 0);
  writeField(view, 128, 4, 4, 94);
  writeField(view, 140, 4, 5, 3);
  ['Width', 'Height', 'Tileset', 'Tile_List', 'Tile_ID', 'Tile_Orientation'].forEach((label, index) => {
    bytes.set(new TextEncoder().encode(label), 152 + index * 16);
  });
  bytes[248] = 5;
  bytes.set(new TextEncoder().encode('tin01'), 249);
  [0, 1, 2, 3, 4, 5].forEach((value, index) => view.setUint32(256 + index * 4, value, true));
  view.setUint32(280, 1, true);
  view.setUint32(284, 1, true);
  return bytes;
}

function writeStruct(view, offset, id, dataOrOffset, fieldCount) {
  view.setUint32(offset, id, true);
  view.setUint32(offset + 4, dataOrOffset, true);
  view.setUint32(offset + 8, fieldCount, true);
}

function writeField(view, offset, type, labelIndex, dataOrOffset) {
  view.setUint32(offset, type, true);
  view.setUint32(offset + 4, labelIndex, true);
  view.setUint32(offset + 8, dataOrOffset, true);
}

function makeModule(resource) {
  const keyOffset = 160;
  const resourceOffset = keyOffset + 24;
  const dataOffset = resourceOffset + 8;
  const bytes = new Uint8Array(dataOffset + resource.byteLength);
  const view = new DataView(bytes.buffer);
  bytes.set(new TextEncoder().encode('MOD V1.0'), 0);
  view.setUint32(16, 1, true);
  view.setUint32(24, keyOffset, true);
  view.setUint32(28, resourceOffset, true);
  bytes.set(new TextEncoder().encode('sample'), keyOffset);
  view.setUint32(keyOffset + 16, 0, true);
  view.setUint16(keyOffset + 20, 2012, true);
  view.setUint32(resourceOffset, dataOffset, true);
  view.setUint32(resourceOffset + 4, resource.byteLength, true);
  bytes.set(resource, dataOffset);
  return bytes;
}

test('GFF reader parses scalar fields, resrefs, and struct lists', () => {
  const document = parseGff(makeGff(), 'ARE ');
  assert.equal(document.root.Width, 8);
  assert.equal(document.root.Height, 6);
  assert.equal(document.root.Tileset, 'tin01');
  assert.equal(document.root.Tile_List.length, 1);
  assert.equal(document.root.Tile_List[0].Tile_ID, 94);
  assert.equal(document.root.Tile_List[0].Tile_Orientation, 3);
  assert.equal(getGffStructType(document.root), 0xffffffff);
  assert.equal(getGffStructType(document.root.Tile_List[0]), 42);
  assert.equal(Object.keys(document.root).includes('structType'), false);
});

test('MOD reader extracts a keyed GFF resource', () => {
  const archive = parseErf(makeModule(makeGff()));
  assert.equal(archive.type, 'MOD');
  const resource = archive.entries.get('sample:2012');
  assert.ok(resource);
  assert.equal(parseGff(resource, 'ARE ').root.Tileset, 'tin01');
});

test('2DA reader supports files without an explicit DEFAULT row', () => {
  const table = parse2da('2DA V2.0\n\nLabel ModelName Static\n0 Brazier PLC_I05 1\n7 "new:Brazier" TNP_FIRE_001 0\n');
  assert.equal(table.rows.get(0).ModelName, 'PLC_I05');
  assert.equal(table.rows.get(7).Label, 'new:Brazier');
  assert.equal(table.rows.get(7).Static, '0');
});

test('door appearance resolves generic and typed models and skips invisible rows', () => {
  const genericDoors = parse2da('2DA V2.0\nLabel ModelName VisibleModel\n1 Fancy T_DOOR02 1\n2 Invisible **** 0\n');
  const doorTypes = parse2da('2DA V2.0\nLabel Model VisibleModel\n24 Wood T_DOOR24 1\n');
  assert.deepEqual(resolveDoorModel(0, 1, genericDoors, doorTypes), { visible: true, model: 't_door02' });
  assert.deepEqual(resolveDoorModel(24, 1, genericDoors, doorTypes), { visible: true, model: 't_door24' });
  assert.deepEqual(resolveDoorModel(0, 2, genericDoors, doorTypes), { visible: false, model: '' });
});

test('player creature resolves skeleton and nonzero body-part model IDs', () => {
  const tables = {
    appearance: { rows: new Map([[3, { MODELTYPE: 'P', RACE: 'A' }]]) },
    racialTypes: { rows: new Map([[3, { Appearance: '3' }]]) },
    gender: { rows: new Map([[0, { GENDER: 'M' }]]) },
    phenotype: { rows: new Map([[0, { DefaultPhenoType: '0' }]]) }
  };
  const creature = resolveCreatureModels({
    Appearance_Type: 3,
    Race: 3,
    Gender: 0,
    Phenotype: 0,
    Appearance_Head: 20,
    BodyPart_Torso: 1,
    BodyPart_Belt: 0,
    XPosition: 1,
    YPosition: 2,
    ZPosition: 0,
    XOrientation: 0,
    YOrientation: 1
  }, 0, tables);
  assert.equal(creature.model, 'pma0');
  assert.equal(creature.parts[0].model, 'pma0_head020');
  assert.equal(creature.parts[1].model, 'pma0_chest001');
  assert.equal(creature.parts.some((part) => part.node === 'belt_g'), false);
  assert.ok(Math.abs(creature.bearing) < 1e-9);
});

test('tileset reader maps tile IDs to model resrefs', () => {
  const tileset = parseTileset('[GENERAL]\nTransition=3\n[TILES]\nCount=2\n[TILE0]\nModel=room_a\n[TILE1]\nModel=room_b\n');
  assert.equal(tileset.transition, 3);
  assert.equal(tileset.tiles[1].model, 'room_b');
});

test('area color DWORDs decode from NWN BGR storage to RGB channels', () => {
  assert.deepEqual(decodeNwnColor(0x00332211), [0x11 / 255, 0x22 / 255, 0x33 / 255]);
  assert.deepEqual(decodeNwnColor(0), [0, 0, 0]);
});

test('mesh faces retain contiguous bitmap material groups in source order', () => {
  const faces = [
    [0, 1, 2, 0, 0, 1, 2, 0],
    [2, 1, 3, 0, 2, 1, 3, 1],
    [4, 5, 6, 0, 4, 5, 6, 1],
    [6, 5, 7, 0, 6, 5, 7, 8],
    [0, 0]
  ];
  assert.deepEqual(groupFacesByMaterial(faces, 2), [
    { materialIndex: 0, faces: [faces[0]] },
    { materialIndex: 1, faces: [faces[1], faces[2]] },
    { materialIndex: 0, faces: [faces[3]] }
  ]);
});

test('BioWare DDS parser reads DXT1 dimensions and mip data', () => {
  const bytes = new Uint8Array(28);
  const view = new DataView(bytes.buffer);
  view.setUint32(0, 4, true);
  view.setUint32(4, 4, true);
  view.setUint32(8, 3, true);
  view.setUint32(12, 8, true);
  bytes.fill(0x5a, 20);
  const texture = parseBioWareDds(bytes.buffer);
  assert.equal(texture.image.width, 4);
  assert.equal(texture.image.height, 4);
  assert.equal(texture.mipmaps.length, 1);
  assert.equal(texture.mipmaps[0].data.length, 8);
});

test('binary mode-zero meshes are empty sentinels only when every count is zero', () => {
  assert.equal(isEmptyBinaryMeshRecord(0, 0, 0, 0), true);
  assert.equal(isEmptyBinaryMeshRecord(0, 1, 0, 0), false);
  assert.equal(isEmptyBinaryMeshRecord(0, 0, 3, 0), false);
  assert.equal(isEmptyBinaryMeshRecord(3, 0, 0, 0), false);
});

test('MDL format detection accepts NWMax ASCII and rejects binary headers', () => {
  const modelText = '# Exported from NWmax\nnewmodel pma0\nsetsupermodel pma0 a_ba\nbeginmodelgeom pma0\n';
  assert.equal(isAsciiMdl(new TextEncoder().encode(modelText)), true);
  assert.equal(isAsciiMdl(new TextEncoder().encode('#MAXMODEL ASCII\nnewmodel prop\nbeginmodelgeom prop\n')), true);
  assert.equal(isAsciiMdl(new Uint8Array([0, 0, 0, 0, 20, 9, 0, 0])), false);
});

test('ASCII MDL axis-angle orientation converts to quaternion while binary remains quaternion', () => {
  const axisAngle = decodeModelOrientation([0, 0, 1, Math.PI / 2], 'axis-angle');
  assert.ok(Math.abs(axisAngle[0]) < 1e-8);
  assert.ok(Math.abs(axisAngle[1]) < 1e-8);
  assert.ok(Math.abs(axisAngle[2] - Math.SQRT1_2) < 1e-8);
  assert.ok(Math.abs(axisAngle[3] - Math.SQRT1_2) < 1e-8);
  assert.deepEqual(decodeModelOrientation([0, 0, 0, 1], 'axis-angle'), [0, 0, 0, 1]);
  assert.deepEqual(decodeModelOrientation([0, 0, 0, 2], 'quaternion'), [0, 0, 0, 1]);
});

test('BioWare PLT combines intensity and layer pixels through palette rows', () => {
  const bytes = new Uint8Array(32);
  bytes.set(new TextEncoder().encode('PLT V1  '), 0);
  const view = new DataView(bytes.buffer);
  view.setUint32(8, 2, true);
  view.setUint32(16, 2, true);
  view.setUint32(20, 2, true);
  bytes[24] = 7;
  bytes[25] = 0;
  bytes[26] = 11;
  bytes[27] = 1;
  bytes[28] = 9;
  bytes[29] = 1;
  bytes[30] = 13;
  bytes[31] = 0;
  const paletteData = new Uint8Array(256 * 8 * 4);
  paletteData.set([10, 20, 30, 255], (4 * 256 + 7) * 4);
  paletteData.set([40, 50, 60, 255], (4 * 256 + 13) * 4);
  const hairPaletteData = new Uint8Array(256 * 8 * 4);
  hairPaletteData.set([70, 80, 90, 255], (2 * 256 + 11) * 4);
  hairPaletteData.set([100, 110, 120, 255], (2 * 256 + 9) * 4);
  const decoded = decodeBioWarePlt(bytes, new Map([
    ['pal_skin01', { width: 256, height: 8, data: paletteData }],
    ['pal_hair01', { width: 256, height: 8, data: hairPaletteData }]
  ]), [3, 5]);
  // The first decoded row maps to UV v=0; no second vertical reversal.
  assert.equal(decoded.flipY, false);
  assert.deepEqual([...decoded.data], [
    10, 20, 30, 255,
    70, 80, 90, 255,
    100, 110, 120, 255,
    40, 50, 60, 255
  ]);
});

test('emitter preview spreads particles through its configured cone and spawn area', () => {
  const properties = { spread: 1.2, velocity: 2, randvel: 0.3, xsize: 100, ysize: 50 };
  const first = sampleEmitterParticle(properties, 0, 8);
  const second = sampleEmitterParticle(properties, 1, 8);
  assert.notDeepEqual(first.velocity, second.velocity);
  assert.notDeepEqual(first.origin, second.origin);
  assert.ok(first.velocity[1] > 0);
  assert.ok(first.origin.every(value => Math.abs(value) <= 0.5));
});

test('wide emitter spread is interpreted as a full cone width, not downward half-angle', () => {
  for (let index = 0; index < 64; index += 1) {
    const particle = sampleEmitterParticle({ spread: Math.PI, velocity: 2 }, index, 64);
    assert.ok(particle.velocity[1] >= -1e-8);
  }
});

test('creature PLT lookup falls back through phenotype and human race', () => {
  assert.deepEqual(
    creaturePltCandidates('m', 'a', 0, 1, 'neck', 1),
    ['pma0_neck001', 'pma1_neck001', 'pmh0_neck001', 'pmh1_neck001']
  );
  assert.deepEqual(creaturePltCandidates('m', 'h', 0, 0, 'chest', 4), ['pmh0_chest004']);
});

test('WOK parser applies tile transforms and filters surfaces by walkability', () => {
  const wok = `#MAXWALKMESH  ASCII
beginwalkmeshgeom sample
node aabb floor
position 0 0 0
orientation 0 0 1 0
verts 4
0 0 0
2 0 0
0 2 0
2 2 0
faces 2
0 1 2 0 0 0 0 1
1 3 2 0 0 0 0 2
endnode
node aabb raised
position 5 0 0
orientation 0 0 1 0
verts 3
0 0 0
2 0 0
0 2 0
faces 1
0 1 2 0 0 0 0 1
endnode
endwalkmeshgeom sample
`;
  const triangles = parseWalkmesh(wok, [false, true, false], {
    position: [10, 20, 3],
    orientation: 1
  });
  assert.equal(triangles.length, 2);
  assert.deepEqual(triangles[0].vertices, [
    [10, 3, -20],
    [10, 3, -22],
    [8, 3, -20]
  ]);
  assert.equal(findWalkableHeight(triangles, 9.8, -20.2), 3);
  assert.equal(findWalkableHeight(triangles, 8.2, -21.8), null);
  assert.deepEqual(triangles[1].vertices[0], [10, 3, -25]);
  const moved = moveOnWalkmesh(triangles, [9.4, 3, -20.6], 0.1, -0.1, 0.02, 0.2);
  assert.ok(Math.abs(moved[0] - 9.5) < 1e-8);
  assert.equal(moved[1], 3);
  assert.ok(Math.abs(moved[2] + 20.7) < 1e-8);
  assert.equal(moveOnWalkmesh(triangles, [9.4, 3, -20.6], 2, 0, 0.02, 0.2), null);
});

test('PWK and DWK triangles block capsule samples but not floor-parallel travel', () => {
  const objectMesh = `#MAXDOOR ASCII
node trimesh blocker
position 0 0 0
orientation 0 0 1 0
verts 4
2 0 0
2 0 2
2 -4 0
2 -4 2
faces 2
0 1 2 1 0 0 0 7
1 3 2 1 0 0 0 7
endnode
`;
  const obstacles = parseWalkmesh(objectMesh);
  assert.equal(obstacles.length, 2);
  assert.equal(collidesWithObjectWalkmeshes(obstacles, [1, 0, 1], [3, 0, 1], 0.18), true);
  assert.equal(collidesWithObjectWalkmeshes(obstacles, [1, 0, 1], [1.5, 0, 1], 0.18), false);
});
