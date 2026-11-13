const fs = require('node:fs');

const [binaryPath, ...argumentsAfterPath] = process.argv.slice(2);
const trailingOption = argumentsAfterPath.find(value => value.startsWith('--trailing-bytes='));
const trailingBytes = trailingOption ? Number(trailingOption.split('=', 2)[1]) : 0;
if (!Number.isInteger(trailingBytes) || trailingBytes < 0 || trailingBytes > 8) {
  throw new Error('Trailing-byte count must be an integer between 0 and 8');
}
const targetText = argumentsAfterPath.filter(value => value !== trailingOption);
if (!binaryPath || !targetText.length) {
  throw new Error('Usage: node scan-rip-references.cjs <PE path> <virtual address>...');
}
const bytes = fs.readFileSync(binaryPath);
const pe = bytes.readUInt32LE(0x3c);
if (bytes.toString('ascii', pe, pe + 4) !== 'PE\0\0') throw new Error('Not a PE image');
const count = bytes.readUInt16LE(pe + 6);
const optional = pe + 24;
if (bytes.readUInt16LE(optional) !== 0x20b) throw new Error('Expected PE32+');
const imageBase = Number(bytes.readBigUInt64LE(optional + 24));
const sectionTable = optional + bytes.readUInt16LE(pe + 20);
const targets = new Set(targetText.map(value => Number(BigInt(value))));
const hits = [];
for (let section = 0; section < count; section++) {
  const header = sectionTable + section * 40;
  const name = bytes.toString('ascii', header, header + 8).replace(/\0.*$/, '');
  const virtualAddress = bytes.readUInt32LE(header + 12);
  const rawSize = bytes.readUInt32LE(header + 16);
  const rawPointer = bytes.readUInt32LE(header + 20);
  const characteristics = bytes.readUInt32LE(header + 36);
  if (!(characteristics & 0x20000000) || rawPointer + rawSize > bytes.length) continue;
  for (let offset = 0; offset + 4 <= rawSize; offset++) {
    const displacement = bytes.readInt32LE(rawPointer + offset);
    // Most rel32 operands end their instruction. CMP/TEST encodings may have
    // an immediate after the displacement; --trailing-bytes accounts for it.
    const instructionEnd = imageBase + virtualAddress + offset + 4 + trailingBytes;
    const target = instructionEnd + displacement;
    if (!targets.has(target)) continue;
    const before = bytes.subarray(rawPointer + Math.max(0, offset - 8), rawPointer + offset).toString('hex');
    const after = bytes.subarray(rawPointer + offset + 4, rawPointer + Math.min(rawSize, offset + 12)).toString('hex');
    hits.push({target: `0x${target.toString(16)}`, displacementAt: `0x${(instructionEnd - 4 - trailingBytes).toString(16)}`, section: name, before, after});
  }
}
process.stdout.write(JSON.stringify({binaryPath, imageBase: `0x${imageBase.toString(16)}`, trailingBytes, targets: [...targets].map(v => `0x${v.toString(16)}`), hits}, null, 2) + '\n');
