import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { openServerResourceContext } from '../electron/server_resource_context.mjs';
import { parse2da } from '../src/area.js';
import { parseGff } from '../src/gff.js';
import { gffField as field, gffRecord, typedGff, writeGff } from '../src/gff_writer.js';
import { parseModel } from '../src/model_parser.js';
import { NCS_OP, parseNcs, parseScriptApi } from '../src/ncs.js';
import { decodeResourceText, parseErf } from '../src/resource_archive.js';

// Derive from the authored benchmark. All art stays in the installed catalog.
const baselinePath = path.resolve('runtime-logs/dense-performance-server/modules/DensePerf.mod');
const home = path.resolve('runtime-logs/dense-performance-cx-server');
const moduleName = 'DensePerfCx';
const areaName = 'cx_showcase';
const arrivalTag = 'cx_showcase_in';
const returnTag = 'entry_a';
const baselineSha256 = 'fec1d0e61a4542216bfb8e6e16a85700f0e1a59b71cfbfb888661ea8f693b247';
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const B = x => field(0, x), W = x => field(2, x), H = x => field(3, x);
const D = x => field(4, x), I = x => field(5, x), F = x => field(8, x);
const S = x => field(10, x), R = x => field(11, x), T = x => field(12, x);
const L = x => field(15, x), empty = () => L([]);

const baselineBytes = await fs.readFile(baselinePath);
assert.equal(sha256(baselineBytes), baselineSha256, 'The supported DensePerf baseline changed');
const baseline = parseErf(baselineBytes).entries;
const entries = new Map(baseline);
const catalog = await openServerResourceContext({ install: path.resolve('../FullDecomp/NwnRootInstall') });
const text = async (name, type) => decodeResourceText(await catalog.getResource(name, type));
const api = new Map(parseScriptApi(await text('nwscript', 2009)).map(action => [action.name, action]));
const appearances = parse2da(await text('placeables', 2017)).orderedRows;

function script(name, build) {
  const body = [];
  const code = {
    action(name) {
      const action = api.get(name);
      assert.ok(action, `Installed command ${name} is unavailable`);
      body.push(NCS_OP.ACTION, 0, action.id >> 8, action.id & 255, action.args.length);
    },
    integer(value) {
      const bytes = Buffer.alloc(4);
      bytes.writeInt32BE(value);
      body.push(NCS_OP.CONST, 3, ...bytes);
    },
    string(value) {
      const bytes = Buffer.from(value, 'ascii');
      body.push(NCS_OP.CONST, 5, bytes.length >> 8, bytes.length & 255, ...bytes);
    },
    branch(op) {
      const offset = body.length;
      body.push(op, 0, 0, 0, 0, 0);
      return () => {
        const relative = Buffer.alloc(4);
        relative.writeInt32BE(body.length - offset);
        body.splice(offset + 2, 4, ...relative);
      };
    },
    assigned(subject, actions) {
      // Zero-local STORESTATE, with the continuation body at +16. The JMP
      // skips it in the caller while AssignCommand receives that saved body.
      body.push(NCS_OP.STORESTATE, 16, 0, 0, 0, 0, 0, 0, 0, 0);
      const finishJump = code.branch(NCS_OP.JMP);
      actions();
      body.push(NCS_OP.RETN, 0);
      finishJump();
      code.action(subject);
      code.action('AssignCommand');
    },
  };
  build(code);
  body.push(NCS_OP.RETN, 0);
  const bytes = Buffer.alloc(13 + body.length);
  bytes.write('NCS V1.0');
  bytes[8] = 0x42;
  bytes.writeUInt32BE(bytes.length, 9);
  bytes.set(body, 13);
  parseNcs(bytes, name);
  entries.set(`${name}:2010`, bytes);
}

function jumpScript(name, destination) {
  script(name, code => code.assigned('GetLastUsedBy', () => {
    code.string(destination);
    code.action('GetWaypointByTag');
    code.action('GetLocation');
    code.action('JumpToLocation');
  }));
}

function weatherScript(name, weather, description) {
  script(name, code => {
    code.integer(weather);
    code.action('GetLastUsedBy');
    code.action('GetArea');
    code.action('SetWeather');
    code.string(description);
    code.action('GetLastUsedBy');
    code.action('SendMessageToPC');
  });
}

