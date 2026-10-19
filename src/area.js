import { parseGff } from './gff.js';
import { decodeResourceText, RESOURCE_TYPE } from './resource_archive.js';
import { parseTileSurfaceMesh, rotateTilePoint } from './tile_surface_mesh.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';
import {tileMapImageRef} from './tile_map_image.js';

const MAX_AREA_TILES = 65_536;

export async function loadAreaWalkmesh(area, resolver) {
  const table = parse2da(decodeResourceText(await resolver.getResource('surfacemat', RESOURCE_TYPE.TWO_DA)));
  const triangles = [];
  const cameraTriangles = [];
  const missing = [];
  for (const [index, tile] of area.tiles.entries()) {
    const x = index % area.width, y = Math.floor(index / area.width);
    try {
      const bytes = await resolver.getResource(tile.model, RESOURCE_TYPE.WOK);
      // Use the same native loader as simulation: f32 node transforms, integer
      // vertex snapping, physical surface rows and exact tile quarter turns.
      // Exporter residues otherwise leave invisible cracks between adjacent WOKs.
      const mesh = parseTileSurfaceMesh(bytes, table);
      const transformVertices = source => source.map(([vx, vy, vz]) => {
        const [worldX, worldY] = rotateTilePoint({ x, y, orientation: tile.orientation ?? 0 },
          [Math.fround(x * 10 + vx), Math.fround(y * 10 + vy)], false);
        return [worldX, Math.fround(vz + Math.fround(tile.height * area.tileHeight)), -worldY];
      });
      const vertices=transformVertices(mesh.vertices);
      triangles.push(...mesh.faces.map((face, i) => ({ vertices: face.map(index => vertices[index]), surfaceType: mesh.materials[i] })));
      cameraTriangles.push(...mesh.faces.map((face,i)=>({vertices:face.map(index=>vertices[index]),surfaceType:mesh.materials[i]})));
      const denied=transformVertices(mesh.denied.vertices);
      cameraTriangles.push(...mesh.denied.faces.map((face,i)=>({vertices:face.map(index=>denied[index]),surfaceType:mesh.denied.materials[i]})));
    } catch (error) {
      runtimeDiagnostics.error(error, 'scene.walkmesh-unavailable', { area: area.resRef, model: tile.model, tileIndex: index });
      missing.push({ model: tile.model, reason: error.message });
    }
  }
  return { triangles, cameraTriangles, missing };
}

