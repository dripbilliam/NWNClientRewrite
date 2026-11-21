// Read +0x30/+0x38/+0x40 slots for the Part primary RTTI tables already enumerated
// by the independently checked Part Draw census. Candidate targets do not
// establish runtime construction or hit-test admission.
const fs = require('node:fs');
const crypto = require('node:crypto');
const file = process.argv[2];
if (!file) throw new Error('Usage: node audit-part-hitcheck-vtables.cjs <pinned nwmain.exe>');
const bytes = fs.readFileSync(file);
const digest = crypto.createHash('sha256').update(bytes).digest('hex');
const expected = '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
if (digest !== expected) throw new Error(`Wrong binary: ${digest}`);
const ledger = JSON.parse(fs.readFileSync(`${__dirname}/part-draw-rtti-census-ledger.json`, 'utf8'));
if (ledger.binary_sha256 !== digest || ledger.edges.length !== 18) throw new Error('Part RTTI census changed');
const pe = bytes.readUInt32LE(0x3c);
const opt = pe + 24;
const imageBase = bytes.readBigUInt64LE(opt + 24);
const sect = opt + bytes.readUInt16LE(pe + 20);
const sections = [];
for (let i = 0; i < bytes.readUInt16LE(pe + 6); i++) {
  const p = sect + 40 * i;
  sections.push({ rva: bytes.readUInt32LE(p + 12), raw: bytes.readUInt32LE(p + 20), size: bytes.readUInt32LE(p + 16) });
}
function pointer(va) {
  const rva = Number(va - imageBase);
  const s = sections.find(x => rva >= x.rva && rva + 8 <= x.rva + x.size);
  if (!s) throw new Error(`Unmapped slot 0x${va.toString(16)}`);
  return `0x${bytes.readBigUInt64LE(s.raw + rva - s.rva).toString(16)}`;
}
const rows = ledger.edges.map(e => {
  const vt = BigInt(e.from);
  return { type: e.class, vtable: e.from, getAurObject: pointer(vt + 0x30n), hitCheck: pointer(vt + 0x38n), hitCheckGeom: pointer(vt + 0x40n) };
});
process.stdout.write(JSON.stringify({ binary_sha256: digest, count: rows.length, rows }, null, 2) + '\n');