jumpScript('cx_gate_in', arrivalTag);
jumpScript('cx_gate_out', returnTag);
weatherScript('cx_set_rain', 1, 'Rain. Compare the open smoke plume with the one under the awning.');
weatherScript('cx_set_snow', 2, 'Snow. The awning shelters the same patch of ground.');
weatherScript('cx_set_clear', 0, 'Clear skies. Compare the two plumes and look for runoff at the awning edge.');
script('cx_intro', code => {
  code.action('GetEnteringObject');
  code.action('GetIsPC');
  const end = code.branch(NCS_OP.JZ);
  code.string('CX Showcase: use a weather chest, then head north to compare open and covered smoke. The portal behind you returns to Dense Performance.');
  code.action('GetEnteringObject');
  code.action('SendMessageToPC');
  end();
});

// Stock appearance rows are pinned to their model names below. Labels are the
// actual native object names so picking and Examine identify each station.
const occupied = [];
function placeable(tag, name, appearance, model, x, y, { description = '', onUse = '' } = {}) {
  assert.equal(appearances[appearance]?.ModelName.toLowerCase(), model, name);
  assert.ok(catalog.hasResource(model, 2002), `Missing installed model ${model}`);
  occupied.push({ tag, name, appearance, model, x, y, onUse });
  return gffRecord({
    Tag: S(tag), LocName: T(name), Description: T(description), TemplateResRef: R(''),
    Appearance: D(appearance), X: F(x), Y: F(y), Z: F(0), Bearing: F(0),
    Static: B(onUse ? 0 : 1), Useable: B(onUse ? 1 : 0), HasInventory: B(0),
    Plot: B(1), HP: H(20), CurrentHP: H(20), Hardness: B(5), Faction: D(2),
    AnimationState: B(0), InventoryList: empty(), OnUsed: R(onUse),
  }, 9);
}

function transition(tag, label, target, x, y) {
  return gffRecord({
    Tag: S(tag), TemplateResRef: R(''), LocalizedName: T(label), Type: I(1), Faction: D(2),
    Cursor: B(1), HighlightHeight: F(0), LinkedTo: S(target), LinkedToFlags: B(2),
    LoadScreenID: W(0), TrapFlag: B(0), XPosition: F(x), YPosition: F(y), ZPosition: F(0),
    XOrientation: F(0), YOrientation: F(0), ZOrientation: F(0),
    Geometry: L([[-1.3, -1.3], [1.3, -1.3], [1.3, 1.3], [-1.3, 1.3]].map(([px, py]) =>
      gffRecord({ PointX: F(px), PointY: F(py), PointZ: F(0) }, 3))),
  }, 1);
}

const denseA = typedGff(parseGff(baseline.get('dense_a:2023')).root);
denseA.fields['Placeable List'].value.push(placeable('cx_gate_marker_in', 'CX Particle Showcase', 28, 'plc_d07', 50, 44, {
  onUse: 'cx_gate_in', description: 'Travel to the CX Particle Showcase, then return here through its gate.',
}));
denseA.fields.TriggerList.value.push(transition('cx_gate_trigger_in', 'CX Particle Showcase', arrivalTag, 50, 44));
entries.set('dense_a:2023', writeGff('GIT ', denseA));

const props = [
  placeable('cx_gate_marker_out', 'Return to Dense Performance', 28, 'plc_d07', 25, 4.5, { onUse: 'cx_gate_out' }),
  placeable('cx_sign', 'CX Showcase | Weather controls ahead', 87, 'plc_l05', 25, 9.5),
  placeable('cx_rain_box', 'Start rain', 7, 'plc_a08', 20.5, 12, { onUse: 'cx_set_rain' }),
  placeable('cx_snow_box', 'Start snow', 8, 'plc_a09', 25, 12, { onUse: 'cx_set_snow' }),
  placeable('cx_clear_box', 'Clear the sky', 9, 'plc_a10', 29.5, 12, { onUse: 'cx_set_clear' }),
  placeable('cx_brazier', 'Additive flame and blended smoke', 57, 'plc_i05', 16, 17),
  placeable('cx_flame', 'Large flame and smoke', 149, 'plc_t04', 20, 17),
  placeable('cx_cover', 'Rain shelter', 15378, 'ds_market_16', 27, 22),
  placeable('cx_smoke_cover', 'Blended smoke under the awning', 15197, 'dag_smk', 27, 22),
  placeable('cx_smoke_open', 'Blended smoke in the open', 15197, 'dag_smk', 34, 22),
  placeable('cx_trail_blue', 'Blue motion-blur trails', 159, 'plc_u04', 16, 26),
  placeable('cx_trail_cyan', 'Cyan motion-blur trails', 160, 'plc_u05', 20, 26),
  placeable('cx_mist', 'Linked mist ribbons', 791, 'tnp_gmist', 15, 32),
  placeable('cx_fountain', 'Additive water ripples and spray', 64, 'plc_j02', 33, 31),
];

