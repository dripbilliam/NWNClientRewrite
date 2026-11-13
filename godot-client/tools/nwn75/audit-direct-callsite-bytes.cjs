// Verifies literal E8/E9 rel32 and EB rel8 edges. Other instruction encodings are reported
// as unverified, never interpreted as absent calls or bad targets.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const binaryPath = process.argv[2];
if (!binaryPath) throw new Error('Usage: node audit-direct-callsite-bytes.cjs <pinned nwmain.exe>');
const bytes = fs.readFileSync(binaryPath);
const digest = crypto.createHash('sha256').update(bytes).digest('hex');
const expected = '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
if (digest !== expected) throw new Error(`Binary SHA-256 mismatch: ${digest}`);
const pe = bytes.readUInt32LE(0x3c);
if (bytes.toString('ascii', pe, pe + 4) !== 'PE\0\0') throw new Error('Not a PE image');
const optional = pe + 24;
const base = bytes.readBigUInt64LE(optional + 24);
const count = bytes.readUInt16LE(pe + 6);
const sectionTable = optional + bytes.readUInt16LE(pe + 20);
const sections = [];
for (let i = 0; i < count; i++) {
  const at = sectionTable + i * 40;
  sections.push({rva: bytes.readUInt32LE(at + 12), size: bytes.readUInt32LE(at + 16), raw: bytes.readUInt32LE(at + 20)});
}
function offsetOf(address) {
  const rva = Number(BigInt(address) - base);
  const section = sections.find(s => rva >= s.rva && rva + 5 <= s.rva + s.size);
  return section ? section.raw + rva - section.rva : null;
}
let candidates = 0;
let verified = 0;
const nonRel32 = [];
const mismatches = [];
const directKinds = new Set(['direct_static', 'direct_call', 'direct', 'conditional_direct',
  'original_direct_child', 'tail_jump', 'direct_jump_thunk', 'short_tail_jump',
  'original_jump_thunk', 'import_tail_jump', 'jump_thunk']);
for (const name of fs.readdirSync(__dirname).filter(n => n.endsWith('ledger.json'))) {
  const ledger = JSON.parse(fs.readFileSync(path.join(__dirname, name), 'utf8'));
  for (const edge of ledger.edges || []) {
    if (!directKinds.has(edge.kind)) continue;
    if (!/^0x[0-9a-f]+$/i.test(edge.to || '')) continue;
    const sites = [...new Set([edge.callsite || edge.call_site || edge.site,
      ...(Array.isArray(edge.callsites) ? edge.callsites : [])].filter(site => /^0x[0-9a-f]+$/i.test(site || '')))];
    for (const site of sites) {
      candidates++;
      const at = offsetOf(site);
      if (at === null || ![0xe8, 0xe9, 0xeb].includes(bytes[at])) {
        nonRel32.push({ledger: name, site, kind: edge.kind});
        continue;
      }
      const shortJump = bytes[at] === 0xeb;
      const actual = BigInt(site) + BigInt(shortJump ? 2 : 5) +
        BigInt(shortJump ? bytes.readInt8(at + 1) : bytes.readInt32LE(at + 1));
      if (actual !== BigInt(edge.to)) {
        mismatches.push({ledger: name, site, expected: edge.to, actual: `0x${actual.toString(16)}`});
      } else verified++;
    }
  }
}
process.stdout.write(JSON.stringify({binary_sha256: digest, candidates, verified, nonRel32Count: nonRel32.length, nonRel32Sample: nonRel32.slice(0, 20), mismatchCount: mismatches.length, mismatches: mismatches.slice(0, 20)}, null, 2) + '\n');
if (mismatches.length) process.exitCode = 1;
