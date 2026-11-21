const fs = require('node:fs');

const [binaryPath, ...addresses] = process.argv.slice(2);
if (!binaryPath || !addresses.length) throw new Error('Usage: node pe-function-range.cjs <PE path> <virtual address>...');
const bytes = fs.readFileSync(binaryPath);
const pe = bytes.readUInt32LE(0x3c);
if (bytes.toString('ascii', pe, pe + 4) !== 'PE\0\0') throw new Error('Not a PE image');
const sectionCount = bytes.readUInt16LE(pe + 6);
const optional = pe + 24;
if (bytes.readUInt16LE(optional) !== 0x20b) throw new Error('Expected PE32+');
const imageBase = Number(bytes.readBigUInt64LE(optional + 24));
const sectionTable = optional + bytes.readUInt16LE(pe + 20);
const sections = [];
for (let i = 0; i < sectionCount; i++) {
  const h = sectionTable + i * 40;
  sections.push({name: bytes.toString('ascii', h, h + 8).replace(/\0.*$/, ''), va: bytes.readUInt32LE(h + 12), size: bytes.readUInt32LE(h + 16), raw: bytes.readUInt32LE(h + 20)});
}
const pdata = sections.find(x => x.name === '.pdata');
if (!pdata || pdata.raw + pdata.size > bytes.length) throw new Error('Missing or invalid .pdata');
const ranges = [];
for (let p = pdata.raw; p + 12 <= pdata.raw + pdata.size; p += 12) {
  const begin = bytes.readUInt32LE(p), end = bytes.readUInt32LE(p + 4);
  if (begin && end > begin) ranges.push({begin, end});
}
const results = addresses.map(value => {
  const address = Number(BigInt(value));
  const rva = address - imageBase;
  const matches = ranges.filter(r => r.begin <= rva && rva < r.end);
  return {address: `0x${address.toString(16)}`, ranges: matches.map(r => ({begin: `0x${(imageBase + r.begin).toString(16)}`, endExclusive: `0x${(imageBase + r.end).toString(16)}`}))};
});
process.stdout.write(JSON.stringify({results}, null, 2) + '\n');