// Build a flat outdoor area from the same native ARE schema as DensePerf.
const area = typedGff(parseGff(baseline.get('dense_a:2012')).root);
const tileModel = /\[TILE109\]\s*Model=ttr01_o01_01(?:\r?\n)/i;
const tileset = await text('ttr01', 2013);
assert.match(tileset, /^Interior=0\s*$/im);
assert.match(tileset, tileModel);
assert.ok(catalog.hasResource('ttr01_o01_01', 2002));
const tile = () => gffRecord({
  Tile_ID: I(109), Tile_Orientation: I(0), Tile_Height: I(0), Tile_MainLight1: B(0), Tile_MainLight2: B(0),
  Tile_SrcLight1: B(0), Tile_SrcLight2: B(0), Tile_AnimLoop1: B(1), Tile_AnimLoop2: B(1), Tile_AnimLoop3: B(1),
}, 1);
Object.assign(area.fields, {
  Tag: S(areaName), Name: T('CX Particle Showcase'), ResRef: R(areaName),
  Comments: S('Authored outdoor CX particle comparison area'), Width: I(5), Height: I(4), Flags: D(0),
  SunAmbientColor: D(0x4a4a4a), SunDiffuseColor: D(0xffffff), SunShadows: B(1), ShadowOpacity: B(80),
  OnEnter: R('cx_intro'), Tile_List: L(Array.from({ length: 20 }, tile)),
});
entries.set(`${areaName}:2012`, writeGff('ARE ', area));

const git = typedGff(parseGff(baseline.get('dense_a:2023')).root);
const arrival = git.fields.WaypointList.value[0];
Object.assign(arrival.fields, { Tag: S(arrivalTag), LocalizedName: T('Showcase entry'), XPosition: F(25), YPosition: F(7) });
Object.assign(git.fields, {
  'Creature List': empty(), 'Placeable List': L(props),
  TriggerList: L([transition('cx_gate_trigger_out', 'Return to Dense Performance', returnTag, 25, 4.5)]),
  WaypointList: L([arrival]),
});
entries.set(`${areaName}:2023`, writeGff('GIT ', git));

const ifo = typedGff(parseGff(baseline.get('module:2014')).root);
ifo.fields.Mod_Area_list.value.push(gffRecord({ Area_Name: R(areaName) }, 6));
ifo.fields.Mod_Name = T('Dense Performance + CX Showcase');
ifo.fields.Mod_Tag = S(moduleName);
entries.set('module:2014', writeGff('IFO ', ifo));

function packModule(resources) {
  const count = resources.size;
  const keyOffset = 160;
  const tableOffset = keyOffset + count * 24;
  let payloadOffset = tableOffset + count * 8;
  const bytes = Buffer.alloc(payloadOffset + [...resources.values()].reduce((total, row) => total + row.length, 0));
  bytes.write('MOD V1.0');
  bytes.writeUInt32LE(count, 16);
  bytes.writeUInt32LE(160, 20);
  bytes.writeUInt32LE(keyOffset, 24);
  bytes.writeUInt32LE(tableOffset, 28);
  let index = 0;
  for (const [key, payload] of resources) {
    const [name, type] = key.split(':');
    assert.match(name, /^[a-z0-9_]{1,16}$/);
    bytes.write(name, keyOffset + index * 24, 16, 'ascii');
    bytes.writeUInt32LE(index, keyOffset + index * 24 + 16);
    bytes.writeUInt16LE(Number(type), keyOffset + index * 24 + 20);
    bytes.writeUInt32LE(payloadOffset, tableOffset + index * 8);
    bytes.writeUInt32LE(payload.length, tableOffset + index * 8 + 4);
    bytes.set(payload, payloadOffset);
    payloadOffset += payload.length;
    index++;
  }
  return bytes;
}