export async function parseAreaModule(moduleResRef, resolver) {
  const areaDocument = parseGff(await resolver.getResource(moduleResRef, RESOURCE_TYPE.ARE), 'ARE ');
  const gitDocument = parseGff(await resolver.getResource(moduleResRef, RESOURCE_TYPE.GIT), 'GIT ');
  const area = areaDocument.root;
  const git = gitDocument.root;
  const width = readCount(area.Width, 'Area Width');
  const height = readCount(area.Height, 'Area Height');
  if (!width || !height || width * height > MAX_AREA_TILES) {
    throw new Error('Area dimensions are invalid or too large.');
  }
  if (!Array.isArray(area.Tile_List) || area.Tile_List.length !== width * height) {
    throw new Error(`Area Tile_List has ${area.Tile_List?.length ?? 0} entries; expected ${width * height}.`);
  }

  const tilesetResRef = requireResRef(area.Tileset, 'Area Tileset');
  const tileset = parseTileset(decodeResourceText(await resolver.getResource(tilesetResRef, RESOURCE_TYPE.SET)));
  const tiles = area.Tile_List.map((entry, index) => {
    const tileId = readCount(entry.Tile_ID, `Tile ${index} ID`);
    const tileDefinition = tileset.tiles[tileId];
    if (!tileDefinition?.model) throw new Error(`Tileset ${tilesetResRef} has no model for tile ${tileId}.`);
    const orientation = readCount(entry.Tile_Orientation ?? 0, `Tile ${index} orientation`);
    if (orientation > 3) throw new Error(`Tile ${index} orientation ${orientation} is unsupported.`);
    return {
      tileId,
      model: tileDefinition.model,
      mapImage:tileDefinition.mapImage,
      height: readCount(entry.Tile_Height ?? 0, `Tile ${index} height`),
      orientation
    };
  });

  const [appearanceTable, genericDoorTable, doorTypeTable] = await Promise.all([
    resolver.getResource('placeables', RESOURCE_TYPE.TWO_DA),
    resolver.getResource('genericdoors', RESOURCE_TYPE.TWO_DA),
    resolver.getResource('doortypes', RESOURCE_TYPE.TWO_DA)
  ]).then((buffers) => buffers.map((buffer) => parse2da(decodeResourceText(buffer))));
  const [creatureAppearanceTable, racialTypesTable, genderTable, phenotypeTable] = await Promise.all([
    'appearance', 'racialtypes', 'gender', 'phenotype'
  ].map(async (name) => parse2da(decodeResourceText(await resolver.getResource(name, RESOURCE_TYPE.TWO_DA)))));
  const placeables = (git['Placeable List'] ?? []).map((entry, index) => {
    const appearance = readCount(entry.Appearance, `Placeable ${index} Appearance`);
    const model = appearanceTable.rows.get(appearance)?.ModelName;
    if (!model || model === '****') throw new Error(`Placeable appearance ${appearance} has no model in placeables.2da.`);
    return {
      model: model.toLowerCase(),
      x: readFinite(entry.X, `Placeable ${index} X`),
      y: readFinite(entry.Y, `Placeable ${index} Y`),
      z: readFinite(entry.Z, `Placeable ${index} Z`),
      bearing: readFinite(entry.Bearing ?? 0, `Placeable ${index} Bearing`),
      template: String(entry.TemplateResRef ?? ''),
      tag: String(entry.Tag ?? ''),
      usable: entry.Useable !== 0,
      locked: Boolean(entry.Locked),
      lockable: entry.Lockable === undefined ? undefined : Boolean(entry.Lockable),
      trapped: entry.TrapFlag === undefined ? undefined : Boolean(entry.TrapFlag)
    };
  });
  const doors = [];
  let unsupportedDoors = 0;
  const doorBlueprints = new Map();
  for (const [index, placement] of (git['Door List'] ?? []).entries()) {
    const template = String(placement.TemplateResRef ?? '').toLowerCase();
    if (template && !doorBlueprints.has(template)) {
      try { doorBlueprints.set(template, parseGff(await resolver.getResource(template, RESOURCE_TYPE.UTD), 'UTD ').root); }
      catch (error) { runtimeDiagnostics.error(error, 'scene.blueprint-unavailable', { area: moduleResRef, resRef: template, sourceKey: `${moduleResRef}:door:${index}` }); doorBlueprints.set(template, {}); }
    }
    const entry = { ...(doorBlueprints.get(template) ?? {}), ...placement };
    const appearance = readCount(entry.Appearance ?? 0, `Door ${index} Appearance`);
    const genericType = readCount(entry.GenericType_New ?? entry.GenericType ?? 0, `Door ${index} GenericType`);
    const doorAppearance = resolveDoorModel(appearance, genericType, genericDoorTable, doorTypeTable);
    if (!doorAppearance) {
      runtimeDiagnostics.record('scene.door-appearance-unavailable', `Door appearance ${appearance}/${genericType} cannot be resolved`, { area: moduleResRef, sourceKey: `${moduleResRef}:door:${index}`, appearance, genericType, tag: entry.Tag });
      unsupportedDoors += 1;
      continue;
    }
    if (!doorAppearance.visible) continue;
    doors.push({
      sourceIndex: index,
      model: doorAppearance.model,
      x: readFinite(entry.X, `Door ${index} X`),
      y: readFinite(entry.Y, `Door ${index} Y`),
      z: readFinite(entry.Z, `Door ${index} Z`),
      bearing: readFinite(entry.Bearing ?? 0, `Door ${index} Bearing`),
      animationState: readCount(entry.AnimationState ?? 0, `Door ${index} AnimationState`),
      locked: Boolean(entry.Locked),
      lockable: entry.Lockable === undefined ? undefined : Boolean(entry.Lockable),
      trapped: entry.TrapFlag === undefined ? undefined : Boolean(entry.TrapFlag),
      usable: entry.Useable !== 0,
      scripts: { click: String(entry.OnClick ?? ''), open: String(entry.OnOpen ?? ''), closed: String(entry.OnClosed ?? ''), failToOpen: String(entry.OnFailToOpen ?? '') },
      linkedTo: String(entry.LinkedTo ?? ''),
      linkedToFlags: readCount(entry.LinkedToFlags ?? 0, `Door ${index} LinkedToFlags`),
      linkedToModule: String(entry.LinkedToModule ?? ''),
      template: String(entry.TemplateResRef ?? ''),
      tag: String(entry.Tag ?? '')
    });
  }
  const creatures = [];
  let unsupportedCreatures = 0;
  for (const [index, entry] of (git['Creature List'] ?? []).entries()) {
    const creature = resolveCreatureModels(entry, index, {
      appearance: creatureAppearanceTable,
      racialTypes: racialTypesTable,
      gender: genderTable,
      phenotype: phenotypeTable
    });
    if (creature) creatures.push(creature);
    else { unsupportedCreatures += 1; runtimeDiagnostics.record('scene.creature-appearance-unavailable', `Creature appearance ${entry.Appearance_Type} cannot be resolved`, { area: moduleResRef, sourceKey: `${moduleResRef}:creature:${index}`, tag: entry.Tag, appearance: entry.Appearance_Type }); }
  }

  const areaName = typeof area.Name === 'string'
    ? area.Name
    : area.Name?.entries?.[0]?.text || moduleResRef;
  const unsupported = {
    doors: unsupportedDoors,
    creatures: unsupportedCreatures,
    encounters: git['Encounter List']?.length ?? 0
  };
  return {
    resRef: moduleResRef,
    name: areaName,
    width,
    height,
    tileset: tilesetResRef,
    tileHeight: tileset.transition,
    lighting: {
      sunAmbientColor: decodeNwnColor(area.SunAmbientColor ?? 0),
      sunDiffuseColor: decodeNwnColor(area.SunDiffuseColor ?? 0),
      moonAmbientColor: decodeNwnColor(area.MoonAmbientColor ?? 0),
      moonDiffuseColor: decodeNwnColor(area.MoonDiffuseColor ?? 0),
      sunShadows: area.SunShadows ?? 0,
      moonShadows: area.MoonShadows ?? 0,
      shadowOpacity: area.ShadowOpacity ?? 255
    },
    tiles,
    placeables,
    doors,
    creatures,
    unsupported
  };
}

