// Static MSVC RTTI/vftable scan of the installed PE. It reports candidates;
// constructor/vtable ownership must be checked before assigning a class slot.
const fs = require('node:fs');
const [binaryPath] = process.argv.slice(2);
if (!binaryPath) throw new Error('Usage: node census-rtti-gui-update.cjs <PE path>');
const bytes = fs.readFileSync(binaryPath);
const pe = bytes.readUInt32LE(0x3c);
if (bytes.toString('ascii', pe, pe + 4) !== 'PE\0\0') throw new Error('Not PE');
const optional = pe + 24;
if (bytes.readUInt16LE(optional) !== 0x20b) throw new Error('Expected PE32+');
const imageBase = Number(bytes.readBigUInt64LE(optional + 24));
const count = bytes.readUInt16LE(pe + 6);
const table = optional + bytes.readUInt16LE(pe + 20);
const sections = Array.from({length: count}, (_, i) => {
  const h = table + i * 40;
  return {
    name: bytes.toString('ascii', h, h + 8).replace(/\0.*$/, ''),
    rva: bytes.readUInt32LE(h + 12),
    rawSize: bytes.readUInt32LE(h + 16),
    raw: bytes.readUInt32LE(h + 20),
    chars: bytes.readUInt32LE(h + 36),
  };
});
const rdata = sections.find(s => s.name === '.rdata');
const data = sections.find(s => s.name === '.data');
if (!rdata || !data) throw new Error('Missing .rdata/.data');
const atRva = rva => {
  const s = sections.find(v => v.rva <= rva && rva + 8 <= v.rva + v.rawSize);
  return s ? s.raw + rva - s.rva : -1;
};
const hex = v => `0x${v.toString(16)}`;
const typeNames = [];
for (let p = data.raw + 16; p < data.raw + data.rawSize - 8; p++) {
  if (bytes[p] !== 0x2e || bytes[p + 1] !== 0x3f || bytes[p + 2] !== 0x41 || ![0x56, 0x55].includes(bytes[p + 3])) continue;
  let end = p + 4;
  while (end < p + 300 && bytes[end] !== 0) end++;
  if (end >= p + 300) continue;
  const name = bytes.toString('ascii', p, end);
  if (!name.endsWith('@@')) continue;
  typeNames.push({name, descriptorRva: data.rva + p - data.raw - 16});
  p = end;
}
const typeByRva = new Map(typeNames.map(t => [t.descriptorRva, t.name]));
const colByVa = new Map();
for (let c = rdata.raw; c < rdata.raw + rdata.rawSize - 24; c += 4) {
  if (bytes.readUInt32LE(c) !== 1) continue;
  const name = typeByRva.get(bytes.readUInt32LE(c + 12));
  if (!name || bytes.readUInt32LE(c + 20) !== rdata.rva + c - rdata.raw) continue;
  colByVa.set(imageBase + rdata.rva + c - rdata.raw, {name,objectOffset:bytes.readUInt32LE(c+4)});
}
const candidates = [];
for (let p = rdata.raw; p < rdata.raw + rdata.rawSize - 8; p += 8) {
    const colVa = Number(bytes.readBigUInt64LE(p));
    const col = colByVa.get(colVa);
    if (!col) continue;
    const vtableVa = imageBase + rdata.rva + p - rdata.raw + 8;
    const slotOff = atRva(vtableVa + 0x58 - imageBase);
    if (slotOff >= 0) {
      const target = Number(bytes.readBigUInt64LE(slotOff));
      const targetSection = sections.find(s => (s.chars & 0x20000000) && imageBase + s.rva <= target && target < imageBase + s.rva + s.rawSize);
      if (targetSection) candidates.push({name:col.name,objectOffset:col.objectOffset,vtable:hex(vtableVa),slot:hex(vtableVa+0x58),target:hex(target),col:hex(colVa)});
    }
}
process.stdout.write(JSON.stringify({binaryPath,typeNameCount:typeNames.length,colCount:colByVa.size,candidates}, null, 2)+'\n');
