// Selected stable BIC continuity, not authentication or entire-character parity.
// No resource/TLK lookup, game state, filesystem, rendering, or raw BIC retention.
import { createHash } from 'node:crypto';
import { parseGff, getGffFieldTypes, getGffStructType } from '../../src/gff.js';

const SOURCE = 'native-handoff-character-v1';
const POLICY_SCOPE = 'selected-character-fields-and-spells-v2';
const MAX_BYTES = 32 * 1024 * 1024, MAX_NODES = 200_000, MAX_DEPTH = 64;
const IDENTITY = Object.freeze(['FirstName','LastName','Gender','Race','Subrace','Age','Deity','Tag','Description']);
const ABILITIES = Object.freeze(['Str','Dex','Con','Int','Wis','Cha']);
const PROGRESSION = Object.freeze(['Experience','Gold','SkillPoints','SkillList','FeatList','LvlStatList']);
const CLASS_FIELDS = Object.freeze(['Class','ClassLevel','School','Domain1','Domain2']);
// SaveClassInfo has exactly ten native levels; observe only present fields.
const isSpellList = label => /^(?:KnownList|MemorizedList)[0-9]$/.test(label) || label === 'SpellsPerDayList';
const ITEM_TRANSIENT = Object.freeze(['ObjectId','XPosition','YPosition','ZPosition','XOrientation','YOrientation','ZOrientation','Repos_PosX','Repos_Posy']);
const ROOT_FIELDS = new Set([...IDENTITY,...ABILITIES,...PROGRESSION,'ClassList','Equip_ItemList','ItemList']);
const ITEM_IGNORED = new Set(ITEM_TRANSIENT);
const hash = value => createHash('sha256').update(value).digest('hex');
const clone = value => JSON.parse(JSON.stringify(value));
const sorted = values => values.sort((a,b) => {
  const x = stable(a), y = stable(b); return x < y ? -1 : x > y ? 1 : 0;
});
function stable(value) {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return '[' + value.map(stable).join(',') + ']';
  return '{' + Object.keys(value).sort().map(k => JSON.stringify(k) + ':' + stable(value[k])).join(',') + '}';
}
function bytesOf(input) {
  if (input instanceof ArrayBuffer) return new Uint8Array(input);
  if (ArrayBuffer.isView(input)) return new Uint8Array(input.buffer,input.byteOffset,input.byteLength);
  throw new TypeError('BIC bytes must be an ArrayBuffer or byte view');
}

/** Parse the actual bytes once. `bytes` is a count; no raw bytes leave this API. */
export function readHandoffCharacter(input) {
  const bytes = bytesOf(input);
  if (bytes.byteLength > MAX_BYTES) throw Error('BIC continuity input exceeds 32 MiB');
  return {kind:'bic',bytes:bytes.byteLength,sha256:hash(bytes),parsedOriginal:true,
    character:projectHandoffCharacter(parseGff(bytes,'BIC '))};
}

