import { parseGff } from './gff.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';

const MAX_RESOURCES = 1_000_000;
const textDecoder = new TextDecoder('windows-1252');

export const RESOURCE_TYPE = Object.freeze({
  TGA: 3,
  WAV: 4,
  SSF: 2060,
  SHD: 2069,
  PLT: 6,
  SET: 2013,
  TWO_DA: 2017,
  MDL: 2002,
  NSS: 2009,
  NCS: 2010,
  ARE: 2012,
  IFO: 2014,
  GIT: 2023,
  UTP: 2044,
  UTI: 2025,
  UTD: 2042,
  UTW: 2058,
  JRL: 2056,
  DLG: 2029,
  GUI: 2047,
  TTF: 2074,
  DDS: 2033,
  WOK: 2016,
  DWK: 2052,
  PWK: 2053
});

export function parseErf(input) {
  const bytes = toBytes(input);
  requireRange(bytes, 0, 160, 'ERF header');
  const type = readTag(bytes, 0);
  const version = readTag(bytes, 4);
  if (!['ERF ', 'MOD ', 'HAK '].includes(type)) throw new Error(`Unsupported archive type ${type}.`);
  if (version !== 'V1.0' && version !== 'V1.1') throw new Error(`Unsupported ${type.trim()} version ${version}.`);

  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const resourceCount = view.getUint32(16, true);
  const keyListOffset = view.getUint32(24, true);
  const resourceListOffset = view.getUint32(28, true);
  if (resourceCount > MAX_RESOURCES) throw new Error('Archive contains too many resources.');
  if (resourceListOffset < keyListOffset) throw new Error('ERF resource table precedes its key table.');
  const keyListSize = resourceListOffset - keyListOffset;
  const keyStride = version === 'V1.0' || (resourceCount && keyListSize / resourceCount < 40) ? 24 : 40;
  requireRange(bytes, keyListOffset, resourceCount * keyStride, 'ERF key list');
  requireRange(bytes, resourceListOffset, resourceCount * 8, 'ERF resource list');

  const entries = new Map();
  for (let index = 0; index < resourceCount; index += 1) {
    const keyOffset = keyListOffset + index * keyStride;
    const nameLength = keyStride === 40 ? 32 : 16;
    const resref = readFixedString(bytes, keyOffset, nameLength).toLowerCase();
    const resourceType = view.getUint16(keyOffset + nameLength + 4, true);
    const resourceOffset = view.getUint32(resourceListOffset + index * 8, true);
    const resourceSize = view.getUint32(resourceListOffset + index * 8 + 4, true);
    requireRange(bytes, resourceOffset, resourceSize, `ERF resource ${resref}`);
    entries.set(resourceKey(resref, resourceType), bytes.slice(resourceOffset, resourceOffset + resourceSize));
  }
  return { type: type.trim(), version, entries };
}

export function parseKey(input) {
  const bytes = toBytes(input);
  requireRange(bytes, 0, 24, 'KEY header');
  if (readTag(bytes, 0) !== 'KEY ') throw new Error('Selected game-data folder has an invalid KEY file.');
  const version = readTag(bytes, 4);
  if (version !== 'V1  ' && version !== 'V1.1') throw new Error(`Unsupported KEY version ${version}.`);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const bifCount = view.getUint32(8, true);
  const resourceCount = view.getUint32(12, true);
  let headerOffset = 16;
  if (version === 'V1.1') headerOffset += 4;
  const bifTableOffset = view.getUint32(headerOffset, true);
  const resourceTableOffset = view.getUint32(headerOffset + 4, true);
  const bifEntrySize = 12;
  const resourceEntrySize = version === 'V1.1' ? 26 : 22;
  if (bifCount > MAX_RESOURCES || resourceCount > MAX_RESOURCES) throw new Error('KEY file contains too many entries.');
  requireRange(bytes, bifTableOffset, bifCount * bifEntrySize, 'KEY BIF table');
  requireRange(bytes, resourceTableOffset, resourceCount * resourceEntrySize, 'KEY resource table');

  const bifNames = Array.from({ length: bifCount }, (_, index) => {
    const offset = bifTableOffset + index * bifEntrySize;
    const nameOffset = view.getUint32(offset + 4, true);
    const nameSize = version === 'V1.1' ? view.getUint32(offset + 8, true) : view.getUint16(offset + 8, true);
    requireRange(bytes, nameOffset, nameSize, 'KEY BIF filename');
    return readFixedString(bytes, nameOffset, nameSize).replaceAll('\\', '/').replace(/^\/+/, '').toLowerCase();
  });

  const resources = new Map();
  for (let index = 0; index < resourceCount; index += 1) {
    const offset = resourceTableOffset + index * resourceEntrySize;
    const resref = readFixedString(bytes, offset, 16).toLowerCase();
    const resourceType = view.getUint16(offset + 16, true);
    const resourceId = view.getUint32(offset + 18, true);
    const bifIndex = version === 'V1.1' ? view.getUint32(offset + 22, true) >>> 20 : resourceId >>> 20;
    if (bifIndex >= bifNames.length) throw new Error(`KEY resource ${resref} references missing BIF ${bifIndex}.`);
    resources.set(resourceKey(resref, resourceType), {
      resref,
      resourceType,
      bifIndex,
      resourceIndex: resourceId & 0xfffff
    });
  }
  return { version, bifNames, resources };
}

