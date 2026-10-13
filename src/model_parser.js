import { parseBinaryMdl } from './binary_mdl.js';
import { isAsciiMdl } from './mdl_format.js';
import { parseAsciiAnimations } from './mdl_animation.js';

export function parseAsciiMdl(text) {
  const lines = text.replaceAll('\r', '').split('\n');
  const nodes = [];
  let modelName = 'unnamed';
  let current = null;
  let inModelGeometry = false;
  let pendingArray = null;

  for (const sourceLine of lines) {
    const line = sourceLine.trim();
    if (!line || line.startsWith('#')) continue;

    if (pendingArray && pendingArray.remaining > 0) {
      const values = line.split(/\s+/).map(Number);
      if (values.some((value) => !Number.isFinite(value))) {
        throw new Error(`Invalid ${pendingArray.kind} data near ${pendingArray.node.name}.`);
      }
      pendingArray.node[pendingArray.kind].push(values);
      pendingArray.remaining -= 1;
      continue;
    }
    pendingArray = null;

    if (line.startsWith('newmodel ')) {
      modelName = line.slice('newmodel '.length).trim();
      continue;
    }
    if (line.startsWith('beginmodelgeom ')) {
      inModelGeometry = true;
      continue;
    }
    if (line.startsWith('endmodelgeom ')) {
      inModelGeometry = false;
      current = null;
      continue;
    }
    if (!inModelGeometry) continue;

    const nodeMatch = line.match(/^node\s+(\S+)\s+(.+)$/i);
    if (nodeMatch) {
      current = {
        type: nodeMatch[1].toLowerCase(),
        name: nodeMatch[2].trim(),
        parent: 'NULL',
        position: [0, 0, 0],
        orientation: [0, 0, 1, 0],
        orientationFormat: 'axis-angle',
        scale: 1,
        bitmap: '',
        bitmaps: [],
        properties: Object.create(null),
        verts: [],
        tverts: [],
        faces: []
      };
      nodes.push(current);
      continue;
    }
    if (line === 'endnode') {
      current = null;
      continue;
    }
    if (!current) continue;

    let match = line.match(/^parent\s+(.+)$/i);
    if (match) {
      current.parent = match[1].trim();
      continue;
    }
    match = line.match(/^bitmap\s+(\S+)/i);
    if (match) {
      current.bitmaps.push(match[1]);
      if (current.bitmaps.length === 1) current.bitmap = match[1];
      continue;
    }
    match = line.match(/^position\s+(.+)$/i);
    if (match) {
      current.position = parseNumberList(match[1], 3, current.name);
      continue;
    }
    match = line.match(/^orientation\s+(.+)$/i);
    if (match) {
      current.orientation = parseNumberList(match[1], 4, current.name);
      continue;
    }
    match = line.match(/^(verts|tverts|faces)\s+(\d+)$/i);
    if (match) {
      const kind = match[1].toLowerCase();
      const count = Number(match[2]);
      if (count > 1_000_000) throw new Error(`Unreasonable ${kind} count in ${current.name}.`);
      pendingArray = { kind, node: current, remaining: count };
    }
    const propertyMatch = line.match(/^([a-z][a-z0-9_]*)\s+(.+)$/i);
    if (propertyMatch) {
      const key = propertyMatch[1].toLowerCase();
      const values = propertyMatch[2].trim().split(/\s+/);
      const numbers = values.map(Number);
      current.properties[key] = numbers.every(Number.isFinite)
        ? (numbers.length === 1 ? numbers[0] : numbers)
        : propertyMatch[2].trim();
    }
  }

  if (pendingArray?.remaining > 0) {
    throw new Error(`Truncated ${pendingArray.kind} section in ${pendingArray.node.name}.`);
  }
  if (nodes.length === 0) throw new Error('No model nodes were found.');

  const byName = new Map(nodes.map((node) => [node.name, node]));
  const materialNames = [...new Set([
    ...nodes.filter((node) => node.type === 'trimesh').flatMap((node) =>
      (node.bitmaps.length ? node.bitmaps : [node.bitmap]).filter((bitmap) => bitmap && bitmap.toLowerCase() !== 'null')),
    ...nodes.filter((node) => node.type === 'emitter' && typeof node.properties.texture === 'string').map((node) => node.properties.texture)
  ])];
  let animationMetadata;
  try { animationMetadata = parseAsciiAnimations(text); }
  catch (error) { animationMetadata = { animations: [], supermodel: '', animationScale: 1, unsupportedAnimations: [error.message] }; }
  return { modelName, format: 'ASCII MDL', nodes, byName, materialNames, ...animationMetadata };
}

export function parseModel(buffer) {
  return isAsciiMdl(buffer)
    ? parseAsciiMdl(new TextDecoder('ascii').decode(buffer))
    : parseBinaryMdl(buffer);
}

function parseNumberList(value, length, name) {
  const values = value.split(/\s+/).map(Number);
  if (values.length < length || values.slice(0, length).some((item) => !Number.isFinite(item))) {
    throw new Error(`Invalid transform in node ${name}.`);
  }
  return values.slice(0, length);
}

