// Read highlight Part selector slots from the pinned native executable.
const fs = require('node:fs');
const crypto = require('node:crypto');
const binary = process.argv[2];
if (!binary) throw new Error('Usage: node audit-highlight-part-slots.cjs <nwmain.exe>');
const bytes = fs.readFileSync(binary);
const hash = crypto.createHash('sha256').update(bytes).digest('hex');
const expected = '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
if (hash !== expected) throw new Error(`Wrong binary: ${hash}`);
const pe = bytes.readUInt32LE(0x3c);
const optional = pe + 24;
const base = bytes.readBigUInt64LE(optional + 24);
const sectionTable = optional + bytes.readUInt16LE(pe + 20);
const sections = [];
for (let i = 0; i < bytes.readUInt16LE(pe + 6); i++) {
  const p = sectionTable + 40 * i;
  sections.push({rva:bytes.readUInt32LE(p + 12),size:bytes.readUInt32LE(p + 16),raw:bytes.readUInt32LE(p + 20)});
}
function qword(address) {
  const rva = Number(BigInt(address) - base);
  const section = sections.find(s => rva >= s.rva && rva + 8 <= s.rva + s.size);
  if (!section) throw new Error(`Unmapped address ${address}`);
  return `0x${bytes.readBigUInt64LE(section.raw + rva - section.rva).toString(16)}`;
}
const ledger = JSON.parse(fs.readFileSync('tools/nwn75/part-draw-rtti-census-ledger.json', 'utf8'));
const rows = ledger.edges.map(e => ({class:e.class,vtable:e.from,as_tri_mesh:qword(BigInt(e.from)+0x58n),as_skin:qword(BigInt(e.from)+0xa0n)}));
const scene_texture_setter = qword(0x140d8dd30n + 0x128n);
const texture_bind = qword(0x140d90c70n + 0x100n);
process.stdout.write(JSON.stringify({binary_sha256:hash,scene_texture_setter,texture_bind,rows},null,2) + '\n');