const CREATURE_PARTS = [
  ['head', 'Appearance_Head', 'head_g'],
  ['neck', 'BodyPart_Neck', 'neck_g'],
  ['chest', 'BodyPart_Torso', 'torso_g'],
  ['pelvis', 'BodyPart_Pelvis', 'pelvis_g'],
  ['belt', 'BodyPart_Belt', 'belt_g'],
  ['footr', 'ArmorPart_RFoot', 'rfoot_g'],
  ['footl', 'BodyPart_LFoot', 'lfoot_g'],
  ['shinr', 'BodyPart_RShin', 'rshin_g'],
  ['shinl', 'BodyPart_LShin', 'lshin_g'],
  ['legl', 'BodyPart_LThigh', 'lthigh_g'],
  ['legr', 'BodyPart_RThigh', 'rthigh_g'],
  ['forer', 'BodyPart_RFArm', 'rforearm_g'],
  ['forel', 'BodyPart_LFArm', 'lforearm_g'],
  ['bicepr', 'BodyPart_RBicep', 'rbicep_g'],
  ['bicepl', 'BodyPart_LBicep', 'lbicep_g'],
  ['shor', 'BodyPart_RShoul', 'rshoulder_g'],
  ['shol', 'BodyPart_LShoul', 'lshoulder_g'],
  ['handr', 'BodyPart_RHand', 'rhand_g'],
  ['handl', 'BodyPart_LHand', 'lhand_g']
];

