// Resolves pinned PE export RVA entries and names; an export is an external
// callable boundary, not evidence that a caller actually invokes it.
const fs = require('node:fs');
const crypto = require('node:crypto');

const [binaryPath, ...args] = process.argv.slice(2);
const nameOption = args.find(value => value.startsWith('--name-contains='));
const limitOption = args.find(value => value.startsWith('--limit='));
const wanted = args.filter(value => value !== nameOption && value !== limitOption);
if (!binaryPath || (!wanted.length && !nameOption)) throw new Error('Usage: node inspect-pe-exports.cjs <PE path> <virtual address>... | --name-contains=<text> [--limit=N]');
const bytes = fs.readFileSync(binaryPath);
const digest = crypto.createHash('sha256').update(bytes).digest('hex');
if (digest !== '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a') throw new Error('Binary SHA-256 mismatch');
const pe = bytes.readUInt32LE(0x3c);
if (bytes.toString('ascii', pe, pe + 4) !== 'PE\0\0') throw new Error('Not a PE image');
const optional = pe + 24;
const base = bytes.readBigUInt64LE(optional + 24);
const sectionTable = optional + bytes.readUInt16LE(pe + 20);
const sections = [];
for (let i = 0; i < bytes.readUInt16LE(pe + 6); i++) {
  const at = sectionTable + i * 40;
  sections.push({rva: bytes.readUInt32LE(at + 12), size: bytes.readUInt32LE(at + 16), raw: bytes.readUInt32LE(at + 20)});
}
function offset(rva) {
  const section = sections.find(s => rva >= s.rva && rva < s.rva + s.size);
  if (!section) throw new Error(`Unmapped RVA 0x${rva.toString(16)}`);
  return section.raw + rva - section.rva;
}
function stringAt(rva) {
  const at = offset(rva);
  const end = bytes.indexOf(0, at);
  if (end < 0) throw new Error('Unterminated export name');
  return bytes.toString('ascii', at, end);
}
const directoryRva = bytes.readUInt32LE(optional + 112);
const directorySize = bytes.readUInt32LE(optional + 116);
const dir = offset(directoryRva);
const ordinalBase = bytes.readUInt32LE(dir + 16);
const functionCount = bytes.readUInt32LE(dir + 20);
const nameCount = bytes.readUInt32LE(dir + 24);
const functionTable = offset(bytes.readUInt32LE(dir + 28));
const nameTable = offset(bytes.readUInt32LE(dir + 32));
const ordinalTable = offset(bytes.readUInt32LE(dir + 36));
const namesByIndex = new Map();
for (let i = 0; i < nameCount; i++) {
  const index = bytes.readUInt16LE(ordinalTable + i * 2);
  const names = namesByIndex.get(index) || [];
  names.push(stringAt(bytes.readUInt32LE(nameTable + i * 4)));
  namesByIndex.set(index, names);
}
const results = wanted.map(address => {
  const rva = Number(BigInt(address) - base);
  const entries = [];
  for (let i = 0; i < functionCount; i++) {
    if (bytes.readUInt32LE(functionTable + i * 4) !== rva) continue;
    entries.push({ordinal: ordinalBase + i, names: namesByIndex.get(i) || [], forwarder: rva >= directoryRva && rva < directoryRva + directorySize});
  }
  return {address, entries};
});
let matchingNames;
if (nameOption) {
  const term = nameOption.slice('--name-contains='.length).toLowerCase();
  const limit = limitOption ? Number(limitOption.slice('--limit='.length)) : 100;
  if (!term || !Number.isInteger(limit) || limit < 1 || limit > 10000) throw new Error('Invalid name term or limit');
  matchingNames = [];
  for (let i = 0; i < functionCount; i++) {
    const names = (namesByIndex.get(i) || []).filter(name => name.toLowerCase().includes(term));
    if (!names.length) continue;
    matchingNames.push({address: `0x${(base + BigInt(bytes.readUInt32LE(functionTable + i * 4))).toString(16)}`, ordinal: ordinalBase + i, names});
  }
  matchingNames = {count: matchingNames.length, entries: matchingNames.slice(0, limit)};
}
process.stdout.write(JSON.stringify({binary_sha256: digest, exportDirectoryRva: `0x${directoryRva.toString(16)}`, functionCount, nameCount, results, matchingNames}, null, 2) + '\n');
