const fs = require('node:fs');

const [binaryPath, ...targetText] = process.argv.slice(2);
if (!binaryPath || !targetText.length) {
  throw new Error('Usage: node scan-pointer-references.cjs <PE path> <virtual address>...');
}
const bytes = fs.readFileSync(binaryPath);
const pe = bytes.readUInt32LE(0x3c);
if (bytes.toString('ascii', pe, pe + 4) !== 'PE\0\0') throw new Error('Not a PE image');
const count = bytes.readUInt16LE(pe + 6);
const optional = pe + 24;
if (bytes.readUInt16LE(optional) !== 0x20b) throw new Error('Expected PE32+');
const imageBase = bytes.readBigUInt64LE(optional + 24);
const sectionTable = optional + bytes.readUInt16LE(pe + 20);
const targets = new Set(targetText.map(value => BigInt(value)));
const hits = [];
for (let section = 0; section < count; section++) {
  const header = sectionTable + section * 40;
  const name = bytes.toString('ascii', header, header + 8).replace(/\0.*$/, '');
  const virtualAddress = bytes.readUInt32LE(header + 12);
  const rawSize = bytes.readUInt32LE(header + 16);
  const rawPointer = bytes.readUInt32LE(header + 20);
  if (rawPointer + rawSize > bytes.length) continue;
  for (let offset = 0; offset + 8 <= rawSize; offset += 8) {
    const value = bytes.readBigUInt64LE(rawPointer + offset);
    if (!targets.has(value)) continue;
    const neighbors = [];
    for (let relative = -4; relative <= 8; relative++) {
      const neighborOffset = offset + relative * 8;
      if (neighborOffset < 0 || neighborOffset + 8 > rawSize) continue;
      neighbors.push({at: `0x${(imageBase + BigInt(virtualAddress + neighborOffset)).toString(16)}`, value: `0x${bytes.readBigUInt64LE(rawPointer + neighborOffset).toString(16)}`});
    }
    hits.push({target: `0x${value.toString(16)}`, pointerAt: `0x${(imageBase + BigInt(virtualAddress + offset)).toString(16)}`, section: name, neighbors});
  }
}
process.stdout.write(JSON.stringify({hits}, null, 2) + '\n');