export function resolveCreatureModels(entry, index, tables) {
  const appearanceId = readCount(entry.Appearance_Type, `Creature ${index} Appearance_Type`);
  const appearance = tables.appearance.rows.get(appearanceId);
  if (!appearance) return null;
  const raceName = String(appearance.RACE ?? '').toLowerCase();
  if (appearance.MODELTYPE !== 'P') {
    if (!raceName || raceName === '****') return null;
    return makeCreaturePlacement(entry, index, { model: raceName, parts: [] });
  }

  const raceId = readCount(entry.Race, `Creature ${index} Race`);
  const race = tables.racialTypes.rows.get(raceId);
  const genderId = readCount(entry.Gender ?? 0, `Creature ${index} Gender`);
  const gender = tables.gender.rows.get(genderId);
  if (!race || !gender || !raceName || raceName === '****') return null;
  const phenotypeId = readCount(entry.Phenotype ?? 0, `Creature ${index} Phenotype`);
  const phenotype = tables.phenotype.rows.get(phenotypeId);
  const defaultPhenotype = phenotype?.DefaultPhenoType ?? String(phenotypeId);
  const prefix = `p${gender.GENDER}${raceName}`;
  const model = `${prefix}${phenotypeId}`.toLowerCase();
  const fields = Object.create(null);
  for (const [partName, fieldName, nodeName] of CREATURE_PARTS) {
    const partId = Number(entry[fieldName] ?? 0);
    if (!Number.isInteger(partId) || partId <= 0) continue;
    fields[fieldName] = {
      model: `${prefix}${phenotypeId}_${partName}${String(partId).padStart(3, '0')}`.toLowerCase(),
      fallbackModel: `${prefix}${defaultPhenotype}_${partName}${String(partId).padStart(3, '0')}`.toLowerCase(),
        pltCandidates: creaturePltCandidates(gender.GENDER, raceName, phenotypeId, defaultPhenotype, partName, partId),
      node: nodeName
    };
  }
  const parts = Object.values(fields);
  return makeCreaturePlacement(entry, index, { model, fallbackModel: `${prefix}${defaultPhenotype}`.toLowerCase(), parts });
}

function makeCreaturePlacement(entry, index, models) {
  const bearingX = readFinite(entry.XOrientation ?? 0, `Creature ${index} XOrientation`);
  const bearingY = readFinite(entry.YOrientation ?? 1, `Creature ${index} YOrientation`);
  return {
    ...models,
    sourceIndex: index,
    paletteColors: [
      readCount(entry.Color_Skin ?? 0, `Creature ${index} Color_Skin`),
      readCount(entry.Color_Hair ?? 0, `Creature ${index} Color_Hair`),
      readCount(entry.Color_Metal1 ?? 0, `Creature ${index} Color_Metal1`),
      readCount(entry.Color_Metal2 ?? 0, `Creature ${index} Color_Metal2`),
      readCount(entry.Color_Cloth1 ?? 0, `Creature ${index} Color_Cloth1`),
      readCount(entry.Color_Cloth2 ?? 0, `Creature ${index} Color_Cloth2`),
      readCount(entry.Color_Leather1 ?? 0, `Creature ${index} Color_Leather1`),
      readCount(entry.Color_Leather2 ?? 0, `Creature ${index} Color_Leather2`),
      readCount(entry.Color_Tattoo1 ?? 0, `Creature ${index} Color_Tattoo1`),
      readCount(entry.Color_Tattoo2 ?? 0, `Creature ${index} Color_Tattoo2`)
    ],
    x: readFinite(entry.XPosition, `Creature ${index} XPosition`),
    y: readFinite(entry.YPosition, `Creature ${index} YPosition`),
    z: readFinite(entry.ZPosition, `Creature ${index} ZPosition`),
    bearing: -Math.atan2(bearingX, bearingY),
    tag: String(entry.Tag ?? ''),
    template: String(entry.TemplateResRef ?? '')
  };
}

export function resolveDoorModel(appearance, genericType, genericDoorTable, doorTypeTable) {
  const table = appearance === 0 ? genericDoorTable : doorTypeTable;
  const row = table.rows.get(appearance === 0 ? genericType : appearance);
  if (!row) return null;
  if (row.VisibleModel === '0') return { visible: false, model: '' };
  const model = row.ModelName ?? row.Model;
  if (!model || model === '****') return null;
  return { visible: true, model: model.toLowerCase() };
}

export function decodeNwnColor(value) {
  const packed = Number.isInteger(value) ? value >>> 0 : 0;
  return [packed & 0xff, (packed >>> 8) & 0xff, (packed >>> 16) & 0xff]
    .map((channel) => channel / 255);
}