export class ResourceResolver {
  static async createGameData(gameFiles) {
    try {
    return new ResourceResolver({ entries: new Map() }, await loadInstalledKeys(gameFiles), gameFiles);
    } catch (error) { runtimeDiagnostics.error(error, 'load.game-data-failed'); throw error; }
  }

  static async create(moduleFile, gameFiles, hakFiles = []) {
    try {
    const moduleBytes = await readFileBytes(moduleFile);
    const module = parseErf(moduleBytes);
    const key = await loadInstalledKeys(gameFiles);
    const hakList = module.entries.has(resourceKey('module', RESOURCE_TYPE.IFO))
      ? parseGff(module.entries.get(resourceKey('module', RESOURCE_TYPE.IFO)), 'IFO ').root.Mod_HakList ?? []
      : [];
    const candidates = new Map([...hakFiles].map((file) => [
      filePath(file).split('/').at(-1).replace(/\.hak$/i, ''), file
    ]));
    const haks = [];
    const missingHaks = [];
    for (const entry of hakList) {
      const name = String(entry.Mod_Hak ?? '').toLowerCase();
      const file = candidates.get(name);
      if (!file) {
        missingHaks.push(name);
        continue;
      }
      haks.push({ name, ...parseErf(await readFileBytes(file)) });
    }
    const resolver = new ResourceResolver(module, key, gameFiles, haks, missingHaks);
    resolver.moduleName = moduleFile.name ?? 'module';
    for (const resRef of missingHaks) runtimeDiagnostics.record('load.hak-missing', `Module HAK ${resRef} is unavailable`, { module: resolver.moduleName, resRef });
    return resolver;
    } catch (error) { runtimeDiagnostics.error(error, 'load.module-failed', { module: moduleFile.name }); throw error; }
  }

  constructor(module, key, gameFiles, haks = [], missingHaks = []) {
    this.module = module;
    this.key = key;
    this.files = [...gameFiles];
    this.haks = haks;
    this.missingHaks = missingHaks;
    this.bifCache = new Map();
  }

  // Native Exists is a catalog query, not a BIF read/decode. Zero-length
  // registered resources still exist, and missing probes are normal branches.
  hasResource(resref,resourceType){const key=resourceKey(String(resref).toLowerCase(),resourceType);return this.module.entries.has(key)||this.haks.some(hak=>hak.entries.has(key))||this.key.resources.has(key);}

  async getResource(resref, resourceType) {
    const name = String(resref).toLowerCase();
    let source = 'lookup', bifName;
    try {
    const moduleResource = this.module.entries.get(resourceKey(name, resourceType));
    if (moduleResource) return moduleResource.slice().buffer;
    for (const hak of this.haks) {
      const resource = hak.entries.get(resourceKey(name, resourceType));
      if (resource) return resource.slice().buffer;
    }
    const entry = this.key.resources.get(resourceKey(name, resourceType));
    if (!entry) {
      const error = new Error(`Resource ${name} (type ${resourceType}) was not found in the module, loaded HAKs, or KEY.`);
      error.code = 'RESOURCE_NOT_FOUND'; error.resourceType = resourceType; error.resRef = name; throw error;
    }
    source = 'bif'; bifName = this.key.bifNames[entry.bifIndex];
    const bifBytes = await this.getBifBytes(bifName);
    const resource = readBifResource(bifBytes, entry.resourceIndex, resourceType, name);
    return resource.slice().buffer;
    } catch (error) {
      // Lookups include normal TGA/DDS/PLT and model fallback probes. A final
      // omission is recorded separately by the consumer with its context.
      runtimeDiagnostics.record(source === 'lookup' ? 'resource.lookup-failed' : 'resource.read-failed', error.message, { module: this.moduleName, resRef: name, resourceType, bifName,
        keySources: this.key.sources,
        resourceExtension: Object.keys(RESOURCE_TYPE).find(key => RESOURCE_TYPE[key] === resourceType), haks: this.haks.map(hak => hak.name), missingHaks: this.missingHaks, outcome: `${source === 'lookup' ? 'lookup' : 'archive read'} failed; consumer may recover with a fallback`, stack: error.stack }, source === 'lookup' ? 'info' : 'error');
      throw error;
    }
  }

  async getBifBytes(bifName) {
    if (!this.bifCache.has(bifName)) {
      const wanted = normalizePath(bifName);
      const candidates = this.files.filter((file) => {
        const path = normalizePath(filePath(file));
        return path === wanted || path.endsWith(`/${wanted}`);
      });
      if (candidates.length !== 1) {
        throw new Error(`Could not uniquely locate ${bifName} in the selected game-data folder.`);
      }
      this.bifCache.set(bifName, readFileBytes(candidates[0]));
    }
    return this.bifCache.get(bifName);
  }
}