const bytes = packModule(entries);
const saved = parseErf(bytes).entries;
assert.deepEqual([...saved.keys()], [...entries.keys()]);
for (const [key, original] of baseline) {
  if (key !== 'dense_a:2023' && key !== 'module:2014') assert.deepEqual(saved.get(key), original, key);
}
const rawA = parseGff(baseline.get('dense_a:2023')).root;
const nextA = parseGff(saved.get('dense_a:2023')).root;
const inbound = nextA.TriggerList.pop();
nextA['Placeable List'].pop();
assert.deepEqual(nextA, rawA, 'Dense area A must differ only by the gate and trigger');
const oldIfo = parseGff(baseline.get('module:2014')).root;
const nextIfo = parseGff(saved.get('module:2014')).root;
assert.equal(nextIfo.Mod_Area_list.pop().Area_Name, areaName);
nextIfo.Mod_Name = oldIfo.Mod_Name;
nextIfo.Mod_Tag = oldIfo.Mod_Tag;
assert.deepEqual(nextIfo, oldIfo, 'Original arrival and scripted stress controls must stay intact');

const builtArea = parseGff(saved.get(`${areaName}:2012`)).root;
const builtGit = parseGff(saved.get(`${areaName}:2023`)).root;
assert.equal(builtArea.Flags, 0, 'Showcase must use outdoor area flags');
assert.equal(builtArea.Tile_List.length, builtArea.Width * builtArea.Height);
assert.equal(inbound.LinkedTo, builtGit.WaypointList[0].Tag);
assert.equal(builtGit.TriggerList[0].LinkedTo, rawA.WaypointList[0].Tag);
assert.equal(builtGit['Placeable List'].length, props.length);
for (const prop of builtGit['Placeable List']) {
  if (prop.OnUsed) assert.ok(saved.has(`${prop.OnUsed}:2010`), prop.Tag);
  assert.ok(prop.X > 0 && prop.X < builtArea.Width * 10 && prop.Y > 0 && prop.Y < builtArea.Height * 10, prop.Tag);
}

const expectedEmitters = [
  ['plc_d07', 'Normal', 'Lighten'], ['plc_i05', 'Normal', 'Normal'], ['plc_i05', 'Normal', 'Lighten'],
  ['dag_smk', 'Normal', 'Normal'], ['plc_u04', 'Motion_Blur', 'Lighten'],
  ['plc_u05', 'Motion_Blur', 'Lighten'], ['tnp_gmist', 'Linked', 'Lighten'],
  ['plc_j02', 'Billboard_to_World_Z', 'Lighten'],
];
for (const [model, render, blend] of expectedEmitters) {
  const parsed = parseModel(await catalog.getResource(model, 2002));
  const matching = parsed.nodes.filter(node => node.type === 'emitter' && node.properties.render === render && node.properties.blend === blend);
  assert.ok(matching.some(node => [3, 2033, 2059, 2073].some(type => catalog.hasResource(node.properties.texture, type))), `${model} lacks ${render}/${blend} with an installed atlas`);
}

const output = path.join(home, 'modules', `${moduleName}.mod`);
await fs.mkdir(path.dirname(output), { recursive: true });
try {
  await fs.writeFile(output, bytes, { flag: 'wx' });
} catch (error) {
  if (error.code !== 'EEXIST') throw error;
  assert.deepEqual(await fs.readFile(output), bytes, 'A different showcase artifact exists; preserve it');
}
assert.equal(sha256(await fs.readFile(baselinePath)), baselineSha256);
console.log(JSON.stringify({
  module: moduleName, output, sha256: sha256(bytes), bytes: bytes.length,
  baselineUnchanged: true, areas: ['dense_a', 'dense_b', areaName],
  gate: { x: 50, y: 44, to: arrivalTag }, returnGate: { x: 25, y: 4.5, to: returnTag },
  outdoor: true, stationCount: props.length, stations: occupied, expectedEmitters,
}, null, 2));