export function parseTileset(text) {
  const sections = parseIni(text);
  const count = Number(sections.TILES?.Count);
  const transition = Number(sections.GENERAL?.Transition ?? 1);
  if (!Number.isInteger(count) || count < 1 || count > MAX_AREA_TILES) {
    throw new Error('Tileset has an invalid TILES Count.');
  }
  if (!Number.isFinite(transition) || transition < 0) throw new Error('Tileset has an invalid height transition.');
  const tiles = Array.from({ length: count }, (_, index) => ({
    model: sections[`TILE${index}`]?.Model?.toLowerCase() ?? '',
    mapImage:tileMapImageRef(sections[`TILE${index}`]?.ImageMap2D),
    // Preserve native SET fields independently of the shared WOK resource.
    pathNodeFields: Object.fromEntries(['PathNode','Orientation','VisibilityNode','VisibilityOrientation','DoorVisibilityNode','DoorVisibilityOrientation','Doors']
      .map(key=>[key,sections[`TILE${index}`]?.[key]]))
  }));
  return { transition, tiles };
}

export function parse2da(text) {
  const lines = text.replaceAll('\r', '').split('\n').map((line) => line.trim());
  const first = lines.findIndex((line) => line && !line.startsWith(';'));
  if (first < 0 || !lines[first].startsWith('2DA V')) throw new Error('Unsupported 2DA header.');
  const defaultLine = lines.findIndex((line, index) => index > first && /^DEFAULT:/i.test(line));
  const defaultValue = defaultLine < 0 ? '****' : (tokenize2da(lines[defaultLine])[1] ?? '****');
  let headerLine = defaultLine < 0 ? first + 1 : defaultLine + 1;
  while (headerLine < lines.length && (!lines[headerLine] || lines[headerLine].startsWith(';'))) headerLine += 1;
  if (headerLine >= lines.length) throw new Error('2DA file is missing column names.');

  const columns = tokenize2da(lines[headerLine]);
  const rows = new Map();
  // C2DA integer access uses physical row position, not the printed row label.
  const orderedRows = [];
  const orderedCells = [];
  for (let index = headerLine + 1; index < lines.length; index += 1) {
    const line = lines[index];
    if (!line || line.startsWith(';')) continue;
    const tokens = tokenize2da(line);
    const rowId = Number(tokens[0]);
    const row = Object.create(null);
    for (let column = 0; column < columns.length; column += 1) {
      if (!Object.hasOwn(row, columns[column])) row[columns[column]] = tokens[column + 1] ?? defaultValue;
    }
    orderedRows.push(row);
    orderedCells.push(columns.map((_name, column) => tokens[column + 1] ?? defaultValue));
    if (Number.isInteger(rowId)) rows.set(rowId, row);
  }
  return { defaultValue, columns, rows, orderedRows, orderedCells };
}

function parseIni(text) {
  const sections = Object.create(null);
  let section = '';
  for (const sourceLine of text.replaceAll('\r', '').split('\n')) {
    const line = sourceLine.trim();
    if (!line || line.startsWith(';')) continue;
    const heading = line.match(/^\[([^\]]+)\]$/);
    if (heading) {
      section = heading[1].toUpperCase();
      sections[section] ??= Object.create(null);
      continue;
    }
    const pair = line.match(/^([^=]+)=(.*)$/);
    if (pair && section) sections[section][pair[1].trim()] = pair[2].trim();
  }
  return sections;
}

function tokenize2da(line) {
  const tokens = [];
  const matcher = /"((?:[^"]|"")*)"|(\S+)/g;
  for (const match of line.matchAll(matcher)) tokens.push((match[1] ?? match[2]).replaceAll('""', '"'));
  return tokens;
}

function readCount(value, label) {
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number < 0) throw new Error(`${label} is invalid.`);
  return number;
}

function readFinite(value, label) {
  const number = Number(value);
  if (!Number.isFinite(number)) throw new Error(`${label} is invalid.`);
  return number;
}

function requireResRef(value, label) {
  if (typeof value !== 'string' || !value || value === '****') throw new Error(`${label} is missing.`);
  return value.toLowerCase();
}

export function creaturePltCandidates(gender, race, phenotype, fallbackPhenotype, partName, partId) {
  const suffix = `_${partName}${String(partId).padStart(3, '0')}`;
  return [...new Set([
    `p${gender}${race}${phenotype}${suffix}`,
    `p${gender}${race}${fallbackPhenotype}${suffix}`,
    `p${gender}h${phenotype}${suffix}`,
    `p${gender}h${fallbackPhenotype}${suffix}`
  ].map(name => name.toLowerCase()))];
}