// Native registration 0x140194a76/0x140194aec assigns retail priority
// 2,000,000 and base 1,000,000. AddKeyTable 0x14018e330 orders descending;
// GetKeyEntry 0x14018ffb0 takes the first match. Preserve each KEY's local BIF
// and resource index when combining catalogs. This only covers installed base
// and retail archives; localization/loose overrides need their own providers.
async function loadInstalledKeys(gameFiles) {
  const files = [...gameFiles], bifNames = [], resources = new Map(), sources = [];
  for (const name of ['nwn_retail.key', 'nwn_base.key']) {
    const matches = files.filter(file => filePath(file) === name || filePath(file).endsWith(`/${name}`));
    if (matches.length > 1) throw new Error(`Could not uniquely locate ${name} in the selected game-data folder.`);
    if (!matches.length) {
      if (name === 'nwn_base.key') throw new Error('The selected game-data folder must contain data/nwn_base.key.');
      runtimeDiagnostics.record('resource.key-missing', 'Installed retail resource KEY is unavailable; updated resources cannot be loaded', { resource: name });
      continue;
    }
    const key = parseKey(await readFileBytes(matches[0])), offset = bifNames.length;
    bifNames.push(...key.bifNames); sources.push(name);
    for (const [reference, entry] of key.resources) if (!resources.has(reference)) resources.set(reference, { ...entry, bifIndex: offset + entry.bifIndex, keySource: name });
  }
  return { bifNames, resources, sources };
}

export function decodeResourceText(buffer) {
  return textDecoder.decode(toBytes(buffer));
}

export async function readFileBytes(file) {
  if (file instanceof ArrayBuffer) return new Uint8Array(file);
  if (ArrayBuffer.isView(file)) return new Uint8Array(file.buffer, file.byteOffset, file.byteLength);
  if (file && typeof file.arrayBuffer === 'function') return new Uint8Array(await file.arrayBuffer());
  throw new TypeError('Expected a local File or binary buffer.');
}

function readBifResource(input, resourceIndex, expectedType, resref) {
  const bytes = toBytes(input);
  requireRange(bytes, 0, 20, 'BIF header');
  if (readTag(bytes, 0) !== 'BIFF') throw new Error(`Referenced BIF for ${resref} has an invalid signature.`);
  const version = readTag(bytes, 4);
  if (version !== 'V1  ' && version !== 'V1.1') throw new Error(`Unsupported BIF version ${version}.`);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const resourceCount = view.getUint32(8, true);
  const fixedCount = view.getUint32(12, true);
  const tableOffset = view.getUint32(16, true);
  if (fixedCount !== 0) throw new Error('Fixed-size BIF resources are not supported yet.');
  const entrySize = version === 'V1.1' ? 20 : 16;
  if (resourceIndex >= resourceCount) throw new Error(`BIF resource index for ${resref} is out of range.`);
  const entryOffset = tableOffset + resourceIndex * entrySize;
  requireRange(bytes, entryOffset, entrySize, 'BIF variable-resource table');
  let cursor = entryOffset + 4;
  if (version === 'V1.1') cursor += 4;
  const offset = view.getUint32(cursor, true);
  const size = view.getUint32(cursor + 4, true);
  const actualType = view.getUint32(cursor + 8, true);
  if (actualType !== expectedType) throw new Error(`KEY/BIF type mismatch for ${resref}: ${expectedType}/${actualType}.`);
  requireRange(bytes, offset, size, `BIF resource ${resref}`);
  return bytes.slice(offset, offset + size);
}

function resourceKey(resref, type) {
  return `${resref.toLowerCase()}:${type}`;
}

function filePath(file) {
  return normalizePath(file.webkitRelativePath || file.name || '');
}

function normalizePath(value) {
  return String(value).replaceAll('\\', '/').replace(/^\/+/, '').toLowerCase();
}

function readTag(bytes, offset) {
  requireRange(bytes, offset, 4, 'file signature');
  return String.fromCharCode(...bytes.subarray(offset, offset + 4));
}

function readFixedString(bytes, offset, length) {
  requireRange(bytes, offset, length, 'fixed string');
  const value = bytes.subarray(offset, offset + length);
  const end = value.indexOf(0);
  return new TextDecoder('ascii').decode(end < 0 ? value : value.subarray(0, end));
}

function toBytes(input) {
  if (input instanceof Uint8Array) return input;
  if (ArrayBuffer.isView(input)) return new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
  if (input instanceof ArrayBuffer) return new Uint8Array(input);
  throw new TypeError('Expected an ArrayBuffer or Uint8Array.');
}

function requireRange(bytes, offset, length, label) {
  if (!Number.isSafeInteger(offset) || !Number.isSafeInteger(length) || offset < 0 || length < 0 || offset + length > bytes.byteLength) {
    throw new Error(`${label} is out of range.`);
  }
}