/** Requires actual parseGff metadata. An authored character object is not input. */
export function projectHandoffCharacter(parsed) {
  if (parsed?.fileType !== 'BIC ' || !['V3.2','V3.3'].includes(parsed.version) || !getGffFieldTypes(parsed.root))
    throw Error('Actual parsed BIC and its GFF field metadata are required');
  const root = parsed.root, missingCore = [], invalidCore = [], itemOmissions = new Set();
  let nodes = 0, itemCount = 0;
  function visit(depth) {
    if (++nodes > MAX_NODES || depth > MAX_DEPTH) throw Error('BIC continuity structure budget exceeded');
  }
  function field(record,label,depth = 0,domain = 'plain') {
    const types = getGffFieldTypes(record);
    if (!types) throw Error('Parsed GFF record metadata is unavailable');
    if (!Object.hasOwn(record,label)) return {present:false};
    if (!Object.hasOwn(types,label)) throw Error('GFF field type is unavailable: ' + label);
    return {present:true,type:types[label],value:value(record[label],types[label],depth + 1,domain,label)};
  }
  function record(input,depth,domain = 'plain',selected = null) {
    visit(depth);
    if (!getGffFieldTypes(input) || getGffStructType(input) === undefined) throw Error('Parsed GFF structure metadata is unavailable');
    if (domain === 'item') {
      itemCount++;
      requireField(input,'BaseItem',`item[${itemCount - 1}].BaseItem`,[0,1,2,3,4,5]);
    }
    const fields = {};
    for (const label of (selected ?? Object.keys(input)).slice().sort()) {
      if (domain === 'item' && ITEM_IGNORED.has(label)) { itemOmissions.add(label); continue; }
      fields[label] = field(input,label,depth,domain);
    }
    return {structType:getGffStructType(input),fields};
  }
  function value(input,type,depth,domain,label) {
    visit(depth);
    if (type === 14) return record(input,depth);
    if (type === 15) {
      if (!Array.isArray(input)) throw Error('GFF list is not an array');
      const items = input.map(v => record(v,depth,domain === 'item' && label === 'ItemList' ? 'item' : 'plain'));
      // Container order/grid is excluded, while duplicate item multiplicity stays.
      return domain === 'item' && label === 'ItemList' ? sorted(items) : items;
    }
    if (type === 6 || type === 7) {
      if (typeof input !== 'bigint') throw Error('GFF 64-bit integer has lost precision');
      return {decimal:input.toString()};
    }
    if (type === 12) {
      if (!input || !Number.isInteger(input.strRef) || !Array.isArray(input.entries)) throw Error('Malformed parsed localized string');
      // Preserve language entry order as well as raw references; no TLK resolution.
      return {strRef:input.strRef,entries:input.entries.map(e => {
        if (!Number.isInteger(e.languageId) || typeof e.text !== 'string') throw Error('Malformed localized entry');
        return {languageId:e.languageId,text:e.text};
      })};
    }
    if (type === 13) return {hex:Buffer.from(bytesOf(input)).toString('hex')};
    if (type === 16 || type === 17) {
      if (!Array.isArray(input) || input.length !== (type === 16 ? 4 : 3) || input.some(v => !Number.isFinite(v))) throw Error('Malformed GFF vector');
      return input.slice();
    }
    if (typeof input === 'string' && (type === 10 || type === 11)) return input;
    if (typeof input === 'number' && Number.isFinite(input) && (type <= 5 || type === 8 || type === 9 || type === 18)) return input;
    throw Error('Unsupported or non-finite GFF field value: ' + label);
  }
  function requireField(record,label,path,types) {
    if (!Object.hasOwn(record,label)) missingCore.push(path);
    else if (!types.includes(getGffFieldTypes(record)?.[label])) invalidCore.push(path);
  }
  for (const label of ['FirstName','LastName']) requireField(root,label,label,[12]);
  for (const label of ['Gender','Race',...ABILITIES]) requireField(root,label,label,[0]);
  for (const label of ['ClassList','Equip_ItemList','ItemList']) requireField(root,label,label,[15]);
  const classes = Array.isArray(root.ClassList) ? root.ClassList.map((c,index) => {
    // Installed BIC uses INT Class and SHORT ClassLevel. Preserve every actual
    // integer width in the digest, rather than rejecting native signed SHORT.
    for (const label of ['Class','ClassLevel']) requireField(c,label,`ClassList[${index}].${label}`,[0,1,2,3,4,5]);
    if (Object.hasOwn(c,'Class') && (!Number.isSafeInteger(c.Class) || c.Class < 0)) invalidCore.push(`ClassList[${index}].Class.value`);
    if (Object.hasOwn(c,'ClassLevel') && (!Number.isSafeInteger(c.ClassLevel) || c.ClassLevel < 1)) invalidCore.push(`ClassList[${index}].ClassLevel.value`);
    const projected = record(c,0,'plain',CLASS_FIELDS);
    const family = prefix => {
      const labels = Object.keys(c).filter(label => new RegExp('^' + prefix + '[0-9]$').test(label)).sort();
      return {present:labels.length > 0,fields:Object.fromEntries(labels.map(label => [label,field(c,label)]))};
    };
    projected.spellbook={known:family('KnownList'),memorized:family('MemorizedList'),dailyUses:field(c,'SpellsPerDayList')};
    for (const label of Object.keys(c).filter(isSpellList))
      if (getGffFieldTypes(c)[label] !== 15) invalidCore.push(`ClassList[${index}].${label}.type`);
    return projected;
  }) : null;
  if (classes?.length === 0) invalidCore.push('ClassList.empty');
  function itemList(label,equipment) {
    if (!Object.hasOwn(root,label)) return {present:false};
    const type = getGffFieldTypes(root)[label];
    if (type !== 15 || !Array.isArray(root[label])) return field(root,label);
    const items = root[label].map(item => record(item,0,'item'));
    if (equipment) {
      const slots = new Set();
      for (const item of items) {
        if (slots.has(item.structType)) invalidCore.push('Equip_ItemList.duplicateSlot:' + item.structType);
        slots.add(item.structType);
      }
      items.sort((a,b) => a.structType - b.structType);
    } else sorted(items);
    return {present:true,type,value:items};
  }
  const canonical = {
    identity:Object.fromEntries(IDENTITY.map(k => [k,field(root,k)])),
    abilities:Object.fromEntries(ABILITIES.map(k => [k,field(root,k)])),
    progression:Object.fromEntries(PROGRESSION.map(k => [k,field(root,k)])),
    classes:Object.hasOwn(root,'ClassList') ? {present:true,type:getGffFieldTypes(root).ClassList,value:classes ?? field(root,'ClassList').value} : {present:false},
    equipment:itemList('Equip_ItemList',true),inventory:itemList('ItemList',false),
  };
  const coverage = {missingCore,invalidCore,classCount:classes?.length ?? null,itemCount,
    scope:POLICY_SCOPE};
  return {version:1,source:SOURCE,complete:missingCore.length === 0 && invalidCore.length === 0,
    semanticSha256:hash(stable(canonical)),canonical,coverage,
    omitted:{rootFields:Object.keys(root).filter(k => !ROOT_FIELDS.has(k)).sort(),
      classFields:Array.isArray(root.ClassList) ? root.ClassList.map(c => Object.keys(c).filter(k => !CLASS_FIELDS.includes(k) && !isSpellList(k)).sort()) : [],
      itemFields:[...itemOmissions].sort(),itemPolicy:ITEM_TRANSIENT.slice(),
      note:'Raw SHA covers the entire BIC. Semantic equality covers only canonical fields; omitted fields are not certified equal.'}};
}

