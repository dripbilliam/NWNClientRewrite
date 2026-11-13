// Find possible omitted literal CALL/JMP connectors into disconnected ledger nodes.
// A byte match is a candidate, not a proven instruction or runtime route.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const [binaryPath, ...requestedRoots] = process.argv.slice(2);
if (!binaryPath) throw new Error('Usage: node audit-disconnected-direct-callers.cjs <pinned PE> [root VA ...]');
const roots = requestedRoots.length ? requestedRoots : ['0x140c11bdc', '0x1400451c0', '0x140233980'];
const directory = __dirname;
const edges = fs.readdirSync(directory).filter(name => name.endsWith('ledger.json'))
  .flatMap(name => (JSON.parse(fs.readFileSync(path.join(directory, name), 'utf8')).edges || [])
    .filter(edge => edge.from && edge.to).map(edge => ({ ...edge, ledger: name })));
const adjacency = new Map();
for (const edge of edges) {
  if (!adjacency.has(edge.from)) adjacency.set(edge.from, new Set());
  adjacency.get(edge.from).add(edge.to);
}
const reachable = new Set(roots);
const queue = [...roots];
for (let i = 0; i < queue.length; i++) {
  for (const target of adjacency.get(queue[i]) || []) {
    if (!reachable.has(target)) { reachable.add(target); queue.push(target); }
  }
}
const disconnected = new Set([...adjacency.keys()].filter(value => /^0x[0-9a-f]+$/i.test(value) && !reachable.has(value)));

const bytes = fs.readFileSync(binaryPath);
const sha256 = crypto.createHash('sha256').update(bytes).digest('hex');
if (sha256 !== '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a') {
  throw new Error(`Unexpected original-binary SHA-256 ${sha256}`);
}
const pe = bytes.readUInt32LE(0x3c);
if (bytes.toString('ascii', pe, pe + 4) !== 'PE\0\0') throw new Error('Not a PE image');
const count = bytes.readUInt16LE(pe + 6);
const optional = pe + 24;
if (bytes.readUInt16LE(optional) !== 0x20b) throw new Error('Expected PE32+');
const base = Number(bytes.readBigUInt64LE(optional + 24));
const sectionTable = optional + bytes.readUInt16LE(pe + 20);
const sections = [];
for (let i = 0; i < count; i++) {
  const h = sectionTable + 40 * i;
  sections.push({name: bytes.toString('ascii', h, h + 8).replace(/\0.*$/, ''),
    va: bytes.readUInt32LE(h + 12), size: bytes.readUInt32LE(h + 16), raw: bytes.readUInt32LE(h + 20),
    characteristics: bytes.readUInt32LE(h + 36)});
}
const pdata = sections.find(section => section.name === '.pdata');
if (!pdata) throw new Error('Missing .pdata');
const ranges = [];
for (let p = pdata.raw; p + 12 <= pdata.raw + pdata.size; p += 12) {
  const begin = bytes.readUInt32LE(p), end = bytes.readUInt32LE(p + 4);
  if (begin && end > begin) ranges.push({begin: base + begin, end: base + end});
}
ranges.sort((a,b) => a.begin - b.begin);
function ownerOf(address) {
  let lo = 0, hi = ranges.length - 1;
  while (lo <= hi) {
    const mid = (lo + hi) >>> 1, range = ranges[mid];
    if (address < range.begin) hi = mid - 1;
    else if (address >= range.end) lo = mid + 1;
    else return range.begin;
  }
  return null;
}
const hits = [];
for (const section of sections.filter(section => section.characteristics & 0x20000000)) {
  if (section.raw + section.size > bytes.length) continue;
  for (let i = 0; i + 5 <= section.size; i++) {
    const opcode = bytes[section.raw + i];
    if (opcode !== 0xe8 && opcode !== 0xe9) continue;
    const site = base + section.va + i;
    const target = site + 5 + bytes.readInt32LE(section.raw + i + 1);
    const targetKey = `0x${target.toString(16)}`;
    if (!disconnected.has(targetKey)) continue;
    const owner = ownerOf(site);
    if (owner === null || !reachable.has(`0x${owner.toString(16)}`)) continue;
    const sourceKey = `0x${owner.toString(16)}`;
    // Ledgers use either the containing function plus `callsite`, or the
    // instruction address itself as `from`. Treat both as recorded sites.
    const siteKey = `0x${site.toString(16)}`;
    const alreadyRecorded = edges.some(edge => edge.to === targetKey &&
      (edge.callsite === siteKey || edge.from === siteKey || edge.from === sourceKey));
    if (!alreadyRecorded) hits.push({source: sourceKey, site: `0x${site.toString(16)}`,
      opcode: opcode === 0xe8 ? 'CALL rel32' : 'JMP rel32', target: targetKey});
  }
}
process.stdout.write(JSON.stringify({warning:'Candidates require instruction and gate verification; computed calls and pdata-less thunks are omitted.',
  binary_sha256: sha256, roots, reachableNodes: reachable.size,
  disconnectedOutgoingNodes: disconnected.size, candidateCount: hits.length, hits}, null, 2) + '\n');
