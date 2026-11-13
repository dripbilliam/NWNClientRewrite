// Static byte-level E8/E9 inventory for one pinned-PE code range.
// Decode matches as candidates until an instruction-aware analysis confirms them.
const fs = require('node:fs');
const crypto = require('node:crypto');
const [binaryPath, startText, endText] = process.argv.slice(2);
if (!binaryPath || !startText || !endText) {
  throw new Error('Usage: node list-pe-range-calls.cjs <pinned PE> <start VA> <end-exclusive VA>');
}
const bytes = fs.readFileSync(binaryPath);
const sha256 = crypto.createHash('sha256').update(bytes).digest('hex');
if (sha256 !== '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a') {
  throw new Error(`Unexpected original-binary SHA-256 ${sha256}`);
}
const pe = bytes.readUInt32LE(0x3c);
if (bytes.toString('ascii', pe, pe + 4) !== 'PE\0\0') throw new Error('Not a PE image');
const optional = pe + 24;
if (bytes.readUInt16LE(optional) !== 0x20b) throw new Error('Expected PE32+');
const base = Number(bytes.readBigUInt64LE(optional + 24));
const sectionCount = bytes.readUInt16LE(pe + 6);
const table = optional + bytes.readUInt16LE(pe + 20);
const sections = [];
for (let i = 0; i < sectionCount; i++) {
  const h = table + 40 * i;
  sections.push({name: bytes.toString('ascii', h, h + 8).replace(/\0.*$/, ''),
    va: base + bytes.readUInt32LE(h + 12), raw: bytes.readUInt32LE(h + 20),
    size: bytes.readUInt32LE(h + 16), characteristics: bytes.readUInt32LE(h + 36)});
}
const start = Number(BigInt(startText)), end = Number(BigInt(endText));
if (end <= start || end - start > 0x100000) throw new Error('Invalid range');
const section = sections.find(x => (x.characteristics & 0x20000000) && start >= x.va && end <= x.va + x.size);
if (!section || section.raw + section.size > bytes.length) throw new Error('Range is not in initialized executable bytes');
const results = [];
for (let site = start; site + 5 <= end; site++) {
  const offset = section.raw + site - section.va;
  const opcode = bytes[offset];
  if (opcode !== 0xe8 && opcode !== 0xe9) continue;
  const target = site + 5 + bytes.readInt32LE(offset + 1);
  results.push({site: `0x${site.toString(16)}`, opcode: opcode === 0xe8 ? 'CALL rel32' : 'JMP rel32',
    target: `0x${target.toString(16)}`});
}
process.stdout.write(JSON.stringify({binary_sha256: sha256, start: startText, endExclusive: endText,
  warning: 'Byte-level candidates; overlapping/data bytes can be false instructions.', count: results.length, results}, null, 2) + '\n');