function proof(input) {
  const p = input?.character ?? input;
  if (p?.version !== 1 || p.source !== SOURCE || !p.canonical || !p.coverage || typeof p.complete !== 'boolean')
    throw Error('A handoff character proof is required');
  const encoded = stable(p.canonical);
  if (encoded.length > 2 * MAX_BYTES || hash(encoded) !== p.semanticSha256) throw Error('Character proof semantic hash does not match');
  return p;
}
/** Bounded differences, retaining total count. Partial coverage never passes. */
export function compareHandoffCharacters(before,after) {
  const a = proof(before), b = proof(after), differences = []; let differenceCount = 0;
  const comparablePolicy = a.coverage.scope === POLICY_SCOPE && b.coverage.scope === POLICY_SCOPE;
  function walk(x,y,path) {
    if (stable(x) === stable(y)) return;
    if (x && y && typeof x === 'object' && typeof y === 'object' && Array.isArray(x) === Array.isArray(y)) {
      for (const k of [...new Set([...Object.keys(x),...Object.keys(y)])].sort()) walk(x[k],y[k],path + '/' + k);
    } else {
      differenceCount++;
      if (differences.length < 64) differences.push({path,before:x === undefined ? {absent:true} : clone(x),after:y === undefined ? {absent:true} : clone(y)});
    }
  }
  walk(a.canonical,b.canonical,'');
  return {version:1,source:SOURCE,success:comparablePolicy && a.complete && b.complete && differenceCount === 0,
    availableEqual:differenceCount === 0,complete:comparablePolicy && a.complete && b.complete,comparablePolicy,
    rawEqual:typeof before?.sha256 === 'string' && typeof after?.sha256 === 'string' ? before.sha256 === after.sha256 : null,
    differenceCount,differences,differencesTruncated:differenceCount > differences.length,
    beforeSha256:a.semanticSha256,afterSha256:b.semanticSha256,
    coverage:{before:clone(a.coverage),after:clone(b.coverage)}};
}

/** Initial upload is shown separately. No normalization/allow-difference masks. */
export function compareHandoffCharacterChain({downloadA,downloadB,finalExport,initial = null,requireInitial = false}) {
  if (requireInitial && !initial) throw Error('Exact initial continuity requested without initial BIC proof');
  const comparisons = [
    {from:'downloadA',to:'downloadB',...compareHandoffCharacters(downloadA,downloadB)},
    {from:'downloadB',to:'finalExport',...compareHandoffCharacters(downloadB,finalExport)},
  ];
  const initialComparison = initial ? {from:'initial',to:'downloadA',required:requireInitial,...compareHandoffCharacters(initial,downloadA)} : null;
  return {version:1,source:SOURCE,success:comparisons.every(c => c.success) && (!requireInitial || initialComparison.success),
    comparisons,initialComparison,scope:'Selected stable BIC fields only; server changes remain differences, never masked.'};
}
